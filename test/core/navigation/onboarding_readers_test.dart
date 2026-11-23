import 'dart:io';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/onboarding/onboarding_readers.dart';
import 'package:exom_app/core/onboarding/onboarding_resolver.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/onboarding_harness.dart';

const _sessionA = LocalAuthSession(uid: 'uid-A', email: 'a@exom.test');

/// OP-APP-15: tutorial and notification readers go through the resolver.
void main() {
  late Directory directory;
  late LocalStorage storage;

  setUp(() async {
    directory = await openInMemorySettingsBox();
    storage = LocalStorage(currentSession: () => _sessionA);
  });

  tearDown(() => closeSettingsBox(directory));

  OnboardingResolution? resolve(AuthState state) => resolveOnboardingForSession(
    authState: state,
    session: _sessionA,
    storage: storage,
  );

  group('tutorial', () {
    test('offered after reinstall when the server says done', () {
      final resolution = resolve(
        AuthAuthenticated(userFromServer(profile: doneProfile)),
      );
      expect(
        shouldOfferTutorial(resolution: resolution, tutorialDone: false),
        isTrue,
      );
      expect(
        shouldOfferTutorial(resolution: resolution, tutorialDone: true),
        isFalse,
      );
    });

    test('not offered while the onboarding is still needed', () {
      final resolution = resolve(
        AuthAuthenticated(userFromServer(profile: pendingProfile)),
      );
      expect(resolution!.needsOnboarding, isTrue);
      expect(
        shouldOfferTutorial(resolution: resolution, tutorialDone: false),
        isFalse,
      );
    });

    test('not offered without an authenticated user', () {
      expect(
        shouldOfferTutorial(
          resolution: resolve(const AuthUnauthenticated()),
          tutorialDone: false,
        ),
        isFalse,
      );
    });

    test('offline (unknown) + empty Hive does not block the tutorial', () {
      final resolution = resolve(
        const AuthAuthenticated(
          UserEntity(id: 'uid-A', email: 'a@exom.test', role: 'CLIENT'),
        ),
      );
      expect(
        shouldOfferTutorial(resolution: resolution, tutorialDone: false),
        isTrue,
      );
    });
  });

  group('notification navigation', () {
    final done = AuthAuthenticated(userFromServer(profile: doneProfile));
    final pending = AuthAuthenticated(userFromServer(profile: pendingProfile));

    test('ready on app routes when the onboarding is settled', () {
      for (final location in [AppRoutes.home, AppRoutes.notifications]) {
        expect(
          isNotificationNavigationReady(
            resolution: resolve(done),
            location: location,
          ),
          isTrue,
        );
      }
    });

    test('never on splash, login or onboarding', () {
      for (final location in [
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.onboarding,
      ]) {
        expect(
          isNotificationNavigationReady(
            resolution: resolve(done),
            location: location,
          ),
          isFalse,
        );
      }
    });

    test('never while the onboarding is still needed', () {
      expect(
        isNotificationNavigationReady(
          resolution: resolve(pending),
          location: AppRoutes.home,
        ),
        isFalse,
      );
    });

    test('ready once the onboarding was completed locally', () async {
      await storage.markOnboardingLocallyDone(
        uid: 'uid-A',
        email: 'a@exom.test',
        outcome: OnboardingOutcomes.completed,
      );
      expect(
        isNotificationNavigationReady(
          resolution: resolve(pending),
          location: AppRoutes.home,
        ),
        isTrue,
      );
    });
  });
}
