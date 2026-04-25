import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:exom_app/core/navigation/app_router.dart';

typedef LocalNotificationTapHandler = void Function(
  String? notificationId,
  String? route,
);

class LocalNotificationService {
  static const channelId = 'exom_high_importance';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    channelId,
    'EXOM Notifications',
    description: 'Alertas y recordatorios importantes de EXOM',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  LocalNotificationTapHandler? _tapHandler;

  set onTap(LocalNotificationTapHandler? handler) => _tapHandler = handler;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchPayload != null && launchPayload.isNotEmpty) {
      _handlePayload(launchPayload);
    }

    _initialized = true;
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;

    String? notificationId;
    String? route;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final id = decoded['notification_id'];
        final r = decoded['route'];
        notificationId = id is String && id.isNotEmpty ? id : null;
        route = r is String && r.isNotEmpty ? r : null;
      } else {
        route = payload;
      }
    } catch (_) {
      route = payload;
    }

    final handler = _tapHandler;
    if (handler != null) {
      handler(notificationId, route);
      return;
    }

    if (route != null) {
      goToRoute(route);
    }
  }

  Future<void> showRemoteMessage(
    RemoteMessage message, {
    String? route,
    String? notificationId,
  }) async {
    await init();

    final title = message.notification?.title?.trim();
    final body = message.notification?.body?.trim();

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final payload = jsonEncode({
      if (notificationId != null && notificationId.isNotEmpty)
        'notification_id': notificationId,
      if (route != null && route.isNotEmpty) 'route': route,
    });

    await _plugin.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  void goToRoute(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_shouldPush(route)) {
        AppRouter.router.push(route);
      } else {
        AppRouter.router.go(route);
      }
    });
  }

  bool _shouldPush(String route) {
    return route == AppRoutes.recap ||
        route.startsWith('${AppRoutes.recap}/') ||
        route == AppRoutes.profile ||
        route == AppRoutes.feedback ||
        route == AppRoutes.settings ||
        route == AppRoutes.help;
  }
}
