// Redesign L5-D3 golden (docs/plans/rediseno-app-l5-contrato-v2.md, L5-D3 and
// section 3.0, CC 8): the main «Arranque» scene, V4d at rest (lockup and
// welcome, gates pending), in dark and light at text scale 1.0 and 1.6 with
// the Android nonlinear text scaler, on a 390x844 surface. Plus the L5-D10
// limit: lime covers at most 6 % of the screen, at rest and through the
// opening.
//
// Same platform rules as components_golden_test.dart: generated on Windows with
// the bundled fonts, so regenerate on the same OS with:
//   flutter test --update-goldens test/golden/l5_d3_arranque_golden_test.dart
import 'dart:ui' as ui;

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/config/app_distribution_config.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/services/app_update_service.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:exom_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:exom_app/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/get_me_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/social_login_usecase.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/splash/presentation/pages/splash_page.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_scene.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_timeline.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/android_nonlinear_text_scaler.dart';
import '../core/widgets/exom_component_harness.dart'
    show expectNoOverflow, expectTapTargetGuidelines;
import '../core/widgets/expect_no_lime_ink.dart';
import 'redesign_scenes.dart' show loadRedesignFonts;

class _UpToDate extends Fake implements AppUpdateService {
  @override
  Future<AppUpdateDecision> checkForUpdates() async => const AppUpdateDecision(
    status: AppUpdateStatus.upToDate,
    currentVersion: '1.0.0',
    currentBuild: 1,
  );

  @override
  Future<bool> openStore(AppUpdateDecision decision) async => true;
}

class _NoSession extends FirebaseAuthService {
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
    firebaseAuthService: _NoSession(),
  );
}

/// Mounts the splash with the auth gate pending (it stays at rest).
Future<AuthBloc> _pumpSplash(
  WidgetTester tester, {
  required Brightness brightness,
  required double scale,
  Size size = const Size(390, 844),
  Locale locale = const Locale('es'),
}) async {
  await loadRedesignFonts();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  sl.registerSingleton<AppUpdateService>(_UpToDate());
  final bloc = _authBloc();
  addTearDown(bloc.close);
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const Scaffold(body: SizedBox.expand()),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: AndroidNonlinearTextScaler(scale)),
          child: child!,
        ),
      ),
    ),
  );
  return bloc;
}

Future<void> _pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 10) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

/// Lets the 6 s gate timeout expire after the test unmounts the splash.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 7));
}

/// Share of the screen painted in lime (#BAF23A within a small tolerance).
Future<double> _limeShare(WidgetTester tester) async {
  final element = find.byType(MaterialApp).evaluate().single;
  final share = await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    var lime = 0;
    final total = image.width * image.height;
    for (var i = 0; i < bytes.lengthInBytes; i += 4) {
      final r = bytes.getUint8(i);
      final g = bytes.getUint8(i + 1);
      final b = bytes.getUint8(i + 2);
      if ((r - 0xBA).abs() < 40 && (g - 0xF2).abs() < 40 && b < 0x3A + 60) {
        lime++;
      }
    }
    image.dispose();
    return lime / total;
  });
  return share!;
}

void main() {
  setUp(() async {
    await sl.reset();
  });
  tearDown(sl.reset);

  for (final brightness in Brightness.values) {
    for (final scale in const [1.0, 1.6]) {
      final name =
          'arranque_v4d_${brightness.name}_${scale == 1.0 ? '1_0x' : '1_6x'}';
      testWidgets('golden $name', (tester) async {
        await _pumpSplash(tester, brightness: brightness, scale: scale);
        await _pumpFor(tester, 700);
        expectNoOverflow(tester);
        if (brightness == Brightness.light) expectNoLimeInk(tester);
        await expectTapTargetGuidelines(tester);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
        await _unmount(tester);
      });
    }
  }

  // CC 3: no overflow at 320 dp with 1.3x and 1.6x, and at 360 dp with 1.6x,
  // in es and en (the welcome scales down to the margins if it must).
  for (final (width, scale) in const [
    (320.0, 1.3),
    (320.0, 1.6),
    (360.0, 1.6),
  ]) {
    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets('no overflow at ${width.toInt()} dp, ${scale}x, '
          '${locale.languageCode}', (tester) async {
        await _pumpSplash(
          tester,
          brightness: Brightness.dark,
          scale: scale,
          size: Size(width, width * 2),
          locale: locale,
        );
        await _pumpFor(tester, 2100); // entry, rest and slow-start notice
        expectNoOverflow(tester);
        expect(find.byKey(SplashPage.slowStartKey), findsOneWidget);
        final notice = tester.getRect(find.byKey(SplashPage.slowStartKey));
        expect(notice.right, lessThanOrEqualTo(width - 20 + 0.01));
        expect(notice.bottom, lessThanOrEqualTo(width * 2));
        await _unmount(tester);
      });
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('L5-D10: lime ≤ 6 % of the screen at rest and through the '
        'opening (${brightness.name})', (tester) async {
      final bloc = await _pumpSplash(
        tester,
        brightness: brightness,
        scale: 1.0,
      );
      await _pumpFor(tester, 700);
      final shares = <String, double>{'rest': await _limeShare(tester)};
      // Gates resolve now (destination login); sample the opening where the
      // rim is longest and the ink still visible. r4 (D3-Q9): the opening
      // onto the login starts 490 ms after the gates (the login is mounted
      // under the X at +650 and the X starts to empty 160 ms into the
      // opening), not at once onto a neutral window: the samples keep the
      // same offsets into the opening.
      bloc.add(const AuthCheckStatusRequested());
      const start = V4dTimeline.handOffOtherDestination - V4dTimeline.growStart;
      var t = 0;
      for (final at in const [20, 60, 100, 160, 260, 400]) {
        await _pumpFor(tester, (start + at).round() - t);
        t = (start + at).round();
        // The sample is inside the opening, at the intended offset.
        final scene = tester.widget<V4dScene>(find.byType(V4dScene).last);
        expect(scene.time - scene.openAt!, closeTo(at, 20), reason: '+$at');
        shares['opening +$at ms'] = await _limeShare(tester);
      }
      debugPrint('L5_D3_LIME_${brightness.name}=$shares');
      for (final entry in shares.entries) {
        expect(entry.value, lessThanOrEqualTo(0.06), reason: entry.key);
      }
      expect(shares['rest'], greaterThan(0));
      await _unmount(tester);
    });
  }
}
