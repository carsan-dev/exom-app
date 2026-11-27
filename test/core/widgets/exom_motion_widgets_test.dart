// T0.5 motion helpers: M2 tab page, M3 arrival, M5 grow bar and count-up,
// M6 press (reduced variant and interruption) and M9 form step. Each one has
// its reduced variant and never delays a tap.
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/exom_page_transitions.dart';
import 'package:exom_app/core/widgets/exom_arrival.dart';
import 'package:exom_app/core/widgets/exom_count_up.dart';
import 'package:exom_app/core/widgets/exom_grow_bar.dart';
import 'package:exom_app/core/widgets/exom_step_transition.dart';
import 'package:exom_app/core/widgets/tappable_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'exom_component_harness.dart';
import 'semantic_labels.dart';

double _effectiveOpacity(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  for (final widget in tester.widgetList<Widget>(
    find.ancestor(
      of: finder,
      matching: find.byWidgetPredicate((_) => true, skipOffstage: false),
    ),
  )) {
    if (widget is FadeTransition) opacity *= widget.opacity.value;
    if (widget is Opacity) opacity *= widget.opacity;
  }
  return opacity;
}

// ---------------------------------------------------------------- M2 tabs

class _Counter extends StatefulWidget {
  const _Counter({required this.label});

  final String label;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => _count++),
    child: Text('${widget.label} $_count'),
  );
}

GoRouter _tabRouter() => GoRouter(
  initialLocation: '/a',
  routes: [
    ShellRoute(
      builder: (context, state, child) => Scaffold(body: child),
      routes: [
        GoRoute(
          path: '/a',
          pageBuilder: (context, state) => ExomTabPage<void>(
            key: state.pageKey,
            child: const ColoredBox(
              key: Key('tab-a'),
              color: Colors.black,
              child: SizedBox.expand(),
            ),
          ),
        ),
        GoRoute(
          path: '/b',
          pageBuilder: (context, state) => ExomTabPage<void>(
            key: state.pageKey,
            child: const ColoredBox(
              key: Key('tab-b'),
              color: Colors.black,
              child: Center(child: _Counter(label: 'B')),
            ),
          ),
        ),
      ],
    ),
  ],
);

Future<GoRouter> _pumpTabs(WidgetTester tester, {bool reduced = false}) async {
  final router = _tabRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Tabs with transparent pages, as in the app (the shell paints the
/// background): tab A has a button at the top-left corner, tab B one in the
/// centre, so a tap on A's button can only reach A.
GoRouter _transparentTabRouter() => GoRouter(
  initialLocation: '/a',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          Scaffold(backgroundColor: Colors.transparent, body: child),
      routes: [
        GoRoute(
          path: '/a',
          pageBuilder: (context, state) => ExomTabPage<void>(
            key: state.pageKey,
            child: const Align(
              alignment: Alignment.topLeft,
              child: _Counter(label: 'A'),
            ),
          ),
        ),
        GoRoute(
          path: '/b',
          pageBuilder: (context, state) => ExomTabPage<void>(
            key: state.pageKey,
            child: const Center(child: _Counter(label: 'B')),
          ),
        ),
      ],
    ),
  ],
);

Future<GoRouter> _pumpTransparentTabs(
  WidgetTester tester, {
  bool reduced = false,
}) async {
  final router = _transparentTabRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Whether [finder] is painted at all: absent, or under a zero opacity,
/// counts as not visible.
bool _visible(WidgetTester tester, Finder finder) =>
    finder.evaluate().isNotEmpty && _effectiveOpacity(tester, finder) > 0;

// ---------------------------------------------------------------- M3 rows

Widget _arrivalRows({
  bool animate = true,
  String suffix = '',
  VoidCallback? onTap,
}) {
  return Align(
    alignment: Alignment.topLeft,
    child: ExomArrival(
      animate: animate,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 8; i++)
            ExomArrivalItem(
              index: i,
              child: SizedBox(
                key: Key('row-$i'),
                width: 200,
                height: 20,
                child: i == 0
                    ? GestureDetector(onTap: onTap, child: Text('row$suffix'))
                    : null,
              ),
            ),
        ],
      ),
    ),
  );
}

double _rowDy(WidgetTester tester, int i) =>
    tester.getTopLeft(find.byKey(Key('row-$i'))).dy - 20.0 * i;

// ---------------------------------------------------------------- M9 steps

class _StepHost extends StatefulWidget {
  const _StepHost({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<_StepHost> createState() => _StepHostState();
}

class _StepHostState extends State<_StepHost> {
  int step = 0;

  void go(int value) => setState(() => step = value);

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: ExomStepTransition(
      step: step,
      child: SizedBox(
        key: Key('step-$step'),
        width: 100,
        height: 40,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Text('Paso ${step + 1}'),
        ),
      ),
    ),
  );
}

double _stepDx(WidgetTester tester, int step) =>
    tester.getTopLeft(find.byKey(Key('step-$step'))).dx;

void main() {
  group('M2 ExomTabPage', () {
    testWidgets('crossfade: out in 60 ms, in in 100 ms, no offset', (
      tester,
    ) async {
      final router = await _pumpTabs(tester);
      router.go('/b');
      await tester.pump();
      // The first frame is laid out offstage (heroes of the shell navigator).
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        _effectiveOpacity(tester, find.byKey(const Key('tab-b'))),
        lessThan(0.05),
      );
      expect(
        _effectiveOpacity(tester, find.byKey(const Key('tab-a'))),
        greaterThan(0.95),
      );

      await tester.pump(const Duration(milliseconds: 30));
      final inMid = _effectiveOpacity(tester, find.byKey(const Key('tab-b')));
      final outMid = _effectiveOpacity(tester, find.byKey(const Key('tab-a')));
      expect(inMid, inExclusiveRange(0, 1));
      expect(outMid, inExclusiveRange(0, 1));
      expect(tester.getTopLeft(find.byKey(const Key('tab-b'))), Offset.zero);

      await tester.pump(const Duration(milliseconds: 30));
      expect(
        _effectiveOpacity(tester, find.byKey(const Key('tab-a'))),
        closeTo(0, 1e-6),
      );
      expect(
        _effectiveOpacity(tester, find.byKey(const Key('tab-b'))),
        lessThan(1),
      );

      await tester.pump(const Duration(milliseconds: 40));
      expect(_effectiveOpacity(tester, find.byKey(const Key('tab-b'))), 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tab-a')), findsNothing);
    });

    testWidgets('the new tab takes taps at once', (tester) async {
      final router = await _pumpTabs(tester);
      router.go('/b');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.text('B 0'));
      await tester.pump();
      expect(find.text('B 1'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('same tab with another query keeps its state (no fade)', (
      tester,
    ) async {
      final router = await _pumpTabs(tester);
      router.go('/b');
      await tester.pumpAndSettle();
      await tester.tap(find.text('B 0'));
      await tester.pump();
      router.go('/b?date=2026-11-20');
      await tester.pump();
      expect(find.text('B 1'), findsOneWidget);
      expect(_effectiveOpacity(tester, find.byKey(const Key('tab-b'))), 1);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: cut', (tester) async {
      final router = await _pumpTabs(tester, reduced: true);
      router.go('/b');
      await tester.pump();
      expect(_effectiveOpacity(tester, find.byKey(const Key('tab-b'))), 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tab-a')), findsNothing);
    });

    testWidgets('reduced motion with transparent pages: the old tab is not '
        'painted under the new one', (tester) async {
      final router = await _pumpTransparentTabs(tester, reduced: true);
      router.go('/b');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(_visible(tester, find.text('A 0')), isFalse, reason: '+1 ms');
      expect(_visible(tester, find.text('B 0')), isTrue);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_visible(tester, find.text('A 0')), isFalse, reason: '+51 ms');
      expect(_visible(tester, find.text('B 0')), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('A 0'), findsNothing);
    });

    testWidgets('during the fade only the new tab is in the semantics tree and '
        'takes taps', (tester) async {
      final handle = tester.ensureSemantics();
      final router = await _pumpTransparentTabs(tester);
      final buttonA = tester.getCenter(find.text('A 0'));
      router.go('/b');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      // The old tab is still painted (fading out)...
      expect(_visible(tester, find.text('A 0')), isTrue);
      // ...but hidden from assistive technology...
      // (The semantics tree itself, not the render objects' cached nodes.)
      expect(find.semantics.byLabel('A 0'), findsNothing);
      expect(find.semantics.byLabel('B 0'), findsOne);
      // ...and from taps.
      await tester.tapAt(buttonA);
      await tester.pump();
      expect(find.text('A 1'), findsNothing);
      expect(find.text('A 0'), findsOneWidget);
      await tester.tap(find.text('B 0'));
      await tester.pump();
      expect(find.text('B 1'), findsOneWidget);
      await tester.pumpAndSettle();
      handle.dispose();
    });
  });

  group('M3 ExomArrival', () {
    testWidgets('fades 160 ms; first 6 rows rise 8 dp staggered 30 ms', (
      tester,
    ) async {
      await pumpComponent(tester, _arrivalRows());
      final content = find.byKey(const Key('row-0'));
      expect(_effectiveOpacity(tester, content), closeTo(0, 1e-6));
      for (var i = 0; i < 6; i++) {
        expect(_rowDy(tester, i), closeTo(8, 0.01), reason: 'row $i');
      }
      expect(_rowDy(tester, 6), 0, reason: 'row 7 does not rise');
      expect(_rowDy(tester, 7), 0);

      await tester.pump(const Duration(milliseconds: 30));
      expect(_rowDy(tester, 0), inExclusiveRange(0, 8));
      expect(_rowDy(tester, 1), closeTo(8, 0.01), reason: 'starts at 30 ms');

      await tester.pump(const Duration(milliseconds: 130));
      expect(_effectiveOpacity(tester, content), 1);
      expect(_rowDy(tester, 0), 0);
      expect(_rowDy(tester, 5), inExclusiveRange(0, 8));

      await tester.pump(const Duration(milliseconds: 150));
      for (var i = 0; i < 8; i++) {
        expect(_rowDy(tester, i), 0);
      }
    });

    testWidgets('only the first load: a refresh does not replay it', (
      tester,
    ) async {
      await pumpComponent(tester, _arrivalRows());
      await tester.pumpAndSettle();
      await pumpComponent(tester, _arrivalRows(suffix: ' 2'));
      expect(find.text('row 2'), findsOneWidget);
      expect(_effectiveOpacity(tester, find.text('row 2')), 1);
      expect(_rowDy(tester, 0), 0);
    });

    testWidgets('animate: false shows the content at once', (tester) async {
      await pumpComponent(tester, _arrivalRows(animate: false));
      expect(_effectiveOpacity(tester, find.byKey(const Key('row-0'))), 1);
      expect(_rowDy(tester, 0), 0);
    });

    testWidgets('a tap during the arrival acts at once', (tester) async {
      var taps = 0;
      await pumpComponent(tester, _arrivalRows(onTap: () => taps++));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.text('row'), warnIfMissed: false);
      expect(taps, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: 120 ms fade, no rise', (tester) async {
      await pumpComponent(tester, _arrivalRows(), disableAnimations: true);
      final content = find.byKey(const Key('row-0'));
      expect(_effectiveOpacity(tester, content), closeTo(0, 1e-6));
      expect(_rowDy(tester, 0), 0);
      await tester.pump(const Duration(milliseconds: 60));
      expect(_effectiveOpacity(tester, content), inExclusiveRange(0, 1));
      expect(_rowDy(tester, 0), 0);
      await tester.pump(const Duration(milliseconds: 60));
      expect(_effectiveOpacity(tester, content), 1);
    });
  });

  group('M5 ExomGrowBar', () {
    Widget bar(double value) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 200,
        child: ExomGrowBar(
          value: value,
          color: Colors.white,
          semanticsLabel: 'Progreso',
          semanticsValue: '${(value * 100).round()} %',
        ),
      ),
    );

    double fill(WidgetTester tester) =>
        tester.getSize(find.byKey(ExomGrowBar.fillKey)).width;

    testWidgets('grows 300 ms ease-out and retargets from where it is', (
      tester,
    ) async {
      await pumpComponent(tester, bar(0.5));
      expect(fill(tester), 0);
      await tester.pump(const Duration(milliseconds: 150));
      // Ease-out: past the linear midpoint at half time.
      expect(fill(tester), inExclusiveRange(50, 100));
      await tester.pump(const Duration(milliseconds: 150));
      expect(fill(tester), 100);

      await pumpComponent(tester, bar(1.0));
      await tester.pump(const Duration(milliseconds: 150));
      expect(fill(tester), inExclusiveRange(100, 200));
      await tester.pump(const Duration(milliseconds: 150));
      expect(fill(tester), 200);
    });

    testWidgets('exposes its value to assistive technology', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(tester, bar(0.5));
      expect(
        tester.getSemantics(find.byType(ExomGrowBar)),
        matchesSemantics(label: 'Progreso', value: '50 %'),
      );
      handle.dispose();
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: final value directly', (tester) async {
      await pumpComponent(tester, bar(0.5), disableAnimations: true);
      expect(fill(tester), 100);
    });

    testWidgets('without semanticsValue it exposes the rounded final '
        'percentage, not the animated one', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const SizedBox(
          width: 200,
          child: ExomGrowBar(
            value: 0.426,
            color: Colors.white,
            semanticsLabel: 'Progreso',
          ),
        ),
      );
      // Still at 0 % on screen; assistive technology gets the final value.
      expect(fill(tester), 0);
      expect(
        tester.getSemantics(find.byType(ExomGrowBar)),
        matchesSemantics(label: 'Progreso', value: '43 %'),
      );
      handle.dispose();
      await tester.pumpAndSettle();
    });
  });

  group('M5 ExomCountUp', () {
    String percent(double v) => '${v.round()} %';

    Widget count(double value) => Center(
      child: ExomCountUp(value: value, formatter: percent),
    );

    testWidgets('counts 600 ms the first time; semantics say the final value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(tester, count(80));
      expect(find.text('0 %'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ExomCountUp)),
        matchesSemantics(label: '80 %'),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('80 %'), findsNothing);
      expect(find.text('0 %'), findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('80 %'), findsOneWidget);

      // Later changes show the value directly.
      await pumpComponent(tester, count(90));
      expect(find.text('90 %'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('reduced motion: final value directly', (tester) async {
      await pumpComponent(tester, count(80), disableAnimations: true);
      expect(find.text('80 %'), findsOneWidget);
    });

    testWidgets('only the first value counts: a first 0 followed by the data '
        'shows the data directly, without counting', (tester) async {
      await pumpComponent(tester, count(0));
      expect(find.text('0 %'), findsOneWidget);
      await pumpComponent(tester, count(80));
      expect(find.text('80 %'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('80 %'), findsOneWidget);
    });
  });

  group('M6 TappableScale', () {
    testWidgets('reduced motion dims to exactly .8 while pressed', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        Center(
          child: TappableScale(
            onTap: () {},
            child: const SizedBox(width: 100, height: 60),
          ),
        ),
        disableAnimations: true,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(TappableScale)),
      );
      await tester.pump();
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0.8,
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a tap during the release animation acts at once', (
      tester,
    ) async {
      var taps = 0;
      await pumpComponent(
        tester,
        Center(
          child: TappableScale(
            onTap: () => taps++,
            child: const SizedBox(width: 100, height: 60),
          ),
        ),
      );
      await tester.tap(find.byType(TappableScale));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(find.byType(TappableScale));
      expect(taps, 2);
      await tester.pumpAndSettle();
    });

    test('every constructor presses to ExomMotion.pressScale (plan §8a)', () {
      const child = SizedBox();
      expect(const TappableScale(child: child).scale, ExomMotion.pressScale);
      expect(
        const TappableScale.light(child: child).scale,
        ExomMotion.pressScale,
      );
      expect(
        const TappableScale.medium(child: child).scale,
        ExomMotion.pressScale,
      );
    });
  });

  group('M9 ExomStepTransition', () {
    testWidgets('next step enters 24 dp from the advance side in 240 ms', (
      tester,
    ) async {
      final key = GlobalKey<_StepHostState>();
      await pumpComponent(tester, _StepHost(key: key, onTap: () {}));
      expect(_stepDx(tester, 0), 0);

      key.currentState!.go(1);
      await tester.pump();
      expect(_stepDx(tester, 1), closeTo(24, 0.01));
      expect(_effectiveOpacity(tester, find.byKey(const Key('step-1'))), 0);
      await tester.pump(const Duration(milliseconds: 120));
      expect(_stepDx(tester, 1), inExclusiveRange(0, 24));
      // The previous step leaves towards the other side.
      expect(_stepDx(tester, 0), lessThan(0));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_stepDx(tester, 1), 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(const Key('step-0')), findsNothing);

      // Going back enters from the other side.
      key.currentState!.go(0);
      await tester.pump();
      expect(_stepDx(tester, 0), closeTo(-24, 0.01));
      await tester.pumpAndSettle();
      expect(_stepDx(tester, 0), 0);
    });

    testWidgets('right-to-left: advancing enters from the left', (
      tester,
    ) async {
      final key = GlobalKey<_StepHostState>();
      await pumpComponent(
        tester,
        Directionality(
          textDirection: TextDirection.rtl,
          child: _StepHost(key: key, onTap: () {}),
        ),
      );
      key.currentState!.go(1);
      await tester.pump();
      expect(_stepDx(tester, 1), closeTo(-24, 0.01));
      await tester.pumpAndSettle();
    });

    testWidgets('only the new step is in the semantics tree (L5-A4c)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final key = GlobalKey<_StepHostState>();
      await pumpComponent(tester, _StepHost(key: key, onTap: () {}));
      key.currentState!.go(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      // Both steps are painted mid-way, but a screen reader reads one.
      expect(find.text('Paso 1'), findsOneWidget);
      expect(semanticCount(tester, 'Paso 1'), 0);
      expect(semanticCount(tester, 'Paso 2'), 1);
      // Going back mid-way: the returning step is read again, alone.
      key.currentState!.go(0);
      await tester.pump();
      expect(semanticCount(tester, 'Paso 1'), 1);
      expect(semanticCount(tester, 'Paso 2'), 0);
      await tester.pumpAndSettle();
      expect(semanticCount(tester, 'Paso 1'), 1);
      handle.dispose();
    });

    testWidgets('the new step takes taps at once; the old one does not', (
      tester,
    ) async {
      var taps = 0;
      final key = GlobalKey<_StepHostState>();
      await pumpComponent(tester, _StepHost(key: key, onTap: () => taps++));
      key.currentState!.go(1);
      await tester.pump();
      // A spot covered only by the leaving step (the new one starts 24 dp
      // further): the tap must not reach it.
      final oldOnly =
          tester.getTopLeft(find.byKey(const Key('step-0'))) +
          const Offset(4, 20);
      expect(
        tester.getTopLeft(find.byKey(const Key('step-1'))).dx,
        greaterThan(oldOnly.dx),
      );
      await tester.tapAt(oldOnly);
      expect(taps, 0);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.text('Paso 2'), warnIfMissed: false);
      expect(taps, 1);
      await tester.pumpAndSettle();
    });

    testWidgets(
      'reversing mid-way continues from where the step is (no jump)',
      (tester) async {
        final key = GlobalKey<_StepHostState>();
        await pumpComponent(tester, _StepHost(key: key, onTap: () {}));
        key.currentState!.go(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final step1 = find.byKey(const Key('step-1'));
        final dxBefore = _stepDx(tester, 1);
        final opacityBefore = _effectiveOpacity(tester, step1);
        expect(dxBefore, inExclusiveRange(0, 24));

        key.currentState!.go(0);
        await tester.pump();
        final dxAfter = _stepDx(tester, 1);
        final opacityAfter = _effectiveOpacity(tester, step1);
        debugPrint(
          'STEP reverse: dx $dxBefore -> $dxAfter, '
          'opacity $opacityBefore -> $opacityAfter',
        );
        expect((dxAfter - dxBefore).abs(), lessThan(1.5));
        expect((opacityAfter - opacityBefore).abs(), lessThan(0.1));
        await tester.pumpAndSettle();
        expect(step1, findsNothing);
      },
    );

    testWidgets(
      'advancing twice mid-way does not make the entering step jump',
      (tester) async {
        final key = GlobalKey<_StepHostState>();
        await pumpComponent(tester, _StepHost(key: key, onTap: () {}));
        key.currentState!.go(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final step1 = find.byKey(const Key('step-1'));
        final dxBefore = _stepDx(tester, 1);
        final opacityBefore = _effectiveOpacity(tester, step1);
        expect(dxBefore, inExclusiveRange(0, 24));

        key.currentState!.go(2);
        await tester.pump();
        final dxAfter = _stepDx(tester, 1);
        final opacityAfter = _effectiveOpacity(tester, step1);
        debugPrint(
          'STEP 0-1-2: dx $dxBefore -> $dxAfter, '
          'opacity $opacityBefore -> $opacityAfter',
        );
        expect((dxAfter - dxBefore).abs(), lessThan(1.5));
        expect((opacityAfter - opacityBefore).abs(), lessThan(0.1));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('step-0')), findsNothing);
        expect(step1, findsNothing);
        expect(_stepDx(tester, 2), 0);
        expect(_effectiveOpacity(tester, find.byKey(const Key('step-2'))), 1);
      },
    );

    testWidgets('advance then go back mid-way ends on the first step only', (
      tester,
    ) async {
      final key = GlobalKey<_StepHostState>();
      await pumpComponent(tester, _StepHost(key: key, onTap: () {}));
      key.currentState!.go(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final step1 = find.byKey(const Key('step-1'));
      final dxBefore = _stepDx(tester, 1);
      final opacityBefore = _effectiveOpacity(tester, step1);

      key.currentState!.go(0);
      await tester.pump();
      final dxAfter = _stepDx(tester, 1);
      final opacityAfter = _effectiveOpacity(tester, step1);
      debugPrint(
        'STEP 0-1-0: dx $dxBefore -> $dxAfter, '
        'opacity $opacityBefore -> $opacityAfter',
      );
      expect((dxAfter - dxBefore).abs(), lessThan(1.5));
      expect((opacityAfter - opacityBefore).abs(), lessThan(0.1));
      await tester.pumpAndSettle();
      expect(step1, findsNothing);
      expect(_stepDx(tester, 0), 0);
      expect(_effectiveOpacity(tester, find.byKey(const Key('step-0'))), 1);
    });

    testWidgets('reduced motion: 100 ms fade, no offset', (tester) async {
      final key = GlobalKey<_StepHostState>();
      await pumpComponent(
        tester,
        _StepHost(key: key, onTap: () {}),
        disableAnimations: true,
      );
      key.currentState!.go(1);
      await tester.pump();
      expect(_stepDx(tester, 1), 0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_stepDx(tester, 1), 0);
      expect(
        _effectiveOpacity(tester, find.byKey(const Key('step-1'))),
        inExclusiveRange(0, 1),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(_effectiveOpacity(tester, find.byKey(const Key('step-1'))), 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(const Key('step-0')), findsNothing);
    });
  });
}
