import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/config/app_distribution_config.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/core/services/app_update_service.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:exom_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:exom_app/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/get_me_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/social_login_usecase.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/splash/presentation/pages/splash_page.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_handoff.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_scene.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_timeline.dart';
import 'package:exom_app/core/widgets/exom_brand_logo.dart';
import 'package:exom_app/core/widgets/exom_launch_symbol.dart';
import 'package:exom_app/main.dart' show ExomBootstrapApp;

import '../../../../helpers/onboarding_harness.dart';

class _UpdateService extends Fake implements AppUpdateService {
  _UpdateService(this.decision);

  final Future<AppUpdateDecision> decision;
  int checks = 0;

  @override
  Future<AppUpdateDecision> checkForUpdates() {
    checks++;
    return decision;
  }

  @override
  Future<bool> openStore(AppUpdateDecision decision) async => true;
}

const _upToDate = AppUpdateDecision(
  status: AppUpdateStatus.upToDate,
  currentVersion: '1.0.0',
  currentBuild: 1,
);

class _Firebase extends FirebaseAuthService {
  @override
  LocalAuthSession? get currentSession => null;
}

class _Repository implements AuthRepository {
  @override
  Future<UserEntity> getMe() => throw UnimplementedError();
  @override
  Future<UserEntity> login(String email, String password) =>
      throw UnimplementedError();
  @override
  Future<UserEntity> socialLogin(String token, String provider) =>
      throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  UserEntity? getCurrentUser() => null;
  @override
  Future<void> deleteAccount() async {}
  @override
  Future<void> forgotPassword(String email) async {}
}

AuthBloc _authBloc() {
  final repository = _Repository();
  return AuthBloc(
    loginUseCase: LoginUseCase(repository),
    socialLoginUseCase: SocialLoginUseCase(repository),
    logoutUseCase: LogoutUseCase(repository),
    getMeUseCase: GetMeUseCase(repository),
    deleteAccountUseCase: DeleteAccountUseCase(repository),
    firebaseAuthService: _Firebase(),
  );
}

Future<int> _pumpUntilLogin(WidgetTester tester, {int limitMs = 8000}) async {
  var elapsed = 0;
  while (find.text('login-route').evaluate().isEmpty && elapsed < limitMs) {
    await tester.pump(const Duration(milliseconds: 10));
    elapsed += 10;
  }
  return elapsed;
}

Future<void> _pumpFor(WidgetTester tester, int ms) async {
  for (var elapsed = 0; elapsed < ms; elapsed += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _mount(
  WidgetTester tester,
  AuthBloc bloc, {
  ThemeData? theme,
}) async {
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const Scaffold(body: Text('login-route')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        routerConfig: router,
        // The app's MaterialApp.router uses theme light, darkTheme dark and a
        // themeMode from prefs (default system), so the splash renders in both
        // themes. Dark by default here; pass [theme] to exercise light.
        theme: theme ?? AppTheme.dark,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
}

/// Unmounts the splash and lets its gate timeouts (6 s) expire.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 7));
}

/// Stand-in for `HomeBloc`: the real `MainShell` builds one with
/// `sl<HomeBloc>()` in `initState`, exactly as [_HomeProbe] does, so counting
/// the factory calls counts the moments Inicio is mounted.
class _HomeBlocProbe extends Fake implements HomeBloc {}

/// Inicio as `MainShell` mounts it: builds its `HomeBloc` and reports its
/// content to the hand-off with the same call and predicate (D3-Q6); the
/// harness plays the bloc's states ([_HomeHarness.states]).
class _HomeProbe extends StatefulWidget {
  const _HomeProbe(this.harness);

  final _HomeHarness harness;

  @override
  State<_HomeProbe> createState() => _HomeProbeState();
}

class _HomeProbeState extends State<_HomeProbe> {
  StreamSubscription<HomeState>? _content;

  @override
  void initState() {
    super.initState();
    sl<HomeBloc>();
    _content = V4dHandoff.watchInicioContent(
      () => widget.harness.states.stream,
      isInicioContent,
    );
  }

  @override
  void dispose() {
    _content?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('home-route')));
}

class _HomeHarness {
  _HomeHarness(this.clock);

  final int Function() clock;
  late final AuthBloc auth;
  int homeBlocs = 0;
  int? firstHomeBlocAt;
  int? readyAt;
  bool slowNoticeSeen = false;

  /// States of Inicio's `HomeBloc`; content ([HomeLoaded]) at [contentAt].
  final states = StreamController<HomeState>.broadcast();
  int? contentAt;
  int? contentSentAt;

  /// First time the hand-off reports the opening as started.
  int? openedAt;

  /// Times at which the curtain's scene was already opening (its time past
  /// its `openAt`) while the hand-off still said it was waiting.
  final openBeforeReported = <int>[];
  void Function()? _pendingCheck;
  int _checkAt = 0;
  void Function(int ms) _tick = (_) {};
}

const _sessionA = LocalAuthSession(uid: 'uid-A', email: 'a@exom.test');

/// Background of the login stand-in: no colour of the splash has it, so a
/// pixel shows whether the window of the X shows the login (D3-Q9).
const _loginColour = Color(0xFF1E5BFF);

/// Mounts the splash with a valid session whose destination is Inicio (or
/// the destination [getMe] leads to). The auth check is requested at
/// [checkAt] ms (null: never), so the gates resolve at that moment.
Future<_HomeHarness> _mountHome(
  WidgetTester tester, {
  required int? checkAt,
  Object? getMe,
  Future<AppUpdateDecision>? update,
  int? contentAt,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  var now = 0;
  final harness = _HomeHarness(() => now)..contentAt = contentAt;
  addTearDown(harness.states.close);
  final firebase = SessionFirebaseAuthService(_sessionA);
  sl.registerSingleton<AppUpdateService>(
    _UpdateService(update ?? Future.value(_upToDate)),
  );
  sl.registerSingleton<FirebaseAuthService>(firebase);
  sl.registerSingleton<LocalStorage>(
    LocalStorage(currentSession: () => firebase.currentSession),
  );
  sl.registerFactory<HomeBloc>(() {
    harness.homeBlocs++;
    harness.firstHomeBlocAt ??= now;
    return _HomeBlocProbe();
  });
  final repository = ScriptedAuthRepository(
    getMe ?? userFromServer(profile: doneProfile),
  );
  final bloc = AuthBloc(
    loginUseCase: LoginUseCase(repository),
    socialLoginUseCase: SocialLoginUseCase(repository),
    logoutUseCase: LogoutUseCase(repository),
    getMeUseCase: GetMeUseCase(repository),
    deleteAccountUseCase: DeleteAccountUseCase(repository),
    firebaseAuthService: firebase,
  );
  addTearDown(bloc.close);
  harness.auth = bloc;
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: AppRoutes.home, builder: (_, _) => _HomeProbe(harness)),
      // The app's login page (and its entry), with a stand-in for LoginPage.
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (_, state) => loginRoutePage(
          key: state.pageKey,
          child: const Scaffold(
            backgroundColor: _loginColour,
            body: Text('login-route'),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const Scaffold(body: Text('onboarding-route')),
      ),
      GoRoute(
        path: AppRoutes.accountLocked,
        builder: (_, _) => const Scaffold(body: Text('locked-route')),
      ),
    ],
  );
  addTearDown(router.dispose);
  if (checkAt == 0) {
    bloc.add(const AuthCheckStatusRequested());
    harness.readyAt = 0;
  }
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        routerConfig: router,
        theme: theme ?? AppTheme.dark,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  if (checkAt != null && checkAt > 0) {
    // Requested from the clock below, at the first pump that reaches it.
    harness._pendingCheck = () {
      bloc.add(const AuthCheckStatusRequested());
      harness.readyAt = now;
    };
    harness._checkAt = checkAt;
  }
  harness._tick = (ms) {
    now = ms;
    if (find.text('Conectando…').evaluate().isNotEmpty) {
      harness.slowNoticeSeen = true;
    }
    final check = harness._pendingCheck;
    if (check != null && ms >= harness._checkAt) {
      harness._pendingCheck = null;
      check();
    }
    final opening = V4dHandoff.current.value;
    if (harness.openedAt == null && opening != null && opening.elapsed >= 0) {
      harness.openedAt = ms;
    }
    final curtainScene = find.descendant(
      of: find.byKey(SplashPage.curtainKey),
      matching: find.byType(V4dScene),
    );
    if (harness.openedAt == null && curtainScene.evaluate().isNotEmpty) {
      final scene = tester.widget<V4dScene>(curtainScene);
      final openAt = scene.openAt;
      if (openAt != null && scene.time >= openAt) {
        harness.openBeforeReported.add(ms);
      }
    }
    final contentAt = harness.contentAt;
    if (contentAt != null &&
        harness.contentSentAt == null &&
        harness.homeBlocs > 0 &&
        ms >= contentAt) {
      harness.contentSentAt = ms;
      harness.states.add(
        HomeLoaded(
          const HomeSummaryEntity(),
          selectedDate: DateTime(2026, 11, 25),
        ),
      );
    }
  };
  return harness;
}

/// Pumps in 10 ms steps from the first frame until Inicio is usable: the
/// splash curtain is gone and Inicio is on screen and receives taps.
Future<int> _pumpUntilUsable(
  WidgetTester tester,
  _HomeHarness home, {
  int limitMs = 8000,
}) async {
  var elapsed = home.clock();
  home._tick(elapsed);
  while (elapsed < limitMs) {
    final usable =
        find.text('home-route').hitTestable().evaluate().isNotEmpty &&
        find.byKey(SplashPage.curtainKey).evaluate().isEmpty;
    if (usable) return elapsed;
    await tester.pump(const Duration(milliseconds: 10));
    elapsed += 10;
    home._tick(elapsed);
  }
  return elapsed;
}

Color _pixel(ByteData rgba, int width, Offset at) {
  final i = (at.dy.round() * width + at.dx.round()) * 4;
  return Color.fromARGB(
    rgba.getUint8(i + 3),
    rgba.getUint8(i),
    rgba.getUint8(i + 1),
    rgba.getUint8(i + 2),
  );
}

int _distance(Color a, Color b) => [
  ((a.r - b.r) * 255).round().abs(),
  ((a.g - b.g) * 255).round().abs(),
  ((a.b - b.b) * 255).round().abs(),
].reduce((x, y) => x > y ? x : y);

/// Opacity of the login stand-in from its route's entry transition.
double _loginOpacity(WidgetTester tester) {
  var opacity = 1.0;
  for (final element
      in find
          .ancestor(
            of: find.text('login-route'),
            matching: find.byType(FadeTransition),
          )
          .evaluate()) {
    opacity *= (element.widget as FadeTransition).opacity.value;
  }
  return opacity;
}

/// What a start towards the login looked like, frame by frame (D3-Q9).
class _LoginRun {
  /// First frame with the login in the tree.
  int? mountedAt;

  /// Start of the opening, as the last V4d scene on screen had it.
  double? openAt;

  /// Curtain gone and the login receives taps.
  int? usableAt;
  final problems = <String>[];
}

/// Pumps in 10 ms steps until the login is usable and records every frame
/// on which the window of the X (or the screen once the X is gone) does not
/// show the login, fully opaque: a plain background between the X and the
/// login, a neutral window or the login's 600 ms fade. With [pixels], it
/// also reads the screen from the start of the opening: the centre of the
/// X is never the plain background, and once the X has grown past the
/// screen the screen is the login.
Future<_LoginRun> _runToLogin(
  WidgetTester tester,
  _HomeHarness home, {
  required ThemeData theme,
  bool pixels = false,
  int limitMs = 4000,
}) async {
  final run = _LoginRun();
  final background = theme.extension<ExomThemePalette>()!.background;
  var t = home.clock();
  home._tick(t);
  while (t < limitMs) {
    await tester.pump(const Duration(milliseconds: 10));
    t += 10;
    home._tick(t);
    if (home.homeBlocs != 0) run.problems.add('$t ms: HomeBloc built');
    if (find.text('home-route').evaluate().isNotEmpty) {
      run.problems.add('$t ms: Inicio built');
    }
    final hasLogin = find.text('login-route').evaluate().isNotEmpty;
    if (hasLogin) run.mountedAt ??= t;
    final loginOpaque = hasLogin && _loginOpacity(tester) == 1;
    final scenes = find.byType(V4dScene).evaluate().toList();
    double? opening;
    Offset? centre;
    for (final element in scenes) {
      final scene = element.widget as V4dScene;
      final open = scene.openAt;
      if (open == null) continue;
      run.openAt = open;
      final o = scene.time - open;
      opening = o;
      centre = scene.layout.xCentre;
      if (o <= V4dTimeline.growStart) continue;
      // The X has started to empty: its window shows what is under it.
      if (scene.content != V4dWindowContent.login) {
        run.problems.add('$t ms: window ${scene.content.name}, o = $o');
      }
      if (!hasLogin) run.problems.add('$t ms: window open, no login');
      if (hasLogin && !loginOpaque) {
        run.problems.add('$t ms: login fading in the window');
      }
    }
    if (scenes.isEmpty && home.readyAt != null) {
      if (!hasLogin) run.problems.add('$t ms: no X and no login');
      if (hasLogin && !loginOpaque) run.problems.add('$t ms: login fading');
    }
    if (pixels && ((opening != null && opening >= 0) || scenes.isEmpty)) {
      final at = centre ?? const Offset(206, 457);
      final element = find.byType(MaterialApp).evaluate().single;
      final (middle, corner) = (await tester.runAsync(() async {
        final image = await captureImage(element);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final colours = (
          _pixel(bytes, image.width, at),
          // Bottom right: away from the login stand-in's text.
          _pixel(
            bytes,
            image.width,
            Offset(image.width - 4.0, image.height - 4.0),
          ),
        );
        image.dispose();
        return colours;
      }))!;
      if (_distance(middle, background) <= 24) {
        run.problems.add('$t ms: plain background at the X centre');
      }
      if ((opening == null || opening >= V4dTimeline.grow) &&
          (_distance(middle, _loginColour) > 8 ||
              _distance(corner, _loginColour) > 8)) {
        run.problems.add('$t ms: X grown but the screen is not the login');
      }
    }
    final usable =
        find.text('login-route').hitTestable().evaluate().isNotEmpty &&
        find.byKey(SplashPage.curtainKey).evaluate().isEmpty &&
        scenes.isEmpty;
    if (usable) {
      run.usableAt = t;
      break;
    }
  }
  return run;
}

void main() {
  setUp(() async {
    await sl.reset();
  });
  tearDown(sl.reset);

  // L5-D3 (contract, «Tests»): the two tests that asserted the former timing
  // («MEASURE splash simulated ms to navigation with gates ready», 2100 ms of
  // entry + 650 ms of exit, and «does not navigate before the entry animation
  // completes», no navigation at 2000 ms) are replaced. V4d no longer waits
  // for its entry: the correct contract is «nothing happens before the gates
  // resolve nor before the opening ends», measured below with Inicio as the
  // destination. The three gate tests after this group stay unchanged.
  //
  // r3, D3-Q6 (owner, 2026-11-25; replaces case (2) of the timeline for
  // Inicio): Inicio is built under the opaque X at t_ready and the opening
  // starts when Inicio has painted content, at the latest 600 ms after
  // t_ready, and never before 660 ms when the entry played complete:
  // t_open = max(660, min(t_content, t_ready + 600)); usable at
  // t_open + 790 = max(1450, ...). The former table (gates at 0, 400, 660
  // and 2000 -> usable at 790, 1190, 1450 and 2790) opened at t_ready.
  group('V4d timeline, destination Inicio', () {
    late Directory directory;

    setUp(() async {
      directory = await openInMemorySettingsBox();
    });
    tearDown(() async {
      await closeSettingsBox(directory);
    });
    tearDown(V4dHandoff.reset);

    for (final (ready, content, opens, usable) in const [
      // Content 200 ms after t_ready (gates after the rest): opens there.
      (1000, 1200, 1200, 1990),
      // No content: opens at the cap, t_ready + 600.
      (1000, null, 1600, 2390),
      (660, null, 1260, 2050),
      // Gates and content before 660: the entry and the rest play complete.
      (0, 200, 660, 1450),
      (0, null, 660, 1450),
      (400, 600, 660, 1450),
      // Slow start: content after the notice.
      (2000, 2200, 2200, 2990),
    ]) {
      final what = content == null ? 'no content' : 'content at $content ms';
      testWidgets('gates at $ready ms, $what: opens at $opens ms, Inicio '
          'usable at $usable ms', (tester) async {
        final home = await _mountHome(
          tester,
          checkAt: ready,
          contentAt: content,
        );
        final elapsed = await _pumpUntilUsable(tester, home);
        // ignore: avoid_print
        print(
          'SPLASH_V4D_READY_${ready}_CONTENT_${content}_USABLE_MS=$elapsed',
        );
        expect(home.readyAt, isNotNull);
        // Inicio is mounted under the X once, when the gates resolve.
        expect(home.homeBlocs, 1);
        expect(home.firstHomeBlocAt, greaterThanOrEqualTo(home.readyAt!));
        expect(home.firstHomeBlocAt, lessThanOrEqualTo(home.readyAt! + 20));
        // The X stays opaque until the opening starts.
        expect(home.openBeforeReported, isEmpty);
        expect(home.openedAt, inInclusiveRange(opens, opens + 20));
        if (content != null) {
          // Inicio's data was on screen behind the X before the window
          // opened (the X no longer opens onto the skeleton).
          expect(home.openedAt, greaterThan(home.contentSentAt!));
        }
        expect(elapsed, inInclusiveRange(usable, usable + 20));
        expect(home.slowNoticeSeen, ready >= 2000);
      });
    }

    testWidgets('waiting for content: Inicio is built under the opaque X and '
        'cannot be reached', (tester) async {
      final home = await _mountHome(tester, checkAt: 1000);
      var t = 0;
      while (t < 1500) {
        await tester.pump(const Duration(milliseconds: 10));
        t += 10;
        home._tick(t);
      }
      expect(home.homeBlocs, 1);
      expect(find.text('home-route'), findsOneWidget);
      expect(find.text('home-route').hitTestable(), findsNothing);
      expect(V4dHandoff.current.value?.elapsed, lessThan(0));
      final scene = tester.widget<V4dScene>(
        find.descendant(
          of: find.byKey(SplashPage.curtainKey),
          matching: find.byType(V4dScene),
        ),
      );
      // Not even scheduled: it waits for content or the cap (1600).
      expect(scene.openAt, isNull);
    });

    testWidgets('slow start (> 2 s): icon and phrase, no lime', (tester) async {
      final home = await _mountHome(tester, checkAt: null);
      await _pumpFor(tester, 1950);
      expect(find.text('Conectando…'), findsNothing);
      await _pumpFor(tester, 100);
      expect(find.text('Conectando…'), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(SplashPage.slowStartKey),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, ExomIcons.syncing);
      final palette = AppTheme.dark.extension<ExomThemePalette>()!;
      expect(icon.color, palette.textSecondary);
      expect(home.homeBlocs, 0);
      await _unmount(tester);
    });

    // r4, D3-Q8 (owner, 2026-11-25): in reduced motion the 120 ms fade to
    // Inicio also waits for Inicio's content, at the latest 600 ms after
    // t_ready, and keeps the 600 ms hold: t_fade = max(600, min(t_content,
    // t_ready + 600)); usable at t_fade + 120. Inicio is built under the
    // opaque lockup at t_ready, as under the X. Replaces the former table
    // (gates at 0 and 800 -> usable at 720 and 920, fade at max(600,
    // t_ready) with Inicio built at the fade); the row (0, 720) is kept.
    for (final (ready, content, usable) in const [
      (0, null, 720),
      (0, 200, 720),
      (300, 700, 820),
      (800, 1000, 1120),
      (800, null, 1520),
    ]) {
      final what = content == null ? 'no content' : 'content at $content ms';
      testWidgets('reduced motion, gates at $ready ms, $what: Inicio built '
          'under the lockup at t_ready, usable at $usable ms', (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final home = await _mountHome(
          tester,
          checkAt: ready,
          contentAt: content,
        );
        final elapsed = await _pumpUntilUsable(tester, home);
        expect(home.homeBlocs, 1);
        expect(home.firstHomeBlocAt, greaterThanOrEqualTo(home.readyAt!));
        expect(home.firstHomeBlocAt, lessThanOrEqualTo(home.readyAt! + 20));
        expect(home.openedAt, inInclusiveRange(usable - 120, usable - 100));
        if (content != null) {
          // The fade starts once Inicio's data is on screen under the
          // lockup, not over its skeleton.
          expect(home.openedAt, greaterThan(home.contentSentAt!));
        }
        expect(elapsed, inInclusiveRange(usable, usable + 20));
      });
    }

    // r4, D3-Q9 (owner, 2026-11-25): with destination login the login is
    // built under the X and the X opens onto it, with the opening of Inicio
    // and no wait for content; no neutral window and no 600 ms fade of the
    // login on this path. The login is mounted 650 ms after t_ready, as the
    // splash always did (the three gate tests below require 600-700 ms), and
    // the opening starts so that the X begins to empty on the frame after it
    // is mounted: t_open = max(660, t_mount - 160); usable at t_open + 790.
    for (final (ready, mounts, opens, usable) in const [
      (0, 650, 660, 1450),
      (400, 1050, 890, 1680),
      (1000, 1650, 1490, 2280),
    ]) {
      testWidgets('destination login, gates at $ready ms: login built under '
          'the X at $mounts ms, opens at $opens ms onto it, usable at '
          '$usable ms; HomeBloc never built', (tester) async {
        final home = await _mountHome(
          tester,
          checkAt: ready,
          getMe: const ApiException(statusCode: 401, message: 'rejected'),
        );
        final run = await _runToLogin(tester, home, theme: AppTheme.dark);
        expect(run.problems, isEmpty);
        expect(run.mountedAt, inInclusiveRange(mounts, mounts + 20));
        expect(run.openAt, inInclusiveRange(opens, opens + 20));
        expect(run.usableAt, inInclusiveRange(usable, usable + 20));
        expect(home.homeBlocs, 0);
        expect(V4dHandoff.loginEntry.value, isFalse);
      });
    }

    for (final (label, theme, ready) in [
      ('dark', AppTheme.dark, 1000),
      ('light', AppTheme.light, 0),
    ]) {
      testWidgets('destination login ($label): the screen goes from the X to '
          'the login with no plain background frame', (tester) async {
        final home = await _mountHome(
          tester,
          checkAt: ready,
          getMe: const ApiException(statusCode: 401, message: 'rejected'),
          theme: theme,
        );
        final run = await _runToLogin(tester, home, theme: theme, pixels: true);
        expect(run.problems, isEmpty);
        expect(run.usableAt, isNotNull);
        expect(home.homeBlocs, 0);
      });
    }

    testWidgets('destination login: a tap after the gates jumps to the '
        'login, at once and without the fade', (tester) async {
      final home = await _mountHome(
        tester,
        checkAt: 0,
        getMe: const ApiException(statusCode: 401, message: 'rejected'),
      );
      // Gates resolved at 0; the login would be mounted at 650.
      await _pumpFor(tester, 300);
      expect(find.text('login-route'), findsNothing);
      await tester.tapAt(const Offset(200, 400));
      await tester.pump();
      expect(find.text('login-route'), findsOneWidget);
      expect(_loginOpacity(tester), 1);
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(SplashPage.curtainKey), findsNothing);
      expect(find.text('login-route').hitTestable(), findsOneWidget);
      expect(V4dHandoff.loginEntry.value, isFalse);
      expect(home.homeBlocs, 0);
    });

    test('login page: 600 ms fade, except during the splash hand-off', () {
      CustomTransitionPage<void> page() =>
          loginRoutePage(key: const ValueKey('login'), child: const SizedBox())
              as CustomTransitionPage<void>;
      // Logout, expired session or any other entry: the fade as in 8ea32f2.
      expect(page().transitionDuration, const Duration(milliseconds: 600));
      V4dHandoff.loginEntry.value = true;
      expect(page().transitionDuration, Duration.zero);
      V4dHandoff.clear();
      expect(page().transitionDuration, const Duration(milliseconds: 600));
    });

    testWidgets('HomeBloc is not built before auth resolves', (tester) async {
      final home = await _mountHome(tester, checkAt: 3000);
      final elapsed = await _pumpUntilUsable(tester, home);
      expect(home.homeBlocs, 1);
      expect(home.readyAt, isNotNull);
      // Inicio is mounted under the X only once the gates are resolved.
      expect(home.firstHomeBlocAt, greaterThanOrEqualTo(home.readyAt!));
      expect(home.firstHomeBlocAt, greaterThanOrEqualTo(3000));
      // r3 (D3-Q6): no content, so it opens at the cap (3000 + 600) and is
      // usable 790 ms later (it was 3000 + 790 when it opened at t_ready).
      expect(elapsed, inInclusiveRange(4390, 4410));
    });

    // r4 (D3-Q9): the login (401) row moved to the destination login tests
    // above, where the X opens onto the login instead of a neutral window;
    // they also check frame by frame that HomeBloc is never built.
    for (final (label, Object getMe, route) in [
      ('onboarding', userFromServer(profile: pendingProfile), 'onboarding'),
      (
        'account locked (423)',
        const ApiException(statusCode: 423, message: 'locked'),
        'locked',
      ),
    ]) {
      testWidgets('destination $label: HomeBloc never built, neutral window', (
        tester,
      ) async {
        final home = await _mountHome(tester, checkAt: 0, getMe: getMe);
        for (var t = 0; t < 3000; t += 10) {
          await tester.pump(const Duration(milliseconds: 10));
          expect(home.homeBlocs, 0, reason: 'at $t ms');
          expect(find.text('home-route'), findsNothing);
        }
        expect(find.text('$route-route'), findsOneWidget);
        expect(find.byKey(SplashPage.curtainKey), findsNothing);
      });
    }

    // r3 (D3-Q6): at 200 ms the curtain now waits for Inicio's content (the
    // opening starts at 660), so the tap during the opening is at 700 ms;
    // the tap while waiting is the next test.
    testWidgets('a tap during the opening jumps to the end', (tester) async {
      final home = await _mountHome(tester, checkAt: 0);
      await _pumpFor(tester, 700);
      expect(V4dHandoff.current.value?.elapsed, greaterThanOrEqualTo(0));
      expect(find.byKey(SplashPage.curtainKey), findsOneWidget);
      await tester.tapAt(const Offset(200, 400));
      await tester.pump();
      expect(find.byKey(SplashPage.curtainKey), findsNothing);
      expect(find.text('home-route'), findsOneWidget);
      expect(home.homeBlocs, 1);
    });

    testWidgets('a tap while waiting for content jumps to the end', (
      tester,
    ) async {
      final home = await _mountHome(tester, checkAt: 0);
      await _pumpFor(tester, 200);
      expect(V4dHandoff.current.value?.elapsed, lessThan(0));
      expect(find.byKey(SplashPage.curtainKey), findsOneWidget);
      await tester.tapAt(const Offset(200, 400));
      await tester.pump();
      expect(find.byKey(SplashPage.curtainKey), findsNothing);
      expect(V4dHandoff.active, isFalse);
      expect(find.text('home-route').hitTestable(), findsOneWidget);
      expect(home.homeBlocs, 1);
    });

    testWidgets('a tap before the gates resolve only ends the entry', (
      tester,
    ) async {
      final home = await _mountHome(tester, checkAt: null);
      await _pumpFor(tester, 100);
      await tester.tapAt(const Offset(200, 400));
      await _pumpFor(tester, 1000);
      expect(find.byType(SplashPage), findsOneWidget);
      expect(home.homeBlocs, 0);
      expect(find.text('home-route'), findsNothing);
      await _unmount(tester);
    });

    // Review follow-up 2: the destination is read again when the splash
    // navigates or hands off, as before L5-D3. A session that stops being
    // valid between t_ready and that moment never mounts Inicio.
    Future<void> expectLoginWithoutInicio(
      WidgetTester tester,
      _HomeHarness home, {
      required int fromMs,
      int untilMs = 2500,
    }) async {
      for (var t = fromMs; t < untilMs; t += 10) {
        await tester.pump(const Duration(milliseconds: 10));
        expect(home.homeBlocs, 0, reason: 'at $t ms');
        expect(find.text('home-route'), findsNothing, reason: 'at $t ms');
        expect(find.text('onboarding-route'), findsNothing, reason: 'at $t ms');
      }
      expect(find.text('login-route'), findsOneWidget);
      expect(find.byKey(SplashPage.curtainKey), findsNothing);
    }

    Future<void> sessionLostRightAfterReady(WidgetTester tester) async {
      final home = await _mountHome(tester, checkAt: null);
      late final StreamSubscription<AuthState> logout;
      logout = home.auth.stream.listen((state) {
        if (state is AuthAuthenticated) {
          logout.cancel();
          home.auth.add(const AuthLogoutRequested());
        }
      });
      addTearDown(logout.cancel);
      await _pumpFor(tester, 100);
      home.auth.add(const AuthCheckStatusRequested());
      await expectLoginWithoutInicio(tester, home, fromMs: 100);
    }

    // r4 (D3-Q8): in reduced motion Inicio is now built under the lockup at
    // t_ready, as under the X, so the former test (logout at 300 ms with the
    // hand-off at 600) has no window left; it becomes the reduced-motion
    // case of the next test, which loses the session right after t_ready.
    for (final reduced in const [false, true]) {
      testWidgets('${reduced ? 'reduced motion: ' : ''}a session lost right '
          'after t_ready never mounts Inicio', (tester) async {
        if (reduced) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        await sessionLostRightAfterReady(tester);
      });
    }

    testWidgets('destination onboarding: a session lost before navigating '
        'goes to login', (tester) async {
      final home = await _mountHome(
        tester,
        checkAt: 0,
        getMe: userFromServer(profile: pendingProfile),
      );
      // Gates resolved at 0 with destination onboarding; it leaves at 650.
      await _pumpFor(tester, 300);
      expect(find.byType(SplashPage), findsOneWidget);
      home.auth.add(const AuthLogoutRequested());
      await expectLoginWithoutInicio(tester, home, fromMs: 300);
    });

    // r5, review follow-up 1: with a planned destination other than the
    // login (onboarding, locked account) the window of the X already opened
    // on the neutral background at t_ready. If the session is lost before
    // the splash leaves, it navigates to the login as before; it must not
    // hand off to the login under a new, filled X (the lockup would come
    // back and the X would open a second time).
    for (final (label, Object getMe) in [
      ('onboarding', userFromServer(profile: pendingProfile)),
      (
        'account locked (423)',
        const ApiException(statusCode: 423, message: 'locked'),
      ),
    ]) {
      testWidgets('destination $label, session lost before leaving: one '
          'opening, the lockup never comes back', (tester) async {
        final home = await _mountHome(tester, checkAt: 0, getMe: getMe);
        final openings = <double>{};
        var furthest = double.negativeInfinity;
        final problems = <String>[];
        for (var t = 10; t <= 2500; t += 10) {
          await tester.pump(const Duration(milliseconds: 10));
          if (t == 300) {
            expect(find.byType(SplashPage), findsOneWidget);
            home.auth.add(const AuthLogoutRequested());
          }
          for (final scene in tester.widgetList<V4dScene>(
            find.byType(V4dScene),
          )) {
            final open = scene.openAt;
            if (open == null) continue;
            openings.add(open);
            final o = scene.time - open;
            if (o < furthest) {
              problems.add('$t ms: opening back from $furthest to $o');
            }
            furthest = o > furthest ? o : furthest;
          }
          if (home.homeBlocs != 0) problems.add('$t ms: HomeBloc built');
        }
        expect(problems, isEmpty);
        expect(openings, hasLength(1));
        expect(find.text('login-route'), findsOneWidget);
        expect(find.byKey(SplashPage.curtainKey), findsNothing);
        expect(V4dHandoff.loginEntry.value, isFalse);
      });
    }

    // Review follow-up 4b: with a valid session, Inicio (and its HomeBloc) is
    // not built while the update gate is pending or the notice is open, nor
    // when the auth gate times out (6 s).
    testWidgets('update gate pending with a valid session: HomeBloc not '
        'built until it resolves', (tester) async {
      final decision = Completer<AppUpdateDecision>();
      final home = await _mountHome(
        tester,
        checkAt: 0,
        update: decision.future,
      );
      for (var t = 0; t < 5900; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(home.homeBlocs, 0, reason: 'at $t ms');
      }
      expect(find.byType(SplashPage), findsOneWidget);
      decision.complete(_upToDate);
      await _pumpFor(tester, 1000);
      expect(home.homeBlocs, 1);
      expect(find.text('home-route'), findsOneWidget);
    });

    testWidgets('recommended update notice open with a valid session: '
        'HomeBloc not built until «Continuar»', (tester) async {
      final home = await _mountHome(
        tester,
        checkAt: 0,
        update: Future.value(
          const AppUpdateDecision(
            status: AppUpdateStatus.recommendedUpdate,
            currentVersion: '1.0.0',
            currentBuild: 1,
          ),
        ),
      );
      for (var t = 0; t < 3000; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(home.homeBlocs, 0, reason: 'at $t ms');
      }
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await _pumpFor(tester, 1500);
      expect(home.homeBlocs, 1);
      expect(find.text('home-route'), findsOneWidget);
    });

    testWidgets('auth gate timeout (6 s) with a Firebase session: login, '
        'HomeBloc never built', (tester) async {
      final home = await _mountHome(tester, checkAt: null);
      for (var t = 0; t < 7500; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(home.homeBlocs, 0, reason: 'at $t ms');
      }
      expect(find.text('login-route'), findsOneWidget);
      expect(find.text('home-route'), findsNothing);
    });
  });

  testWidgets('destination login: navigates 650 ms after the gates, as the '
      'former exit did', (tester) async {
    sl.registerSingleton<AppUpdateService>(
      _UpdateService(Future.value(_upToDate)),
    );
    final bloc = _authBloc()..add(const AuthCheckStatusRequested());
    addTearDown(bloc.close);
    await _mount(tester, bloc);
    final elapsed = await _pumpUntilLogin(tester);
    expect(find.text('login-route'), findsOneWidget);
    expect(elapsed, inInclusiveRange(650, 670));
  });

  testWidgets('does not navigate while auth is unresolved', (tester) async {
    sl.registerSingleton<AppUpdateService>(
      _UpdateService(Future.value(_upToDate)),
    );
    final bloc = _authBloc(); // AuthInitial: gate not resolved.
    addTearDown(bloc.close);
    await _mount(tester, bloc);
    await _pumpFor(tester, 4000);
    expect(find.text('login-route'), findsNothing);
    bloc.add(const AuthCheckStatusRequested());
    final elapsed = await _pumpUntilLogin(tester);
    expect(find.text('login-route'), findsOneWidget);
    // Exit (650 ms) starts when auth resolves; no extra hold.
    expect(elapsed, inInclusiveRange(600, 700));
  });

  testWidgets('does not navigate while the update gate is pending', (
    tester,
  ) async {
    final decision = Completer<AppUpdateDecision>();
    sl.registerSingleton<AppUpdateService>(_UpdateService(decision.future));
    final bloc = _authBloc()..add(const AuthCheckStatusRequested());
    addTearDown(bloc.close);
    await _mount(tester, bloc);
    await _pumpFor(tester, 4000);
    expect(find.text('login-route'), findsNothing);
    decision.complete(_upToDate);
    final elapsed = await _pumpUntilLogin(tester);
    expect(find.text('login-route'), findsOneWidget);
    expect(elapsed, inInclusiveRange(600, 700));
  });

  testWidgets('blocking update keeps the splash and never navigates', (
    tester,
  ) async {
    sl.registerSingleton<AppUpdateService>(
      _UpdateService(
        Future.value(
          const AppUpdateDecision(
            status: AppUpdateStatus.requiredUpdate,
            currentVersion: '1.0.0',
            currentBuild: 1,
          ),
        ),
      ),
    );
    final bloc = _authBloc()..add(const AuthCheckStatusRequested());
    addTearDown(bloc.close);
    await _mount(tester, bloc);
    await _pumpFor(tester, 4000);
    expect(find.byType(AlertDialog), findsOneWidget);
    await _pumpFor(tester, 5000);
    expect(find.text('login-route'), findsNothing);
  });

  // L5-D3: the splash no longer has the glass disc with a 112 dp symbol; the
  // V4d lockup is the symbol beside «EXOM» at full width. The brand rules of
  // L5-LOGO still hold and are checked at rest (auth unresolved, so the
  // splash stays on screen).
  group('brand', () {
    Future<void> mountSplash(
      WidgetTester tester, {
      ThemeData? theme,
      int pumpMs = 700,
    }) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      sl.registerSingleton<AppUpdateService>(
        _UpdateService(Future.value(_upToDate)),
      );
      final bloc = _authBloc(); // AuthInitial: the splash stays at rest.
      addTearDown(bloc.close);
      await _mount(tester, bloc, theme: theme);
      await _pumpFor(tester, pumpMs);
    }

    testWidgets('lockup: symbol and EXOM wordmark once each', (tester) async {
      await mountSplash(tester);
      expect(find.byType(ExomBrandSymbol), findsOneWidget);
      expect(find.byType(ExomWordmark), findsOneWidget);
      expect(find.byType(ExomBrandLogo), findsNothing);
      // The lockup spans the width with 20 dp margins (sketch, «a»).
      final symbol = tester.getRect(find.byType(ExomBrandSymbol));
      final word = tester.getRect(find.byType(ExomWordmark));
      expect(symbol.left, closeTo(20, 0.5));
      expect(word.left, greaterThan(symbol.right));
      expect(symbol.center.dy, closeTo(word.center.dy, 0.5));
      await _unmount(tester);
    });

    testWidgets('light theme: carbon wordmark, X in carbon', (tester) async {
      await mountSplash(tester, theme: AppTheme.light);
      final palette = AppTheme.light.extension<ExomThemePalette>()!;
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(ExomWordmark),
          matching: find.byType(Text),
        ),
      );
      final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(spans.map((s) => s.style?.color).toList(), [
        palette.textPrimary,
        palette.textPrimary,
        palette.textPrimary,
        palette.textPrimary,
      ]);
      expect(SplashPage.xInkFor(AppTheme.light), palette.textPrimary);
      expect(SplashPage.xInkFor(AppTheme.dark), AppColors.primary);
      await _unmount(tester);
    });

    testWidgets('semantics announce EXOM exactly once', (tester) async {
      final handle = tester.ensureSemantics();
      await mountSplash(tester);
      expect(find.bySemanticsLabel('EXOM'), findsOneWidget);
      handle.dispose();
      await _unmount(tester);
    });

    testWidgets('first frame: the symbol is where the bootstrap screen left '
        'it', (tester) async {
      await mountSplash(tester, pumpMs: 0);
      final symbol = tester.getRect(find.byType(ExomBrandSymbol));
      expect(symbol.center.dx, closeTo(206, 0.5));
      expect(symbol.center.dy, closeTo(457.5, 0.5));
      expect(symbol.width, closeTo(80.64, 0.3));
      await _unmount(tester);
    });

    // Review follow-up 4a: the same continuity measured against the real
    // bootstrap screen, in both themes and on more screens. The bootstrap
    // screen follows the system brightness and the splash the app theme;
    // here both match (when they differ the jump is inherent, see D3).
    for (final brightness in Brightness.values) {
      for (final screen in const [
        Size(412, 915),
        Size(360, 640),
        Size(800, 1280),
      ]) {
        final label =
            '${brightness.name}, '
            '${screen.width.toInt()}x${screen.height.toInt()}';
        testWidgets('first frame ($label): symbol rect equals the '
            'bootstrap screen rect', (tester) async {
          tester.view.physicalSize = screen;
          tester.view.devicePixelRatio = 1.0;
          tester.view.padding = const FakeViewPadding(top: 48, bottom: 34);
          tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 34);
          addTearDown(tester.view.reset);
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );

          await tester.pumpWidget(const ExomBootstrapApp());
          final bootstrap = tester.getRect(find.byType(ExomBrandSymbol));
          await tester.pumpWidget(const SizedBox());

          sl.registerSingleton<AppUpdateService>(
            _UpdateService(Future.value(_upToDate)),
          );
          final bloc = _authBloc(); // AuthInitial: the splash stays.
          addTearDown(bloc.close);
          await _mount(
            tester,
            bloc,
            theme: brightness == Brightness.dark
                ? AppTheme.dark
                : AppTheme.light,
          );
          final symbol = tester.getRect(find.byType(ExomBrandSymbol));
          final launch = ExomLaunchSymbol.rectIn(screen);
          for (final (name, actual, expected) in [
            ('centre x', symbol.center.dx, bootstrap.center.dx),
            ('centre y', symbol.center.dy, bootstrap.center.dy),
            ('height', symbol.height, bootstrap.height),
            ('launch centre x', symbol.center.dx, launch.center.dx),
            ('launch centre y', symbol.center.dy, launch.center.dy),
            ('launch height', symbol.height, launch.height),
          ]) {
            expect(actual, closeTo(expected, 0.01), reason: name);
          }
          // In light the outlined symbol's padded viewBox makes the
          // bootstrap picture box 80.57 wide instead of 80.64, centred on
          // the same point (as in main_bootstrap_test.dart).
          expect(
            symbol.width,
            closeTo(
              bootstrap.width,
              brightness == Brightness.dark ? 0.01 : 0.1,
            ),
          );
          await _unmount(tester);
        });
      }
    }
  });
}
