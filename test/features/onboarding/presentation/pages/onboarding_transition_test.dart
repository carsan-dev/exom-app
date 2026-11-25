// L5-D2 · Onboarding, round 2 (M2): the M9 form step in full. The new
// segment of the progress rule grows in 300 ms when advancing; an
// interruption carries on from where things are (no restart from 0); reduced
// motion is a 100 ms fade with the rule full at once.
// Round 4 (O2): no frame between steps without the content of a step.
// Round 5 (owner): the two steps overlap, as in the sketch. From the tap the
// step that leaves fades out in 100 ms (offset to the side the form moves
// away from) while the new one enters in 240 ms from the side it moves to.
// Until round 4 the exit and the entrance ran one after the other; the tests
// of this file that fixed that order now fix the overlap, with the same
// figures, sides, taps and semantics.
// L5-C5b (owner): the overlap left a ghost; the standard step change is now a
// push of the two opaque steps (280 ms, easeInOutCubic). Reduced motion keeps
// the 100 ms crossfade.
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_welcome_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../onboarding_test_support.dart';

const _back = 'onboarding-back';
const _transition = 'onboarding-step-transition';
const _basicsNext = 'onboarding-basics-next';
const _bodyNext = 'onboarding-body-next';

const _basics = 1;
const _body = 2;

const _frame = Duration(milliseconds: 16);

/// Entrance of [step] (0 welcome … 4 summary), or the first one painted.
Finder _entrance([int? step]) => step == null
    ? find.byKey(const Key(_transition)).first
    : find.descendant(
        of: find.byKey(OnboardingPage.stepKey(step)),
        matching: find.byKey(const Key(_transition)),
      );

double _offset(WidgetTester tester, [int? step]) => tester
    .widget<Transform>(
      find
          .descendant(of: _entrance(step), matching: find.byType(Transform))
          .first,
    )
    .transform
    .getTranslation()
    .x;

double _opacity(WidgetTester tester, [int? step]) => tester
    .widget<FadeTransition>(
      find
          .descendant(
            of: _entrance(step),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

/// Product of every opacity above the content of [step] (1 when nothing
/// fades it).
double _inkOpacity(WidgetTester tester, int step) {
  final content = find
      .descendant(of: _entrance(step), matching: find.byType(Transform))
      .first;
  var opacity = 1.0;
  for (final widget in tester.widgetList<Widget>(
    find.ancestor(of: content, matching: find.byWidgetPredicate((_) => true)),
  )) {
    if (widget is FadeTransition) opacity *= widget.opacity.value;
    if (widget is Opacity) opacity *= widget.opacity;
  }
  return opacity;
}

/// Width of the slot of the step on screen.
double _slotWidth(WidgetTester tester) => tester.getSize(_entrance()).width;

/// Width factor of the segment of the rule that is still growing (null when
/// every segment is complete).
double? _growth(WidgetTester tester) {
  final finder = find.byKey(ExomProgressRule.growthKey);
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<FractionallySizedBox>(finder.first).widthFactor;
}

Future<void> _toBasics(WidgetTester tester, {bool reduced = false}) async {
  await pumpOnboardingPage(
    tester,
    FakeOnboardingRepository(),
    disableAnimations: reduced,
  );
  await tapKey(tester, 'onboarding-start');
  await settleOnboarding(tester);
}

/// Taps [key] and lets the change start (the bloc state arrives by
/// microtask).
Future<void> _tap(WidgetTester tester, String key) async {
  await tapKey(tester, key);
  await tester.pump();
}

void main() {
  // L5-C5b (owner): the overlapped cross-fade left a faint ghost of the step
  // that leaves. Now a push: the step that leaves moves fully out to one side
  // while the new one enters from the other, both fully opaque, in 280 ms on
  // easeInOutCubic. The pinned footer stays in place (the new step's at once).
  group('M9 standard', () {
    testWidgets('advancing: a push to the start, both steps fully opaque, '
        'in 280 ms', (tester) async {
      await _toBasics(tester);
      final width = _slotWidth(tester);
      await _tap(tester, _basicsNext);
      await tester.pump(const Duration(milliseconds: 140));
      // Both painted, neither faded: the previous one half out to the start,
      // the new one half in from the end, side by side. While a step leaves
      // the new one does not take taps either (no double tap through it).
      expect(find.byKey(const Key(_basicsNext)), findsOneWidget);
      expect(find.byKey(const Key(_bodyNext)), findsOneWidget);
      expect(_inkOpacity(tester, _basics), 1);
      expect(_inkOpacity(tester, _body), 1);
      expect(_offset(tester, _basics), inExclusiveRange(-width, 0));
      expect(_offset(tester, _body), inExclusiveRange(0, width));
      expect(
        _offset(tester, _body) - _offset(tester, _basics),
        closeTo(width, 0.5),
      );
      expect(find.byKey(const Key(_basicsNext)).hitTestable(), findsNothing);
      // Still moving just before 280 ms; in place and alone after it.
      await tester.pump(const Duration(milliseconds: 130));
      expect(_offset(tester, _body), greaterThan(0));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(_frame);
      expect(find.byKey(const Key(_basicsNext)), findsNothing);
      expect(_offset(tester, _body), 0);
      expect(find.byKey(const Key(_bodyNext)).hitTestable(), findsOneWidget);
      await settleOnboarding(tester);
      expect(_offset(tester), 0);
      expect(_opacity(tester), 1);
    });

    testWidgets('back: the push goes the other way', (tester) async {
      await _toBasics(tester);
      final width = _slotWidth(tester);
      await _tap(tester, _basicsNext);
      await settleOnboarding(tester);
      await _tap(tester, _back);
      await tester.pump(const Duration(milliseconds: 140));
      expect(find.byKey(const Key(_bodyNext)), findsOneWidget);
      expect(find.byKey(const Key(_basicsNext)), findsOneWidget);
      expect(_inkOpacity(tester, _basics), 1);
      expect(_inkOpacity(tester, _body), 1);
      expect(_offset(tester, _body), inExclusiveRange(0, width));
      expect(_offset(tester, _basics), inExclusiveRange(-width, 0));
      expect(
        _offset(tester, _body) - _offset(tester, _basics),
        closeTo(width, 0.5),
      );
      await settleOnboarding(tester);
      expect(find.byKey(const Key(_bodyNext)), findsNothing);
      expect(_offset(tester), 0);
      expect(find.byKey(const Key(_back)), findsNothing);
    });

    testWidgets('the content is clipped to its area', (tester) async {
      await _toBasics(tester);
      expect(
        find.descendant(
          of: _entrance(_basics),
          matching: find.byType(ClipRect),
        ),
        findsWidgets,
      );
    });

    testWidgets('the new segment of the rule grows in 300 ms when advancing '
        'and going back shows it complete', (tester) async {
      await _toBasics(tester);
      await _tap(tester, _basicsNext);
      // The rule starts with the entrance, from the tap.
      await tester.pump(const Duration(milliseconds: 60));
      final early = _growth(tester);
      expect(early, isNotNull);
      expect(early, allOf(greaterThan(0), lessThan(1)));
      // The rule still has about 50 ms left.
      await tester.pump(const Duration(milliseconds: 190));
      expect(_growth(tester), allOf(greaterThan(early!), lessThan(1)));
      await tester.pump(const Duration(milliseconds: 60));
      expect(_growth(tester), isNull);
      expect(
        find.byKey(const ValueKey('exom-rule-segment-on')),
        findsNWidgets(2),
      );
      // Going back: the rule is shown complete, no growth.
      await _tap(tester, _back);
      await tester.pump(const Duration(milliseconds: 60));
      expect(_growth(tester), isNull);
      await settleOnboarding(tester);
      expect(_growth(tester), isNull);
    });

    testWidgets('going back mid-push reverses it from where it is', (
      tester,
    ) async {
      await _toBasics(tester);
      await _tap(tester, _basicsNext);
      await tester.pump(const Duration(milliseconds: 120));
      final basicsBefore = _offset(tester, _basics);
      final bodyBefore = _offset(tester, _body);
      await tapKey(tester, _back);
      await tester.pump();
      await tester.pump(_frame);
      // No jump: both carry on from where they were, fully opaque.
      expect(_offset(tester, _basics), closeTo(basicsBefore, 8));
      expect(_offset(tester, _body), closeTo(bodyBefore, 8));
      expect(_inkOpacity(tester, _basics), 1);
      expect(_inkOpacity(tester, _body), 1);
      expect(find.byKey(const Key(_bodyNext)).hitTestable(), findsNothing);
      await settleOnboarding(tester);
      expect(find.byKey(const Key(_basicsNext)), findsOneWidget);
      expect(find.byKey(const Key(_bodyNext)), findsNothing);
      expect(_offset(tester), 0);
    });

    testWidgets('a second change towards a third step mid-push jumps '
        'cleanly: never more than two steps painted', (tester) async {
      await _toBasics(tester);
      await _tap(tester, _basicsNext);
      await settleOnboarding(tester);
      await _tap(tester, _bodyNext);
      await settleOnboarding(tester);
      // Goals (3) back to body (2), and back again to basics (1) mid-way.
      await _tap(tester, _back);
      await tester.pump(const Duration(milliseconds: 100));
      await tapKey(tester, _back);
      await tester.pump();
      for (var i = 0; i < 25; i++) {
        expect(
          find.byKey(const Key(_transition)).evaluate().length,
          lessThanOrEqualTo(2),
          reason: 'frame $i',
        );
        await tester.pump(_frame);
      }
      await settleOnboarding(tester);
      expect(find.byKey(const Key(_basicsNext)), findsOneWidget);
      expect(find.byKey(const Key(_transition)).evaluate(), hasLength(1));
      expect(_offset(tester), 0);
    });
  });

  group('M9 reduced motion', () {
    testWidgets('a 100 ms crossfade, no offset, the rule complete', (
      tester,
    ) async {
      await _toBasics(tester, reduced: true);
      await _tap(tester, _basicsNext);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key(_basicsNext)), findsOneWidget);
      expect(find.byKey(const Key(_bodyNext)), findsOneWidget);
      expect(_opacity(tester, _basics), allOf(greaterThan(0), lessThan(1)));
      expect(_opacity(tester, _body), allOf(greaterThan(0), lessThan(1)));
      expect(
        _opacity(tester, _basics) + _opacity(tester, _body),
        closeTo(1, 0.01),
      );
      expect(_offset(tester, _basics), 0);
      expect(_offset(tester, _body), 0);
      expect(_growth(tester), isNull);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(_frame);
      expect(find.byKey(const Key(_basicsNext)), findsNothing);
      expect(_opacity(tester, _body), 1);
      expect(_offset(tester, _body), 0);
      expect(_growth(tester), isNull);
      expect(
        find.byKey(const ValueKey('exom-rule-segment-on')),
        findsNWidgets(2),
      );
    });
  });

  group('M9 robustness', () {
    testWidgets('the welcome does not move vertically while it fades out', (
      tester,
    ) async {
      await pumpOnboardingPage(tester, FakeOnboardingRepository());
      final top = tester.getTopLeft(find.byType(OnboardingWelcomeStep)).dy;
      await _tap(tester, 'onboarding-start');
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byType(OnboardingWelcomeStep), findsOneWidget);
        expect(
          tester.getTopLeft(find.byType(OnboardingWelcomeStep)).dy,
          top,
        );
      }
      await settleOnboarding(tester);
      expect(find.byKey(const Key(_basicsNext)), findsOneWidget);
    });

    testWidgets('an interruption mid-transition keeps what was typed', (
      tester,
    ) async {
      await _toBasics(tester);
      await tester.enterText(
        find.byKey(const Key('onboarding-first-name')),
        'Lucía Ana',
      );
      await _tap(tester, _basicsNext);
      await tester.pump(const Duration(milliseconds: 40));
      await tapKey(tester, _back);
      await tester.pump();
      await settleOnboarding(tester);
      expect(find.byKey(const Key(_basicsNext)), findsOneWidget);
      expect(find.text('Lucía Ana'), findsOneWidget);
    });

    testWidgets('a double tap on next during the transition does not skip '
        'a step', (tester) async {
      await _toBasics(tester);
      await _tap(tester, _basicsNext);
      await tester.pump(const Duration(milliseconds: 30));
      // The leaving step takes no taps: the second tap reaches nothing.
      await tester.tap(
        find.byKey(const Key(_basicsNext)),
        warnIfMissed: false,
      );
      await tester.pump();
      await settleOnboarding(tester);
      expect(find.byKey(const Key(_bodyNext)), findsOneWidget);
      expect(find.byKey(const Key('onboarding-goals-next')), findsNothing);
    });

    testWidgets('while both steps are painted only the new one is in the '
        'semantics, so the screen reader reads the new step', (tester) async {
      final semantics = tester.ensureSemantics();
      await _toBasics(tester);
      expect(find.semantics.byLabel('Paso 1 de 4'), findsOne);
      await _tap(tester, _basicsNext);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key(_basicsNext)), findsOneWidget);
      expect(find.semantics.byLabel('Paso 1 de 4'), findsNothing);
      expect(find.semantics.byLabel('Paso 2 de 4'), findsOne);
      await settleOnboarding(tester);
      expect(find.semantics.byLabel('Paso 2 de 4'), findsOne);
      // Back: the same, the other way.
      await _tap(tester, _back);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key(_bodyNext)), findsOneWidget);
      expect(find.semantics.byLabel('Paso 2 de 4'), findsNothing);
      expect(find.semantics.byLabel('Paso 1 de 4'), findsOne);
      await settleOnboarding(tester);
      semantics.dispose();
    });

    testWidgets('unmounting the page mid-animation throws nothing', (
      tester,
    ) async {
      await _toBasics(tester);
      await _tap(tester, _basicsNext);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });

  // Rounds 4 (O2) and 5 (owner, overlap as in the sketch): the step that
  // enters starts to appear while the previous one leaves, so the content
  // area is never empty nor nearly empty. Criterion: in every frame the sum
  // of the opacities of the steps painted is at least [_minPainted]. With
  // the M9 figures (exit 100 ms on the exit curve, entrance 240 ms on the
  // enter curve, both from the tap) the lowest sum is ~0.903, at 100 ms;
  // reduced motion is a linear crossfade (sum 1). A step that leaves and
  // then enters in sequence reaches 0 between them. Going back half-way, the
  // steps carry on from what is painted; the floor is then [minInterrupted]
  // (lowest ~0.88: back just as the previous step has gone, so the step that
  // leaves starts at ~0.9 instead of 1).
  group('M9 overlap: no empty frame between steps (rounds 4 and 5)', () {
    const minPainted = 0.9;
    const minInterrupted = 0.85;

    /// Opacity of every step painted now (hidden steps are offstage).
    List<double> painted(WidgetTester tester) => [
      for (final element in find.byKey(const Key(_transition)).evaluate())
        ((element.widget as KeyedSubtree).child as FadeTransition)
            .opacity
            .value,
    ];

    void expectFilled(WidgetTester tester, String when, {double? min}) {
      final opacities = painted(tester);
      final sum = opacities.fold<double>(0, (a, b) => a + b);
      expect(
        sum,
        greaterThanOrEqualTo(min ?? minPainted),
        reason: 'painted steps $opacities $when',
      );
    }

    Future<void> walk(
      WidgetTester tester,
      String key,
      Duration frame, {
      Duration? interruptAfter,
      String? interruptKey,
    }) async {
      await _tap(tester, key);
      var elapsed = Duration.zero;
      var i = 0;
      var interrupted = false;
      final min = interruptAfter == null ? minPainted : minInterrupted;
      while (elapsed < const Duration(milliseconds: 700)) {
        expectFilled(
          tester,
          'in frame $i (${elapsed.inMilliseconds} ms)',
          min: min,
        );
        if (!interrupted &&
            interruptAfter != null &&
            elapsed >= interruptAfter) {
          interrupted = true;
          await _tap(tester, interruptKey!);
          expectFilled(tester, 'right after the interruption', min: min);
        }
        await tester.pump(frame);
        elapsed += frame;
        i++;
      }
      expectFilled(tester, 'at the end');
      expect(painted(tester), [1.0], reason: 'one step at rest');
    }

    for (final reduced in [false, true]) {
      for (final ms in [16, 4]) {
        final mode = reduced ? 'reduced' : 'normal';
        testWidgets('$mode, ${ms}ms frames: forward and back are never '
            'empty', (tester) async {
          await _toBasics(tester, reduced: reduced);
          final frame = Duration(milliseconds: ms);
          await walk(tester, _basicsNext, frame);
          expect(find.byKey(const Key(_bodyNext)), findsOneWidget);
          await walk(tester, _bodyNext, frame);
          expect(find.byKey(const Key('onboarding-goals-next')), findsOneWidget);
          await walk(tester, _back, frame);
          expect(find.byKey(const Key(_bodyNext)), findsOneWidget);
          await walk(tester, _back, frame);
          expect(find.byKey(const Key(_basicsNext)), findsOneWidget);
        });
      }

      for (final at in [40, 100, 160]) {
        testWidgets('${reduced ? 'reduced' : 'normal'}: back at $at ms '
            'of an advance is never empty', (tester) async {
          await _toBasics(tester, reduced: reduced);
          await walk(
            tester,
            _basicsNext,
            const Duration(milliseconds: 4),
            interruptAfter: Duration(milliseconds: at),
            interruptKey: _back,
          );
          expect(find.byKey(const Key(_basicsNext)), findsOneWidget);
          expect(find.byKey(const Key(_bodyNext)), findsNothing);
        });
      }
    }
  });
  // Round 6 (F1): a step that is hidden or leaving must not keep the primary
  // focus (the keyboard would stay open on a field nobody sees).
  group('focus does not stay in a step that is gone', () {
    bool focusInside(WidgetTester tester, int step) {
      final focus = FocusManager.instance.primaryFocus;
      if (focus?.context == null) return false;
      return find
          .descendant(
            of: find.byKey(OnboardingPage.stepKey(step)),
            matching: find.byWidgetPredicate((w) => true),
            matchRoot: true,
          )
          .evaluate()
          .any((e) => e == focus!.context || _isAncestor(e, focus.context!));
    }

    testWidgets('advancing 1 to 2', (tester) async {
      await _toBasics(tester);
      final field = find
          .descendant(
            of: find.byKey(OnboardingPage.stepKey(_basics)),
            matching: find.byType(TextFormField),
          )
          .first;
      await tester.tap(field);
      await tester.pump();
      expect(focusInside(tester, _basics), isTrue);
      await _tap(tester, _basicsNext);
      await tester.pump(const Duration(milliseconds: 50));
      expect(focusInside(tester, _basics), isFalse);
      await settleOnboarding(tester);
      expect(focusInside(tester, _basics), isFalse);
    });

    testWidgets('back 2 to 1', (tester) async {
      await _toBasics(tester);
      await _tap(tester, _basicsNext);
      await settleOnboarding(tester);
      await typeIntoStepper(tester, 'onboarding-weight', '70,5');
      expect(focusInside(tester, _body), isTrue);
      await _tap(tester, _back);
      await tester.pump(const Duration(milliseconds: 50));
      expect(focusInside(tester, _body), isFalse);
      await settleOnboarding(tester);
      expect(focusInside(tester, _body), isFalse);
    });
  });
}

bool _isAncestor(Element ancestor, BuildContext context) {
  var found = false;
  context.visitAncestorElements((e) {
    if (e == ancestor) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}
