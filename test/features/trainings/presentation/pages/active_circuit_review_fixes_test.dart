// L3 review A (active circuit), fixes F1-F3: setState after an await on a
// disposed page, «Terminar circuito» busy forever while the TrainingBloc is
// not loaded, and footer actions tapped while «+30 s» is in flight (they are
// applied in order instead of being dropped). Also pins the re-arm guard of
// the logged transition (reviewer mutation M8 survived every other test).
import 'dart:async';

import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'circuit_test_harness.dart';

final _a = circuitExercise('a', 'Burpees', restSeconds: 30);
final _b = circuitExercise('b', 'Sentadilla con salto', restSeconds: 20);

const _footer = ValueKey('circuit-executing-footer');
const _extend = Key('circuit-rest-extend');
const _skip = Key('circuit-rest-skip');

DateTime _persistedEnd(CircuitHarness h) =>
    DateTime.parse(h.storage.lastWrite['rest_ends_at'] as String);

Future<CircuitHarness> _resting(
  WidgetTester tester, {
  String status = 'exerciseResting',
  int round = 1,
  int index = 1,
}) => pumpCircuit(
  tester,
  exercises: [_a, _b],
  rounds: 2,
  restBetweenRounds: 60,
  restored: preL3State(
    round: round,
    exerciseIndex: index,
    status: status,
    restEndsAt: DateTime.now().add(const Duration(seconds: 25)),
    performances: {
      'a': [
        {'set_number': 1, 'reps': 12},
      ],
    },
  ),
);

/// Lets the footer cross-fade finish (220 ms) so a single footer is left.
Future<void> _crossFade(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('A-F3: footer actions during an in-flight «+30 s»', () {
    testWidgets('two rapid «+30 s» add 60 s: each persisted and re-armed '
        'once on the same native session', (tester) async {
      final h = await _resting(tester);
      final end = h.native.starts.single.endsAt;
      final id = h.native.starts.single.id;
      final writes = h.storage.writes.length;

      h.storage.writeGate = Completer<void>();
      await tester.tap(find.byKey(_extend));
      await _crossFade(tester);
      // The first extension is still persisting: the second tap is queued.
      await tester.tap(find.byKey(_extend));
      await _crossFade(tester);
      expect(h.native.starts, hasLength(1));
      h.storage.writeGate!.complete();
      await settleFrames(tester);

      expect(_persistedEnd(h), end.add(const Duration(seconds: 60)));
      expect(h.storage.writes.length, writes + 2);
      expect(
        h.storage.writes.skip(writes).map((w) => w['rest_ends_at']),
        [
          end.add(const Duration(seconds: 30)).toIso8601String(),
          end.add(const Duration(seconds: 60)).toIso8601String(),
        ],
      );
      final rearms = h.native.starts.skip(1).toList();
      expect(rearms.map((s) => s.id), [id, id]);
      expect(rearms.map((s) => s.endsAt), [
        end.add(const Duration(seconds: 30)),
        end.add(const Duration(seconds: 60)),
      ]);
      expect(h.native.cancels, 0);
      expect(h.native.finishes, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('skip during the extension ends the rest once, after it',
        (tester) async {
      final h = await _resting(tester);
      final end = h.native.starts.single.endsAt;
      final id = h.native.starts.single.id;
      final writes = h.storage.writes.length;

      h.storage.writeGate = Completer<void>();
      await tester.tap(find.byKey(_extend));
      await _crossFade(tester);
      await tester.tap(find.byKey(_skip));
      await tester.tap(find.byKey(_skip), warnIfMissed: false);
      await tester.pump();
      // Nothing of the skip happens before the extension completes.
      expect(h.native.cancels, 0);
      h.storage.writeGate!.complete();
      await settleFrames(tester);

      expect(h.native.log, ['start:$id', 'start:$id', 'cancel']);
      expect(h.native.finishes, 0);
      // One write per transition: the extension, then the end of the rest.
      expect(h.storage.writes.length, writes + 2);
      expect(
        h.storage.writes[writes]['rest_ends_at'],
        end.add(const Duration(seconds: 30)).toIso8601String(),
      );
      expect(h.storage.lastWrite['status'], 'executing');
      expect(h.storage.lastWrite['rest_ends_at'], isNull);
      expect(h.storage.lastWrite['exercise_index'], 1);
      expect(h.storage.lastWrite['round'], 1);
      expect(find.byKey(_footer), findsOneWidget);
    });

    testWidgets('a «+30 s» whose cache write throws is reported and shown, '
        'and a following skip still works', (tester) async {
      final h = await _resting(tester);
      final id = h.native.starts.single.id;
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      h.storage.writeGate = Completer<void>();
      await tester.tap(find.byKey(_extend));
      await _crossFade(tester);
      h.storage.writeGate!.completeError(StateError('cache write failed'));
      await settleFrames(tester);

      expect(
        find.text(circuitL10n(tester).circuitSaveError),
        findsOneWidget,
      );
      expect(reported, hasLength(1));
      expect(reported.single.exception, isA<StateError>());
      expect(reported.single.library, 'active_circuit_page');
      // The write threw: the native timer was not re-armed.
      expect(h.native.starts, hasLength(1));

      // The queue goes on: a skip after the failure ends the rest.
      h.storage.writeGate = null;
      await tester.tap(find.byKey(_skip));
      await settleFrames(tester);
      expect(h.native.log, ['start:$id', 'cancel']);
      expect(h.storage.lastWrite['status'], 'executing');
      expect(h.storage.lastWrite['rest_ends_at'], isNull);
    });

    testWidgets('the page disposed while «+30 s» persists: no exception, '
        'nothing re-armed', (tester) async {
      final h = await _resting(tester);
      h.storage.writeGate = Completer<void>();
      await tester.tap(find.byKey(_extend));
      await _crossFade(tester);
      // A queued tap must not run on the disposed page either.
      await tester.tap(find.byKey(_skip));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      h.storage.writeGate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(h.native.starts, hasLength(1));
      expect(h.native.cancels, 0);
    });
  });

  group('A-F1: no setState after an await on a disposed page', () {
    testWidgets('the final rest skipped and the page disposed while its '
        'state persists: no exception', (tester) async {
      final h = await pumpCircuit(
        tester,
        exercises: [_a, _b],
        rounds: 1,
        restored: preL3State(
          round: 1,
          exerciseIndex: 1,
          status: 'finalResting',
          restEndsAt: DateTime.now().add(const Duration(seconds: 25)),
        ),
      );
      h.storage.writeGate = Completer<void>();
      await tester.tap(find.byKey(_skip));
      await tester.pump();
      expect(h.storage.lastWrite['ready_to_finish'], isTrue);
      await tester.pumpWidget(const SizedBox());
      h.storage.writeGate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(h.bloc.completions, isEmpty);
    });
  });

  group('A-F2: «Terminar circuito» while the TrainingBloc is not loaded', () {
    testWidgets('returns to enabled with the save error, keeps the frozen '
        'ids; the retry with the bloc loaded uses the same ids', (
      tester,
    ) async {
      final restored = preL3State(
        readyToFinish: true,
        exerciseIndex: 1,
        performances: {
          'a': [
            {'set_number': 1, 'reps': 12},
          ],
          'b': [
            {'set_number': 1, 'reps': 10},
          ],
        },
        completionActions: {
          'a': {
            'operation_id': 'op-frozen-a',
            'sets': [
              {'set_number': 1, 'reps': 12},
            ],
            'weight_used': null,
            'feedback_id': null,
          },
          'b': {
            'operation_id': 'op-frozen-b',
            'sets': [
              {'set_number': 1, 'reps': 10},
            ],
            'weight_used': null,
            'feedback_id': null,
          },
        },
      );
      final h = await pumpCircuit(
        tester,
        exercises: [_a, _b],
        rounds: 1,
        restored: restored,
      );
      final loaded = h.bloc.state;
      h.bloc.state = TrainingInitial();
      final l10n = circuitL10n(tester);
      final writes = h.storage.writes.length;

      await tester.tap(find.byKey(_footer));
      await settleFrames(tester);
      expect(find.text(l10n.circuitSaveError), findsOneWidget);
      final button = tester.widget<ExomPrimaryButton>(
        find.descendant(
          of: find.byKey(_footer),
          matching: find.byType(ExomPrimaryButton),
        ),
      );
      expect(button.busy, isFalse);
      expect(button.onPressed, isNotNull);
      expect(find.text(l10n.circuitFinishButton.toUpperCase()), findsOneWidget);
      expect(h.bloc.completions, isEmpty);
      expect(h.storage.removedKeys, isEmpty);
      // Whatever was rewritten keeps the frozen completion snapshot.
      for (final write in h.storage.writes.skip(writes)) {
        expect(write['completion_actions'], restored['completion_actions']);
        expect(write['ready_to_finish'], isTrue);
      }

      h.bloc.state = loaded;
      await tester.tap(find.byKey(_footer));
      await settleFrames(tester);
      expect(h.bloc.completions.map((e) => e.operationId), [
        'op-frozen-a',
        'op-frozen-b',
      ]);
      expect(find.text('detail'), findsOneWidget);
      expect(h.storage.removedKeys, [circuitStateKey()]);
    });
  });

  group('re-arm guard of the logged transition (mutation M8)', () {
    testWidgets('a rest skipped while the logged set persists is never '
        're-armed natively', (tester) async {
      final h = await pumpCircuit(tester, exercises: [_a, _b], rounds: 1);
      h.storage.writeGate = Completer<void>();
      await tester.tap(find.byKey(_footer));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('set-sheet-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      // The rest started and its write is still in flight.
      expect(h.storage.lastWrite['status'], 'exerciseResting');
      expect(h.native.starts, isEmpty);

      await tester.tap(find.byKey(_skip));
      await tester.pump();
      h.storage.writeGate!.complete();
      await settleFrames(tester);

      expect(h.native.log, ['cancel']);
      expect(h.native.starts, isEmpty);
      expect(h.storage.lastWrite['status'], 'executing');
      expect(h.storage.lastWrite['exercise_index'], 1);
    });
  });
}
