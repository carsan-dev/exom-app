import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_brand_logo.dart';
import 'package:exom_app/core/widgets/exom_launch_symbol.dart';
import 'package:exom_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden/redesign_scenes.dart' show loadRedesignFonts;

const _fadeKey = ValueKey<String>('bootstrap-progress-fade');

Future<void> _setSurface(
  WidgetTester tester, {
  bool insets = true,
  bool reduceMotion = false,
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  // The bootstrap screen follows the system brightness, like the native
  // splash; flutter_test defaults to light, so each test sets it.
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  if (insets) {
    tester.view.padding = const FakeViewPadding(top: 48, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 34);
  }
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

double _fadeOpacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.byKey(_fadeKey)).opacity.value;

void main() {
  group('ExomBootstrapApp', () {
    testWidgets('carbon background, light system icons', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(const ExomBootstrapApp());
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.background);
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      );
      expect(region.value.statusBarIconBrightness, Brightness.light);
      expect(region.value.systemNavigationBarIconBrightness, Brightness.light);
      expect(region.value.statusBarColor, Colors.transparent);
      expect(region.value.systemNavigationBarColor, AppColors.background);
      expect(region.value, bootstrapSystemUiStyle);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('symbol centred on the screen, 80.64 wide, no text', (
      tester,
    ) async {
      await _setSurface(tester);
      await tester.pumpWidget(const ExomBootstrapApp());
      final symbol = find.byType(ExomBrandSymbol);
      expect(symbol, findsOneWidget);
      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        (picture.bytesLoader as SvgAssetLoader).assetName,
        'assets/images/exom_balance.svg',
      );
      final rect = tester.getRect(find.byType(SvgPicture));
      expect(rect.width, closeTo(80.64, 0.01));
      expect(rect.height, closeTo(75.264, 0.01));
      expect(rect.center.dx, closeTo(412 / 2, 0.5));
      expect(rect.center.dy, closeTo(915 / 2, 0.5));
      expect(find.byType(Text), findsNothing);
      expect(find.text('EXOM'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('indicator 24 dp lime, 32 dp under the symbol', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(const ExomBootstrapApp());
      final indicator = find.byType(CircularProgressIndicator);
      final widget = tester.widget<CircularProgressIndicator>(indicator);
      expect(widget.strokeWidth, 2);
      expect(widget.color, AppColors.primary);
      final symbol = tester.getRect(find.byType(SvgPicture));
      final box = tester.getRect(indicator);
      expect(box.size, const Size(24, 24));
      expect(box.center.dx, closeTo(206, 0.5));
      expect(box.top, closeTo(symbol.bottom + 32, 0.5));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('indicator hidden 300 ms, then fades in over 200 ms', (
      tester,
    ) async {
      await _setSurface(tester);
      await tester.pumpWidget(const ExomBootstrapApp());
      expect(_fadeOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 250));
      expect(_fadeOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));
      final mid = _fadeOpacity(tester);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_fadeOpacity(tester), 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ready before 300 ms: never visible, no pending timer', (
      tester,
    ) async {
      await _setSurface(tester);
      await tester.pumpWidget(const ExomBootstrapApp());
      await tester.pump(const Duration(milliseconds: 100));
      expect(_fadeOpacity(tester), 0);
      await tester.pumpWidget(const SizedBox());
      // Timer cancelled on dispose: the framework would flag a pending one.
    });

    testWidgets('reduced motion: same delay, then shown without fade', (
      tester,
    ) async {
      await _setSurface(tester, reduceMotion: true);
      await tester.pumpWidget(const ExomBootstrapApp());
      expect(_fadeOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 250));
      expect(_fadeOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 1));
      expect(_fadeOpacity(tester), 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('semantics: EXOM on the symbol, default progress node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _setSurface(tester);
      await tester.pumpWidget(const ExomBootstrapApp());
      expect(find.bySemanticsLabel('EXOM'), findsOneWidget);
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('follows the system brightness (native splash, D3-Q2)', () {
    const paper = Color(0xFFF2F1E9);
    const carbon = Color(0xFF101111);
    const lightAccent = Color(0xFF4F6B00);
    const screen = Size(412, 915);

    for (final brightness in Brightness.values) {
      final isDark = brightness == Brightness.dark;
      final background = isDark ? carbon : paper;
      final icons = isDark ? Brightness.light : Brightness.dark;

      testWidgets('${brightness.name}: background and system bars', (
        tester,
      ) async {
        await _setSurface(tester, brightness: brightness);
        await tester.pumpWidget(const ExomBootstrapApp());
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, background);
        final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
        );
        expect(region.value.statusBarColor, Colors.transparent);
        expect(region.value.statusBarIconBrightness, icons);
        expect(region.value.statusBarBrightness, brightness);
        expect(region.value.systemNavigationBarColor, background);
        expect(region.value.systemNavigationBarIconBrightness, icons);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('${brightness.name}: symbol recoloured, same geometry', (
        tester,
      ) async {
        await _setSurface(tester, brightness: brightness);
        await tester.pumpWidget(const ExomBootstrapApp());
        final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
        expect(picture.bytesLoader, bootstrapSymbolLoader(brightness));
        final context = tester.element(find.byType(SvgPicture));
        expect(Theme.of(context).brightness, brightness);
        final rect = tester.getRect(find.byType(SvgPicture));
        final expected = ExomLaunchSymbol.rectIn(screen);
        expect(rect.center.dx, closeTo(expected.center.dx, 0.01));
        expect(rect.center.dy, closeTo(expected.center.dy, 0.01));
        expect(rect.height, closeTo(75.264, 0.01));
        // In light the outlined symbol's padded viewBox makes the picture box
        // 80.57 wide instead of 80.64 (ExomBrandSymbol, L5-LOGO).
        expect(rect.width, closeTo(80.64, isDark ? 0.01 : 0.1));
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('${brightness.name}: indicator in the theme accent', (
        tester,
      ) async {
        await _setSurface(tester, brightness: brightness);
        await tester.pumpWidget(const ExomBootstrapApp());
        final widget = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(widget.color, isDark ? AppColors.primary : lightAccent);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('${brightness.name}: precache fills that brightness key', (
        tester,
      ) async {
        svg.cache.clear();
        await _setSurface(tester, brightness: brightness);
        await tester.runAsync(precacheBootstrapSymbol);
        var loaded = false;
        await tester.runAsync(
          () => svg.cache.putIfAbsent(
            bootstrapSymbolLoader(brightness).cacheKey(null),
            () {
              loaded = true;
              throw StateError('cache miss');
            },
          ),
        );
        expect(loaded, isFalse);
      });

      testWidgets('golden first frame ${brightness.name}', (tester) async {
        svg.cache.clear();
        await _setSurface(tester, brightness: brightness);
        await tester.runAsync(precacheBootstrapSymbol);
        await tester.pumpWidget(const ExomBootstrapApp());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'golden/goldens/arranque_inicializacion_${brightness.name}.png',
          ),
        );
        await tester.pumpWidget(const SizedBox());
      }, tags: ['golden']);
    }
  });

  group('first-frame symbol', () {
    // The decoded picture is wrapped in a FittedBox; the placeholder is not.
    final painted = find.descendant(
      of: find.byType(SvgPicture),
      matching: find.byType(FittedBox),
    );

    setUp(svg.cache.clear);

    testWidgets('after precache the first pump already holds the picture', (
      tester,
    ) async {
      await _setSurface(tester);
      await tester.runAsync(precacheBootstrapSymbol);
      await tester.pumpWidget(const ExomBootstrapApp());
      // In flutter_test the asset load resolves synchronously, so this only
      // guards the wiring; the cache-hit test below guards the device path.
      expect(painted, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('precache fills the key the widget loads (cache hit)', (
      tester,
    ) async {
      await _setSurface(tester);
      final key = bootstrapSymbolLoader().cacheKey(null);
      await tester.runAsync(precacheBootstrapSymbol);
      var loaded = false;
      // A hit returns the cached bytes without running the loader.
      await tester.runAsync(
        () => svg.cache.putIfAbsent(key, () {
          loaded = true;
          throw StateError('cache miss');
        }),
      );
      expect(loaded, isFalse);
      await tester.pumpWidget(const ExomBootstrapApp());
      final widget = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final loader = widget.bytesLoader as SvgAssetLoader;
      final context = tester.element(find.byType(SvgPicture));
      expect(loader, bootstrapSymbolLoader());
      expect(loader.cacheKey(context), key);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('exhausted cap still shows the app and frees the frame', (
      tester,
    ) async {
      await _setSurface(tester);
      Widget? shown;
      await tester.runAsync(
        () => showBootstrapSplash(cap: Duration.zero, run: (w) => shown = w),
      );
      expect(shown, isA<ExomBootstrapApp>());
      // deferFirstFrame() makes sendFramesToEngine false until allowFirstFrame().
      expect(WidgetsBinding.instance.sendFramesToEngine, isTrue);
    });
  });

  group('ExomBootstrapErrorApp', () {
    testWidgets('dark scaffold, full lockup 40, bone message', (tester) async {
      await loadRedesignFonts();
      await _setSurface(tester);
      await tester.pumpWidget(const ExomBootstrapErrorApp(error: 'boom'));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.background);
      final logo = tester.widget<ExomBrandLogo>(find.byType(ExomBrandLogo));
      expect(logo.height, 40);
      final text = tester.widget<Text>(find.byType(Text).last);
      expect(text.style?.color, AppColors.textPrimary);
      expect(text.style?.color, const Color(0xFFF2F1E9));
      final logoRect = tester.getRect(find.byType(ExomBrandLogo));
      final textRect = tester.getRect(find.byType(Text).last);
      expect(logoRect.bottom, lessThanOrEqualTo(textRect.top));
      // Dark lockup: dark brightness reaches the logo through the theme.
      final context = tester.element(find.byType(ExomBrandLogo));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(find.text('boom'), findsNothing);
    });
  });
}
