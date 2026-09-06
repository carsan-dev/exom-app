import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/navigation/notification_route_utils.dart';
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
  final bool Function() _isAuthenticated;

  final StreamController<RemoteMessage> _incomingController =
      StreamController<RemoteMessage>.broadcast();

  /// Stream fired when a push arrives (foreground or opened from background).
  /// Listeners can refresh UI state like the unread-count badge.
  Stream<RemoteMessage> get onIncomingMessage => _incomingController.stream;

  FcmService(
    this._apiClient,
    this._localStorage,
    this._localNotificationService, {
    bool Function()? isAuthenticated,
  }) : _isAuthenticated =
           isAuthenticated ?? (() => FirebaseAuth.instance.currentUser != null);

  Future<void> init() async {
    _localNotificationService.onTap = _handleLocalTap;
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

    if (!_isAuthenticated()) {
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
    if (!_isAuthenticated()) return;
    final route = _resolveRoute(message);
    final rawId = message.data['notification_id'];
    final notificationId = rawId is String && rawId.isNotEmpty ? rawId : null;

    debugPrint(
      '[FCM] Foreground message: ${message.notification?.title} — ${message.notification?.body}',
    );

    _localNotificationService.showRemoteMessage(
      message,
      route: route,
      notificationId: notificationId,
    );
    _emitIncoming(message);
  }

  void _handleNotificationOpen(RemoteMessage message) {
    if (!_isAuthenticated()) return;
    final rawId = message.data['notification_id'];
    final notificationId = rawId is String && rawId.isNotEmpty ? rawId : null;
    if (notificationId != null) {
      unawaited(_markNotificationRead(notificationId));
    } else {
      _emitIncoming(message);
    }

    final route = _resolveRoute(message);
    if (route == null) {
      return;
    }

    debugPrint('[FCM] Open notification route: $route');
    _goToRoute(route);
  }

  void _handleLocalTap(String? notificationId, String? route) {
    if (!_isAuthenticated()) return;
    if (notificationId != null && notificationId.isNotEmpty) {
      unawaited(_markNotificationRead(notificationId));
    }

    if (route != null && route.isNotEmpty) {
      debugPrint('[FCM] Local notification tap route: $route');
      _localNotificationService.goToRoute(route);
    }
  }

  Future<void> _markNotificationRead(String id) async {
    if (!_isAuthenticated()) return;
    try {
      await _apiClient.dio.put<dynamic>('/notifications/$id/read');
      debugPrint('[FCM] Notification $id marked as read');
    } catch (e) {
      debugPrint('[FCM] Failed to mark notification $id as read: $e');
    } finally {
      if (!_incomingController.isClosed) {
        _incomingController.add(
          RemoteMessage(data: const {'__internal_read_refresh': '1'}),
        );
      }
    }
  }

  void _emitIncoming(RemoteMessage message) {
    if (_incomingController.isClosed) return;
    _incomingController.add(message);
  }

  String? _resolveRoute(RemoteMessage message) {
    final directRoute = message.data['route'];
    if (directRoute is String && directRoute.startsWith('/')) {
      final normalized = normalizeNotificationRoute(directRoute);
      if (normalized != null) {
        return normalized;
      }
    }

    final type = message.data['type']?.toLowerCase();
    String? fallbackRoute;
    switch (type) {
      case 'recap_feedback':
      case 'recap_reminder':
      case 'recap':
        // Route may carry a specific recap id, e.g. '/recap/<id>'
        // The direct route path is preferred — already handled above via directRoute check.
        fallbackRoute = '/recap';
        break;
      case 'training':
      case 'training_reminder':
      case 'training_note_reply':
        fallbackRoute = '/trainings';
        break;
      case 'meal':
      case 'diet':
      case 'diet_reminder':
        fallbackRoute = '/diets';
        break;
      case 'challenge':
      case 'challenge_update':
        fallbackRoute = '/challenges';
        break;
      case 'profile':
        fallbackRoute = '/profile';
        break;
      case 'calendar':
        fallbackRoute = '/calendar';
        break;
      case 'home':
        fallbackRoute = '/';
        break;
      default:
        fallbackRoute = '/notifications';
    }

    return normalizeNotificationRoute(
      fallbackRoute,
      fallbackToNotifications:
          directRoute is String && directRoute.startsWith('/'),
    );
  }

  void _goToRoute(String route) {
    _localNotificationService.goToRoute(route);
  }
}
