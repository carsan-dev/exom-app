import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:exom_app/core/navigation/app_router.dart';

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
        final route = response.payload;
        if (route != null && route.isNotEmpty) {
          goToRoute(route);
        }
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchRoute = launchDetails?.notificationResponse?.payload;
    if (launchRoute != null && launchRoute.isNotEmpty) {
      goToRoute(launchRoute);
    }

    _initialized = true;
  }

  Future<void> showRemoteMessage(RemoteMessage message, {String? route}) async {
    await init();

    final title = message.notification?.title?.trim();
    final body = message.notification?.body?.trim();

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

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
      payload: route,
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
