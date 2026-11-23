import 'dart:io';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/onboarding/onboarding_resolver.dart';
import 'package:exom_app/core/onboarding/onboarding_sync_coordinator.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:exom_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/upload_avatar_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/onboarding_harness.dart';
import '../../../../helpers/onboarding_remote_fakes.dart';

const _sessionA = LocalAuthSession(uid: 'uid-A', email: 'a@exom.test');
const _markKey = 'onboarding_complete::a@exom.test';

class _ProfileRepository implements ProfileRepository {
  _ProfileRepository(this.onUpdate);

  final Future<void> Function(Map<String, dynamic> data) onUpdate;
  int updates = 0;

  @override
  Future<ProfileEntity> getProfile() async => const ProfileEntity(id: 'p-A');

  @override
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data) async {
    updates++;
    await onUpdate(data);
    return const ProfileEntity(id: 'p-A');
  }

  @override
  Future<ProfileEntity> uploadAvatar(File file) => throw UnimplementedError();
}

void main() {
  late Directory directory;
  late LocalStorage storage;
  late FakeOnboardingRemote remote;
  late OnboardingSyncCoordinator coordinator;

  setUp(() async {
    directory = await openInMemorySettingsBox();
    storage = LocalStorage(currentSession: () => _sessionA);
    remote = FakeOnboardingRemote();
    coordinator = OnboardingSyncCoordinator(
      storage: storage,
      currentSession: () => _sessionA,
      remote: remote,
    );
    // Validated CLIENT whose server state is still pending (R6).
    coordinator.handle(
      AuthAuthenticated(userFromServer(profile: pendingProfile)),
    );
    await coordinator.settled;
  });

  tearDown(() => closeSettingsBox(directory));

  OnboardingBloc buildBloc(_ProfileRepository repository) => OnboardingBloc(
    getProfile: GetProfileUseCase(repository),
    updateProfile: UpdateProfileUseCase(repository),
    uploadAvatar: UploadAvatarUseCase(repository),
    localStorage: storage,
    currentSession: () => _sessionA,
    syncCoordinator: coordinator,
  );

  Future<OnboardingBloc> atSummary(_ProfileRepository repository) async {
    final bloc = buildBloc(repository);
    bloc.add(const OnboardingStarted());
    await bloc.stream.firstWhere((state) => state is OnboardingStepActive);
    return bloc;
  }

  group('OP-RED-05 / OP-APP-08 skip', () {
    test('registers a SKIPPED pending and sends POST SKIPPED', () async {
      final repository = _ProfileRepository((_) async {});
      final bloc = buildBloc(repository);
      OnboardingState? stateAtPost;
      Map<String, Object?>? pendingAtPost;
      remote.onCall = (_) {
        stateAtPost = bloc.state;
        pendingAtPost = storage.onboardingPendingFor('uid-A');
      };

      bloc.add(const OnboardingSkipped());
      await bloc.stream.firstWhere((state) => state is OnboardingCompleted);
      await coordinator.settled;

      expect(repository.updates, 0, reason: 'skip never sends PUT');
      expect(remote.calls, hasLength(1));
      expect(remote.calls.single.outcome, OnboardingOutcomes.skipped);
      expect(remote.calls.single.expectedOwner, 'uid-A');
      expect(stateAtPost, isA<OnboardingCompleted>());
      expect(pendingAtPost?['outcome'], OnboardingOutcomes.skipped);
      expect(settingsBox.get(_markKey), isTrue);
      expect(
        storage.onboardingPendingFor('uid-A'),
        isNull,
        reason: '2xx clears the pending entry',
      );
      await bloc.close();
    });

    test(
      'POST failure keeps the SKIPPED pending and still completes',
      () async {
        remote.responses.add(() => throw networkError());
        final bloc = buildBloc(_ProfileRepository((_) async {}));

        bloc.add(const OnboardingSkipped());
        await bloc.stream.firstWhere((state) => state is OnboardingCompleted);
        await coordinator.settled;

        expect(remote.calls, hasLength(1));
        expect(
          storage.onboardingPendingFor('uid-A')?['outcome'],
          OnboardingOutcomes.skipped,
        );
        expect(settingsBox.get(_markKey), isTrue);
        await bloc.close();
      },
    );
  });

  group('OP-APP-07 submit', () {
    test('PUT -> local write -> Completed -> POST COMPLETED', () async {
      final order = <String>[];
      late OnboardingBloc bloc;
      final repository = _ProfileRepository((_) async {
        order.add(
          'PUT(local=${storage.onboardingPendingFor('uid-A') != null || settingsBox.get(_markKey) == true})',
        );
      });
      remote.onCall = (call) {
        final pending = storage.onboardingPendingFor('uid-A');
        order.add(
          'POST(${call.outcome}, state=${bloc.state.runtimeType}, pending=${pending?['outcome']}, mark=${settingsBox.get(_markKey)})',
        );
      };
      bloc = await atSummary(repository);

      bloc.add(const OnboardingSubmitted());
      await bloc.stream.firstWhere((state) => state is OnboardingCompleted);
      await coordinator.settled;

      expect(order, [
        'PUT(local=false)',
        'POST(COMPLETED, state=OnboardingCompleted, pending=COMPLETED, mark=true)',
      ]);
      expect(storage.onboardingPendingFor('uid-A'), isNull);
      await bloc.close();
    });

    for (final failure in <String, Object Function()>{
      'network': networkError,
      '5xx': () => httpError(503),
      '404 (old API)': () => httpError(404),
    }.entries) {
      test(
        'POST ${failure.key} failure still completes with pending',
        () async {
          remote.responses.add(() => throw failure.value());
          final bloc = await atSummary(_ProfileRepository((_) async {}));

          bloc.add(const OnboardingSubmitted());
          await bloc.stream.firstWhere((state) => state is OnboardingCompleted);
          await coordinator.settled;

          expect(bloc.state, isA<OnboardingCompleted>());
          expect(
            storage.onboardingPendingFor('uid-A')?['outcome'],
            OnboardingOutcomes.completed,
          );
          expect(settingsBox.get(_markKey), isTrue);
          await bloc.close();
        },
      );
    }

    test(
      'PUT failure keeps current behaviour: no mark, no pending, no POST',
      () async {
        final bloc = await atSummary(
          _ProfileRepository((_) async => throw httpError(500)),
        );
        final states = <OnboardingState>[];
        final subscription = bloc.stream.listen(states.add);

        bloc.add(const OnboardingSubmitted());
        await bloc.stream.firstWhere((state) => state is OnboardingStepActive);
        await coordinator.settled;

        expect(states.whereType<OnboardingSubmitError>(), hasLength(1));
        expect(states.whereType<OnboardingCompleted>(), isEmpty);
        expect(settingsBox.get(_markKey), isNull);
        expect(storage.onboardingPendingFor('uid-A'), isNull);
        expect(remote.calls, isEmpty);
        await subscription.cancel();
        await bloc.close();
      },
    );
  });

  test('the four-argument constructor used by D2 still compiles', () {
    final repository = _ProfileRepository((_) async {});
    final bloc = OnboardingBloc(
      getProfile: GetProfileUseCase(repository),
      updateProfile: UpdateProfileUseCase(repository),
      uploadAvatar: UploadAvatarUseCase(repository),
      localStorage: storage,
    );
    expect(bloc.state, isA<OnboardingInitial>());
    bloc.close();
  });
}
