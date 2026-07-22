import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handle background FCM messages (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background FCM message: ${message.messageId}');
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'payment_reminder';
  static const _channelName = 'Payment Reminders';
  static const _channelDesc = 'Monthly payment reminder notifications';

  static const _pushChannelId = 'push_notifications';
  static const _pushChannelName = 'Push Notifications';
  static const _pushChannelDesc = 'Real-time push notifications for group activity';

  /// Initialize notification plugin, timezone data, and FCM
  static Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);

    // Create notification channels
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _pushChannelId,
        _pushChannelName,
        description: _pushChannelDesc,
        importance: Importance.high,
      ),
    );

    // Set up FCM
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _setupFCM();

    _initialized = true;
    debugPrint('NotificationService initialized');
  }

  /// Set up Firebase Cloud Messaging
  static Future<void> _setupFCM() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle foreground messages — show as local notification
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Save FCM token to Firestore
    await _saveFcmToken();

    // Listen for token refresh
    messaging.onTokenRefresh.listen((token) => _saveFcmToken(token: token));
  }

  /// Save FCM token to Firestore for the current user
  static Future<void> _saveFcmToken({String? token}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      token ??= await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));

      debugPrint('FCM token saved for user ${user.uid}');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Handle FCM messages received while app is in foreground
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _notifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _pushChannelId,
          _pushChannelName,
          channelDescription: _pushChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
      ),
    );
  }

  /// Schedule reminders for all user's groups based on each group's reminderDay
  static Future<void> scheduleGroupReminders() async {
    if (!_initialized) await init();

    // Cancel all previously scheduled reminders
    await _notifications.cancelAll();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Get all groups the user is a member of
      final groupsSnapshot = await firestore
          .collection('groups')
          .where('memberIds', arrayContains: user.uid)
          .get();

      if (groupsSnapshot.docs.isEmpty) return;

      final myt = tz.getLocation('Asia/Kuala_Lumpur');
      final now = tz.TZDateTime.now(myt);

      for (int i = 0; i < groupsSnapshot.docs.length; i++) {
        final groupDoc = groupsSnapshot.docs[i];
        final data = groupDoc.data();
        final groupName = data['name'] ?? 'Group';
        final reminderDay = (data['reminderDay'] as int?) ?? 28;

        // Calculate next reminder date for this group
        var scheduled = tz.TZDateTime(myt, now.year, now.month, reminderDay, 9, 0);

        // If this month's reminder already passed, schedule for next month
        if (scheduled.isBefore(now)) {
          if (now.month == 12) {
            scheduled = tz.TZDateTime(myt, now.year + 1, 1, reminderDay, 9, 0);
          } else {
            scheduled = tz.TZDateTime(myt, now.year, now.month + 1, reminderDay, 9, 0);
          }
        }

        // Use unique notification ID per group (offset by 100 to avoid clash with immediate notifications)
        final notifId = 100 + i;

        await _notifications.zonedSchedule(
          notifId,
          'Payment Reminder - $groupName 💰',
          'Jangan lupa bayar yuran bulan ni untuk $groupName!',
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@drawable/ic_notification',
            ),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );

        debugPrint('Scheduled reminder for "$groupName" on day $reminderDay at 9:00 AM MYT');
      }
    } catch (e) {
      debugPrint('Error scheduling group reminders: $e');
    }
  }

  /// Check unpaid groups and show immediate notification if needed
  /// Called on app launch to remind user of unpaid months
  static Future<void> checkAndNotifyUnpaid() async {
    if (!_initialized) await init();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Get all groups the user is a member of
      final groupsSnapshot = await firestore
          .collection('groups')
          .where('memberIds', arrayContains: user.uid)
          .get();

      if (groupsSnapshot.docs.isEmpty) return;

      final now = DateTime.now();
      final targetMonth = now.month;
      final targetYear = now.year;

      List<String> unpaidGroups = [];

      for (final groupDoc in groupsSnapshot.docs) {
        final data = groupDoc.data();
        final groupName = data['name'] ?? 'Unknown Group';
        final reminderDay = (data['reminderDay'] as int?) ?? 28;

        // Only check groups where reminder day has passed
        if (now.day < reminderDay) continue;

        // Check if user paid for current month
        final paymentSnapshot = await firestore
            .collection('payments')
            .where('groupId', isEqualTo: groupDoc.id)
            .where('userId', isEqualTo: user.uid)
            .where('month', isEqualTo: targetMonth)
            .where('year', isEqualTo: targetYear)
            .limit(1)
            .get();

        if (paymentSnapshot.docs.isEmpty) {
          unpaidGroups.add(groupName);
        }
      }

      if (unpaidGroups.isEmpty) return;

      final groupList = unpaidGroups.join(', ');
      final message = unpaidGroups.length == 1
          ? 'Belum bayar yuran bulan ni untuk $groupList'
          : 'Belum bayar yuran bulan ni untuk ${unpaidGroups.length} group: $groupList';

      await _notifications.show(
        1,
        'Bayaran Belum Dibuat 🔔',
        message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
          ),
        ),
      );

      debugPrint('Showed unpaid notification for: $groupList');
    } catch (e) {
      debugPrint('Error checking unpaid status: $e');
    }
  }

  /// Schedule reminders for user's debts and bills based on each item's dueDay
  static Future<void> scheduleDebtAndBillReminders() async {
    if (!_initialized) await init();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Get all active debts/bills for this user
      final debtsSnapshot = await firestore
          .collection('debts')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      if (debtsSnapshot.docs.isEmpty) return;

      final myt = tz.getLocation('Asia/Kuala_Lumpur');
      final now = tz.TZDateTime.now(myt);

      for (int i = 0; i < debtsSnapshot.docs.length; i++) {
        final doc = debtsSnapshot.docs[i];
        final data = doc.data();
        final title = data['title'] ?? 'Payment';
        final type = data['type'] ?? 'debt';
        final dueDay = (data['dueDay'] as int?) ?? 1;
        final amount = (data['monthlyPayment'] ?? 0).toDouble();

        // Schedule 1 day before due date as reminder
        var reminderDay = dueDay - 1;
        if (reminderDay < 1) reminderDay = 28; // wrap to previous month end

        var scheduled = tz.TZDateTime(myt, now.year, now.month, reminderDay, 9, 0);

        // If this month's reminder already passed, schedule for next month
        if (scheduled.isBefore(now)) {
          if (now.month == 12) {
            scheduled = tz.TZDateTime(myt, now.year + 1, 1, reminderDay, 9, 0);
          } else {
            scheduled = tz.TZDateTime(myt, now.year, now.month + 1, reminderDay, 9, 0);
          }
        }

        // Use unique notification ID (offset by 500 to avoid clash with group reminders)
        final notifId = 500 + i;
        final isBill = type == 'bill';
        final label = isBill ? 'Bill' : 'Debt';
        final emoji = isBill ? '📋' : '💳';

        await _notifications.zonedSchedule(
          notifId,
          '$label Reminder - $title $emoji',
          'Bayaran ${isBill ? 'bil' : 'hutang'} "$title" RM${amount.toStringAsFixed(2)} due esok (day $dueDay)!',
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@drawable/ic_notification',
            ),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );

        debugPrint('Scheduled $label reminder for "$title" on day $reminderDay at 9:00 AM MYT');
      }
    } catch (e) {
      debugPrint('Error scheduling debt/bill reminders: $e');
    }
  }

  /// Check unpaid debts/bills for current month and show immediate notification
  static Future<void> checkAndNotifyUnpaidDebts() async {
    if (!_initialized) await init();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      final debtsSnapshot = await firestore
          .collection('debts')
          .where('userId', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      if (debtsSnapshot.docs.isEmpty) return;

      final now = DateTime.now();
      List<String> overdueItems = [];

      for (final doc in debtsSnapshot.docs) {
        final data = doc.data();
        final title = data['title'] ?? 'Unknown';
        final dueDay = (data['dueDay'] as int?) ?? 1;
        final type = data['type'] ?? 'debt';

        // Only check if due day has passed this month
        if (now.day < dueDay) continue;

        // Check if payment exists for current month
        final paymentSnapshot = await firestore
            .collection('debts')
            .doc(doc.id)
            .collection('payments')
            .where('month', isEqualTo: now.month)
            .where('year', isEqualTo: now.year)
            .limit(1)
            .get();

        if (paymentSnapshot.docs.isEmpty) {
          final label = type == 'bill' ? 'Bil' : 'Hutang';
          overdueItems.add('$label: $title');
        }
      }

      if (overdueItems.isEmpty) return;

      final message = overdueItems.length == 1
          ? 'Belum bayar ${overdueItems.first} bulan ni'
          : 'Belum bayar ${overdueItems.length} item bulan ni:\n${overdueItems.join('\n')}';

      await _notifications.show(
        3, // unique ID for debt/bill unpaid notification
        'Bayaran Tertunggak 🔔',
        message,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            styleInformation: BigTextStyleInformation(message),
          ),
        ),
      );

      debugPrint('Showed overdue debt/bill notification for: ${overdueItems.join(', ')}');
    } catch (e) {
      debugPrint('Error checking unpaid debts/bills: $e');
    }
  }

  /// Check if user was recently added to any group and notify them
  static Future<void> checkNewGroupMembership() async {
    if (!_initialized) await init();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Get all groups the user is a member of
      final groupsSnapshot = await firestore
          .collection('groups')
          .where('memberIds', arrayContains: user.uid)
          .get();

      if (groupsSnapshot.docs.isEmpty) return;

      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(hours: 24));

      for (final groupDoc in groupsSnapshot.docs) {
        final data = groupDoc.data();
        final groupName = data['name'] ?? 'Unknown Group';

        // Check when user joined this group
        final memberDoc = await firestore
            .collection('groups')
            .doc(groupDoc.id)
            .collection('members')
            .doc(user.uid)
            .get();

        if (!memberDoc.exists) continue;
        final memberData = memberDoc.data()!;
        final joinedAt = memberData['joinedAt'];
        if (joinedAt == null) continue;

        final joinDate = joinedAt is Timestamp ? joinedAt.toDate() : DateTime.tryParse(joinedAt.toString());
        if (joinDate == null) continue;

        // Only notify if joined within the last 24 hours and not the creator
        final createdBy = data['createdBy'];
        if (joinDate.isAfter(cutoff) && createdBy != user.uid) {
          // Check if we already notified (use notifiedJoined field)
          if (memberData['notifiedJoined'] == true) continue;

          await _notifications.show(
            groupDoc.id.hashCode,
            'Welcome to $groupName!',
            'You have been added to $groupName. Monthly amount: RM${(data['monthlyAmount'] ?? 0).toStringAsFixed(2)}',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                _channelName,
                channelDescription: _channelDesc,
                importance: Importance.high,
                priority: Priority.high,
                icon: '@drawable/ic_notification',
              ),
            ),
          );

          // Mark as notified
          await firestore
              .collection('groups')
              .doc(groupDoc.id)
              .collection('members')
              .doc(user.uid)
              .update({'notifiedJoined': true});

          debugPrint('Notified user of new membership in "$groupName"');
        }
      }
    } catch (e) {
      debugPrint('Error checking new group membership: $e');
    }
  }

  /// Returns the group docs where [uid] is an admin — either the creator or a
  /// member with `isAdmin == true`. Costs one member-doc read per group that
  /// isn't already owned by the user.
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _adminGroupDocs(FirebaseFirestore firestore, String uid) async {
    final groupsSnapshot = await firestore
        .collection('groups')
        .where('memberIds', arrayContains: uid)
        .get();

    final result = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in groupsSnapshot.docs) {
      if (doc.data()['createdBy'] == uid) {
        result.add(doc);
        continue;
      }
      final memberDoc = await firestore
          .collection('groups')
          .doc(doc.id)
          .collection('members')
          .doc(uid)
          .get();
      if (memberDoc.exists && memberDoc.data()?['isAdmin'] == true) {
        result.add(doc);
      }
    }
    return result;
  }

  /// For admins: check for recent payments and notify
  static Future<void> checkRecentPaymentsForAdmin() async {
    if (!_initialized) await init();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Groups where the user is an admin (creator or member.isAdmin).
      final adminGroupDocs = await _adminGroupDocs(firestore, user.uid);

      if (adminGroupDocs.isEmpty) return;

      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      List<String> recentPayments = [];

      for (final groupDoc in adminGroupDocs) {
        final data = groupDoc.data();
        final groupName = data['name'] ?? 'Unknown Group';

        // Get payments in the last 24 hours for this group (not by admin themselves)
        final paymentsSnapshot = await firestore
            .collection('payments')
            .where('groupId', isEqualTo: groupDoc.id)
            .where('createdAt', isGreaterThan: cutoff)
            .get();

        for (final paymentDoc in paymentsSnapshot.docs) {
          final paymentData = paymentDoc.data();
          final payerUserId = paymentData['userId'] as String?;
          if (payerUserId == user.uid) continue; // Skip own payments

          // Check if already notified
          if (paymentData['adminNotified'] == true) continue;

          final payerName = paymentData['userName'] ?? 'Someone';
          final amount = (paymentData['amount'] ?? 0).toDouble();
          recentPayments.add('$payerName paid RM${amount.toStringAsFixed(2)} for $groupName');

          // Mark as notified
          await firestore
              .collection('payments')
              .doc(paymentDoc.id)
              .update({'adminNotified': true});
        }
      }

      if (recentPayments.isEmpty) return;

      final message = recentPayments.length == 1
          ? recentPayments.first
          : '${recentPayments.length} new payments received:\n${recentPayments.join('\n')}';

      await _notifications.show(
        2,
        'Payment Received!',
        message,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            styleInformation: BigTextStyleInformation(message),
          ),
        ),
      );

      debugPrint('Notified admin of ${recentPayments.length} recent payments');
    } catch (e) {
      debugPrint('Error checking recent payments for admin: $e');
    }
  }

  /// For admins: notify about pending fund-loan requests that need approval.
  static Future<void> checkPendingFundLoansForAdmin() async {
    if (!_initialized) await init();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Groups where the user is an admin (creator or member.isAdmin).
      final adminGroupDocs = await _adminGroupDocs(firestore, user.uid);

      if (adminGroupDocs.isEmpty) return;

      List<String> requests = [];

      for (final groupDoc in adminGroupDocs) {
        final groupName = groupDoc.data()['name'] ?? 'Unknown Group';

        // Single equality filter (avoids composite index); status filtered below.
        final loansSnapshot = await firestore
            .collection('fund_loans')
            .where('groupId', isEqualTo: groupDoc.id)
            .get();

        for (final loanDoc in loansSnapshot.docs) {
          final d = loanDoc.data();
          if ((d['status'] ?? 'pending') != 'pending') continue;
          if (d['adminNotified'] == true) continue;
          if (d['createdBy'] == user.uid) continue; // skip own requests

          final borrower = d['borrowerName'] ?? 'A member';
          final amount = (d['principal'] ?? 0).toDouble();
          final title = d['title'] ?? '';
          requests.add('$borrower requested RM${amount.toStringAsFixed(2)} ($title) in $groupName');

          await firestore
              .collection('fund_loans')
              .doc(loanDoc.id)
              .update({'adminNotified': true});
        }
      }

      if (requests.isEmpty) return;

      final message = requests.length == 1
          ? requests.first
          : '${requests.length} loan requests need approval:\n${requests.join('\n')}';

      await _notifications.show(
        4,
        'Loan Request 🔔',
        message,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _pushChannelId,
            _pushChannelName,
            channelDescription: _pushChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            styleInformation: BigTextStyleInformation(message),
          ),
        ),
      );

      debugPrint('Notified admin of ${requests.length} pending fund-loan requests');
    } catch (e) {
      debugPrint('Error checking pending fund loans for admin: $e');
    }
  }

  /// For borrowers: notify when a fund-loan request is approved or rejected.
  static Future<void> checkFundLoanDecisionsForMember() async {
    if (!_initialized) await init();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Loans where the current user is the borrower.
      final loansSnapshot = await firestore
          .collection('fund_loans')
          .where('borrowerId', isEqualTo: user.uid)
          .get();

      if (loansSnapshot.docs.isEmpty) return;

      List<String> decisions = [];

      for (final loanDoc in loansSnapshot.docs) {
        final d = loanDoc.data();
        final status = d['status'] as String? ?? 'pending';
        if (status != 'approved' && status != 'rejected') continue;
        if (d['borrowerNotified'] == true) continue;

        final amount = (d['principal'] ?? 0).toDouble();
        final title = d['title'] ?? '';
        decisions.add(status == 'approved'
            ? 'Approved: RM${amount.toStringAsFixed(2)} for "$title"'
            : 'Rejected: your request for "$title"');

        await firestore
            .collection('fund_loans')
            .doc(loanDoc.id)
            .update({'borrowerNotified': true});
      }

      if (decisions.isEmpty) return;

      final message = decisions.length == 1
          ? decisions.first
          : '${decisions.length} loan updates:\n${decisions.join('\n')}';

      await _notifications.show(
        5,
        'Fund Loan Update 🔔',
        message,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _pushChannelId,
            _pushChannelName,
            channelDescription: _pushChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            styleInformation: BigTextStyleInformation(message),
          ),
        ),
      );

      debugPrint('Notified borrower of ${decisions.length} fund-loan decisions');
    } catch (e) {
      debugPrint('Error checking fund loan decisions for member: $e');
    }
  }
}
