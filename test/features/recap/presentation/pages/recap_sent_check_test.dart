// L5-C5b · Recap, «Enviado»: the check next to the headline (owner decision
// 2026-11-25, animation «Sello»). It waits until the trailing edge of the lime
// band has passed the headline (norm 3), then its stroke is drawn in 180 ms
// (ease-out) and it is stamped in 80 ms (scale 1.12 x 0.88 settling to 1)
// with one light haptic at the start of the stamp. Reduced motion: the check
// is drawn whole, without stamp or haptic.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_sent_check.dart';
import 'package:exom_app/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'recap_list_redesign_test.dart'
    show RecapListTestRepository, pumpRecapList, recapListOpen;

class _QuietObserver extends BlocObserver {}

const _action = ValueKey('recap-step-action');
const _sent = ValueKey('recap-sent');
const _sweep = ValueKey('recap-sent-sweep');
const _area = ValueKey('recap-sent-sweep-area');
const _check = ValueKey('recap-sent-check');
const _headlineRow = ValueKey('recap-sent-headline-row');

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Records the haptic calls sent to the platform.
List<String> _recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add('${call.arguments}');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

/// Opens the form, goes to the last step, sends and pumps until «Enviado» is
/// built (the sweep starts with it).
Future<void> _sendUntilSent(
  WidgetTester tester, {
  bool reduced = false,
  bool dark = false,
}) async {
  await pumpRecapList(
    tester,
    repository: RecapListTestRepository(recapListOpen()),
    disableAnimations: reduced,
    dark: dark,
  );
  await tester.tap(find.byKey(const ValueKey('recap-new')));
  await _settle(tester);
  BlocProvider.of<RecapBloc>(
    tester.element(find.byType(Scaffold).first),
  ).add(const RecapStepChanged(5));
  await _settle(tester);
  await tester.ensureVisible(find.byKey(_action));
  await tester.pump();
  await tester.tap(find.byKey(_action));
  for (var i = 0; i < 40 && find.byKey(_sent).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(find.byKey(_sent), findsOneWidget);
}

RecapSentCheckPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byKey(_check), matching: find.byType(CustomPaint)),
  );
  final painter = paint.painter;
  if (painter is RecapSentCheckPainter) return painter;
  throw TestFailure('the check is not painted by RecapSentCheckPainter');
}

void main() {
  setUpAll(() async => initializeDateFormatting('es'));
  setUp(() => Bloc.observer = _QuietObserver());
  tearDown(() async => sl.reset());

  group('timing helpers', () {
    test('260 ms: trace in 180 ms, then an 80 ms stamp', () {
      expect(RecapSentCheck.duration, const Duration(milliseconds: 260));
      expect(RecapSentCheck.traceAt(0), 0);
      expect(RecapSentCheck.traceAt(90 / 260), greaterThan(0.5));
      expect(RecapSentCheck.traceAt(180 / 260), 1);
      expect(RecapSentCheck.stampScaleAt(100 / 260), const Offset(1, 1));
      final start = RecapSentCheck.stampScaleAt(180 / 260 + 1e-6);
      expect(start.dx, closeTo(1.12, 0.01));
      expect(start.dy, closeTo(0.88, 0.01));
      for (var ms = 181; ms < 260; ms++) {
        final s = RecapSentCheck.stampScaleAt(ms / 260);
        expect(s.dx, inInclusiveRange(0.98, 1.12));
        expect(s.dy, inInclusiveRange(0.88, 1.02));
      }
      expect(RecapSentCheck.stampScaleAt(1), const Offset(1, 1));
    });
  });

  group('«Sello» after the band passes the headline', () {
    testWidgets('not drawn until the trailing edge passes the headline; '
        'then the trace grows to whole', (tester) async {
      await _sendUntilSent(tester);
      final area = tester.getRect(find.byKey(_area));
      final headlineBottom = tester.getRect(find.byKey(_headlineRow)).bottom;
      var lastTrace = 0.0;
      var sawWaiting = false;
      var sawTracing = false;
      for (var i = 0; i < 80; i++) {
        final trace = _painter(tester).trace;
        if (find.byKey(_sweep).evaluate().isNotEmpty) {
          final trailing = tester.getRect(find.byKey(_sweep)).top;
          if (trailing < headlineBottom - 0.5) {
            sawWaiting = true;
            expect(trace, 0, reason: 'band still above the headline end');
          }
        }
        expect(trace, greaterThanOrEqualTo(lastTrace));
        if (trace > 0 && trace < 1) sawTracing = true;
        lastTrace = trace;
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(area.height, greaterThan(0));
      expect(sawWaiting, isTrue);
      expect(sawTracing, isTrue);
      expect(_painter(tester).trace, 1);
      expect(_painter(tester).stampScale, const Offset(1, 1));
    });

    testWidgets('stamp mid-way is not 1, ends at 1; one light haptic', (
      tester,
    ) async {
      final haptics = _recordHaptics(tester);
      await _sendUntilSent(tester);
      haptics.clear();
      var sawStamp = false;
      var hapticsBeforeStamp = -1;
      for (var i = 0; i < 160; i++) {
        final painter = _painter(tester);
        if (painter.trace < 1) hapticsBeforeStamp = haptics.length;
        final scale = painter.stampScale;
        if (scale.dx > 1.001 && scale.dy < 0.999) sawStamp = true;
        await tester.pump(const Duration(milliseconds: 5));
      }
      expect(hapticsBeforeStamp, 0, reason: 'no haptic while tracing');
      expect(sawStamp, isTrue);
      expect(_painter(tester).stampScale, const Offset(1, 1));
      expect(haptics, ['HapticFeedbackType.lightImpact']);
    });

    for (final dark in [false, true]) {
      testWidgets(
        'colour is the headline accent (${dark ? 'dark' : 'light'})',
        (tester) async {
          await _sendUntilSent(tester, dark: dark);
          final palette = tester.element(find.byKey(_sent)).exomPalette;
          expect(_painter(tester).color, palette.data);
          expect(
            tester.widget<Text>(find.text('ENVIADO.')).style?.color,
            palette.data,
          );
        },
      );
    }

    testWidgets('system back mid-sweep: no haptic afterwards', (tester) async {
      final haptics = _recordHaptics(tester);
      await _sendUntilSent(tester);
      haptics.clear();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.byKey(_sent), findsNothing);
      expect(haptics, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion: whole check, no stamp, no haptic', (
      tester,
    ) async {
      final haptics = _recordHaptics(tester);
      await _sendUntilSent(tester, reduced: true);
      haptics.clear();
      for (var i = 0; i < 10; i++) {
        expect(_painter(tester).trace, 1);
        expect(_painter(tester).stampScale, const Offset(1, 1));
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(haptics, isEmpty);
    });
  });
}
