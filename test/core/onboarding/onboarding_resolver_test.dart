import 'dart:io';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/onboarding/onboarding_readers.dart';
import 'package:exom_app/core/onboarding/onboarding_resolver.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/onboarding_harness.dart';

/// OP-APP-02: the 13 rows of the plan table 3.3.
void main() {
  UserEntity validated(String role, Map<String, Object?> profile) =>
      userFromServer(role: role, profile: profile);

  // Offline entity built by AuthBloc from the Firebase session.
  const synthetic = UserEntity(
    id: 'uid-A',
    email: 'a@exom.test',
    role: 'CLIENT',
    onboardingStatus: OnboardingServerStatus.unknown,
    isServerValidated: false,
  );

  group('R1 validated ADMIN / SUPER_ADMIN', () {
    for (final role in ['ADMIN', 'SUPER_ADMIN']) {
      for (final profile in [doneProfile, pendingProfile, legacyProfile]) {
        for (final localDone in [false, true]) {
          test(
            '$role ${profile['onboarding_completed_at']} local=$localDone',
            () {
              expect(
                resolveOnboarding(
                  user: validated(role, profile),
                  localDone: localDone,
                  hasPending: localDone,
                ),
                const OnboardingResolution(
                  needsOnboarding: false,
                  clearPending: true,
                ),
              );
            },
          );
        }
      }
    }
  });

  test('R2 CLIENT done + nothing local -> Home, write cache', () {
    final result = resolveOnboarding(
      user: validated('CLIENT', doneProfile),
      localDone: false,
    );
    expect(result.needsOnboarding, isFalse);
    expect(result.writeLocalCache, isTrue);
    expect(result.sendPending, isFalse);
    expect(result.registerRepair, isFalse);
  });

  test('R3 CLIENT done + local done -> Home, clear pending, no send', () {
    final result = resolveOnboarding(
      user: validated('CLIENT', doneProfile),
      localDone: true,
      hasPending: true,
    );
    expect(result.needsOnboarding, isFalse);
    expect(result.clearPending, isTrue);
    expect(result.sendPending, isFalse);
  });

  test('R4 CLIENT pending + Hive mark only -> Home, repair and send', () {
    expect(
      resolveOnboarding(
        user: validated('CLIENT', pendingProfile),
        localDone: true,
      ),
      const OnboardingResolution(
        needsOnboarding: false,
        registerRepair: true,
        sendPending: true,
      ),
    );
  });

  test('R5 CLIENT pending + pending present -> Home, resend, no repair', () {
    expect(
      resolveOnboarding(
        user: validated('CLIENT', pendingProfile),
        localDone: true,
        hasPending: true,
      ),
      const OnboardingResolution(needsOnboarding: false, sendPending: true),
    );
  });

  test('R6 CLIENT pending + nothing local -> onboarding, no effects', () {
    expect(
      resolveOnboarding(
        user: validated('CLIENT', pendingProfile),
        localDone: false,
      ),
      const OnboardingResolution(needsOnboarding: true),
    );
  });

  test('R7 old API (unknown) + local done -> Home, pending kept and sent', () {
    expect(
      resolveOnboarding(
        user: validated('CLIENT', legacyProfile),
        localDone: true,
        hasPending: true,
      ),
      const OnboardingResolution(needsOnboarding: false, sendPending: true),
    );
    // Mark without pending on an old API: no repair (the POST would 404).
    expect(
      resolveOnboarding(
        user: validated('CLIENT', legacyProfile),
        localDone: true,
      ),
      const OnboardingResolution(needsOnboarding: false),
    );
  });

  test('R8 old API (unknown) + nothing local -> Home, no effects', () {
    expect(
      resolveOnboarding(
        user: validated('CLIENT', legacyProfile),
        localDone: false,
      ),
      const OnboardingResolution(needsOnboarding: false),
    );
  });

  test('R9 offline synthetic + local done -> Home, no effects', () {
    expect(
      resolveOnboarding(user: synthetic, localDone: true, hasPending: true),
      const OnboardingResolution(needsOnboarding: false),
    );
  });

  test('R10 offline synthetic + nothing local -> Home, no effects', () {
    expect(
      resolveOnboarding(user: synthetic, localDone: false),
      const OnboardingResolution(needsOnboarding: false),
    );
  });

  group('R11-R13 no authenticated user: readers decide nothing', () {
    late Directory directory;
    late LocalStorage storage;
    const session = LocalAuthSession(uid: 'uid-A', email: 'a@exom.test');

    setUp(() async {
      directory = await openInMemorySettingsBox();
      storage = LocalStorage(currentSession: () => session);
      await storage.markOnboardingLocallyDone(
        uid: 'uid-A',
        email: 'a@exom.test',
        outcome: OnboardingOutcomes.completed,
      );
    });

    tearDown(() => closeSettingsBox(directory));

    for (final entry in <String, AuthState>{
      'R11 401/403 -> AuthUnauthenticated': const AuthUnauthenticated(),
      'R12 423 -> AuthAccountLocked': const AuthAccountLocked(),
      'R13 5xx -> AuthError': const AuthError('down'),
    }.entries) {
      test(entry.key, () {
        expect(
          resolveOnboardingForSession(
            authState: entry.value,
            session: session,
            storage: storage,
          ),
          isNull,
        );
        expect(storage.onboardingPendingFor('uid-A'), isNotNull);
      });
    }
  });
}
