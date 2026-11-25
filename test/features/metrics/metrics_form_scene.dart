// Scene of the metrics form for the L5-E9b goldens and layout tests: the real
// MetricsFormPage pushed over a stub home, with the real bloc and use cases
// over in-memory repositories. Not a test file: it has no `main` and is only
// imported.
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:exom_app/features/metrics/domain/usecases/save_metric_usecase.dart';
import 'package:exom_app/features/metrics/presentation/bloc/metrics_bloc.dart';
import 'package:exom_app/features/metrics/presentation/pages/metrics_page.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../golden/redesign_scenes.dart' show loadRedesignFonts;

/// The day of the scene, as in the sketch «Formulario de métricas»: 68.4 kg,
/// 168 cm, 31.2 kg of muscle mass, 7.5 h of sleep and a 74 cm waist.
final BodyMetricEntity sceneMetric = BodyMetricEntity(
  id: 'metric-1',
  date: DateTime(2026, 11, 18),
  weightKg: 68.4,
  heightCm: 168,
  muscleMassKg: 31.2,
  sleepHours: 7.5,
  waistCm: 74,
);

class _Repository extends Fake implements MetricsRepository {
  _Repository(this.latest);

  final BodyMetricEntity? latest;

  @override
  Future<BodyMetricEntity?> getLatestMetric({String? date}) async => latest;

  @override
  Future<BodyMetricEntity> saveMetric(Map<String, dynamic> data) async =>
      latest ?? sceneMetric;
}

class _Profile extends Fake implements ProfileEntity {}

class _ProfileRepository extends Fake implements ProfileRepository {
  @override
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data) async =>
      _Profile();
}

class _Storage extends LocalStorage {
  _Storage(this.unitSystem);

  final UnitSystem unitSystem;

  @override
  ThemeMode getThemeModePreference() => ThemeMode.dark;
  @override
  Locale? getLocalePreference() => null;
  @override
  UnitSystem getUnitSystemPreference() => unitSystem;
  @override
  Map<String, dynamic>? getCachedMap(String key) => null;
}

/// Pushes the metrics form with [latest] loaded and waits for it to settle,
/// without animations.
Future<void> pumpMetricsFormScene(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('es'),
  UnitSystem unitSystem = UnitSystem.metric,
  double width = 390,
  double height = 844,
  BodyMetricEntity? latest,
  bool loadFonts = true,
}) async {
  if (loadFonts) await loadRedesignFonts();
  await sl.reset();
  addTearDown(sl.reset);
  final storage = _Storage(unitSystem);
  final repository = _Repository(latest ?? sceneMetric);
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerFactory<MetricsBloc>(
    () => MetricsBloc(
      saveMetricUseCase: SaveMetricUseCase(repository),
      metricsRepository: repository,
      updateProfileUseCase: UpdateProfileUseCase(_ProfileRepository()),
    ),
  );
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => GlassDecoration.brightness = Brightness.dark);
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    BlocProvider<AppPreferencesCubit>(
      create: (_) => AppPreferencesCubit(storage),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          GlassDecoration.brightness = Theme.of(context).brightness;
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: textScaler, disableAnimations: true),
            child: child!,
          );
        },
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(builder: (_) => const MetricsFormPage()),
  );
  await tester.pumpAndSettle();
}
