import 'dart:io';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/onboarding_harness.dart';

const _sessionA = LocalAuthSession(uid: 'uid-A', email: 'a@exom.test');

void main() {
  late Directory directory;
  late LocalStorage storage;

  setUp(() async {
    directory = await openInMemorySettingsBox();
    storage = LocalStorage(currentSession: () => _sessionA);
  });

  tearDown(() => closeSettingsBox(directory));

  String? redirect(String location, AuthState state) =>
      resolveAppRouteRedirectFor(
        location: location,
        authState: state,
        session: _sessionA,
        storage: storage,
      );

  test('OP-RED-02 /login with server done + empty Hive goes Home', () {
    final state = AuthAuthenticated(userFromServer(profile: doneProfile));

    expect(redirect(AppRoutes.login, state), AppRoutes.home);
    expect(redirect(AppRoutes.trainings, state), isNull);
  });

  test('/login with server pending + empty Hive goes to onboarding', () {
    final state = AuthAuthenticated(userFromServer(profile: pendingProfile));

    expect(redirect(AppRoutes.login, state), AppRoutes.onboarding);
    expect(redirect(AppRoutes.trainings, state), AppRoutes.onboarding);
  });

  test('offline (unknown) + empty Hive never redirects to onboarding', () {
    const state = AuthAuthenticated(
      UserEntity(id: 'uid-A', email: 'a@exom.test', role: 'CLIENT'),
    );

    expect(redirect(AppRoutes.login, state), AppRoutes.home);
    expect(redirect(AppRoutes.trainings, state), isNull);
  });

  test('old API (key absent) + empty Hive never redirects to onboarding', () {
    final state = AuthAuthenticated(userFromServer(profile: legacyProfile));

    expect(redirect(AppRoutes.login, state), AppRoutes.home);
  });

  for (final role in ['ADMIN', 'SUPER_ADMIN']) {
    test('validated $role is never sent to onboarding', () {
      final state = AuthAuthenticated(
        userFromServer(role: role, profile: pendingProfile),
      );

      expect(redirect(AppRoutes.login, state), AppRoutes.home);
      expect(redirect(AppRoutes.trainings, state), isNull);
    });
  }
}
