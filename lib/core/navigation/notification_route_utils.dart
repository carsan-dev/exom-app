import 'package:flutter/foundation.dart';

const String _notificationsFallbackRoute = '/notifications';

const Set<String> _dateAwarePaths = {'/trainings', '/diets', '/calendar'};

const Set<String> _supportedExactPaths = {
  '/',
  '/trainings',
  '/diets',
  '/calendar',
  '/challenges',
  '/profile',
  '/profile/metrics',
  '/recap',
  '/feedback',
  '/notifications',
  '/settings',
  '/help',
};

const List<String> _supportedPrefixes = ['/trainings/', '/recap/'];

const Set<String> _pushExactPaths = {
  '/profile',
  '/profile/metrics',
  '/recap',
  '/feedback',
  '/notifications',
  '/settings',
  '/help',
};

const List<String> _pushPrefixes = ['/trainings/', '/recap/'];

String resolveNotificationRoute(Map<String, dynamic> data) {
  final directRoute = data['route'];
  if (directRoute is String) {
    final normalized = normalizeNotificationRoute(
      directRoute,
      fallbackToNotifications: true,
    );
    if (normalized != null && normalized != _notificationsFallbackRoute) {
      return normalized;
    }
  }

  final type = data['type']?.toString().toLowerCase();
  final fallbackRoute = switch (type) {
    'recap_feedback' || 'recap_reminder' || 'recap' => '/recap',
    'training' || 'training_reminder' || 'training_note_reply' => '/trainings',
    'meal' || 'diet' || 'diet_reminder' => '/diets',
    'challenge' || 'challenge_update' => '/challenges',
    'profile' => '/profile',
    'calendar' => '/calendar',
    'home' => '/',
    _ => _notificationsFallbackRoute,
  };
  return normalizeNotificationRoute(
        fallbackRoute,
        fallbackToNotifications: true,
      ) ??
      _notificationsFallbackRoute;
}

String? normalizeNotificationRoute(
  String? rawRoute, {
  DateTime? createdAt,
  bool fallbackToNotifications = false,
}) {
  if (rawRoute == null) {
    return fallbackToNotifications ? _notificationsFallbackRoute : null;
  }

  final trimmedRoute = rawRoute.trim();
  if (trimmedRoute.isEmpty || !trimmedRoute.startsWith('/')) {
    return fallbackToNotifications ? _notificationsFallbackRoute : null;
  }

  final uri = Uri.tryParse(trimmedRoute);
  if (uri == null || uri.path.isEmpty) {
    return fallbackToNotifications ? _notificationsFallbackRoute : null;
  }

  final normalizedPath = _normalizePath(uri.path);
  if (!_isSupportedPath(normalizedPath)) {
    debugPrint('[Notifications] Unsupported route: $rawRoute');
    return fallbackToNotifications ? _notificationsFallbackRoute : null;
  }

  final normalizedUri = _applyDateIfNeeded(
    uri.replace(path: normalizedPath),
    createdAt,
  );
  return normalizedUri.toString();
}

bool shouldPushNotificationRoute(String route) {
  final normalizedRoute = normalizeNotificationRoute(route);
  if (normalizedRoute == null) return false;

  final path = Uri.parse(normalizedRoute).path;
  if (_pushExactPaths.contains(path)) {
    return true;
  }

  return _pushPrefixes.any(path.startsWith);
}

String _normalizePath(String path) {
  if (path == '/achievements' ||
      path == '/achievement' ||
      path == '/challenge' ||
      path.startsWith('/achievements/') ||
      path.startsWith('/achievement/') ||
      path.startsWith('/challenge/') ||
      path.startsWith('/challenges/')) {
    return '/challenges';
  }

  if (path == '/metrics' ||
      path.startsWith('/metrics/') ||
      path == '/profile/metrics/' ||
      path.startsWith('/profile/metrics/')) {
    return '/profile/metrics';
  }

  return path;
}

bool _isSupportedPath(String path) {
  if (_supportedExactPaths.contains(path)) {
    return true;
  }

  return _supportedPrefixes.any(path.startsWith);
}

Uri _applyDateIfNeeded(Uri uri, DateTime? createdAt) {
  if (createdAt == null ||
      !_dateAwarePaths.contains(uri.path) ||
      uri.queryParameters.containsKey('date')) {
    return uri;
  }

  final localCreatedAt = createdAt.toLocal();
  final now = DateTime.now();
  final isToday =
      localCreatedAt.year == now.year &&
      localCreatedAt.month == now.month &&
      localCreatedAt.day == now.day;

  if (isToday) {
    return uri;
  }

  final year = localCreatedAt.year.toString().padLeft(4, '0');
  final month = localCreatedAt.month.toString().padLeft(2, '0');
  final day = localCreatedAt.day.toString().padLeft(2, '0');

  return uri.replace(
    queryParameters: {...uri.queryParameters, 'date': '$year-$month-$day'},
  );
}
