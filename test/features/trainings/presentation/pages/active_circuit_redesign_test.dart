// Active circuit redesign (L3 unit 4): direction A on top of the unchanged
// persistence (same cache key, same map, a write on every transition), the
// shared set sheet (D3 parser, D4 prefill, D5 units, RIR chips with the
// target on every round), the rest truth (persisted rest_ends_at) with
// «+30 s» and «Saltar descanso» (D7), the completion identity (frozen
// operation ids), the exit confirmation and the mandatory last-set video.
import 'dart:async';
import 'dart:convert';

import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/features/feedback/presentation/pages/feedback_page.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/services/circuit_progression.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_circuit_page.dart';
import 'package:exom_app/features/trainings/presentation/widgets/execution_timer.dart';
import 'package:exom_app/features/trainings/presentation/widgets/set_performance_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'circuit_test_harness.dart';

final _a = circuitExercise('a', 'Burpees', targetRir: 2, restSeconds: 30);
final _b = circuitExercise('b', 'Sentadilla con salto', restSeconds: 20);

const _footer = ValueKey('circuit-executing-footer');

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(_footer));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _saveSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('set-sheet-save')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Finder get _countField => find.byKey(const Key('set-sheet-count-field'));
Finder get _weightField => find.byKey(const Key('set-sheet-weight-field'));

String _text(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!.text;

int? _selectedRir(WidgetTester tester) => tester
    .widget<ExomChoiceChips<int>>(find.byKey(const Key('set-sheet-rir')))
    .selected;

Future<void> _tapRir(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const Key('set-sheet-rir')),
      matching: find.text(label),
    ),
  );
  await tester.pump();
}

Map<String, dynamic> _json(Object? value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

Finder _restFooter(DateTime end) =>
    find.byKey(ValueKey('round-rest-${end.millisecondsSinceEpoch}'));

DateTime _persistedEnd(CircuitHarness h) =>
    DateTime.parse(h.storage.lastWrite['rest_ends_at'] as String);

/// The released page's reader (`_restoreState` at b033b6a), as a pure
/// function: what the pre-L3 app would restore from [stored]. Used to prove
/// that maps written by the redesigned page stay readable by it.
({
  int round,
  int index,
  String status,
  DateTime? restEndsAt,
  bool ready,
  Map<String, List<SetPerformance>> performances,
  Map<String, Map<String, dynamic>> actions,
  Map<String, String> feedbackIds,
})?
_readLikeReleasedApp(Map<String, dynamic> stored, int rounds, int count) {
  final round = (stored['round'] as num?)?.toInt();
  final index = (stored['exercise_index'] as num?)?.toInt();
  final status = stored['status'] as String?;
  const statuses = [
    'executing',
    'exerciseResting',
    'roundResting',
    'finalResting',
  ];
  if (round == null ||
      round < 1 ||
      round > rounds ||
      index == null ||
      index < 0 ||
      index >= count ||
      !statuses.contains(status)) {
    return null;
  }
  final performances = <String, List<SetPerformance>>{};
  final rawPerformances = stored['performances'];
  if (rawPerformances is Map) {
    for (final entry in rawPerformances.entries) {
      if (entry.value is! List) continue;
      final sets = [
        for (final raw in (entry.value as List).whereType<Map>())
          SetPerformance.fromJson(Map<String, dynamic>.from(raw)),
      ];
      if (sets.isNotEmpty) performances[entry.key.toString()] = sets;
    }
  }
  final actions = <String, Map<String, dynamic>>{};
  final rawActions = stored['completion_actions'];
  if (rawActions is Map) {
    for (final entry in rawActions.entries) {
      if (entry.value is! Map) continue;
      final action = Map<String, dynamic>.from(entry.value as Map);
      if (action['operation_id'] is String &&
          (action['operation_id'] as String).isNotEmpty) {
        actions[entry.key.toString()] = action;
      }
    }
  }
  final rawIds = stored['feedback_ids'];
  return (
    round: round,
    index: index,
    status: status!,
    restEndsAt: DateTime.tryParse(stored['rest_ends_at'] as String? ?? ''),
    ready: stored['ready_to_finish'] == true,
    performances: performances,
    actions: actions,
    feedbackIds: rawIds is Map
        ? rawIds.map((k, v) => MapEntry(k.toString(), v.toString()))
        : const {},
  );
}

void main() {
  group('pure helpers', () {
    test('circuitRestTotalSeconds never indexes out of range (F1)', () {
      int total(CircuitRestKind kind, int index, List<int> rests) =>
          circuitRestTotalSeconds(
            kind: kind,
            currentExerciseIndex: index,
            exerciseRestSeconds: rests,
            roundRestSeconds: 60,
          );
      // One-exercise circuit, final rest: its own rest (was exercises[-1]).
      expect(total(CircuitRestKind.finalRest, 0, [30]), 30);
      expect(total(CircuitRestKind.finalRest, 2, [10, 20, 45]), 45);
      // Exercise rest: the index was already advanced.
      expect(total(CircuitRestKind.exercise, 1, [10, 20]), 10);
      expect(total(CircuitRestKind.exercise, 0, [10, 20]), 0);
      expect(total(CircuitRestKind.round, 1, [10, 20]), 60);
      expect(total(CircuitRestKind.none, 1, [10, 20]), 0);
      expect(total(CircuitRestKind.finalRest, 0, [7200]), 3600);
    });

    test('circuitCompletedCount for every status (F2)', () {
      int count(int round, int index, String status, {bool ready = false}) =>
          circuitCompletedCount(
            round: round,
            exerciseIndex: index,
            exerciseCount: 3,
            totalRounds: 2,
            status: status,
            readyToFinish: ready,
          );
      expect(count(1, 0, 'executing'), 0);
      expect(count(1, 2, 'executing'), 2);
      expect(count(1, 1, 'exerciseResting'), 1);
      expect(count(1, 2, 'roundResting'), 3);
      expect(count(2, 0, 'executing'), 3);
      expect(count(2, 2, 'finalResting'), 6);
      expect(count(2, 2, 'executing', ready: true), 6);
      expect(count(2, 2, 'done'), 6);
    });
  });

  group('cache compatibility (constraint 1)', () {
    testWidgets('restores a mid-rest state written by the released app '
        '(frozen completion, feedback, RIR-only set, RIR 8) and writes it back '
        'with the same keys and values', (tester) async {
      final end = DateTime.now().add(const Duration(seconds: 45));
      final fixture = preL3State(
        sessionId: 'sess-1',
        round: 2,
        exerciseIndex: 1,
        status: 'exerciseResting',
        restEndsAt: end,
        performances: {
          'a': [
            {'set_number': 1, 'reps': 12, 'weight_kg': 20.0, 'rir': 8},
            {'set_number': 2, 'rir': 2},
          ],
          'b': [
            {'set_number': 1, 'seconds': 45},
          ],
        },
        completionActions: {
          'a': {
            'operation_id': 'op-frozen-a',
            'sets': [
              {'set_number': 1, 'reps': 12, 'weight_kg': 20.0, 'rir': 8},
            ],
            'weight_used': 20.0,
            'feedback_id': 'client-upload-1',
          },
        },
        feedbackIds: {'a': 'client-upload-1'},
        feedbackStatuses: {'a': 'queued'},
      )..['unknown_future_key'] = 'ignored';
      final h = await pumpCircuit(
        tester,
        exercises: [_a, _b],
        restored: fixture,
        sessionId: 'sess-1',
        queueStatuses: const {'client-upload-1': 'queued'},
      );
      final l10n = circuitL10n(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.circuitRoundOf(2, 2)), findsOneWidget);
      expect(find.text(l10n.restTimerTitle.toUpperCase()), findsOneWidget);
      expect(_restFooter(end), findsOneWidget);
      expect(
        find.byKey(ValueKey('rest-countdown-${end.millisecondsSinceEpoch}')),
        findsOneWidget,
      );
      // Rest truth: the native timer is re-armed from the persisted end.
      expect(h.native.starts, hasLength(1));
      expect(
        h.native.starts.single.id,
        '$circuitTrainingId:$circuitBlockId:${end.millisecondsSinceEpoch}',
      );
      expect(h.native.starts.single.endsAt, end);
      // Round 2: 'a' only has a RIR-only set; it is shown, not repaired.
      expect(find.text('RIR 2'), findsOneWidget);
      // The restore itself writes nothing.
      expect(h.storage.writes, isEmpty);

      await tester.tap(find.byKey(const Key('circuit-rest-skip')));
      await settleFrames(tester);
      expect(h.native.cancels, 1);
      final written = h.storage.lastWrite;
      expect(h.storage.writeKeys.single, circuitStateKey(sessionId: 'sess-1'));
      expect(written.keys.toSet(), preL3CircuitKeys);
      expect(written['training_session_id'], 'sess-1');
      expect(written['round'], 2);
      expect(written['exercise_index'], 1);
      expect(written['status'], 'executing');
      expect(written['rest_ends_at'], isNull);
      expect(written['ready_to_finish'], isFalse);
      expect(
        jsonEncode(written['performances']),
        jsonEncode(fixture['performances']),
      );
      expect(
        jsonEncode(written['completion_actions']),
        jsonEncode(fixture['completion_actions']),
      );
      expect(written['feedback_ids'], {'a': 'client-upload-1'});
      expect(written['feedback_statuses'], {'a': 'queued'});
    });

    testWidgets('every write of a full run keeps the released key set, '
        'types and transitions, and the released reader accepts it', (
      tester,
    ) async {
      final h = await pumpCircuit(
        tester,
        exercises: [_a, _b],
        rounds: 2,
        restBetweenRounds: 60,
      );
      Future<void> log() async {
        await _openSheet(tester);
        await _saveSheet(tester);
      }

      Future<void> skip() async {
        await tester.tap(find.byKey(const Key('circuit-rest-skip')));
        await settleFrames(tester);
      }

      await log(); // a r1 -> exercise rest
      await skip();
      await log(); // b r1 -> round rest
      await skip();
      await log(); // a r2 -> exercise rest
      await skip();
      await log(); // b r2 -> final rest (20 s)
      await skip(); // -> ready -> completion -> pop
      await settleFrames(tester);

      final transitions = [
        for (final write in h.storage.writes)
          '${write['status']}:${write['round']}:${write['exercise_index']}:'
              '${write['ready_to_finish']}',
      ];
      expect(transitions, [
        'exerciseResting:1:1:false',
        'executing:1:1:false',
        'roundResting:1:1:false',
        'executing:2:0:false',
        'exerciseResting:2:1:false',
        'executing:2:1:false',
        'finalResting:2:1:false',
        // L3 (F3): the final rest ends into «ready to finish», persisted
        // before the completion starts.
        'executing:2:1:true',
        // One snapshot write per exercise before its dispatch (unchanged).
        'executing:2:1:true',
        'executing:2:1:true',
      ]);
      for (final write in h.storage.writes) {
        expect(write.keys.toSet(), preL3CircuitKeys);
        expect(write['round'], isA<int>());
        expect(write['exercise_index'], isA<int>());
        expect(write['ready_to_finish'], isA<bool>());
        final end = write['rest_ends_at'];
        if (end != null) {
          // Local ISO without offset, as `DateTime.now()` wrote it.
          expect(end, isA<String>());
          expect((end as String).endsWith('Z'), isFalse);
          expect(DateTime.parse(end).isUtc, isFalse);
        }
        final parsed = _readLikeReleasedApp(write, 2, 2);
        expect(parsed, isNotNull, reason: 'released reader rejects $write');
      }
      expect(h.storage.writeKeys.toSet(), {circuitStateKey()});
      expect(h.storage.removedKeys, [circuitStateKey()]);
      expect(find.text('detail'), findsOneWidget);
    });

    testWidgets('a state written by the new page restores in the new page '
        '(round trip through the released reader shape)', (tester) async {
      final first = await pumpCircuit(tester, exercises: [_a, _b]);
      await _openSheet(tester);
      await tester.enterText(_weightField, '20');
      await _saveSheet(tester);
      final written = _json(first.storage.lastWrite);
      final released = _readLikeReleasedApp(written, 2, 2)!;
      expect(released.status, 'exerciseResting');
      expect(released.performances['a']!.single.weightKg, 20.0);

      final second = await pumpCircuit(
        tester,
        exercises: [_a, _b],
        restored: written,
      );
      expect(_restFooter(released.restEndsAt!), findsOneWidget);
      expect(second.native.starts.single.endsAt, released.restEndsAt);
    });
  });

  group('units (constraint 2)', () {
    testWidgets('metric: persisted set and completion payload are identical '
        'to the pre-L3 values for 12 reps / 62,5 kg / RIR 2', (tester) async {
      final single = circuitExercise('a', 'Burpees', targetRir: 2);
      final h = await pumpCircuit(tester, exercises: [single], rounds: 1);
      await _openSheet(tester);
      expect(_text(tester, _countField), '12');
      expect(_selectedRir(tester), 2);
      await tester.enterText(_weightField, '62,5');
      await _saveSheet(tester);
      await settleFrames(tester);

      // Pre-L3: SetPerformance(setNumber: 1, reps: 12, weightKg: 62.5,
      // rir: 2).toJson(), weight_used = sets.last.weightKg.
      const expectedSet = {'set_number': 1, 'reps': 12, 'weight_kg': 62.5, 'rir': 2};
      final snapshot = h.storage.writes.last;
      expect(
        jsonEncode(snapshot['performances']),
        jsonEncode({
          'a': [expectedSet],
        }),
      );
      final action = (snapshot['completion_actions'] as Map)['a'] as Map;
      expect(
        jsonEncode({...action}..remove('operation_id')),
        jsonEncode({
          'sets': [expectedSet],
          'weight_used': 62.5,
          'feedback_id': null,
        }),
      );
      final event = h.bloc.completions.single;
      expect(event.operationId, action['operation_id']);
      expect(event.weightUsed, 62.5);
      expect(event.weightUsed, isA<double>());
      expect(jsonEncode(event.sets!.map((s) => s.toJson()).toList()), jsonEncode([expectedSet]));
      expect(event.sessionId, isNull);
      expect(event.completed, isTrue);
      expect(event.trainingExerciseId, 'a');
      expect(event.exerciseId, 'ex-a');
      expect(event.sessionStamp, 'owner:1:test');
    });

    testWidgets('metric: an untouched 61.235 kg is saved exactly and «62.5» '
        'with a point is 62.5', (tester) async {
      final h = await pumpCircuit(
        tester,
        exercises: [circuitExercise('a', 'Burpees')],
        rounds: 3,
        restored: preL3State(
          round: 2,
          performances: {
            'a': [
              {'set_number': 1, 'reps': 10, 'weight_kg': 61.235},
            ],
          },
        ),
      );
      await _openSheet(tester);
      await _saveSheet(tester);
      final sets = (h.storage.lastWrite['performances'] as Map)['a'] as List;
      expect((sets.last as Map)['weight_kg'], 61.235);
      expect((sets.last as Map)['reps'], 10);

      await _openSheet(tester);
      await tester.enterText(_weightField, '62.5');
      await _saveSheet(tester);
      final again = (h.storage.lastWrite['performances'] as Map)['a'] as List;
      expect((again.last as Map)['weight_kg'], 62.5);
    });

    testWidgets('imperial: entered and shown in lb, stored in kg', (
      tester,
    ) async {
      final h = await pumpCircuit(
        tester,
        exercises: [circuitExercise('a', 'Burpees')],
        rounds: 3,
        unitSystem: UnitSystem.imperial,
      );
      await _openSheet(tester);
      await tester.enterText(_weightField, '135');
      await _saveSheet(tester);
      var sets = (h.storage.lastWrite['performances'] as Map)['a'] as List;
      expect((sets.last as Map)['weight_kg'], 61.235);
      expect(find.text('Tu peso: 135 lb'), findsOneWidget);

      await _openSheet(tester);
      expect(_text(tester, _weightField), '135');
      await _saveSheet(tester);
      sets = (h.storage.lastWrite['performances'] as Map)['a'] as List;
      expect((sets.last as Map)['weight_kg'], 61.235);
    });
  });

  group('completion identity (constraint 3)', () {
    testWidgets('a retry reuses the frozen operation ids and payloads; '
        'nothing is regenerated per retry', (tester) async {
      var failures = 0;
      final h = await pumpCircuit(
        tester,
        exercises: [_a, _b],
        rounds: 1,
        restored: preL3State(
          readyToFinish: true,
          exerciseIndex: 1,
          performances: {
            'a': [
              {'set_number': 1, 'reps': 99},
            ],
            'b': [
              {'set_number': 1, 'reps': 10, 'weight_kg': 30.0},
            ],
          },
          completionActions: {
            'a': {
              'operation_id': 'op-frozen-a',
              'sets': [
                {'set_number': 1, 'reps': 12, 'rir': 8},
              ],
              'weight_used': null,
              'feedback_id': null,
            },
          },
        ),
        failWhen: (event) => event.trainingExerciseId == 'b' && failures++ == 0,
      );
      final l10n = circuitL10n(tester);
      expect(find.text(l10n.circuitFinishButton.toUpperCase()), findsOneWidget);

      await tester.tap(find.byKey(_footer));
      await settleFrames(tester);
      expect(find.text(l10n.circuitSaveError), findsOneWidget);
      expect(find.text(l10n.circuitFinishButton.toUpperCase()), findsOneWidget);
      final first = h.bloc.completions;
      expect(first.map((e) => e.trainingExerciseId), ['a', 'b']);
      expect(first[0].operationId, 'op-frozen-a');
      // The frozen payload wins over the live sets (reps 99).
      expect(first[0].sets!.single.reps, 12);
      expect(first[0].sets!.single.rir, 8);
      final frozenB = first[1].operationId;
      expect(frozenB, isNotEmpty);
      expect(first[1].weightUsed, 30.0);
      final persistedB =
          (h.storage.lastWrite['completion_actions'] as Map)['b'] as Map;
      expect(persistedB['operation_id'], frozenB);

      await tester.tap(find.byKey(_footer));
      await settleFrames(tester);
      final all = h.bloc.completions;
      expect(all, hasLength(4));
      expect(all[2].operationId, 'op-frozen-a');
      expect(all[3].operationId, frozenB);
      expect(find.text('detail'), findsOneWidget);
      expect(h.storage.removedKeys, [circuitStateKey()]);
    });

    testWidgets('the mandatory last-set video keeps its two points: reminder '
        'before the last round sheet, missing videos before any completion', (
      tester,
    ) async {
      final h = await pumpCircuit(
        tester,
        exercises: [circuitExercise('a', 'Burpees')],
        rounds: 1,
        requiresLastSetVideo: true,
      );
      h.storage.settings['last_set_video_reminder_enabled'] = true;
      final l10n = circuitL10n(tester);
      await tester.tap(find.byKey(_footer));
      await settleFrames(tester);
      expect(find.text(l10n.lastSetReminderTitle), findsOneWidget);
      expect(find.byType(SetPerformanceSheet), findsNothing);
      await tester.tap(find.text(l10n.attachAtEnd));
      await settleFrames(tester);
      expect(find.byType(SetPerformanceSheet), findsOneWidget);
      await _saveSheet(tester);
      await settleFrames(tester);
      // Ready to finish; the missing videos sheet comes before any dispatch.
      expect(find.byType(CircuitFeedbackForm), findsOneWidget);
      expect(find.byKey(const Key('send-circuit-feedback')), findsOneWidget);
      expect(h.bloc.events, isEmpty);
      await tester.tapAt(const Offset(20, 20));
      await settleFrames(tester);
      expect(find.byType(CircuitFeedbackForm), findsNothing);
      expect(h.bloc.events, isEmpty);
      expect(h.storage.lastWrite['ready_to_finish'], isTrue);
      expect(find.text(l10n.circuitFinishButton.toUpperCase()), findsOneWidget);
    });
  });

  group('rest (constraint 4, D7)', () {
    Future<CircuitHarness> resting(
      WidgetTester tester, {
      Duration left = const Duration(seconds: 25),
      String status = 'exerciseResting',
      List<TrainingExerciseEntity>? exercises,
      int index = 1,
      int round = 1,
    }) => pumpCircuit(
      tester,
      exercises: exercises ?? [_a, _b],
      restBetweenRounds: 60,
      restored: preL3State(
        round: round,
        exerciseIndex: index,
        status: status,
        restEndsAt: DateTime.now().add(left),
        performances: {
          'a': [
            {'set_number': 1, 'reps': 12},
          ],
        },
      ),
    );

    testWidgets('«+30 s» persists the new end and re-arms the same native '
        'session; three taps add 90 s', (tester) async {
      final h = await resting(tester);
      final end = h.native.starts.single.endsAt;
      final id = h.native.starts.single.id;
      expect(find.byType(ExomPrimaryButton), findsNothing, reason: 'no lime');

      await tester.tap(find.byKey(const Key('circuit-rest-extend')));
      await settleFrames(tester);
      expect(_persistedEnd(h), end.add(const Duration(seconds: 30)));
      expect(h.storage.lastWrite.keys.toSet(), preL3CircuitKeys);
      expect(h.storage.lastWrite['status'], 'exerciseResting');
      expect(h.native.starts, hasLength(2));
      expect(h.native.starts.last.id, id);
      expect(h.native.starts.last.endsAt, end.add(const Duration(seconds: 30)));
      expect(h.native.cancels, 0);
      expect(_restFooter(end.add(const Duration(seconds: 30))), findsOneWidget);

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('circuit-rest-extend')));
        await settleFrames(tester);
      }
      expect(_persistedEnd(h), end.add(const Duration(seconds: 90)));
      expect(h.native.starts.map((s) => s.id).toSet(), {id});
      expect(h.native.cancels, 0);
    });

    testWidgets('«+30 s» is capped at now + 30 min', (tester) async {
      final h = await resting(
        tester,
        left: const Duration(minutes: 29, seconds: 50),
      );
      await tester.tap(find.byKey(const Key('circuit-rest-extend')));
      await settleFrames(tester);
      final ahead = _persistedEnd(h).difference(DateTime.now());
      expect(ahead, lessThanOrEqualTo(const Duration(minutes: 30)));
      expect(ahead, greaterThan(const Duration(minutes: 29, seconds: 55)));
    });

    testWidgets('a tick of the outgoing footer after «+30 s» does not end '
        'the extended rest', (tester) async {
      final h = await resting(
        tester,
        left: const Duration(milliseconds: 1500),
      );
      final oldEnd = h.native.starts.single.endsAt;
      await tester.tap(find.byKey(const Key('circuit-rest-extend')));
      await tester.pump();
      // The old footer is still cross-fading out (220 ms) with its ticker.
      expect(_restFooter(oldEnd), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1600)),
      );
      // Fires the old ticker (past its end) before the switcher removes it.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.storage.lastWrite['status'], 'exerciseResting');
      expect(_persistedEnd(h), oldEnd.add(const Duration(seconds: 30)));
      expect(h.native.finishes, 0);
      expect(_restFooter(oldEnd.add(const Duration(seconds: 30))), findsOneWidget);
    });

    testWidgets('skip after «+30 s» cancels once and advances once; a double '
        'tap on skip is ignored', (tester) async {
      final h = await resting(tester);
      await tester.tap(find.byKey(const Key('circuit-rest-extend')));
      await settleFrames(tester);
      final writes = h.storage.writes.length;
      final skip = find.byKey(const Key('circuit-rest-skip'));
      await tester.tap(skip);
      await tester.tap(skip, warnIfMissed: false);
      await settleFrames(tester);
      expect(h.native.cancels, 1);
      expect(h.storage.writes.length, writes + 1);
      expect(h.storage.lastWrite['status'], 'executing');
      expect(h.storage.lastWrite['exercise_index'], 1);
      expect(h.storage.lastWrite['round'], 1);
    });

    testWidgets('«+30 s» while the skip is still leaving is ignored: no '
        'native timer is re-armed after the cancel', (tester) async {
      final h = await resting(tester);
      h.native.gate = Completer<void>();
      await tester.tap(find.byKey(const Key('circuit-rest-skip')));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('circuit-rest-extend')),
        warnIfMissed: false,
      );
      await tester.pump();
      h.native.gate!.complete();
      await settleFrames(tester);
      expect(h.native.log, ['start:${h.native.starts.first.id}', 'cancel']);
      expect(h.storage.lastWrite['status'], 'executing');
      expect(h.storage.lastWrite['rest_ends_at'], isNull);
    });

    testWidgets('a restored rest extended beyond its prescription resumes '
        'with the extended end', (tester) async {
      final h = await resting(tester, left: const Duration(seconds: 80));
      final session = h.native.starts.single;
      expect(session.durationSeconds, inInclusiveRange(78, 80));
      expect(find.text('1:20'), findsOneWidget);
    });

    testWidgets('round rest: big countdown, «Ronda 1 hecha», next round, '
        'skip moves to round 2', (tester) async {
      final h = await resting(tester, status: 'roundResting', left: const Duration(seconds: 50));
      final l10n = circuitL10n(tester);
      expect(find.text(l10n.circuitRoundRestTitle.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.circuitRoundDone(1)), findsOneWidget);
      expect(find.text(l10n.circuitNextRound(2, 'Burpees')), findsOneWidget);
      expect(find.byType(ExomPrimaryButton), findsNothing, reason: 'no lime');
      await tester.tap(find.byKey(const Key('circuit-rest-skip')));
      await settleFrames(tester);
      expect(h.storage.lastWrite['round'], 2);
      expect(h.storage.lastWrite['exercise_index'], 0);
      expect(find.text(l10n.circuitRoundOf(2, 2)), findsOneWidget);
    });

    testWidgets('final rest: «+30 s» then skip ends into ready and completes '
        'once (F1 live flow: one exercise, rest 30)', (tester) async {
      final single = circuitExercise('a', 'Burpees', restSeconds: 30);
      final h = await pumpCircuit(tester, exercises: [single], rounds: 2);
      final l10n = circuitL10n(tester);
      await _openSheet(tester);
      await _saveSheet(tester);
      // Round 1 → round 2 directly (no round rest).
      expect(h.storage.lastWrite['round'], 2);
      await _openSheet(tester);
      await _saveSheet(tester);
      expect(tester.takeException(), isNull);
      expect(h.storage.lastWrite['status'], 'finalResting');
      expect(find.text(l10n.circuitFinalRestTitle.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.circuitAfterRestEnd), findsOneWidget);
      final end = _persistedEnd(h);
      await tester.tap(find.byKey(const Key('circuit-rest-extend')));
      await settleFrames(tester);
      expect(_persistedEnd(h), end.add(const Duration(seconds: 30)));
      await tester.tap(find.byKey(const Key('circuit-rest-skip')));
      await settleFrames(tester);
      expect(h.bloc.completions, hasLength(1));
      expect(find.text('detail'), findsOneWidget);
      // Final rest left with cancel; completion does not cancel again.
      expect(h.native.cancels, 1);
    });
  });

  group('sheet (D3, D4, RIR)', () {
    testWidgets('parser errors keep the text, show a field error, focus the '
        'field and write nothing', (tester) async {
      final h = await pumpCircuit(tester, exercises: [_a, _b]);
      final l10n = circuitL10n(tester);
      for (final typed in ['62,5,5', 'abc', '1.250']) {
        await _openSheet(tester);
        await tester.enterText(_weightField, typed);
        await tester.tap(find.byKey(const Key('set-sheet-save')));
        await settleFrames(tester);
        expect(find.byType(SetPerformanceSheet), findsOneWidget);
        expect(_text(tester, _weightField), typed);
        expect(tester.widget<TextField>(_weightField).focusNode!.hasFocus, isTrue);
        expect(h.storage.writes, isEmpty);
        await tester.tap(find.byKey(const Key('set-sheet-cancel')));
        await settleFrames(tester);
      }
      await _openSheet(tester);
      await tester.enterText(_weightField, 'abc');
      await tester.tap(find.byKey(const Key('set-sheet-save')));
      await settleFrames(tester);
      expect(find.text(l10n.setInputNotANumber('abc', '62,5')), findsOneWidget);
    });

    testWidgets('a set with only RIR is refused; a required count is '
        'required', (tester) async {
      final optional = circuitExercise('a', 'Burpees', targetValue: null, targetRir: 2, repsOrDuration: 'AMRAP');
      final h = await pumpCircuit(tester, exercises: [optional]);
      final l10n = circuitL10n(tester);
      await _openSheet(tester);
      expect(_text(tester, _countField), '');
      expect(_selectedRir(tester), 2);
      await tester.tap(find.byKey(const Key('set-sheet-save')));
      await settleFrames(tester);
      expect(find.text(l10n.setPerformanceDataError), findsOneWidget);
      expect(h.storage.writes, isEmpty);
      await tester.tap(find.byKey(const Key('set-sheet-cancel')));
      await settleFrames(tester);

      final required = circuitExercise('r', 'Remo', targetValue: null, repsOrDuration: 'AMRAP', requestSetTracking: true);
      final h2 = await pumpCircuit(tester, exercises: [required]);
      await _openSheet(tester);
      expect(find.byKey(const Key('set-sheet-skip-tracking')), findsNothing);
      await tester.enterText(_weightField, '20');
      await tester.tap(find.byKey(const Key('set-sheet-save')));
      await settleFrames(tester);
      expect(find.text(l10n.setPerformanceRepsError), findsOneWidget);
      expect(h2.storage.writes, isEmpty);
    });

    testWidgets('optional tracking: «Completar sin registrar» advances '
        'without a set, as before', (tester) async {
      final h = await pumpCircuit(tester, exercises: [_b, _a]);
      final l10n = circuitL10n(tester);
      await _openSheet(tester);
      await tester.tap(find.byKey(const Key('set-sheet-skip-tracking')));
      await settleFrames(tester);
      expect(h.storage.lastWrite['performances'], isEmpty);
      expect(h.storage.lastWrite['status'], 'exerciseResting');
      expect(h.storage.lastWrite['exercise_index'], 1);
      // Nothing was logged, so nothing claims to be saved.
      expect(find.byKey(const Key('circuit-set-status')), findsNothing);
      expect(find.text(l10n.circuitNotLogged), findsOneWidget);
    });

    testWidgets('the target RIR is preselected on every round, not carried '
        'over; a stored RIR 8 shows as 5+ and is kept untouched', (
      tester,
    ) async {
      final h = await pumpCircuit(
        tester,
        exercises: [circuitExercise('a', 'Burpees', targetRir: 2)],
        rounds: 3,
      );
      await _openSheet(tester);
      expect(_selectedRir(tester), 2);
      await _tapRir(tester, '4');
      await _saveSheet(tester);
      var sets = (h.storage.lastWrite['performances'] as Map)['a'] as List;
      expect((sets.last as Map)['rir'], 4);
      await _openSheet(tester);
      expect(_selectedRir(tester), 2);
      await tester.tap(find.byKey(const Key('set-sheet-cancel')));
      await settleFrames(tester);

      // Interrupted save: round 1 already holds RIR 8 (released free text).
      final h2 = await pumpCircuit(
        tester,
        exercises: [circuitExercise('a', 'Burpees', targetRir: 2)],
        rounds: 3,
        restored: preL3State(
          performances: {
            'a': [
              {'set_number': 1, 'reps': 10, 'rir': 8},
            ],
          },
        ),
      );
      await _openSheet(tester);
      expect(_selectedRir(tester), 5);
      expect(_text(tester, _countField), '10');
      await _saveSheet(tester);
      sets = (h2.storage.lastWrite['performances'] as Map)['a'] as List;
      expect(sets.last, {'set_number': 1, 'reps': 10, 'rir': 8});
    });

    testWidgets('a double tap on «Registrar serie» opens one sheet and logs '
        'one set with one write', (tester) async {
      final h = await pumpCircuit(tester, exercises: [_a, _b]);
      await tester.tap(find.byKey(_footer));
      await tester.tap(find.byKey(_footer), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SetPerformanceSheet), findsOneWidget);
      await _saveSheet(tester);
      expect(h.storage.writes, hasLength(1));
      expect(((h.storage.lastWrite['performances'] as Map)['a'] as List), hasLength(1));
    });

    testWidgets('prefill: previous session same round, «Anterior» and «Tu '
        'peso»; the device icon line says only «Guardada en este móvil»', (
      tester,
    ) async {
      await pumpCircuit(
        tester,
        exercises: [_a, _b],
        previous: {
          'a': const [
            SetPerformance(setNumber: 1, reps: 10, weightKg: 22.5, rir: 2),
          ],
        },
      );
      final l10n = circuitL10n(tester);
      expect(find.text('Tu peso: 22,5 kg'), findsOneWidget);
      expect(find.text('Anterior: 10 × 22,5 kg · RIR 2'), findsOneWidget);
      expect(find.text(l10n.activeExerciseRestAfter(30)), findsOneWidget);
      await _openSheet(tester);
      expect(_text(tester, _countField), '10');
      expect(_text(tester, _weightField), '22,5');
      expect(find.byKey(const Key('set-sheet-same-as-previous')), findsOneWidget);
      await _saveSheet(tester);
      expect(
        find.text(l10n.circuitSavedStatus('Burpees', 1, l10n.syncStatusSavedOnDevice)),
        findsOneWidget,
      );
      expect(find.text(l10n.syncStatusConfirmed), findsNothing);
      expect(find.text(l10n.syncStatusPending), findsNothing);
    });
  });

  group('exit (constraint 6)', () {
    testWidgets('cancel stays; leave cancels the native rest once, keeps the '
        'state and goes back', (tester) async {
      final h = await pumpCircuit(tester, exercises: [_a, _b]);
      final l10n = circuitL10n(tester);
      await _openSheet(tester);
      await _saveSheet(tester);
      final writes = h.storage.writes.length;

      await tester.tap(find.byKey(const Key('circuit-close')));
      await settleFrames(tester);
      expect(find.text(l10n.activeExerciseCloseMessage(1, 4)), findsOneWidget);
      await tester.tap(find.text(l10n.cancel));
      await settleFrames(tester);
      expect(find.byType(ActiveCircuitPage), findsOneWidget);
      expect(h.native.cancels, 0);

      await tester.binding.handlePopRoute();
      await settleFrames(tester);
      await tester.tap(find.text(l10n.continueButton));
      await settleFrames(tester);
      expect(find.text('detail'), findsOneWidget);
      expect(h.native.cancels, 1);
      expect(h.storage.writes.length, writes);
      expect(h.storage.removedKeys, isEmpty);
    });
  });

  group('timed exercises (unchanged timing)', () {
    testWidgets('the interval timer keeps its key and its draft is removed '
        'after logging, as before', (tester) async {
      final timed = circuitExercise(
        't',
        'Plancha',
        measureType: ExerciseMeasureType.seconds,
        targetValue: 45,
        repsOrDuration: '45s',
      );
      final h = await pumpCircuit(tester, exercises: [timed, _b]);
      expect(find.byType(CircuitExecutionTimer), findsOneWidget);
      expect(find.byKey(const ValueKey('t:1')), findsOneWidget);
      await _openSheet(tester);
      expect(_text(tester, _countField), '45');
      await _saveSheet(tester);
      expect(h.storage.drafts.removed, ['t:interval:1:$circuitDate']);
      final sets = (h.storage.lastWrite['performances'] as Map)['t'] as List;
      expect(sets.single, {'set_number': 1, 'seconds': 45});
    });
  });

  group('layout and accessibility', () {
    for (final brightness in Brightness.values) {
      testWidgets('320 dp at text scale 1.6 (${brightness.name}): executing, '
          'sheet, rest and ready scroll without overflow; footer reachable', (
        tester,
      ) async {
        final long = circuitExercise(
          'a',
          'Press militar con mancuernas sentado en banco inclinado',
          targetRir: 2,
          restSeconds: 30,
        );
        final h = await pumpCircuit(
          tester,
          exercises: [long, _b],
          rounds: 1,
          width: 320,
          height: 640,
          textScale: 1.6,
          brightness: brightness,
          blockName: 'Circuito metabólico de tren inferior y core',
          previous: {
            'a': const [SetPerformance(setNumber: 1, reps: 12, weightKg: 62.5, rir: 2)],
          },
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(_footer).hitTestable(), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('circuit-round-list')),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);

        await _openSheet(tester);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('set-sheet-save')).hitTestable(), findsOneWidget);
        await _saveSheet(tester);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('circuit-rest-skip')).hitTestable(), findsOneWidget);
        expect(find.byKey(const Key('circuit-rest-extend')).hitTestable(), findsOneWidget);

        await tester.tap(find.byKey(const Key('circuit-rest-skip')));
        await settleFrames(tester);
        h.bloc.failWhen = (_) => true;
        await _openSheet(tester);
        await _saveSheet(tester);
        // Final rest (20 s) → skip → ready; the completion fails → retry.
        await tester.tap(find.byKey(const Key('circuit-rest-skip')));
        await settleFrames(tester);
        expect(tester.takeException(), isNull);
        expect(find.byKey(_footer).hitTestable(), findsOneWidget);
      });
    }

    testWidgets('tap targets are at least 48 and labelled (executing and '
        'rest)', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCircuit(tester, exercises: [_a, _b]);
      final l10n = circuitL10n(tester);
      expect(find.byTooltip(l10n.circuitCloseA11y), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('circuit-close'))), const Size(48, 48));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await _openSheet(tester);
      await _saveSheet(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(
        tester.getSemantics(find.byKey(const ValueKey('circuit-row-0'))),
        matchesSemantics(
          label: l10n.circuitRowDoneA11y(
            'Burpees',
            l10n.trainingDetailReps(12),
          ),
        ),
      );
      handle.dispose();
    });
  });
}
