import 'dart:convert';

import 'package:exom_app/features/trainings/presentation/pages/active_circuit_page.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  @override
  String? get sessionStamp => stamp;

  @override
  Future<void> cacheData(String key, dynamic value) async {
    writes.add(Map<String, dynamic>.from(value as Map));
  }
}
