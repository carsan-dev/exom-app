import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:exom_app/core/api/api_client.dart';

class FcmService {
  final ApiClient _apiClient;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  FcmService(this._apiClient);

  Future<void> init() async {
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
      await _sendTokenToServer(token);
    }

    // Refresh token listener
    _messaging.onTokenRefresh.listen(_sendTokenToServer);

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '[FCM] Foreground message: ${message.notification?.title} — ${message.notification?.body}',
      );
    });
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      await _apiClient.patch<Map<String, dynamic>>(
        '/admin/fcm-token',
        data: {'fcm_token': token},
      );
      debugPrint('[FCM] Token sent to server');
    } catch (e) {
      debugPrint('[FCM] Failed to send token: $e');
    }
  }
}
