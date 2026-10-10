import 'dart:convert';
import 'dart:async';

import 'package:exom_app/features/trainings/presentation/pages/active_circuit_page.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/entities/timed_prescription.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';

void main() {
  for (final scenario in [
    'new minutes',
    'saved minutes',
    'unaligned minutes',
    'seconds',
    'repetitions',
    'legacy minutes',
  ]) {
    testWidgets('circuit set form preserves $scenario units', (tester) async {
      await sl.reset();
      final timed = scenario.contains('minutes');
      final savedSeconds = scenario == 'saved minutes'
          ? 600
          : scenario == 'unaligned minutes'
          ? 90
          : null;
      final storage = _CircuitStorage();
      if (savedSeconds != null) {
        storage.restored = {
          'round': 1,
          'exercise_index': 0,
          'status': 'executing',
          'performances': {
            'timed': [
              SetPerformance(setNumber: 1, seconds: savedSeconds).toJson(),
            ],
          },
        };
      }
      final queue = _Queue();
      sl.registerSingleton<LocalStorage>(storage);
      sl.registerSingleton<FirebaseAuthService>(_Auth());
      sl.registerSingleton<FeedbackUploadQueueService>(queue);
      final exercise = TrainingExerciseEntity(
        id: 'timed',
        order: 0,
        sets: 2,
        repsOrDuration: scenario == 'legacy minutes' ? '10 min' : '600s',
        measureType: scenario == 'legacy minutes'
            ? null
            : scenario == 'repetitions'
            ? ExerciseMeasureType.reps
            : ExerciseMeasureType.seconds,
        targetValueMin: timed ? 600 : null,
        targetValueMax: timed ? 600 : null,
        timedPrescription: timed
            ? const TimedPrescription(unit: TimeDisplayUnit.minutes)
            : null,
        restSeconds: 0,
        exercise: const ExerciseEntity(
          id: 'exercise',
          name: 'Walk',
          muscleGroups: [],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ActiveCircuitPage(
            trainingId: 'training',
            blockId: 'block',
            args: ActiveCircuitPageArgs(
              trainingBloc: _Bloc(),
              trainingName: 'Training',
              trainingTypes: const ['FUERZA'],
              accentColorHex: null,
              trainingLevel: 'INTERMEDIATE',
              blockId: 'block',
              blockName: 'Circuit',
              rounds: 2,
              restBetweenRoundsSeconds: 0,
              exercises: [exercise, exercise],
              assignmentDate: '2026-10-10',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final footer = find.byKey(const ValueKey('circuit-executing-footer'));
      await tester.ensureVisible(footer);
      await tester.tap(
        find.descendant(of: footer, matching: find.byType(ElevatedButton)),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      final field = tester.widget<TextField>(fields.first);
      final l10n = AppLocalizations.of(tester.element(fields.first));
      expect(
        field.decoration?.labelText,
        scenario == 'repetitions'
            ? l10n.setPerformanceReps
            : timed && savedSeconds != 90
            ? l10n.setPerformanceMinutes
            : l10n.setPerformanceSeconds,
      );
      if (savedSeconds != null) {
        expect(field.controller?.text, savedSeconds == 600 ? '10' : '90');
      } else {
        await tester.enterText(
          fields.first,
          timed
              ? '10'
              : scenario == 'seconds'
              ? '45'
              : '12',
        );
      }
      await tester.tap(find.text(l10n.weightInputSave));
      await tester.pumpAndSettle();
      final raw = storage.writes.last['performances'] as Map;
      final sets = raw['timed'] as List;
      final performance = SetPerformance.fromJson(
        Map<String, dynamic>.from(sets.last as Map),
      );
      expect(
        performance.seconds,
        scenario == 'repetitions' ? null : savedSeconds ?? (timed ? 600 : 45),
      );
      expect(performance.reps, scenario == 'repetitions' ? 12 : null);
      if (scenario == 'new minutes' || scenario == 'saved minutes') {
        final writes = storage.writes.length;
        await tester.tap(
          find.descendant(of: footer, matching: find.byType(ElevatedButton)),
        );
        await tester.pumpAndSettle();
        if (scenario == 'new minutes') {
          await tester.tap(find.text(l10n.cancel));
        } else {
          Navigator.of(tester.element(find.byType(AlertDialog))).pop();
        }
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(storage.writes.length, writes);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await queue.events.close();
      await sl.reset();
    });
  }
  test('circuit exercise completion reuses its durable identity and payload after restart', () async {
    final saved = <String, Map<String, dynamic>>{};
    final first = snapshotCircuitCompletion(saved, 'exercise-a',
      sets: [{'set_number': 1, 'reps': 10}], weightUsed: 20,
      feedbackId: 'video-a');
    final storage = _CircuitStorage();
    await persistCircuitState(storage, 'circuit', storage.sessionStamp,
      {'completion_actions': saved});
    final restored = jsonDecode(jsonEncode(storage.writes.single)) as Map;
    final restoredActions = restored['completion_actions'] as Map;
    final restarted = <String, Map<String, dynamic>>{
      for (final entry in restoredActions.entries)
        entry.key as String: Map<String, dynamic>.from(entry.value as Map),
    };
    final retry = snapshotCircuitCompletion(restarted, 'exercise-a',
      sets: [{'set_number': 1, 'reps': 99}], weightUsed: 90,
      feedbackId: 'video-b');
    expect(retry, first);
    expect(retry['operation_id'], isNotEmpty);
    expect(retry['sets'], [{'set_number': 1, 'reps': 10}]);
    final other = snapshotCircuitCompletion(restarted, 'exercise-b',
      sets: [{'set_number': 1, 'seconds': 30}]);
    expect(other['operation_id'], isNot(first['operation_id']));
  });

  test('A circuit cannot persist into B after an account generation change', () async {
    final storage = _CircuitStorage();
    final owner = storage.sessionStamp;
    await persistCircuitState(storage, 'active_circuit:exercise', owner,
      {'round': 1});
    storage.stamp = 'B:2:test';
    await persistCircuitState(storage, 'active_circuit:exercise', owner,
      {'round': 2});
    expect(storage.writes, [{'round': 1}]);
  });

  test(
    'restores live circuit feedback states and drops discarded references',
    () {
      final feedbackIds = <String, String>{
        'exercise-live': 'feedback-live',
        'exercise-stale': 'feedback-stale',
        'exercise-complete': 'feedback-complete',
        'exercise-legacy': 'feedback-legacy',
      };
      final storedStatuses = <String, String>{
        'exercise-live': 'uploading',
        'exercise-stale': 'failed',
        'exercise-complete': 'completed',
      };

      final restored = restoreCircuitFeedbackStatuses(
        feedbackIds,
        storedStatuses,
        (id) => id == 'feedback-live' ? 'failed' : null,
      );

      expect(restored, {
        'exercise-live': 'failed',
        'exercise-complete': 'completed',
        'exercise-legacy': 'completed',
      });
      expect(feedbackIds, {
        'exercise-live': 'feedback-live',
        'exercise-complete': 'feedback-complete',
        'exercise-legacy': 'feedback-legacy',
      });
    },
  );
}

class _CircuitStorage extends LocalStorage {
  String stamp = 'A:1:test';
  final List<Map<String, dynamic>> writes = [];
  Map<String, dynamic>? restored;

  @override
  Map<String, dynamic>? getCachedMap(String key) => restored;

  @override
  String? get sessionStamp => stamp;

  @override
  Future<void> cacheData(String key, dynamic value) async {
    writes.add(Map<String, dynamic>.from(value as Map));
  }
}

class _Auth extends Fake implements FirebaseAuthService {
  @override
  User? get currentUser => null;
}

class _Queue extends Fake implements FeedbackUploadQueueService {
  final events = StreamController<FeedbackUploadNotice>.broadcast();
  @override
  Stream<FeedbackUploadNotice> get notices => events.stream;
}

class _Bloc extends Fake implements TrainingBloc {}
