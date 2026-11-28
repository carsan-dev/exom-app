// L5-C5b (owner): the overlapped M9 cross-fade left a faint ghost of the
// previous step. `ExomStepTransitionStyle.slide` is a horizontal push: the
// step that leaves moves fully out to one side while the new one enters from
// the other, both fully opaque, clipped to the content area, in
// [ExomMotion.stepSlide] on [ExomMotion.stepSlideCurve]. Reduced motion keeps
// the short fade of the default style.
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/widgets/exom_step_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'semantic_labels.dart';

const double _width = 200;

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

Finder _step(int step) => find.byKey(Key('step-$step'));

double _dx(WidgetTester tester, int step) =>
    tester.getTopLeft(_step(step)).dx -
    tester.getTopLeft(find.byType(ExomStepTransition)).dx;

class _FocusHost extends StatefulWidget {
  const _FocusHost({super.key, required this.style});

  final ExomStepTransitionStyle style;

  @override
  State<_FocusHost> createState() => _FocusHostState();
}

class _FocusHostState extends State<_FocusHost> {
  int step = 0;
  final FocusNode node = FocusNode();

  void go(int value) => setState(() => step = value);

  @override
  void dispose() {
    node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: _width,
      height: 80,
      child: ExomStepTransition(
        step: step,
        style: widget.style,
        child: SizedBox(
          key: Key('step-$step'),
          width: _width,
          height: 80,
          child: step == 0
              ? TextField(key: const Key('field'), focusNode: node)
              : const Text('Paso 2'),
        ),
      ),
    ),
  );
}

class _SlideHost extends StatefulWidget {
  const _SlideHost({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  State<_SlideHost> createState() => _SlideHostState();
}

class _SlideHostState extends State<_SlideHost> {
  int step = 0;

  void go(int value) => setState(() => step = value);

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: _width,
      height: 40,
      child: ExomStepTransition(
        step: step,
        style: ExomStepTransitionStyle.slide,
        child: SizedBox(
          key: Key('step-$step'),
          width: _width,
          height: 40,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Text('Paso ${step + 1}'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('the push lasts 280 ms on easeInOutCubic (norms 6 and 9)', () {
    expect(ExomMotion.stepSlide, const Duration(milliseconds: 280));
    expect(ExomMotion.stepSlideCurve, Curves.easeInOutCubic);
  });

  testWidgets('advancing: a push to the start, both steps fully opaque', (
    tester,
  ) async {
    final key = GlobalKey<_SlideHostState>();
    await pumpComponent(tester, _SlideHost(key: key));
    key.currentState!.go(1);
    await tester.pump();
    expect(_dx(tester, 1), closeTo(_width, 0.01));
    expect(_dx(tester, 0), closeTo(0, 0.01));

    await tester.pump(const Duration(milliseconds: 140));
    // Mid-way: no opacity on either step (no ghost), and they move as one
    // strip, the new one right after the old one.
    expect(_effectiveOpacity(tester, _step(0)), 1);
    expect(_effectiveOpacity(tester, _step(1)), 1);
    expect(_dx(tester, 0), inExclusiveRange(-_width, 0));
    expect(_dx(tester, 1), inExclusiveRange(0, _width));
    expect(_dx(tester, 1) - _dx(tester, 0), closeTo(_width, 0.01));
    // Clipped to the content area.
    expect(
      find.ancestor(of: _step(1), matching: find.byType(ClipRect)),
      findsWidgets,
    );

    await tester.pump(const Duration(milliseconds: 139));
    expect(_dx(tester, 1), greaterThan(0));
    await tester.pump(const Duration(milliseconds: 1));
    expect(_dx(tester, 1), 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(_step(0), findsNothing);
  });

  testWidgets('going back pushes the other way', (tester) async {
    final key = GlobalKey<_SlideHostState>();
    await pumpComponent(tester, _SlideHost(key: key));
    key.currentState!.go(1);
    await tester.pumpAndSettle();
    key.currentState!.go(0);
    await tester.pump();
    expect(_dx(tester, 0), closeTo(-_width, 0.01));
    await tester.pump(const Duration(milliseconds: 140));
    expect(_dx(tester, 0), inExclusiveRange(-_width, 0));
    expect(_dx(tester, 1), inExclusiveRange(0, _width));
    expect(_effectiveOpacity(tester, _step(0)), 1);
    expect(_effectiveOpacity(tester, _step(1)), 1);
    await tester.pumpAndSettle();
    expect(_dx(tester, 0), 0);
    expect(_step(1), findsNothing);
  });

  testWidgets('right-to-left: advancing enters from the left', (tester) async {
    final key = GlobalKey<_SlideHostState>();
    await pumpComponent(
      tester,
      Directionality(
        textDirection: TextDirection.rtl,
        child: _SlideHost(key: key),
      ),
    );
    key.currentState!.go(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(_dx(tester, 1), lessThan(0));
    expect(_dx(tester, 0), greaterThan(0));
    await tester.pumpAndSettle();
  });

  testWidgets('two quick advances leave only one old step mounted', (
    tester,
  ) async {
    final key = GlobalKey<_SlideHostState>();
    await pumpComponent(tester, _SlideHost(key: key));
    key.currentState!.go(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    key.currentState!.go(2);
    await tester.pump();
    expect(_step(0), findsNothing);
    expect(_step(1), findsOneWidget);
    expect(_step(2), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 140));
    expect(_effectiveOpacity(tester, _step(1)), 1);
    expect(_dx(tester, 2) - _dx(tester, 1), closeTo(_width, 0.01));
    await tester.pumpAndSettle();
    expect(_step(1), findsNothing);
    expect(_dx(tester, 2), 0);
  });

  testWidgets('going back mid-way reverses the push from where it is', (
    tester,
  ) async {
    final key = GlobalKey<_SlideHostState>();
    await pumpComponent(tester, _SlideHost(key: key));
    key.currentState!.go(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final before0 = _dx(tester, 0);
    final before1 = _dx(tester, 1);
    key.currentState!.go(0);
    await tester.pump();
    expect(_dx(tester, 0), closeTo(before0, 0.5));
    expect(_dx(tester, 1), closeTo(before1, 0.5));
    await tester.pumpAndSettle();
    expect(_dx(tester, 0), 0);
    expect(_step(1), findsNothing);
  });

  testWidgets('only the new step takes taps and is in the semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    final key = GlobalKey<_SlideHostState>();
    await pumpComponent(tester, _SlideHost(key: key, onTap: () => taps++));
    key.currentState!.go(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(semanticCount(tester, 'Paso 1'), 0);
    expect(semanticCount(tester, 'Paso 2'), 1);
    await tester.tapAt(tester.getCenter(_step(0)));
    expect(taps, 0);
    await tester.tapAt(tester.getCenter(_step(1)));
    expect(taps, 1);
    await tester.pumpAndSettle();
    handle.dispose();
  });

  for (final style in ExomStepTransitionStyle.values) {
    testWidgets('${style.name}: a field focused in the step that leaves is '
        'excluded from focus', (tester) async {
      final key = GlobalKey<_FocusHostState>();
      await pumpComponent(tester, _FocusHost(key: key, style: style));
      await tester.tap(find.byKey(const Key('field')));
      await tester.pump();
      expect(key.currentState!.node.hasFocus, isTrue);
      key.currentState!.go(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_step(0), findsOneWidget);
      expect(key.currentState!.node.hasFocus, isFalse);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('reduced motion: the short fade of the default style', (
    tester,
  ) async {
    final key = GlobalKey<_SlideHostState>();
    await pumpComponent(tester, _SlideHost(key: key), disableAnimations: true);
    key.currentState!.go(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_dx(tester, 1), 0);
    expect(_effectiveOpacity(tester, _step(1)), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_effectiveOpacity(tester, _step(1)), 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(_step(0), findsNothing);
  });

  testWidgets('the default style is still the overlapped M9', (tester) async {
    expect(
      const ExomStepTransition(step: 0, child: SizedBox()).style,
      ExomStepTransitionStyle.overlap,
    );
  });
}
