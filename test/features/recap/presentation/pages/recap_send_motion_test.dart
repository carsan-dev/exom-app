// L5-C5b · Recap, motion of the send (plan §8 norms 1-9, 20):
// * «ENVIAR RECAP» dispatches RecapSubmitRequested on the tap, once (norm 2:
//   the action starts on tap). The paper plane flies as feedback in 300 ms
//   (60 ms wind-up + 240 ms accelerating arc along the nose, 45° flattening
//   to 15°, that leaves the screen through its right edge, growing to 1.6
//   and turning with the arc), drawn in the root
//   overlay, whose portal keeps its state if the button is remounted (D1).
//   While the send is in flight the form stays
//   on screen, takes no taps and the button turns busy after the busy delay,
//   once the plane has left.
// * Owner 2026-11-25 («que se haga rápido y cuando termine pase a la página
//   de enviado»): the old 280 ms flight that faded out 96 dp above the button
//   was replaced by this one; its tests now check the new contract.
// * «Enviado» (only after the server confirmed, norm 3) enters with a lime
//   band one third of the body high that travels down in 450 ms and paints the
//   page above its trailing edge (owner decision 2026-11-25: a weekly moment,
//   norm 20, so above the 300 ms of norm 9). It replaced the 6 dp band and the
//   landing of the «5», which left the screen with the old header.
// * Reduced motion: no flight, no sweep; the send is still on tap.
import 'dart:async';
import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';
import 'package:exom_app/features/recap/presentation/pages/recap_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import 'recap_list_redesign_test.dart'
    show RecapListTestRepository, pumpRecapList, recapListOpen;

class _EventSpy extends BlocObserver {
  final events = <RecapEvent>[];

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    if (event is RecapEvent) events.add(event);
  }

  int get submits => events.whereType<RecapSubmitRequested>().length;
}

class _QuietObserver extends BlocObserver {}

/// Repository whose submit waits until the test releases it.
class _SlowSubmitRepository extends RecapListTestRepository {
  _SlowSubmitRepository(super.recaps);

  final release = Completer<void>();

  @override
  Future<void> submitRecap(String id) async {
    await release.future;
    return super.submitRecap(id);
  }
}

/// Repository whose submit answers on its own after [delay], like a real
/// server: the bloc goes RecapLoading → (delay) → RecapSubmitted.
class _DelayedSubmitRepository extends RecapListTestRepository {
  _DelayedSubmitRepository(super.recaps, this.delay);

  final Duration delay;

  @override
  Future<void> submitRecap(String id) async {
    await Future<void>.delayed(delay);
    return super.submitRecap(id);
  }
}

/// The plane is really painted: its follower layer is linked to the button
/// (it has a transform this frame), no ancestor hides it (zero opacity or
/// offstage), it has a size, and its centre lies on the screen.
void _expectPlanePainted(WidgetTester tester, String when) {
  final icon = find.byKey(_icon);
  expect(icon, findsOneWidget, reason: '$when: plane built');
  final box = tester.renderObject<RenderBox>(icon);
  expect(box.attached, isTrue, reason: '$when: attached');
  expect(box.size.isEmpty, isFalse, reason: '$when: size');
  RenderObject? node = box;
  var followers = 0;
  while (node != null) {
    if (node is RenderOpacity) {
      expect(node.opacity, greaterThan(0), reason: '$when: opacity');
    }
    if (node is RenderOffstage) {
      expect(node.offstage, isFalse, reason: '$when: offstage');
    }
    if (node is RenderFollowerLayer) {
      followers++;
      final layer = node.debugLayer;
      expect(layer, isNotNull, reason: '$when: follower painted');
      expect(layer!.attached, isTrue, reason: '$when: follower in the scene');
      if (layer is FollowerLayer) {
        expect(
          layer.getLastTransform(),
          isNotNull,
          reason: '$when: follower linked to its target',
        );
      }
    }
    if (node is RenderBox && node.hasSize) {
      expect(node.size.isEmpty, isFalse, reason: '$when: ${node.runtimeType}');
    }
    node = node.parent;
  }
  expect(followers, lessThanOrEqualTo(1));
  final screen = Offset.zero & tester.view.physicalSize;
  expect(
    screen.contains(_globalRect(tester, icon).center),
    isTrue,
    reason: '$when: on screen',
  );
}

const _action = ValueKey('recap-step-action');
const _icon = ValueKey('recap-send-icon');
const _sweep = ValueKey('recap-sent-sweep');
const _sent = ValueKey('recap-sent');
const _back = ValueKey('recap-sent-back');
const _area = ValueKey('recap-sent-sweep-area');
const _reveal = ValueKey('recap-sent-reveal');

const _flightTotal = Duration(milliseconds: 300);

/// Taps «ENVIAR RECAP» and pumps the tap's frame, where the flight clock
/// starts: from here on the pumped time is the flight's time.
Future<void> _tapAndStartFlight(WidgetTester tester) async {
  await tester.tap(find.byKey(_action));
  await tester.pump();
}

const _sweepTotal = Duration(milliseconds: 450);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Pumps [total] in [step] frames (the clock advances only with pumps).
Future<void> _advance(
  WidgetTester tester,
  Duration total, {
  Duration step = const Duration(milliseconds: 10),
}) async {
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

RecapBloc _bloc(WidgetTester tester) =>
    BlocProvider.of<RecapBloc>(tester.element(find.byType(Scaffold).first));

/// Opens the form from the list and shows the last step, ready to send.
Future<void> _openLastStep(
  WidgetTester tester, {
  bool reduced = false,
  bool dark = false,
  RecapListTestRepository? repository,
  double width = 390,
  double height = 844,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await pumpRecapList(
    tester,
    repository: repository ?? RecapListTestRepository(recapListOpen()),
    disableAnimations: reduced,
    dark: dark,
    width: width,
    height: height,
    textScaler: textScaler,
  );
  await tester.tap(find.byKey(const ValueKey('recap-new')));
  await _settle(tester);
  _bloc(tester).add(const RecapStepChanged(5));
  await _settle(tester);
  await tester.ensureVisible(find.byKey(_action));
  await tester.pump();
}

/// Taps «ENVIAR RECAP» and pumps frame by frame until «Enviado» is built
/// (the sweep starts with it).
Future<void> _sendUntilSent(WidgetTester tester) async {
  await tester.tap(find.byKey(_action));
  for (var i = 0; i < 40 && find.byKey(_sent).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(find.byKey(_sent), findsOneWidget);
}

/// Global rect of the box of [finder], with every transform applied.
Rect _globalRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

/// No ancestor of [finder] clips it: every clip they apply contains it. The
/// screen itself is not counted (the plane leaves it on purpose).
void _expectNotClipped(WidgetTester tester, Finder finder) {
  final target = tester.renderObject(finder);
  final rect = _globalRect(tester, finder);
  final screen = Offset.zero & tester.view.physicalSize;
  RenderObject child = target;
  var parent = child.parent;
  while (parent != null) {
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) {
      final global = MatrixUtils.transformRect(
        parent.getTransformTo(null),
        clip,
      ).inflate(0.5);
      if (global.contains(screen.topLeft) &&
          global.contains(screen.bottomRight - const Offset(1, 1))) {
        child = parent;
        parent = parent.parent;
        continue;
      }
      expect(
        global.contains(rect.topLeft) && global.contains(rect.bottomRight),
        isTrue,
        reason: '${parent.runtimeType} clips the icon ($global vs $rect)',
      );
    }
    child = parent;
    parent = parent.parent;
  }
}

/// Bottom of the page shown by the reveal clip, in the coordinates of the
/// sweep area.
double _revealBottom(WidgetTester tester) {
  final clip = tester.renderObject<RenderClipRect>(find.byKey(_reveal));
  final clipper = clip.clipper;
  if (clipper == null) return clip.size.height;
  return clipper.getClip(clip.size).bottom;
}

void main() {
  setUpAll(() async => initializeDateFormatting('es'));
  late _EventSpy spy;
  setUp(() {
    spy = _EventSpy();
    Bloc.observer = spy;
  });
  tearDown(() async {
    Bloc.observer = _QuietObserver();
    await sl.reset();
  });

  group('D1: the plane is painted with the real send sequence', () {
    testWidgets('real bloc, server answers after 900 ms: plane painted at '
        '50, 120 and 200 ms', (tester) async {
      await _openLastStep(
        tester,
        repository: _DelayedSubmitRepository(
          recapListOpen(),
          const Duration(milliseconds: 900),
        ),
      );
      // A finger, not a synthetic tap: the press scale runs for a few frames
      // before the release sends.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_action)),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();
      expect(_bloc(tester).state, isA<RecapLoading>());
      await tester.pump(const Duration(milliseconds: 50));
      _expectPlanePainted(tester, '50 ms');
      await tester.pump(const Duration(milliseconds: 70));
      _expectPlanePainted(tester, '120 ms');
      await tester.pump(const Duration(milliseconds: 80));
      _expectPlanePainted(tester, '200 ms');
      await _settle(tester);
      expect(find.byKey(_sent), findsOneWidget);
      expect(spy.submits, 1);
    });

    // Root cause seen on the emulator (logcat of the overlay's lifecycle):
    // the slot of the button (with its OverlayPortal) was remounted while
    // step 5 was open, because the press feedback swaps its animated wrapper
    // when the reduced-motion preference flips (TalkBack, or the
    // accessibility session `uiautomator dump` opens). The old portal state
    // is disposed after the new one attached, and its dispose detaches the
    // shared controller: `show()` on the tap then shows nothing.
    testWidgets('after the button is remounted (reduced motion on and off) '
        'the plane is still painted', (tester) async {
      await _openLastStep(
        tester,
        repository: _DelayedSubmitRepository(
          recapListOpen(),
          const Duration(milliseconds: 900),
        ),
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pump();
      await tester.tap(find.byKey(_action));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      _expectPlanePainted(tester, '50 ms');
      await tester.pump(const Duration(milliseconds: 70));
      _expectPlanePainted(tester, '120 ms');
      await tester.pump(const Duration(milliseconds: 80));
      _expectPlanePainted(tester, '200 ms');
      await _settle(tester);
      expect(find.byKey(_sent), findsOneWidget);
      expect(spy.submits, 1);
    });
  });

  group('«ENVIAR RECAP» sends on the tap; the plane is feedback', () {
    testWidgets('the event is emitted on the tap, before any frame, once', (
      tester,
    ) async {
      await _openLastStep(tester);
      await tester.tap(find.byKey(_action));
      expect(spy.submits, 1, reason: 'same frame as the tap');
      await _settle(tester);
      expect(spy.submits, 1);
      expect(find.byKey(_sent), findsOneWidget);
    });

    testWidgets('more taps during the flight and the send add nothing', (
      tester,
    ) async {
      await _openLastStep(tester);
      final spot = tester.getCenter(find.byKey(_action));
      await tester.tap(find.byKey(_action));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(spot);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(spot);
      await _settle(tester);
      expect(spy.submits, 1);
    });

    testWidgets('flight: wind-up down-left, launch along the nose (45°), an '
        'arc that flattens and leaves through the right edge above the '
        'button, growing and turning with the arc, at most 320 ms', (
      tester,
    ) async {
      expect(_flightTotal.inMilliseconds, lessThanOrEqualTo(320));
      // The server answers late, so the form (and the plane) stay on screen.
      await _openLastStep(
        tester,
        repository: _SlowSubmitRepository(recapListOpen()),
      );
      final screen = Offset.zero & tester.view.physicalSize;
      final button = tester.getRect(find.byKey(_action));
      final rest = _globalRect(tester, find.byKey(_icon)).center;
      Matrix4 matrix() => tester
          .widget<Transform>(
            find
                .ancestor(
                  of: find.byKey(_icon),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform;
      double turn() => math.atan2(matrix().entry(1, 0), matrix().entry(0, 0));
      double scale() => math.sqrt(
        math.pow(matrix().entry(0, 0), 2) + math.pow(matrix().entry(1, 0), 2),
      );
      Offset centre() => _globalRect(tester, find.byKey(_icon)).center;
      double degrees(Offset d) => math.atan2(-d.dy, d.dx) * 180 / math.pi;

      await _tapAndStartFlight(tester);
      await tester.pump(const Duration(milliseconds: 40));
      final windUp = centre();
      expect(windUp.dx, lessThan(rest.dx), reason: 'pulls back left');
      expect(windUp.dy, greaterThan(rest.dy), reason: 'and down');
      await tester.pump(const Duration(milliseconds: 20));
      final launch = centre();
      await tester.pump(const Duration(milliseconds: 30));
      final early = centre() - launch;
      expect(degrees(early), closeTo(45, 6), reason: 'along the nose: $early');
      expect(turn().abs(), lessThan(4 * math.pi / 180), reason: 'no turn yet');

      final centres = <Offset>[centre()];
      final turns = <double>[turn()];
      final scales = <double>[scale()];
      final times = <int>[90];
      var elapsed = 90;
      Rect? exit;
      while (elapsed < 299) {
        await tester.pump(const Duration(milliseconds: 5));
        elapsed += 5;
        final rect = _globalRect(tester, find.byKey(_icon));
        centres.add(rect.center);
        turns.add(turn());
        scales.add(scale());
        times.add(elapsed);
        if (exit == null && rect.left > screen.right) exit = rect;
      }
      for (var i = 1; i < centres.length; i++) {
        final step = centres[i] - centres[i - 1];
        expect(step.dx, greaterThan(0), reason: 'always to the right');
        expect(step.dy, lessThan(0), reason: 'always rising');
        // Grows once the squash of the wind-up is released (120 ms).
        if (times[i - 1] >= 120) {
          expect(scales[i], greaterThanOrEqualTo(scales[i - 1]));
        }
        expect(turns[i], greaterThanOrEqualTo(turns[i - 1] - 1e-9));
        // The plane turns with the tangent of its path.
        final heading = math.atan2(step.dy, step.dx) + math.pi / 4;
        final mid = (turns[i] + turns[i - 1]) / 2;
        expect(mid, closeTo(heading, 4 * math.pi / 180), reason: 'frame $i');
        if (i > 1) {
          final before = centres[i - 1] - centres[i - 2];
          expect(
            -step.dy / step.dx,
            lessThanOrEqualTo(-before.dy / before.dx + 1e-6),
            reason: 'flattens',
          );
        }
      }
      expect(turns.last * 180 / math.pi, closeTo(30, 4), reason: 'ends ~30°');
      expect(scales.last, closeTo(1.6, 0.1));
      expect(exit, isNotNull, reason: 'leaves through the right edge');
      expect(exit!.bottom, lessThan(button.top), reason: 'above the button');
      expect(exit.top, greaterThan(0), reason: 'not through the top');
      await tester.pump(const Duration(milliseconds: 6));
      expect(find.byKey(_icon), findsNothing, reason: 'gone by 305 ms');
      expect(spy.submits, 1);
    });

    for (final dark in [false, true]) {
      testWidgets('plane colour: button foreground, then page text '
          '(${dark ? 'dark' : 'light'})', (tester) async {
        await _openLastStep(
          tester,
          dark: dark,
          repository: _SlowSubmitRepository(recapListOpen()),
        );
        Color colour() => tester.widget<Icon>(find.byKey(_icon)).color!;
        final palette = tester.element(find.byKey(_action)).exomPalette;
        await tester.tap(find.byKey(_action));
        await tester.pump();
        expect(colour(), kExomPrimaryForeground);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        expect(colour(), kExomPrimaryForeground, reason: 'still on the button');
        // Off the button before it leaves the screen.
        await tester.pump(const Duration(milliseconds: 210));
        expect(find.byKey(_icon), findsOneWidget);
        expect(colour(), palette.textPrimary);
      });
    }

    for (final large in [false, true]) {
      testWidgets('no ancestor clips the plane mid-flight'
          '${large ? ' (text 2.0, 320x480: the footer scrolls)' : ''}', (
        tester,
      ) async {
        await _openLastStep(
          tester,
          repository: _SlowSubmitRepository(recapListOpen()),
          width: large ? 320 : 390,
          height: large ? 480 : 844,
          textScaler: large
              ? const AndroidNonlinearTextScaler(2.0)
              : TextScaler.noScaling,
        );
        await _tapAndStartFlight(tester);
        for (final ms in const [80, 60, 60]) {
          await tester.pump(Duration(milliseconds: ms));
          _expectNotClipped(tester, find.byKey(_icon));
        }
      });
    }

    testWidgets('while the send is in flight the form stays, takes no taps '
        'and the button turns busy after the delay', (tester) async {
      final repository = _SlowSubmitRepository(recapListOpen());
      await _openLastStep(tester, repository: repository);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      );
      await _tapAndStartFlight(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_bloc(tester).state, isA<RecapLoading>());
      expect(find.byKey(const ValueKey('recap-form')), findsOneWidget);
      expect(find.byKey(const ValueKey('recap-loading')), findsNothing);
      ExomPrimaryButton button() =>
          tester.widget<ExomPrimaryButton>(find.byKey(_action));
      expect(button().busy, isFalse, reason: 'the plane is still leaving');
      await tester.pump(const Duration(milliseconds: 350));
      expect(button().busy, isTrue);
      final steps = spy.events.whereType<RecapStepChanged>().length;
      await tester.tap(find.text(l10n.previous), warnIfMissed: false);
      await tester.tap(find.byTooltip(l10n.cancel), warnIfMissed: false);
      await tester.pump();
      expect(spy.events.whereType<RecapStepChanged>(), hasLength(steps));
      expect(spy.events.whereType<RecapFormCancelled>(), isEmpty);
      // Slow server: the band starts on the confirmation.
      expect(find.byKey(_sent), findsNothing);
      repository.release.complete();
      for (var i = 0; i < 5 && find.byKey(_sweep).evaluate().isEmpty; i++) {
        await tester.pump();
      }
      expect(find.byKey(_sent), findsOneWidget);
      expect(find.byKey(_sweep), findsOneWidget);
      await _settle(tester);
      expect(find.byKey(_sent), findsOneWidget);
      expect(spy.submits, 1);
    });

    testWidgets('system back mid-flight leaves with the send already made '
        'and leaves no plane behind', (tester) async {
      final repository = _SlowSubmitRepository(recapListOpen());
      await _openLastStep(tester, repository: repository);
      await _tapAndStartFlight(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(_icon), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.byType(RecapPage), findsNothing);
      expect(find.byKey(_icon), findsNothing, reason: 'no orphan overlay');
      repository.release.complete();
      await _settle(tester);
      expect(spy.submits, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion: sent on tap, no plane leaves the slot', (
      tester,
    ) async {
      await _openLastStep(
        tester,
        reduced: true,
        repository: _SlowSubmitRepository(recapListOpen()),
      );
      final rest = tester.getCenter(find.byKey(_icon));
      final spot = tester.getCenter(find.byKey(_action));
      await tester.tap(find.byKey(_action));
      expect(spy.submits, 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getCenter(find.byKey(_icon)), rest);
      await tester.tapAt(spot);
      await _settle(tester);
      expect(spy.submits, 1);
    });
  });

  group('a fast confirmation waits for the plane to land', () {
    testWidgets('at 100 ms the plane still flies and «Enviado» is not shown; '
        'as it leaves the screen «Enviado» appears and the band starts on '
        'the next frame', (tester) async {
      await _openLastStep(tester);
      await _tapAndStartFlight(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_bloc(tester).state, isA<RecapSubmitted>(), reason: 'confirmed');
      expect(find.byKey(_icon), findsOneWidget, reason: 'plane painted');
      expect(find.byKey(_sent), findsNothing);
      expect(find.byKey(const ValueKey('recap-form')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 195));
      expect(find.byKey(_sent), findsNothing, reason: '295 ms: still flying');
      expect(find.byKey(_icon), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.byKey(_icon), findsNothing, reason: 'left the screen');
      expect(find.byKey(_sent), findsOneWidget, reason: 'same frame');
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(_sweep), findsOneWidget, reason: 'next frame');
      await tester.pump(const Duration(milliseconds: 100));
      final first = tester.getTopLeft(find.byKey(_sweep)).dy;
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(find.byKey(_sweep)).dy, greaterThan(first));
      await _settle(tester);
      expect(find.byKey(_sweep), findsNothing);
      expect(find.byKey(_sent), findsOneWidget);
      expect(spy.submits, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion with a fast repo: «Enviado» on the next '
        'frames, no wait', (tester) async {
      await _openLastStep(tester, reduced: true);
      await tester.tap(find.byKey(_action));
      for (var i = 0; i < 5 && find.byKey(_sent).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byKey(_sent), findsOneWidget);
      expect(find.byKey(_sweep), findsNothing);
      expect(spy.submits, 1);
    });

    testWidgets('system back during the wait: no exception, nothing extra', (
      tester,
    ) async {
      await _openLastStep(tester);
      await tester.tap(find.byKey(_action));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(_sent), findsNothing);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.byType(RecapPage), findsNothing);
      expect(spy.submits, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('«Enviado» enters with a big lime band that paints the page', () {
    testWidgets('450 ms, ease-in-out; band one third of the body high', (
      tester,
    ) async {
      await _openLastStep(tester);
      await _sendUntilSent(tester);
      await tester.pump();
      expect(find.byKey(_sweep), findsOneWidget);
      expect(
        find.byKey(const ValueKey('recap-loading')),
        findsNothing,
        reason: 'below the band is the plain background, not the skeleton',
      );
      final area = tester.getRect(find.byKey(_area));
      final band = tester.getRect(find.byKey(_sweep));
      expect(band.height, closeTo(area.height / 3, 0.5));
      expect(band.width, closeTo(area.width, 0.5));
      expect(
        band.bottom,
        lessThanOrEqualTo(area.top + 1),
        reason: 'enters from above the top edge',
      );
      final palette = tester.element(find.byKey(_sent)).exomPalette;
      expect(
        tester
            .widgetList<ColoredBox>(
              find.descendant(
                of: find.byKey(_sweep),
                matching: find.byType(ColoredBox),
              ),
            )
            .map((box) => box.color),
        contains(palette.limeFill),
      );
      var lastTop = band.top;
      var frames = 0;
      while (find.byKey(_sweep).evaluate().isNotEmpty && frames < 100) {
        await tester.pump(const Duration(milliseconds: 10));
        frames++;
        if (find.byKey(_sweep).evaluate().isEmpty) break;
        final now = tester.getRect(find.byKey(_sweep));
        expect(now.top, greaterThanOrEqualTo(lastTop), reason: 'monotonic');
        expect(now.height, closeTo(area.height / 3, 0.5));
        lastTop = now.top;
      }
      expect(frames, inInclusiveRange(44, 47), reason: '450 ms');
      expect(find.byKey(_sweep), findsNothing, reason: 'gone at the end');
      expect(lastTop, greaterThan(area.bottom - area.height / 3));
    });

    testWidgets('above the trailing edge the page, below the leading edge '
        'the background', (tester) async {
      await _openLastStep(tester);
      await _sendUntilSent(tester);
      await tester.pump();
      final area = tester.getRect(find.byKey(_area));
      for (var i = 0; i < 40 && find.byKey(_sweep).evaluate().isNotEmpty; i++) {
        final band = tester.getRect(find.byKey(_sweep));
        final bottom = _revealBottom(tester);
        final trailing = band.top - area.top;
        final leading = band.bottom - area.top;
        expect(bottom, greaterThanOrEqualTo(trailing.clamp(0.0, area.height)));
        expect(
          bottom,
          closeTo(leading.clamp(0.0, area.height), 0.5),
          reason: 'nothing of the page below the band',
        );
        await tester.pump(const Duration(milliseconds: 10));
      }
      // The page is a repaint boundary under the reveal clip.
      expect(
        find.descendant(
          of: find.byKey(_reveal),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });

    testWidgets('the trailing edge fades into the page over 16 dp', (
      tester,
    ) async {
      await _openLastStep(tester);
      await _sendUntilSent(tester);
      await tester.pump(const Duration(milliseconds: 200));
      final fade = find.descendant(
        of: find.byKey(_sweep),
        matching: find.byKey(const ValueKey('recap-sent-sweep-fade')),
      );
      expect(fade, findsOneWidget);
      expect(tester.getSize(fade).height, closeTo(16, 0.01));
      expect(
        tester.getTopLeft(fade).dy,
        closeTo(tester.getTopLeft(find.byKey(_sweep)).dy, 0.01),
      );
    });

    testWidgets('the view is built at most twice during the sweep', (
      tester,
    ) async {
      await _openLastStep(tester);
      await _sendUntilSent(tester);
      var builds = 0;
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        if (element.widget.key == _sent) builds++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previous);
      await _advance(tester, _sweepTotal + const Duration(milliseconds: 40));
      debugOnRebuildDirtyWidget = previous;
      expect(find.byKey(_sweep), findsNothing);
      expect(builds, lessThanOrEqualTo(2), reason: 'not one build per frame');
    });

    testWidgets('taps are blocked only during the sweep', (tester) async {
      await _openLastStep(tester);
      await _sendUntilSent(tester);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(_back), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.byKey(_sent), findsOneWidget);
      await _advance(tester, _sweepTotal);
      expect(find.byKey(_sweep), findsNothing);
      expect(find.byKey(_back).hitTestable(), findsOneWidget);
      expect(find.byType(ExomCoachBlock).hitTestable(), findsOneWidget);
      // L5-C5b (owner): the coach voice signs «Moi».
      expect(
        tester.widget<ExomCoachBlock>(find.byType(ExomCoachBlock)).author,
        'Moi',
      );
    });

    testWidgets('system back mid-sweep shows the list, nothing dispatched', (
      tester,
    ) async {
      await _openLastStep(tester);
      await _sendUntilSent(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(_sweep), findsOneWidget);
      final before = spy.events.length;
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.byKey(_sent), findsNothing);
      expect(find.byKey(const ValueKey('recap-list')), findsOneWidget);
      expect(spy.events.length, before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a rebuild mid-sweep (size, text scale) does not restart it', (
      tester,
    ) async {
      await _openLastStep(tester);
      await _sendUntilSent(tester);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(_sweep), findsOneWidget);
      tester.view.physicalSize = const Size(400, 844);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 210));
      expect(find.byKey(_sweep), findsNothing, reason: 'ended on time');
    });

    testWidgets('reduced motion: no band, the page at once', (tester) async {
      await _openLastStep(tester, reduced: true);
      await tester.tap(find.byKey(_action));
      for (var i = 0; i < 40 && find.byKey(_sent).evaluate().isEmpty; i++) {
        await tester.pump();
      }
      expect(find.byKey(_sent), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        expect(find.byKey(_sweep), findsNothing);
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(_back).hitTestable(), findsOneWidget);
    });
  });
}
