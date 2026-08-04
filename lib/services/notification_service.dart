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
  static const _pushChannelDesc =
      'Real-time push notifications for group activity';

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

    await _notifications.initialize(initSettings);

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
}
