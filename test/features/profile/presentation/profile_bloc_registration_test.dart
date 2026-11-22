// L5-B4 round 2 (M2): the real registration of ProfileBloc in
// `initDependencies` must stay a factory. R12 relies on it: each page mount
// gets its own bloc, so a profile kept after an error never reaches the next
// session. The scene tests register their own factory and cannot notice a
// change of the production registration; this one runs the real one.
import 'package:exom_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/upload_avatar_usecase.dart';
import 'package:exom_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'profile_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the real registration resolves a new ProfileBloc each time', () async {
    PackageInfo.setMockInitialValues(
      appName: 'EXOM',
      packageName: 'test.exom',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await sl.reset();
    addTearDown(sl.reset);
    await initDependencies();
    expect(sl.isRegistered<ProfileBloc>(), isTrue);

    // Only the leaves the factory reads are swapped for doubles: the
    // ProfileBloc registration under test is the production one.
    final profiles = SceneProfileRepository();
    sl.unregister<GetProfileUseCase>();
    sl.unregister<UpdateProfileUseCase>();
    sl.unregister<UploadAvatarUseCase>();
    sl.unregister<MetricsRepository>();
    sl.registerSingleton(GetProfileUseCase(profiles));
    sl.registerSingleton(UpdateProfileUseCase(profiles));
    sl.registerSingleton(UploadAvatarUseCase(profiles));
    sl.registerSingleton<MetricsRepository>(SceneMetricsRepository());

    final first = sl<ProfileBloc>();
    final second = sl<ProfileBloc>();
    addTearDown(first.close);
    addTearDown(second.close);
    expect(second, isNot(same(first)));
  });
}
