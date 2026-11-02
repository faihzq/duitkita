import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
  static const _pushChannelDesc =
      'Real-time push notifications for group activity';

  // Match reminders get their own channel so they can be muted or made
  // louder without touching payment and group alerts.
  static const _matchChannelId = 'match_reminders';
  static const _matchChannelName = 'Match reminders';
  static const _matchChannelDesc = 'JDT and Malaysia match-day and kick-off';

  /// The data of the notification the user last tapped, until the app acts on
  /// it and clears it. Set from a cold start, from the background, and from
  /// a notification shown while the app was open.
  static final ValueNotifier<Map<String, dynamic>?> tapped = ValueNotifier(
    null,
  );

  /// Initialize notification plugin, timezone data, and FCM
  static Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse:
          (response) => _tapPayload(response.payload),
    );
    // A foreground-shown notification tapped after the app was closed.
    final launch = await _notifications.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _tapPayload(launch!.notificationResponse?.payload);
    }

    // Create notification channels
    final androidPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

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

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _matchChannelId,
        _matchChannelName,
        description: _matchChannelDesc,
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
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Handle foreground messages — show as local notification
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Taps on notifications the system showed: from the background, and the
    // one that cold-started the app.
    FirebaseMessaging.onMessageOpenedApp.listen((m) => tapped.value = m.data);
    final initial = await messaging.getInitialMessage();
    if (initial != null) tapped.value = initial.data;

    // Save the token on every sign-in, not just at startup.
    //
    // init() runs from main() before anyone has signed in, so the old
    // save-once call found a null currentUser and wrote nothing. Any account
    // created or signed into after launch ended up with no fcmToken, and the
    // sending Cloud Function drops those silently (`if (!fcmToken) return`).
    // authStateChanges() also emits the current value on listen, so this covers
    // the already-signed-in cold start too.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _saveFcmToken();
    });

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

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));

      debugPrint('FCM token saved for user ${user.uid}');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Detaches this device from the signed-in account.
  ///
  /// Must be called *before* FirebaseAuth.signOut(): the users/{uid} rule
  /// requires isOwner(uid), so once the credential is gone the write is denied
  /// and the stale token survives. Leaving it behind means the next person to
  /// use this device keeps receiving the previous account's notifications.
  static Future<void> clearFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error clearing FCM token: $e');
    }
  }

  static void _tapPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      tapped.value = Map<String, dynamic>.from(jsonDecode(payload) as Map);
    } catch (_) {
      // Not one of ours (older notifications carried no payload).
    }
  }

  /// Handle FCM messages received while app is in foreground. Android does not
  /// show those itself, so mirror what it would have: the message's channel,
  /// its tag (so a newer reminder replaces an older one) and its picture.
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final android = notification.android;
    final isMatch = message.data['type'] == 'jdt_match';
    final picture = await _download(android?.imageUrl);

    await _notifications.show(
      // Tagged messages share an id so they replace each other; the rest stack.
      (android?.tag ?? message.messageId ?? notification).hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          isMatch ? _matchChannelId : _pushChannelId,
          isMatch ? _matchChannelName : _pushChannelName,
          channelDescription: isMatch ? _matchChannelDesc : _pushChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
          tag: android?.tag,
          largeIcon: picture == null ? null : ByteArrayAndroidBitmap(picture),
          styleInformation:
              picture == null
                  ? BigTextStyleInformation(notification.body ?? '')
                  : BigPictureStyleInformation(
                    ByteArrayAndroidBitmap(picture),
                    hideExpandedLargeIcon: true,
                  ),
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static Future<Uint8List?> _download(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200 ? response.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }
}
