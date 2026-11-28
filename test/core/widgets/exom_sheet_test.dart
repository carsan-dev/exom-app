import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../golden/redesign_scenes.dart' show loadRedesignFonts;

const _screenHeight = 844.0;

// Context the test trigger passes to showExomSheet (the de-duplication key).
BuildContext? _openerContext;

class _Probe extends StatefulWidget {
  const _Probe({required this.events, this.tall = false, this.extra = 0});
  final List<String> events;
  final bool tall;
  final double extra;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void dispose() {
    widget.events.add('disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Serie 2 de 4'),
          const TextField(key: Key('sheet-field')),
          if (widget.tall) const SizedBox(height: 1600),
          SizedBox(height: widget.extra),
          TextButton(
            key: const Key('sheet-close'),
            onPressed: () => Navigator.of(context).pop('guardada'),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  required List<String> events,
  List<Object?>? results,
  bool disableAnimations = false,
  Brightness brightness = Brightness.dark,
  double width = 390,
  double textScale = 1.0,
  EdgeInsets viewInsets = EdgeInsets.zero,
  EdgeInsets padding = EdgeInsets.zero,
  bool isDismissible = true,
  bool tall = false,
  double extra = 0,
  int opens = 1,
}) async {
  await loadRedesignFonts();
  tester.view.physicalSize = Size(width, _screenHeight);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () {
                _openerContext = context;
                for (var i = 0; i < opens; i++) {
                  showExomSheet<String>(
                    context: context,
                    isDismissible: isDismissible,
                    builder: (_) =>
                        _Probe(events: events, tall: tall, extra: extra),
                  ).then((result) {
                    events.add('returned');
                    results?.add(result);
                  });
                }
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/other',
        builder: (context, state) => const Scaffold(body: Text('Otra')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
          viewInsets: viewInsets,
          padding: padding,
        ),
        child: child!,
      ),
    ),
  );
  return router;
}

ModalRoute<dynamic> _sheetRoute(WidgetTester tester) =>
    ModalRoute.of(tester.element(find.text('Serie 2 de 4')))!;

final _panel = find.byKey(const Key('exom-sheet-panel'));
final _handle = find.byKey(const Key('exom-sheet-handle'));

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open')));
  await tester.pump();
}

double _scrimAlpha(WidgetTester tester) {
  final barrier = tester.widget<AnimatedModalBarrier>(
    find.byType(AnimatedModalBarrier),
  );
  return barrier.color.value!.a;
}

final _fullScrimAlpha = ExomSheetRoute.scrimColor.a;

void main() {
  testWidgets('enter: 280 ms on the cubic curve; exit: 200 ms on its curve', (
    tester,
  ) async {
    final events = <String>[];
    await _pump(tester, events: events);
    await _open(tester);
    final route = _sheetRoute(tester);
    expect(route.transitionDuration, const Duration(milliseconds: 280));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    final height = tester.getSize(_panel).height;
    final openTop = tester.getTopLeft(_panel).dy;
    expect(openTop, closeTo(_screenHeight - height, 0.5));

    // Re-open and sample the middle of the enter animation.
    await tester.tap(find.byKey(const Key('sheet-close')));
    await tester.pumpAndSettle();
    await _open(tester);
    await tester.pump(const Duration(milliseconds: 140));
    final enterShown = ExomMotion.sheetEnterCurve.transform(0.5);
    expect(
      tester.getTopLeft(_panel).dy,
      closeTo(_screenHeight - height * enterShown, 1.0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sheet-close')));
    await tester.pump();
    // Exit is ease-in: displacement is the exit curve at elapsed / 200 ms
    // (about 0.099 / 0.325 / 0.630 of the height at 50 / 100 / 150 ms).
    var elapsed = 0;
    for (final ms in const [50, 100, 150]) {
      await tester.pump(Duration(milliseconds: ms - elapsed));
      elapsed = ms;
      final displacement = (tester.getTopLeft(_panel).dy - openTop) / height;
      expect(
        displacement,
        closeTo(ExomMotion.sheetExitCurve.transform(ms / 200), 0.01),
        reason: 'exit displacement at $ms ms',
      );
    }
    expect(ExomMotion.sheetExitCurve.transform(0.5), closeTo(0.325, 0.01));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
  });

  testWidgets('scrim fades on its own 200 ms linear timing', (tester) async {
    final events = <String>[];
    await _pump(tester, events: events);
    await _open(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_scrimAlpha(tester), closeTo(_fullScrimAlpha * 0.5, 0.02));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_scrimAlpha(tester), closeTo(_fullScrimAlpha, 0.001));
    // The sheet is still moving (280 ms) when the scrim is already full.
    expect(_sheetRoute(tester).animation!.value, lessThan(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sheet-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_scrimAlpha(tester), closeTo(_fullScrimAlpha * 0.5, 0.02));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'layout: square top corners (kExomSheetRadius), panel colour, no shadow, handle',
    (tester) async {
      final events = <String>[];
      await _pump(tester, events: events);
      await _open(tester);
      await tester.pumpAndSettle();
      expect(tester.getSize(_handle), const Size(40, 4));
      final material = tester.widget<Material>(_panel);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(kExomSheetRadius)),
      );
      expect(
        material.color,
        AppTheme.dark.extension<ExomThemePalette>()!.surface,
      );
      expect(material.elevation, 0);
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  group('grab area and handle (B-5)', () {
    final grab = find.byKey(const Key('exom-sheet-grab-area'));

    testWidgets('the grab area is at least 48 dp tall and full width', (
      tester,
    ) async {
      await _pump(tester, events: <String>[], tall: true);
      await _open(tester);
      await tester.pumpAndSettle();
      expect(tester.getSize(grab).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(grab).width, tester.getSize(_panel).width);
      expect(tester.getTopLeft(grab), tester.getTopLeft(_panel));
      // The visible handle is unchanged.
      expect(tester.getSize(_handle), const Size(40, 4));
    });

    testWidgets('dragging from the edge of the grab area moves the sheet', (
      tester,
    ) async {
      // Tall content scrolls: without the grab area a drag below the 16 dp
      // strip would scroll it instead of moving the sheet.
      await _pump(tester, events: <String>[], tall: true);
      await _open(tester);
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(_panel).dy;
      final start = Offset(
        tester.getCenter(_panel).dx,
        top + 44, // inside 48 dp, well outside the old 16 dp strip
      );
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(tester.getTopLeft(_panel).dy, closeTo(top + 70, 0.5));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a drag just below the grab area scrolls the content', (
      tester,
    ) async {
      await _pump(tester, events: <String>[], tall: true);
      await _open(tester);
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(_panel).dy;
      final gesture = await tester.startGesture(
        Offset(tester.getCenter(_panel).dx, top + 60),
      );
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(tester.getTopLeft(_panel).dy, closeTo(top, 0.5));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    for (final brightness in Brightness.values) {
      testWidgets('the handle contrasts >= 3:1 with the panel '
          '(${brightness.name})', (tester) async {
        await _pump(tester, events: <String>[], brightness: brightness);
        await _open(tester);
        await tester.pumpAndSettle();
        final theme = brightness == Brightness.dark
            ? AppTheme.dark
            : AppTheme.light;
        final palette = theme.extension<ExomThemePalette>()!;
        final handle = tester.widget<Container>(_handle);
        final color = (handle.decoration! as BoxDecoration).color!;
        expect(color, palette.textMuted);
        final lighter = math.max(
          color.computeLuminance(),
          palette.surface.computeLuminance(),
        );
        final darker = math.min(
          color.computeLuminance(),
          palette.surface.computeLuminance(),
        );
        final ratio = (lighter + 0.05) / (darker + 0.05);
        // ignore: avoid_print
        print(
          'handle contrast ${brightness.name}: ${ratio.toStringAsFixed(2)}',
        );
        expect(ratio, greaterThanOrEqualTo(3));
      });
    }
  });

  testWidgets('the drag follows the finger 1:1', (tester) async {
    final events = <String>[];
    await _pump(tester, events: events);
    await _open(tester);
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(_panel).dy;
    final gesture = await tester.startGesture(tester.getCenter(_handle));
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(tester.getTopLeft(_panel).dy, closeTo(top + 70, 0.5));
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    expect(tester.getTopLeft(_panel).dy, closeTo(top + 50, 0.5));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  for (final (fraction, closes) in const [(0.29, false), (0.31, true)]) {
    testWidgets('slow drag of ${(fraction * 100).round()} % '
        '${closes ? 'closes' : 'springs back'}', (tester) async {
      final events = <String>[];
      await _pump(tester, events: events);
      await _open(tester);
      await tester.pumpAndSettle();
      final height = tester.getSize(_panel).height;
      final top = tester.getTopLeft(_panel).dy;
      await tester.timedDrag(
        _handle,
        Offset(0, height * fraction),
        const Duration(seconds: 2),
      );
      if (closes) {
        await tester.pumpAndSettle();
        expect(_panel, findsNothing);
        expect(events, ['disposed', 'returned']);
      } else {
        // Springs back within 200 ms.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.getTopLeft(_panel).dy, closeTo(top, 0.5));
        await tester.pumpAndSettle();
        expect(events, isEmpty);
      }
    });
  }

  for (final reduced in const [false, true]) {
    testWidgets('a dialog over the sheet mid-drag: the release springs back'
        '${reduced ? ' (reduced motion)' : ''}', (tester) async {
      final events = <String>[];
      await _pump(tester, events: events, disableAnimations: reduced);
      await _open(tester);
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(_panel).dy;
      final gesture = await tester.startGesture(tester.getCenter(_handle));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(tester.getTopLeft(_panel).dy, closeTo(top + 70, 0.5));
      // A route lands on top before the finger lifts.
      final dialog = showDialog<void>(
        context: tester.element(find.text('Serie 2 de 4')),
        builder: (_) => const AlertDialog(content: Text('Encima')),
      );
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_panel).dy, closeTo(top, 0.5));
      Navigator.of(tester.element(find.text('Encima'))).pop();
      await dialog;
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_panel).dy, closeTo(top, 0.5));
      expect(_sheetRoute(tester).isCurrent, isTrue);
      expect(events, isEmpty);
    });
  }

  testWidgets('a quick downward fling closes', (tester) async {
    final events = <String>[];
    // Tall enough that a fling long enough to be measured stays under 30 %.
    await _pump(tester, events: events, extra: 240);
    await _open(tester);
    await tester.pumpAndSettle();
    final height = tester.getSize(_panel).height;
    await tester.fling(_handle, Offset(0, height * 0.2), 1500);
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
    expect(events, ['disposed', 'returned']);
  });

  testWidgets('closing mid-enter reverses from the current position', (
    tester,
  ) async {
    final events = <String>[];
    await _pump(tester, events: events);
    await _open(tester);
    await tester.pumpAndSettle();
    final height = tester.getSize(_panel).height;
    await tester.tap(find.byKey(const Key('sheet-close')));
    await tester.pumpAndSettle();
    await _open(tester);
    await tester.pump(const Duration(milliseconds: 100));
    final before = tester.getTopLeft(_panel).dy;
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      tester.getTopLeft(_panel).dy,
      closeTo(before, height * 0.03),
      reason: 'no jump when the animation is reversed',
    );
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
  });

  group('dismissal', () {
    Future<void> expectCloses(
      WidgetTester tester,
      Future<void> Function() action,
    ) async {
      final events = <String>[];
      await _pump(tester, events: events);
      await _open(tester);
      await tester.pumpAndSettle();
      await action();
      await tester.pumpAndSettle();
      expect(_panel, findsNothing);
      expect(events, ['disposed', 'returned']);
    }

    testWidgets('system back', (tester) async {
      await expectCloses(tester, () => tester.binding.handlePopRoute());
    });

    testWidgets('scrim tap', (tester) async {
      await expectCloses(tester, () => tester.tapAt(const Offset(20, 20)));
    });

    testWidgets('Escape', (tester) async {
      await expectCloses(
        tester,
        () => tester.sendKeyEvent(LogicalKeyboardKey.escape),
      );
    });

    testWidgets('accessibility escape (dismiss action on the sheet)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await expectCloses(tester, () async {
        final node = tester.getSemantics(_panel);
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.dismiss),
          isTrue,
        );
        node.owner!.performAction(node.id, SemanticsAction.dismiss);
      });
      handle.dispose();
    });

    // S11-09: a second tap of a double tap on the trigger lands on the scrim
    // of the entering sheet; it must not close it. Once the entry has
    // finished the scrim closes it again; back still closes it mid-entry.
    for (final reduced in [false, true]) {
      final suffix = reduced ? ' (reduced motion)' : '';
      testWidgets('a scrim tap mid-entry keeps the sheet$suffix', (
        tester,
      ) async {
        final events = <String>[];
        await _pump(tester, events: events, disableAnimations: reduced);
        await _open(tester);
        await tester.pump(const Duration(milliseconds: 50));
        expect(_sheetRoute(tester).animation!.status, AnimationStatus.forward);
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        expect(_panel, findsOneWidget);
        expect(events, isEmpty);

        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        expect(_panel, findsNothing);
        expect(events, ['disposed', 'returned']);
      });
    }

    testWidgets('system back mid-entry still closes', (tester) async {
      final events = <String>[];
      await _pump(tester, events: events);
      await _open(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_sheetRoute(tester).animation!.status, AnimationStatus.forward);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_panel, findsNothing);
      expect(events, ['disposed', 'returned']);
    });

    testWidgets('isDismissible: false ignores scrim, back and Escape', (
      tester,
    ) async {
      final events = <String>[];
      await _pump(tester, events: events, isDismissible: false);
      await _open(tester);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.binding.handlePopRoute();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_panel, findsOneWidget);
      await tester.tap(find.byKey(const Key('sheet-close')));
      await tester.pumpAndSettle();
      expect(events, ['disposed', 'returned']);
    });
  });

  testWidgets('returns only after the sheet subtree is disposed', (
    tester,
  ) async {
    final events = <String>[];
    final results = <Object?>[];
    await _pump(tester, events: events, results: results);
    await _open(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sheet-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(events, isEmpty, reason: 'still animating out');
    await tester.pumpAndSettle();
    expect(events, ['disposed', 'returned']);
    expect(results, ['guardada']);
  });

  testWidgets('a route change closes the sheet (page-aware contract)', (
    tester,
  ) async {
    final events = <String>[];
    final router = await _pump(tester, events: events);
    await _open(tester);
    await tester.pumpAndSettle();
    router.go('/other');
    await tester.pumpAndSettle();
    expect(find.text('Serie 2 de 4'), findsNothing);
    expect(find.text('Otra'), findsOneWidget);
    expect(events, ['disposed', 'returned']);
  });

  testWidgets('a repeated trigger while open is ignored and resolves null', (
    tester,
  ) async {
    final events = <String>[];
    final results = <Object?>[];
    await _pump(tester, events: events, results: results, opens: 2);
    await _open(tester);
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);
    expect(results, [null], reason: 'the duplicate resolves to null at once');
    await tester.tap(find.byKey(const Key('sheet-close')));
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
    // Only the original caller receives the result.
    expect(results, [null, 'guardada']);
    expect(events.where((e) => e == 'disposed'), hasLength(1));
  });

  testWidgets('a trigger while the sheet is closing is ignored (null)', (
    tester,
  ) async {
    final events = <String>[];
    final results = <Object?>[];
    await _pump(tester, events: events, results: results);
    await _open(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sheet-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_panel, findsOneWidget, reason: 'still exiting');
    final second = await showExomSheet<String>(
      context: _openerContext!,
      builder: (_) => const Text('segunda'),
    );
    expect(second, isNull);
    expect(find.text('segunda'), findsNothing);
    await tester.pumpAndSettle();
    expect(results, ['guardada']);
    // Once fully closed a new sheet opens normally.
    await _open(tester);
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);
    await tester.tap(find.byKey(const Key('sheet-close')));
    await tester.pumpAndSettle();
    expect(results, ['guardada', 'guardada']);
  });

  testWidgets('reduced motion: 120 ms fade in and out, no slide', (
    tester,
  ) async {
    final events = <String>[];
    await _pump(tester, events: events, disableAnimations: true);
    await _open(tester);
    final route = _sheetRoute(tester);
    expect(route.transitionDuration, ExomMotion.reducedFade);
    expect(route.reverseTransitionDuration, ExomMotion.reducedFade);
    await tester.pump(const Duration(milliseconds: 60));
    final height = tester.getSize(_panel).height;
    expect(tester.getTopLeft(_panel).dy, closeTo(_screenHeight - height, 0.5));
    final fade = tester.widget<FadeTransition>(
      find.ancestor(
        of: _panel,
        matching: find.byKey(const Key('exom-sheet-fade')),
      ),
    );
    expect(fade.opacity.value, closeTo(0.5, 0.05));
    expect(_scrimAlpha(tester), closeTo(_fullScrimAlpha * 0.5, 0.03));
    await tester.pump(const Duration(milliseconds: 60));
    expect(fade.opacity.value, 1);

    await tester.tap(find.byKey(const Key('sheet-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(fade.opacity.value, closeTo(0.5, 0.05));
    expect(tester.getTopLeft(_panel).dy, closeTo(_screenHeight - height, 0.5));
    expect(_scrimAlpha(tester), closeTo(_fullScrimAlpha * 0.5, 0.03));
    await tester.pumpAndSettle();
    expect(events, ['disposed', 'returned']);
  });

  testWidgets('reduced motion: a 31 % drag still closes', (tester) async {
    final events = <String>[];
    await _pump(tester, events: events, disableAnimations: true);
    await _open(tester);
    await tester.pumpAndSettle();
    final height = tester.getSize(_panel).height;
    await tester.timedDrag(
      _handle,
      Offset(0, height * 0.31),
      const Duration(seconds: 2),
    );
    await tester.pumpAndSettle();
    expect(events, ['disposed', 'returned']);
  });

  testWidgets('keyboard inset lifts the content', (tester) async {
    final events = <String>[];
    await _pump(
      tester,
      events: events,
      viewInsets: const EdgeInsets.only(bottom: 300),
    );
    await _open(tester);
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byKey(const Key('sheet-field')));
    expect(field.bottom, lessThanOrEqualTo(_screenHeight - 300));
    expect(tester.getRect(_panel).bottom, closeTo(_screenHeight - 300, 0.5));
  });

  testWidgets('tall content scrolls above the keyboard without overflow', (
    tester,
  ) async {
    final events = <String>[];
    await _pump(
      tester,
      events: events,
      tall: true,
      viewInsets: const EdgeInsets.only(bottom: 300),
    );
    await _open(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final panel = tester.getRect(_panel);
    expect(panel.bottom, closeTo(_screenHeight - 300, 0.5));
    expect(panel.top, greaterThanOrEqualTo(0));
    await tester.scrollUntilVisible(
      find.byKey(const Key('sheet-close')),
      200,
      scrollable: find
          .descendant(of: _panel, matching: find.byType(Scrollable))
          .first,
    );
    expect(
      tester.getRect(find.byKey(const Key('sheet-close'))).bottom,
      lessThanOrEqualTo(_screenHeight - 300),
    );
  });

  testWidgets('tall content with keyboard and status bar stays between them', (
    tester,
  ) async {
    final events = <String>[];
    await _pump(
      tester,
      events: events,
      tall: true,
      viewInsets: const EdgeInsets.only(bottom: 300),
      padding: const EdgeInsets.only(top: 47),
    );
    await _open(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final panel = tester.getRect(_panel);
    expect(panel.top, greaterThanOrEqualTo(47));
    expect(panel.bottom, lessThanOrEqualTo(_screenHeight - 300));
  });

  for (final (fraction, closes) in const [(0.18, false), (0.31, true)]) {
    testWidgets('grabbing mid-enter: slow ${(fraction * 100).round()} % drag '
        '${closes ? 'closes' : 'settles open'}', (tester) async {
      final events = <String>[];
      await _pump(tester, events: events);
      await _open(tester);
      await tester.pump(const Duration(milliseconds: 60));
      final route = _sheetRoute(tester) as ExomSheetRoute<dynamic>;
      expect(route.shownFraction, inInclusiveRange(0.4, 0.9));
      final height = tester.getSize(_panel).height;
      final gesture = await tester.startGesture(tester.getCenter(_handle));
      const steps = 20;
      for (var i = 0; i < steps; i++) {
        await gesture.moveBy(Offset(0, height * fraction / steps));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      if (closes) {
        expect(_panel, findsNothing);
        expect(events, ['disposed', 'returned']);
      } else {
        expect(_panel, findsOneWidget);
        expect(tester.getRect(_panel).bottom, closeTo(_screenHeight, 0.5));
        expect(events, isEmpty);
      }
    });
  }

  group('body drag (DV-L2-14)', () {
    testWidgets('a short non-scrolling body drag closes the sheet', (
      tester,
    ) async {
      final events = <String>[];
      await _pump(tester, events: events);
      await _open(tester);
      await tester.pumpAndSettle();
      final height = tester.getSize(_panel).height;
      await tester.timedDrag(
        find.text('Serie 2 de 4'),
        Offset(0, height * 0.4),
        const Duration(seconds: 2),
      );
      await tester.pumpAndSettle();
      expect(_panel, findsNothing);
      expect(events, ['disposed', 'returned']);
    });

    testWidgets('a tall scrolling body scrolls and the sheet stays', (
      tester,
    ) async {
      final events = <String>[];
      await _pump(tester, events: events, tall: true);
      await _open(tester);
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(_panel).dy;
      final scrollable = find
          .descendant(of: _panel, matching: find.byType(Scrollable))
          .first;
      final before = tester.state<ScrollableState>(scrollable).position.pixels;
      // Starts below the 48 dp grab area, which owns the top of the panel.
      await tester.timedDrag(
        find.byKey(const Key('exom-sheet-panel')),
        const Offset(0, -200),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(before),
      );
      expect(_panel, findsOneWidget);
      expect(tester.getTopLeft(_panel).dy, closeTo(top, 0.5));
      expect(events, isEmpty);
    });
  });

  testWidgets('modal semantics: route scope, name and barrier label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final events = <String>[];
    await _pump(tester, events: events);
    await _open(tester);
    await tester.pumpAndSettle();
    final data = tester.getSemantics(_panel).getSemanticsData();
    expect(data.flagsCollection.scopesRoute, isTrue);
    expect(data.flagsCollection.namesRoute, isTrue);
    expect(find.bySemanticsLabel('Cerrar hoja'), findsOneWidget);
    expect(
      tester
          .widget<AnimatedModalBarrier>(find.byType(AnimatedModalBarrier))
          .semanticsLabel,
      'Cerrar hoja',
    );
    handle.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets('320 dp at 1.6x without overflow (${brightness.name})', (
      tester,
    ) async {
      final events = <String>[];
      await _pump(
        tester,
        events: events,
        brightness: brightness,
        width: 320,
        textScale: 1.6,
      );
      await _open(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
