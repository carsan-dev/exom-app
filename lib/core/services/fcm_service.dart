import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/storage/local_storage.dart';

class FcmService {
  final ApiClient _apiClient;
  final LocalStorage _localStorage;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;

  FcmService(this._apiClient, this._localStorage);

  Future<void> init() async {
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

    _initialized = true;

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '[FCM] Foreground message: ${message.notification?.title} — ${message.notification?.body}',
      );
    });
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
}
