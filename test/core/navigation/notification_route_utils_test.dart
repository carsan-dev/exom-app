import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/navigation/notification_route_utils.dart';

void main() {
  group('normalizeNotificationRoute', () {
    test('maps legacy achievements route to challenges', () {
      expect(
        normalizeNotificationRoute('/achievements'),
        '/challenges',
      );
    });

    test('maps legacy metrics route to nested profile metrics route', () {
      expect(
        normalizeNotificationRoute('/metrics'),
        '/profile/metrics',
      );
    });

    test('adds notification date to date-aware routes for past notifications', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final year = yesterday.year.toString().padLeft(4, '0');
      final month = yesterday.month.toString().padLeft(2, '0');
      final day = yesterday.day.toString().padLeft(2, '0');

      expect(
        normalizeNotificationRoute(
          '/trainings',
          createdAt: yesterday,
        ),
        '/trainings?date=$year-$month-$day',
      );
    });

    test('falls back to notifications for unsupported routes when requested', () {
      expect(
        normalizeNotificationRoute(
          '/unknown-destination',
          fallbackToNotifications: true,
        ),
        '/notifications',
      );
    });
  });

  group('shouldPushNotificationRoute', () {
    test('pushes profile metrics route', () {
      expect(shouldPushNotificationRoute('/profile/metrics'), isTrue);
    });

    test('does not push shell challenges route', () {
      expect(shouldPushNotificationRoute('/challenges'), isFalse);
    });
  });
}
