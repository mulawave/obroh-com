import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../screens/messages/messages_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/timeline/timeline_screen.dart';
import 'fcm_service.dart';

class NotificationRouter {
  NotificationRouter._();

  static final NotificationRouter I = NotificationRouter._();

  StreamSubscription<FcmTapEvent>? _tapSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  GlobalKey<NavigatorState>? _navigatorKey;

  void bind(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    _tapSub?.cancel();
    _openedAppSub?.cancel();

    _tapSub = FcmService.I.taps.listen((event) {
      _handleData(event.data);
    });

    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleData(Map<String, dynamic>.from(message.data));
    });

    FirebaseMessaging.instance.getInitialMessage().then((initialMessage) {
      if (initialMessage == null) return;
      _handleData(Map<String, dynamic>.from(initialMessage.data));
    });
  }

  void _handleData(Map<String, dynamic> data) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    final type = data['type']?.toString() ?? '';
    final deepLink =
        data['deepLink']?.toString() ??
        data['link']?.toString() ??
        data['route']?.toString() ??
        '';

    if (_routeByLink(navigator, deepLink, data)) return;

    switch (type) {
      case 'new_message':
        navigator.push(
          MaterialPageRoute(builder: (_) => const MessagesScreen()),
        );
        break;
      case 'new_alert':
        navigator.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        break;
      case 'new_post':
      case 'post_activity':
        navigator.push(
          MaterialPageRoute(
            builder: (_) =>
                TimelineScreen(initialPostId: data['postId']?.toString()),
          ),
        );
        break;
      default:
        navigator.push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        break;
    }
  }

  bool _routeByLink(
    NavigatorState navigator,
    String deepLink,
    Map<String, dynamic> data,
  ) {
    if (deepLink.isEmpty) return false;

    if (deepLink.contains('messages')) {
      navigator.push(MaterialPageRoute(builder: (_) => const MessagesScreen()));
      return true;
    }

    if (deepLink.contains('notifications')) {
      navigator.push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
      return true;
    }

    if (deepLink.contains('timeline') || deepLink.contains('post')) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              TimelineScreen(initialPostId: data['postId']?.toString()),
        ),
      );
      return true;
    }

    return false;
  }
}
