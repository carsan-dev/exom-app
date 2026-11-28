// Shared scene of the L5-E9a «Progreso» tests: eight weekly weights, the
// latest record with a waist measurement, the real bloc over a fake
// repository and the L2 component harness (real theme, bundled fonts, width /
// text scale / locale).
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:exom_app/features/metrics/domain/usecases/save_metric_usecase.dart';
import 'package:exom_app/features/metrics/presentation/bloc/metrics_bloc.dart';
import 'package:exom_app/features/metrics/presentation/pages/metrics_progress_page.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/widgets/exom_component_harness.dart';

BodyMetricEntity _w(int month, int day, double kg) => BodyMetricEntity(
  id: 'w-$month-$day',
  date: DateTime(2026, month, day),
  weightKg: kg,
);

/// Eight weekly weights, 30 Sep → 18 Nov 2026 (49 days = 7 weeks).
final sceneWeekly = [
  _w(9, 30, 70.9),
  _w(10, 7, 70.6),
  _w(10, 14, 70.4),
  _w(10, 21, 69.9),
  _w(10, 28, 69.6),
  _w(11, 4, 69.2),
  _w(11, 11, 68.8),
  _w(11, 18, 68.4),
];

final sceneLatest = BodyMetricEntity(
  id: 'latest',
  date: DateTime(2026, 11, 18),
  weightKg: 68.4,
  waistCm: 74,
);

class _SceneRepository extends Fake
    implements MetricsRepository, MetricsHistorySource {
  _SceneRepository({
    required this.history,
    required this.latest,
    required this.fromCache,
  });

  final List<BodyMetricEntity> history;
  final BodyMetricEntity? latest;
  final bool fromCache;

  @override
  Future<MetricsRead<List<BodyMetricEntity>>>
  getWeightHistoryWithSource() async =>
      MetricsRead(history, fromCache: fromCache);

  @override
  Future<MetricsRead<BodyMetricEntity?>> getLatestMetricWithSource() async =>
      MetricsRead(latest, fromCache: fromCache);
}

class _SceneProfile extends Fake implements ProfileEntity {}

class _SceneProfileRepository extends Fake implements ProfileRepository {
  @override
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data) async =>
      _SceneProfile();
}

class _SceneStorage extends LocalStorage {
  @override
  ThemeMode getThemeModePreference() => ThemeMode.dark;
  @override
  Locale? getLocalePreference() => null;
  @override
  UnitSystem getUnitSystemPreference() => UnitSystem.metric;
  @override
  Map<String, dynamic>? getCachedMap(String key) => null;
}

/// The «Progreso» screen. Defaults: network data, weekly weights and the
/// latest record. [fromCache] paints the «datos guardados» band.
Future<void> pumpProgressScene(
  WidgetTester tester, {
  List<BodyMetricEntity>? history,
  BodyMetricEntity? latest,
  bool fromCache = false,
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  TextScaler? textScaler,
  Locale locale = const Locale('es'),
}) async {
  await sl.reset();
  addTearDown(sl.reset);
  final repository = _SceneRepository(
    history: history ?? sceneWeekly,
    latest: latest ?? sceneLatest,
    fromCache: fromCache,
  );
  final storage = _SceneStorage();
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerFactory<MetricsBloc>(
    () => MetricsBloc(
      saveMetricUseCase: SaveMetricUseCase(repository),
      metricsRepository: repository,
      updateProfileUseCase: UpdateProfileUseCase(_SceneProfileRepository()),
    ),
  );
  await pumpComponent(
    tester,
    BlocProvider<AppPreferencesCubit>(
      create: (_) => AppPreferencesCubit(storage),
      child: const MetricsProgressPage(),
    ),
    brightness: brightness,
    width: width,
    height: height,
    textScale: textScale,
    textScaler: textScaler,
    locale: locale,
    disableAnimations: true,
    wrapInScaffold: false,
  );
  await tester.pump(const Duration(milliseconds: 500));
}
