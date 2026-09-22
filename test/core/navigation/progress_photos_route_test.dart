import 'package:exom_app/core/navigation/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('progress photos route access', () {
    test('uses the authenticated nested profile path', () {
      expect(AppRoutes.progressPhotos, '/profile/progress-photos');
    });

    test('allows an authenticated, onboarded user into progress photos', () {
      expect(
        resolveAppRouteRedirect(
          location: AppRoutes.progressPhotos,
          isAuthenticated: true,
          hasFirebaseUser: true,
          isOnboardingComplete: true,
        ),
        isNull,
      );
    });

    test('keeps auth and locked redirects for progress photos', () {
      expect(
        resolveAppRouteRedirect(
          location: AppRoutes.progressPhotos,
          isAuthenticated: false,
          hasFirebaseUser: false,
          isOnboardingComplete: false,
        ),
        AppRoutes.login,
      );
      expect(
        resolveAppRouteRedirect(
          location: AppRoutes.progressPhotos,
          isAuthenticated: true,
          hasFirebaseUser: true,
          isOnboardingComplete: true,
          isLocked: true,
        ),
        AppRoutes.accountLocked,
      );
    });
  });
}
