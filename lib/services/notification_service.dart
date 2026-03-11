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

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
          icon: '@mipmap/ic_launcher',
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
              icon: '@mipmap/ic_launcher',
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
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );

      debugPrint('Showed unpaid notification for: $groupList');
    } catch (e) {
      debugPrint('Error checking unpaid status: $e');
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
                icon: '@mipmap/ic_launcher',
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

  /// For admins: check for recent payments and notify
  static Future<void> checkRecentPaymentsForAdmin() async {
    if (!_initialized) await init();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Get groups where user is admin
      final groupsSnapshot = await firestore
          .collection('groups')
          .where('memberIds', arrayContains: user.uid)
          .get();

      // Filter for groups where user is admin (creator)
      final adminGroupDocs = groupsSnapshot.docs
          .where((doc) => doc.data()['createdBy'] == user.uid)
          .toList();

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
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            styleInformation: BigTextStyleInformation(''),
          ),
        ),
      );

      debugPrint('Notified admin of ${recentPayments.length} recent payments');
    } catch (e) {
      debugPrint('Error checking recent payments for admin: $e');
    }
  }
}
