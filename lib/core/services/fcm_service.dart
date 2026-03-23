import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/services/local_notification_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';

class FcmService {
  final ApiClient _apiClient;
  final LocalStorage _localStorage;
  final LocalNotificationService _localNotificationService;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openAppSubscription;
  bool _initialized = false;

  FcmService(
    this._apiClient,
    this._localStorage,
    this._localNotificationService,
  );

  Future<void> init() async {
    await _localNotificationService.init();

    final notificationsEnabled =
        _localStorage.getSetting<bool>(
          'push_notifications_enabled',
          defaultValue: true,
        ) ??
        true;

    if (!notificationsEnabled) {
      debugPrint('[FCM] Notifications disabled in local settings');
      return;
    }

    if (_initialized) {
      final token = _localStorage.fcmToken ?? await _messaging.getToken();
      if (token != null) {
        await _sendTokenToServer(token);
      }
      debugPrint('[FCM] Already initialized');
      return;
    }

    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Permission denied');
      return;
    }

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get token and send to backend
    final token = await _messaging.getToken();
    if (token != null) {
      await _localStorage.saveFcmToken(token);
    }

    if (token != null && FirebaseAuth.instance.currentUser != null) {
      await _sendTokenToServer(token);
    }

    _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) async {
      if (user == null) {
        return;
      }

      final pendingToken =
          _localStorage.fcmToken ?? await _messaging.getToken();
      if (pendingToken != null) {
        await _sendTokenToServer(pendingToken);
      }
    });

    // Refresh token listener
    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen((
      token,
    ) async {
      await _localStorage.saveFcmToken(token);
      await _sendTokenToServer(token);
    });

    _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    _openAppSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationOpen,
    );

    _initialized = true;

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    final notificationsEnabled =
        _localStorage.getSetting<bool>(
          'push_notifications_enabled',
          defaultValue: true,
        ) ??
        true;

    if (!notificationsEnabled) {
      debugPrint('[FCM] Token not sent because notifications are disabled');
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint('[FCM] Token pending until user signs in');
      await _localStorage.saveFcmToken(token);
      return;
    }

    try {
      await _apiClient.patch<Map<String, dynamic>>(
        '/admin/fcm-token',
        data: {'fcm_token': token},
      );
      await _localStorage.saveFcmToken(token);
      debugPrint('[FCM] Token sent to server');
    } catch (e) {
      await _localStorage.saveFcmToken(token);
      debugPrint('[FCM] Failed to send token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final route = _resolveRoute(message);

    debugPrint(
      '[FCM] Foreground message: ${message.notification?.title} — ${message.notification?.body}',
    );

    _localNotificationService.showRemoteMessage(message, route: route);
  }

  void _handleNotificationOpen(RemoteMessage message) {
    final route = _resolveRoute(message);
    if (route == null) {
      return;
    }

    debugPrint('[FCM] Open notification route: $route');
    _goToRoute(route);
  }

  String? _resolveRoute(RemoteMessage message) {
    final directRoute = message.data['route'];
    if (directRoute is String && directRoute.startsWith('/')) {
      return directRoute;
    }

    final type = message.data['type']?.toLowerCase();
    switch (type) {
      case 'recap_reminder':
      case 'recap':
        return '/recap';
      case 'training':
      case 'training_reminder':
        return '/trainings';
      case 'meal':
      case 'diet':
      case 'diet_reminder':
        return '/diets';
      case 'challenge':
      case 'challenge_update':
        return '/challenges';
      case 'profile':
        return '/profile';
      case 'calendar':
        return '/calendar';
      case 'home':
        return '/';
      default:
        return null;
    }
  }

  void _goToRoute(String route) {
    _localNotificationService.goToRoute(route);
  }
}
