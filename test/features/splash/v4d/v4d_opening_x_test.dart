// L5-D3 r3 · D3-Q7 (owner, 2026-11-25): the X stays filled (and still) while
// E, O, M, the symbol and the welcome fade out, and empties from its centre as
// it starts to grow; the totals do not change (ink 160 ms, growth ends at
// 440 ms, Inicio usable 790 ms after the opening starts). Before r3 it emptied
// in the first 100 ms and was a thin rim while the letters faded.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_scene.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_timeline.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../golden/redesign_scenes.dart' show loadRedesignFonts;

const double _openAt = 1000;

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

void main() {
  test('timeline: the X is filled and still until the ink has faded, then '
      'empties while it grows', () {
    const smax = 50.0;
    for (var o = 0.0; o < V4dTimeline.inkFade; o += 1) {
      expect(V4dTimeline.holeRatio(o), 0, reason: 'filled at $o ms');
      expect(V4dTimeline.growScale(o, smax), 1, reason: 'still at $o ms');
    }
    // It starts to grow and to empty at the same moment, from the centre.
    const start = V4dTimeline.inkFade;
    expect(V4dTimeline.holeRatio(start + 1), greaterThan(0));
    expect(V4dTimeline.growScale(start + 1, smax), greaterThan(1));
    var lastR = 0.0;
    var lastS = 1.0;
    var emptiedAt = double.infinity;
    for (var o = start; o <= V4dTimeline.grow; o += 1) {
      final r = V4dTimeline.holeRatio(o);
      final s = V4dTimeline.growScale(o, smax);
      expect(r, greaterThanOrEqualTo(lastR));
      expect(s, greaterThanOrEqualTo(lastS));
      if (r == 1 && emptiedAt == double.infinity) emptiedAt = o;
      lastR = r;
      lastS = s;
    }
    // Emptied (only the rim left) well before the growth ends.
    expect(emptiedAt, lessThanOrEqualTo(start + V4dTimeline.empty));
    expect(emptiedAt, lessThan(V4dTimeline.grow));
    // Same totals: growth ends at 440 ms, Inicio usable at 790 ms.
    expect(V4dTimeline.growScale(V4dTimeline.grow, smax), closeTo(smax, 1e-9));
    expect(V4dTimeline.grow, 440);
    expect(V4dTimeline.inkFade, 160);
    expect(V4dTimeline.usable, 790);
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: the centre of the X is ink while the '
        'letters fade and opens as it grows', (tester) async {
      await loadRedesignFonts();
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final theme = brightness == Brightness.dark
          ? AppTheme.dark
          : AppTheme.light;
      final palette = theme.extension<ExomThemePalette>()!;
      final ink = v4dXInk(theme);
      V4dLayout? layout;

      Widget scene(double o) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          backgroundColor: palette.background,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final l10n = AppLocalizations.of(context);
              final computed = layout ??= V4dLayout.compute(
                size: constraints.biggest,
                brightness: brightness,
                textScaler: TextScaler.noScaling,
                welcome: [l10n.splashWelcomeFirst, l10n.splashWelcomeSecond],
                baseStyle: DefaultTextStyle.of(context).style,
              );
              return V4dScene(
                layout: computed,
                time: _openAt + o,
                openAt: _openAt,
                entrySkipped: false,
                slowStart: false,
                content: V4dWindowContent.neutral,
              );
            },
          ),
        ),
      );

      Future<Color> centreAt(double o) async {
        await tester.pumpWidget(scene(o));
        final element = find.byType(MaterialApp).evaluate().single;
        final colour = await tester.runAsync(() async {
          final image = await captureImage(element);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final c = _pixel(bytes, image.width, layout!.xCentre);
          image.dispose();
          return c;
        });
        return colour!;
      }

      for (final o in const [0.0, 40.0, 80.0, 120.0, 150.0]) {
        expect(
          _distance(await centreAt(o), ink),
          lessThanOrEqualTo(8),
          reason: 'X filled at +$o ms',
        );
      }
      for (final o in const [180.0, 220.0, 300.0]) {
        expect(
          _distance(await centreAt(o), palette.background),
          lessThanOrEqualTo(8),
          reason: 'X open at its centre at +$o ms',
        );
      }
    });
  }
}
