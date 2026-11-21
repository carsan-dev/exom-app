// Shared scene of the L5-B3 «Ajustes» tests and goldens: an in-memory
// storage double (preferences, active circuit flag, feedback upload queue,
// counters for `clearCache` and the session stamp), fakes for the auth bloc,
// the update service and the rest timer, and a pump with a router so a sheet
// can be closed by a location change (CC 11). Not a test file: it has no
// `main` and is only imported.
import 'dart:async';

import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/services/app_update_service.dart';
import 'package:exom_app/core/services/rest_timer_coordinator.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/settings/presentation/pages/settings_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;

/// Storage double: preferences live in [settings]; [failingKeys] make
/// `saveSetting` throw for those keys; [gate], when set, holds every save until
/// it completes (to observe the switch before the write ends, M8).
class SceneStorage extends LocalStorage {
  SceneStorage({
    this.activeCircuit = false,
    List<Map<String, dynamic>>? uploads,
  }) : uploads = uploads ?? <Map<String, dynamic>>[];

  final Map<String, Object?> settings = <String, Object?>{};
  final Set<String> failingKeys = <String>{};
  final List<Map<String, dynamic>> uploads;
  bool activeCircuit;
  Completer<void>? gate;
  int clears = 0;
  int queueReads = 0;
  String stamp = 'uid-a:1:test';

  @override
  String? get sessionStamp => stamp;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = settings[key];
    return value is T ? value : defaultValue;
  }

  @override
  Future<void> saveSetting(String key, Object? value) async {
    final pending = gate;
    if (pending != null) await pending.future;
    if (failingKeys.contains(key)) {
      throw StateError('write refused for $key');
    }
    settings[key] = value;
  }

  @override
  bool get hasActiveCircuitState => activeCircuit;

  @override
  Future<void> clearCache() async => clears++;

  @override
  List<Map<String, dynamic>> getFeedbackUploadQueue() {
    queueReads++;
    return [for (final item in uploads) Map<String, dynamic>.of(item)];
  }
}

class SceneUpdate extends Fake implements AppUpdateService {
  @override
  String get currentVersionLabel => '1.3.0 (42)';
}

class SceneRestTimer implements RestTimerCoordinator {
  @override
  RestTimerSession? get activeSession => null;
  @override
  Future<void> start(RestTimerSession session) async {}
  @override
  Future<void> finish() async {}
  @override
  Future<void> cancel() async {}
}

/// Auth bloc double: records the events it receives; tests push states
/// through [states].
class SceneAuth extends Fake implements AuthBloc {
  final events = <AuthEvent>[];
  final states = StreamController<AuthState>.broadcast();
  AuthState current = const AuthInitial();

  @override
  AuthState get state => current;

  @override
  Stream<AuthState> get stream => states.stream;

  @override
  void add(AuthEvent event) => events.add(event);

  @override
  bool get isClosed => false;

  @override
  Future<void> close() async {}

  /// Emits [next] as the bloc would (state first, then the stream); pump
  /// afterwards to deliver it.
  void emitState(AuthState next) {
    current = next;
    states.add(next);
  }
}

/// Three uploads in the queue, one of them dismissed: «Subidas pendientes»
/// lists (and counts) two.
List<Map<String, dynamic>> sceneUploads() => [
  {'id': 'u1', 'status': 'queued', 'media_type': 'VIDEO'},
  {'id': 'u2', 'status': 'failed', 'media_type': 'VIDEO'},
  {'id': 'u3', 'status': 'failed', 'media_type': 'VIDEO', 'dismissed': true},
];

class SettingsScene {
  SettingsScene(this.router, this.storage, this.auth);

  final GoRouter router;
  final SceneStorage storage;
  final SceneAuth auth;
}

Future<SettingsScene> pumpSettingsScene(
  WidgetTester tester, {
  SceneStorage? storage,
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('es'),
  bool disableAnimations = true,
}) async {
  await loadRedesignFonts();
  await sl.reset();
  final store = storage ?? SceneStorage(uploads: sceneUploads());
  final auth = SceneAuth();
  sl.registerSingleton<LocalStorage>(store);
  sl.registerSingleton<AppUpdateService>(SceneUpdate());
  sl.registerSingleton<RestTimerCoordinator>(SceneRestTimer());
  addTearDown(() async {
    await auth.states.close();
    await sl.reset();
  });
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => GlassDecoration.brightness = Brightness.dark);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SettingsPage()),
      GoRoute(
        path: '/other',
        builder: (context, state) => const Scaffold(body: Text('Otra')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: auth),
        BlocProvider<AppPreferencesCubit>(
          create: (_) => AppPreferencesCubit(store),
        ),
      ],
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
  await tester.pumpAndSettle();
  return SettingsScene(router, store, auth);
}

/// Scrolls the settings list until [finder] is built and visible.
Future<void> revealInSettings(WidgetTester tester, Finder finder) async {
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
