import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'api_service.dart';

class FcmTapEvent {
  final Map<String, dynamic> data;

  const FcmTapEvent({required this.data});
}

class FcmService {
  FcmService._();

  static final FcmService I = FcmService._();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final StreamController<FcmTapEvent> _tapController =
      StreamController<FcmTapEvent>.broadcast();

  bool _initialized = false;

  Stream<FcmTapEvent> get taps => _tapController.stream;

  Future<void> init() async {
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

  Future<void> registerToken(String token, {String? authToken}) async {
    try {
      await ApiService.post(
        '/fcm/register',
        body: {'token': token, 'platform': 'android'},
        token: authToken,
      );
      if (kDebugMode) {
        print('FCM token registered');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to register FCM token: $e');
      }
    }
  }

  Future<void> unregisterToken(String token, {String? authToken}) async {
    try {
      await ApiService.post(
        '/fcm/unregister',
        body: {'token': token},
        token: authToken,
      );
      if (kDebugMode) {
        print('FCM token unregistered');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to unregister FCM token: $e');
      }
    }
  }

  Future<void> setupTokenRefreshCallback({String? authToken}) async {
    _messaging.onTokenRefresh.listen((newToken) async {
      await registerToken(newToken, authToken: authToken);
    });
  }

  Future<void> handleCurrentToken({String? authToken}) async {
    final token = await _messaging.getToken();
    if (token != null) {
      await registerToken(token, authToken: authToken);
    }
  }

  Future<String?> getCurrentToken() async {
    return await _messaging.getToken();
  }

  Future<void> initAndRegister(String userId, String authToken) async {
    await init();
    await handleCurrentToken(authToken: authToken);
    await setupTokenRefreshCallback(authToken: authToken);
    if (kDebugMode) {
      print('FCM initialized and registered for user $userId');
    }
  }

  Future<void> unregisterCurrentToken({required String authToken}) async {
    final token = await getCurrentToken();
    if (token == null) return;
    await unregisterToken(token, authToken: authToken);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Foreground message: ${message.notification?.title}');
    }
    // Local notifications can be added later with proper flutter_local_notifications setup
  }

  void _handleMessageTap(RemoteMessage message) {
    if (kDebugMode) {
      print('Message tapped: ${message.data}');
    }
    _tapController.add(
      FcmTapEvent(data: Map<String, dynamic>.from(message.data)),
    );

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
