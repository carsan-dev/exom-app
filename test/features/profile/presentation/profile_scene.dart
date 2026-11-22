// Shared scene of the L5-B4 «Perfil» tests and goldens: fake profile and
// metrics repositories behind the real ProfileBloc and use cases (registered
// in `sl` as a factory, like the app), an in-memory storage double for the
// unit preference and a pump with a router so a sheet can be closed by a
// location change (CC 11). Not a test file: it has no `main` and is only
// imported.
import 'dart:async';
import 'dart:io';

import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:exom_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/upload_avatar_usecase.dart';
import 'package:exom_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:exom_app/features/profile/presentation/pages/profile_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../golden/redesign_scenes.dart' show loadRedesignFonts;

/// Profile of the scenes: «Ana Ruiz», intermediate, gain muscle, 168 cm, a
/// 12-day streak and a 40 kg muscle mass goal.
const ProfileEntity sceneProfile = ProfileEntity(
  id: 'user-a',
  firstName: 'Ana',
  lastName: 'Ruiz',
  level: 'INTERMEDIATE',
  goal: 'GAIN_MUSCLE',
  heightCm: 168,
  streakDays: 12,
  currentWeightKg: 68.4,
  muscleMassGoalKg: 40,
);

/// Weight history from 71.4 to 68.4 kg.
List<BodyMetricEntity> sceneHistory() {
  const points = [
    (0, 71.4),
    (14, 70.9),
    (28, 70.2),
    (42, 69.6),
    (56, 69.1),
    (70, 68.8),
    (84, 68.4),
  ];
  return [
    for (var i = 0; i < points.length; i++)
      BodyMetricEntity(
        id: 'w$i',
        date: DateTime(2026, 8, 20).add(Duration(days: points[i].$1)),
        weightKg: points[i].$2,
      ),
  ];
}

/// Latest metric: 31.2 kg of muscle mass, 7.5 h of sleep, 74 cm waist.
BodyMetricEntity sceneLatest() => BodyMetricEntity(
  id: 'm1',
  date: DateTime(2026, 11, 14),
  muscleMassKg: 31.2,
  sleepHours: 7.5,
  waistCm: 74,
);

/// Profile repository double. Each `getProfile` takes the next entry of
/// [loads] (the last one repeats): a [ProfileEntity] is returned, anything
/// else is thrown. [gate], when set, holds `getProfile` until it completes.
class SceneProfileRepository extends Fake implements ProfileRepository {
  SceneProfileRepository({List<Object>? loads})
    : loads = loads ?? <Object>[sceneProfile];

  final List<Object> loads;
  final List<Map<String, dynamic>> updates = <Map<String, dynamic>>[];
  Object? updateResult;
  Completer<ProfileEntity>? avatar;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<ProfileEntity> getProfile() async {
    final index = calls < loads.length ? calls : loads.length - 1;
    calls++;
    final pending = gate;
    if (pending != null) await pending.future;
    final next = loads[index];
    if (next is ProfileEntity) return next;
    throw next;
  }

  @override
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data) async {
    updates.add(Map<String, dynamic>.of(data));
    final result = updateResult;
    if (result == null) {
      final goal = data['muscle_mass_goal'];
      final current = loads.whereType<ProfileEntity>().first;
      return ProfileEntity(
        id: current.id,
        firstName: current.firstName,
        lastName: current.lastName,
        level: current.level,
        goal: current.goal,
        heightCm: current.heightCm,
        streakDays: current.streakDays,
        currentWeightKg: current.currentWeightKg,
        muscleMassGoalKg: goal is double ? goal : current.muscleMassGoalKg,
      );
    }
    if (result is ProfileEntity) return result;
    throw result;
  }

  @override
  Future<ProfileEntity> uploadAvatar(File file) {
    final pending = avatar;
    if (pending != null) return pending.future;
    return Future.value(loads.whereType<ProfileEntity>().first);
  }
}

class SceneMetricsRepository extends Fake implements MetricsRepository {
  SceneMetricsRepository({List<BodyMetricEntity>? history, this.latest})
    : history = history ?? const <BodyMetricEntity>[];

  final List<BodyMetricEntity> history;
  final BodyMetricEntity? latest;

  @override
  Future<List<BodyMetricEntity>> getWeightHistory() async => history;

  @override
  Future<BodyMetricEntity?> getLatestMetric({String? date}) async => latest;
}

class SceneStorage extends LocalStorage {
  SceneStorage({this.unitSystem = UnitSystem.metric});

  final UnitSystem unitSystem;

  @override
  ThemeMode getThemeModePreference() => ThemeMode.dark;
  @override
  Locale? getLocalePreference() => null;
  @override
  UnitSystem getUnitSystemPreference() => unitSystem;
}

/// The scene with data: profile, history and latest metric.
SceneMetricsRepository sceneMetrics() =>
    SceneMetricsRepository(history: sceneHistory(), latest: sceneLatest());

class ProfileScene {
  ProfileScene(this.router, this.profiles, this.blocs);

  final GoRouter router;
  final SceneProfileRepository profiles;

  /// Every bloc the factory created, in order.
  final List<ProfileBloc> blocs;

  ProfileBloc get bloc => blocs.last;
}

/// Registers the ProfileBloc factory with [profiles] and [metrics].
List<ProfileBloc> registerProfileBloc(
  SceneProfileRepository profiles,
  MetricsRepository metrics,
) {
  final blocs = <ProfileBloc>[];
  if (sl.isRegistered<ProfileBloc>()) sl.unregister<ProfileBloc>();
  sl.registerFactory<ProfileBloc>(() {
    final bloc = ProfileBloc(
      getProfileUseCase: GetProfileUseCase(profiles),
      updateProfileUseCase: UpdateProfileUseCase(profiles),
      uploadAvatarUseCase: UploadAvatarUseCase(profiles),
      metricsRepository: metrics,
    );
    blocs.add(bloc);
    return bloc;
  });
  return blocs;
}

Future<ProfileScene> pumpProfileScene(
  WidgetTester tester, {
  SceneProfileRepository? profiles,
  MetricsRepository? metrics,
  UnitSystem unitSystem = UnitSystem.metric,
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('es'),
  bool disableAnimations = true,
  bool settle = true,
}) async {
  await loadRedesignFonts();
  await sl.reset();
  final store = SceneStorage(unitSystem: unitSystem);
  final repo = profiles ?? SceneProfileRepository();
  sl.registerSingleton<LocalStorage>(store);
  final blocs = registerProfileBloc(repo, metrics ?? sceneMetrics());
  addTearDown(sl.reset);
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => GlassDecoration.brightness = Brightness.dark);
  Widget stub(String text) => Scaffold(body: Center(child: Text(text)));
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/start', builder: (context, state) => stub('Inicio')),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/profile/metrics',
        builder: (context, state) => stub('Métricas'),
      ),
      GoRoute(
        path: AppRoutes.progressPhotos,
        builder: (context, state) => stub('Fotos'),
      ),
      GoRoute(
        path: AppRoutes.recap,
        builder: (context, state) => stub('Recap'),
      ),
      GoRoute(path: '/other', builder: (context, state) => stub('Otra')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<AppPreferencesCubit>(
      create: (_) => AppPreferencesCubit(store),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) {
          GlassDecoration.brightness = Theme.of(context).brightness;
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: textScaler,
              disableAnimations: disableAnimations,
            ),
            child: child!,
          );
        },
      ),
    ),
  );
  router.push(AppRoutes.profile);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
  return ProfileScene(router, repo, blocs);
}

/// Scrolls the profile list until [finder] is built and visible.
Future<void> revealInProfile(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// Pull to refresh on the profile list.
Future<void> pullToRefresh(WidgetTester tester) async {
  await tester.fling(find.byType(Scrollable).first, const Offset(0, 500), 1200);
  await tester.pumpAndSettle();
}
