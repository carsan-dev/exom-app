import 'dart:io';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/onboarding/onboarding_resolver.dart';
import 'package:exom_app/core/onboarding/onboarding_sync_coordinator.dart';
import 'package:exom_app/core/services/execution_timer_coordinator.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/auth/presentation/validated_session_gate.dart';
import 'package:exom_app/injection_container.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/onboarding_harness.dart';
import '../../helpers/onboarding_remote_fakes.dart';

/// OP-D17: the AuthBloc hook drives the onboarding sync on every state
/// change, so a second sign-in in the same process is handled too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.exommethod.exom/execution_timer');
  late Directory directory;
  late LocalAuthSession? session;
  late LocalStorage storage;
  late FakeOnboardingRemote remote;
  late OnboardingSyncCoordinator coordinator;

  setUp(() async {
    await sl.reset();
    directory = await openInMemorySettingsBox();
    session = const LocalAuthSession(
      uid: 'uid-A',
      email: 'a@exom.test',
      generation: 1,
    );
    storage = LocalStorage(currentSession: () => session);
    remote = FakeOnboardingRemote();
    coordinator = OnboardingSyncCoordinator(
      storage: storage,
      currentSession: () => session,
      remote: remote,
    );
    final gate = ValidatedSessionGate(() => session);
    sl.registerSingleton<LocalStorage>(storage);
    sl.registerSingleton<ValidatedSessionGate>(gate);
    sl.registerSingleton<ExecutionTimerCoordinator>(
      ExecutionTimerCoordinator(
        channel: channel,
        isAuthorized: () => gate.isAuthenticated,
      ),
    );
    sl.registerSingleton<OnboardingSyncCoordinator>(coordinator);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await sl.reset();
    await closeSettingsBox(directory);
  });

  test('every session change reaches the coordinator (A, logout, B)', () async {
    await storage.markOnboardingLocallyDone(
      uid: 'uid-A',
      email: 'a@exom.test',
      outcome: OnboardingOutcomes.completed,
    );
    handleAuthSessionState(
      AuthAuthenticated(userFromServer(profile: pendingProfile)),
    );
    await coordinator.settled;
    expect(remote.calls.map((call) => call.expectedOwner), ['uid-A']);

    handleAuthSessionState(const AuthLoading());
    handleAuthSessionState(const AuthUnauthenticated());
    session = const LocalAuthSession(
      uid: 'uid-B',
      email: 'b@exom.test',
      generation: 3,
    );
    await storage.markOnboardingLocallyDone(
      uid: 'uid-B',
      email: 'b@exom.test',
      outcome: OnboardingOutcomes.skipped,
    );
    handleAuthSessionState(
      AuthAuthenticated(
        userFromServer(
          id: 'db-B',
          email: 'b@exom.test',
          profile: pendingProfile,
        ),
      ),
    );
    await coordinator.settled;

    expect(remote.calls.map((call) => call.expectedOwner), ['uid-A', 'uid-B']);
    expect(remote.calls.last.outcome, OnboardingOutcomes.skipped);
    expect(sl<ValidatedSessionGate>().isAuthenticated, isTrue);
  });
}
