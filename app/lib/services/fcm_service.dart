import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    // Request notification permission (Android auto-grants, iOS requires request)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('FCM Permission: ${settings.authorizationStatus}');
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Get initial message if app was terminated
    final RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }

    _initialized = true;
  }

  static Future<void> registerToken(String token) async {
    try {
      await ApiService.post('/fcm/register', body: {
        'token': token,
        'platform': 'android',
      });
      if (kDebugMode) {
        print('FCM token registered');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to register FCM token: $e');
      }
    }
  }

  static Future<void> unregisterToken(String token) async {
    try {
      await ApiService.post('/fcm/unregister', body: {'token': token});
      if (kDebugMode) {
        print('FCM token unregistered');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to unregister FCM token: $e');
      }
    }
  }

  static Future<void> setupTokenRefreshCallback() async {
    _messaging.onTokenRefresh.listen((newToken) async {
      await registerToken(newToken);
    });
  }

  static Future<void> handleCurrentToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await registerToken(token);
    }
  }

  static Future<String?> getCurrentToken() async {
    return await _messaging.getToken();
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Foreground message: ${message.notification?.title}');
    }
    // Local notifications can be added later with proper flutter_local_notifications setup
  }

  static void _handleMessageTap(RemoteMessage message) {
    if (kDebugMode) {
      print('Message tapped: ${message.data}');
    }
    // Navigate based on link if provided
    final link = message.data['link'];
    if (link != null) {
      // In a real app, you'd use a navigation key or navigator to navigate
      if (kDebugMode) {
        print('Would navigate to: $link');
      }
    }
  }
}
