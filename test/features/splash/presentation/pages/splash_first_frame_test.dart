// L5-D3 r3 · D3-E1 (emulator pass, 2026-11-25): between the bootstrap screen
// (`showBootstrapSplash`) and the first V4d frame there were 1-2 frames of
// plain background without the symbol. The splash's symbol is an SVG whose
// picture is decoded asynchronously (asset channel, then the SVG parse), and
// the bootstrap screen's picture cannot be reused: its loader key (size,
// outline) and its Localizations locale differ from the splash's. So the
// first V4d frame painted only the background.
//
// The device loads assets through a platform channel, never synchronously;
// [_DeviceAssetBundle] reproduces that here (flutter_test would otherwise
// resolve the asset in the same frame and hide the gap).
import 'dart:ui' as ui;

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/config/app_distribution_config.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/services/app_update_service.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_brand_logo.dart';
import 'package:exom_app/core/widgets/exom_launch_symbol.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';
import 'package:exom_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:exom_app/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/get_me_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/social_login_usecase.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/splash/presentation/pages/splash_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/main.dart'
    show ExomBootstrapApp, precacheBootstrapSymbol, precacheLaunchSymbol;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Like the device: an asset arrives on a later turn of the event loop.
class _DeviceAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    await Future<void>.delayed(Duration.zero);
    return rootBundle.load(key);
  }
}

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

/// Auth never requested: the splash stays on its entry and rest.
AuthBloc _pendingAuth() {
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

/// The app as `runApp(ExomApp())` shows it on start: the router on the
/// splash, the theme of [brightness] and the app's localizations.
Widget _app(GoRouter router, AuthBloc bloc, Brightness brightness) {
  return DefaultAssetBundle(
    bundle: _DeviceAssetBundle(),
    child: BlocProvider<AuthBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
}

class _Frame {
  _Frame(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final ByteData rgba;

  Color pixel(int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(
      rgba.getUint8(i + 3),
      rgba.getUint8(i),
      rgba.getUint8(i + 1),
      rgba.getUint8(i + 2),
    );
  }
}

Future<_Frame> _capture(WidgetTester tester) async {
  final element = find.byType(MaterialApp).evaluate().single;
  final frame = await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final result = _Frame(image.width, image.height, bytes);
    image.dispose();
    return result;
  });
  return frame!;
}

int _channelDistance(Color a, Color b) => [
  ((a.r - b.r) * 255).round().abs(),
  ((a.g - b.g) * 255).round().abs(),
  ((a.b - b.b) * 255).round().abs(),
].reduce((x, y) => x > y ? x : y);

/// Pixels of [rect] that are not [background] (symbol ink).
int _ink(_Frame frame, Rect rect, Color background) {
  var ink = 0;
  for (var y = rect.top.floor(); y < rect.bottom.ceil(); y++) {
    for (var x = rect.left.floor(); x < rect.right.ceil(); x++) {
      if (_channelDistance(frame.pixel(x, y), background) > 24) ink++;
    }
  }
  return ink;
}

const _screen = Size(412, 915);

void main() {
  setUp(() async {
    await sl.reset();
    // A cold start: nothing decoded nor cached yet.
    svg.cache.clear();
    ExomLaunchSymbol.debugClearPictures();
  });
  tearDown(sl.reset);

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: the first V4d frame shows the symbol of '
        'the last bootstrap frame, in the same box', (tester) async {
      tester.view.physicalSize = _screen;
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(top: 48, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 34);
      addTearDown(tester.view.reset);
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final palette =
          (brightness == Brightness.dark ? AppTheme.dark : AppTheme.light)
              .extension<ExomThemePalette>()!;
      final box = ExomLaunchSymbol.rectIn(_screen).inflate(2);

      // main(): the bootstrap screen with its symbol (showBootstrapSplash).
      await tester.runAsync(precacheBootstrapSymbol);
      await tester.pumpWidget(const ExomBootstrapApp());
      await tester.pump();
      final last = await _capture(tester);
      final bootstrapInk = _ink(last, box, palette.background);
      expect(bootstrapInk, greaterThan(1000), reason: 'bootstrap symbol');

      // main(): what runs before runApp(ExomApp()), then the app's first
      // frame (the splash on its first frame).
      await tester.runAsync(precacheLaunchSymbol);
      sl.registerSingleton<AppUpdateService>(_UpToDate());
      final bloc = _pendingAuth();
      addTearDown(bloc.close);
      final router = GoRouter(
        initialLocation: AppRoutes.splash,
        routes: [
          GoRoute(
            path: AppRoutes.splash,
            builder: (_, _) => const SplashPage(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router, bloc, brightness));
      expect(find.byType(SplashPage), findsOneWidget);
      final first = await _capture(tester);

      // Same background everywhere outside the symbol box.
      for (final point in const [
        Offset(10, 10),
        Offset(206, 200),
        Offset(206, 700),
        Offset(400, 900),
      ]) {
        expect(
          _channelDistance(
            first.pixel(point.dx.toInt(), point.dy.toInt()),
            palette.background,
          ),
          lessThanOrEqualTo(2),
          reason: 'background at $point',
        );
      }
      // The symbol is painted, in the same box and with the same ink.
      final firstInk = _ink(first, box, palette.background);
      expect(firstInk, greaterThan(bootstrapInk * 0.97), reason: 'V4d symbol');
      expect(firstInk, lessThan(bootstrapInk * 1.03), reason: 'V4d symbol');
      var same = 0;
      var total = 0;
      for (var y = box.top.floor(); y < box.bottom.ceil(); y++) {
        for (var x = box.left.floor(); x < box.right.ceil(); x++) {
          total++;
          if (_channelDistance(first.pixel(x, y), last.pixel(x, y)) <= 16) {
            same++;
          }
        }
      }
      expect(same / total, greaterThan(0.98), reason: 'pixels as bootstrap');

      // No later frame loses it while the real picture loads and the symbol
      // travels to the lockup.
      for (var t = 10; t <= 200; t += 10) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)),
        );
        await tester.pump(const Duration(milliseconds: 10));
        final frame = await _capture(tester);
        final rect = tester
            .getRect(find.byType(ExomBrandSymbol))
            .inflate(2)
            .intersect(Offset.zero & _screen);
        expect(
          _ink(frame, rect, palette.background),
          greaterThan(1000),
          reason: 'symbol at +$t ms',
        );
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 7));
    });
  }
}
