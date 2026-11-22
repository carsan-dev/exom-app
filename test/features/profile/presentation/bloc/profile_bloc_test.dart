// L5-B4 / EX-Q7 (docs/plans/rediseno-app-l5-contrato-v2.md, L5-D28): once a
// profile is loaded, a failed reload, goal update or avatar upload emits a
// ProfileError that keeps that profile (with its weight history and latest
// metric) so the page can paint the error in line. A first load that fails
// keeps nothing, and a session change in flight never keeps the previous
// owner's profile (R12).
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/upload_avatar_usecase.dart';
import 'package:exom_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../profile_scene.dart';

/// The bloc as the app builds it: real use cases, fake repositories.
ProfileBloc _bloc(SceneProfileRepository profiles) => ProfileBloc(
  getProfileUseCase: GetProfileUseCase(profiles),
  updateProfileUseCase: UpdateProfileUseCase(profiles),
  uploadAvatarUseCase: UploadAvatarUseCase(profiles),
  metricsRepository: sceneMetrics(),
);

Future<List<ProfileState>> _run(
  ProfileBloc bloc,
  ProfileEvent event, {
  required bool Function(ProfileState) until,
}) async {
  final states = <ProfileState>[];
  final done = Completer<void>();
  final sub = bloc.stream.listen((state) {
    states.add(state);
    if (until(state) && !done.isCompleted) done.complete();
  });
  bloc.add(event);
  await done.future.timeout(const Duration(seconds: 2));
  await sub.cancel();
  return states;
}

bool _settled(ProfileState s) => s is ProfileLoaded || s is ProfileError;

Future<ProfileBloc> _loaded(SceneProfileRepository profiles) async {
  final bloc = _bloc(profiles);
  final states = await _run(
    bloc,
    const ProfileLoadRequested(),
    until: _settled,
  );
  expect(states.last, isA<ProfileLoaded>());
  return bloc;
}

void main() {
  test(
    'a first load that fails keeps no profile (full-screen error)',
    () async {
      final bloc = _bloc(
        SceneProfileRepository(loads: [StateError('offline')]),
      );
      addTearDown(bloc.close);
      final states = await _run(
        bloc,
        const ProfileLoadRequested(),
        until: _settled,
      );
      expect(states.first, isA<ProfileLoading>());
      final error = states.last as ProfileError;
      expect(error.profile, isNull);
      expect(error.weightHistory, isEmpty);
      expect(error.latestMetric, isNull);
    },
  );

  test(
    'a reload that fails keeps the loaded profile, history and metric',
    () async {
      final profiles = SceneProfileRepository(
        loads: [sceneProfile, StateError('offline')],
      );
      final bloc = await _loaded(profiles);
      addTearDown(bloc.close);
      final loaded = bloc.state as ProfileLoaded;

      final states = await _run(
        bloc,
        const ProfileLoadRequested(),
        until: _settled,
      );
      expect(states.first, isA<ProfileLoading>());
      final error = states.last as ProfileError;
      expect(error.profile, same(loaded.profile));
      expect(error.weightHistory, same(loaded.weightHistory));
      expect(error.latestMetric, same(loaded.latestMetric));
      expect(error.message, contains('offline'));
    },
  );

  test('a second failed retry still keeps the same profile', () async {
    final profiles = SceneProfileRepository(
      loads: [sceneProfile, StateError('offline')],
    );
    final bloc = await _loaded(profiles);
    addTearDown(bloc.close);
    await _run(bloc, const ProfileLoadRequested(), until: _settled);
    final states = await _run(
      bloc,
      const ProfileLoadRequested(),
      until: _settled,
    );
    final error = states.last as ProfileError;
    expect(error.profile, same(sceneProfile));
  });

  test(
    'a retry that succeeds replaces the error with the loaded profile',
    () async {
      final profiles = SceneProfileRepository(
        loads: [sceneProfile, StateError('offline'), sceneProfile],
      );
      final bloc = await _loaded(profiles);
      addTearDown(bloc.close);
      await _run(bloc, const ProfileLoadRequested(), until: _settled);
      final states = await _run(
        bloc,
        const ProfileLoadRequested(),
        until: _settled,
      );
      expect(states.last, isA<ProfileLoaded>());
    },
  );

  test('a session change during the reload keeps no profile (R12)', () async {
    final profiles = SceneProfileRepository(
      loads: [sceneProfile, const LocalSessionChanged()],
    );
    final bloc = await _loaded(profiles);
    addTearDown(bloc.close);
    final states = await _run(
      bloc,
      const ProfileLoadRequested(),
      until: _settled,
    );
    final error = states.last as ProfileError;
    expect(error.profile, isNull);
  });

  test('a request cancelled by the session keeps no profile (R12)', () async {
    final profiles = SceneProfileRepository(
      loads: [
        sceneProfile,
        DioException(
          requestOptions: RequestOptions(path: '/profile'),
          type: DioExceptionType.cancel,
        ),
      ],
    );
    final bloc = await _loaded(profiles);
    addTearDown(bloc.close);
    final states = await _run(
      bloc,
      const ProfileLoadRequested(),
      until: _settled,
    );
    expect((states.last as ProfileError).profile, isNull);
  });

  test(
    'a goal update that fails keeps the profile shown before saving',
    () async {
      final profiles = SceneProfileRepository()
        ..updateResult = StateError('server');
      final bloc = await _loaded(profiles);
      addTearDown(bloc.close);
      final loaded = bloc.state as ProfileLoaded;
      final states = await _run(
        bloc,
        const ProfileMuscleGoalUpdated(41.5),
        until: _settled,
      );
      final error = states.last as ProfileError;
      expect(error.profile, same(loaded.profile));
      expect(error.weightHistory, same(loaded.weightHistory));
      expect(error.latestMetric, same(loaded.latestMetric));
      expect(profiles.updates.single, {'muscle_mass_goal': 41.5});
    },
  );

  test('an avatar upload that fails keeps the profile', () async {
    final profiles = SceneProfileRepository();
    final bloc = await _loaded(profiles);
    addTearDown(bloc.close);
    final loaded = bloc.state as ProfileLoaded;
    final upload = profiles.avatar = Completer<ProfileEntity>();
    // Fails once the bloc is already waiting on the upload.
    unawaited(
      Future<void>.delayed(
        Duration.zero,
        () => upload.completeError(StateError('upload')),
      ),
    );
    final states = await _run(
      bloc,
      ProfileAvatarUploadRequested(File('avatar.jpg')),
      until: (s) => s is ProfileError,
    );
    expect(states.first, isA<ProfileAvatarUploading>());
    final error = states.last as ProfileError;
    expect(error.profile, same(loaded.profile));
    expect(error.latestMetric, same(loaded.latestMetric));
  });

  test('the legacy positional constructor still builds an error without '
      'profile', () {
    const error = ProfileError('x');
    expect(error.message, 'x');
    expect(error.profile, isNull);
    expect(error.weightHistory, isEmpty);
  });
}
