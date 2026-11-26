// COLA r2 (D1): only a claim may record an overtaking. A `predecessor_id`
// that names a later queue entry for any other reason (a deleted action that
// is queued again with the same operation id, a link persisted by an earlier
// build) must keep the strict day order: nothing of the day goes ahead of an
// action that is not provably held by a video, nor behind a conflict.
import 'package:flutter_test/flutter_test.dart';

import 'progress_queue_held_by_video_test.dart' show Harness, day;

Future<void> uploadRow(Harness h, String id, String status) async {
  final queue = h.store.getFeedbackUploadQueue()
    ..removeWhere((row) => row['id'] == id);
  queue.add({
    'id': id,
    'status': status,
    ...h.store.queueIdentity,
    if (status == 'failed') 'last_error': 'file_missing',
    'training_id': 'training-circuit',
    'assignment_date': day,
    'training_session_id': 's1',
  });
  await h.store.saveFeedbackUploadQueue(queue);
}

/// `predecessor_id` links that name a later entry of the queue.
List<String> forwardLinks(List<Map<String, dynamic>> queue) => [
  for (var index = 0; index < queue.length; index++)
    if (queue
        .skip(index + 1)
        .any((later) => later['id'] == queue[index]['predecessor_id']))
      '${queue[index]['id']} -> ${queue[index]['predecessor_id']}',
];

String completionId(Harness h) => h.store
    .getPendingSyncActions()
    .singleWhere((a) => a['type'] == 'complete_training')['id'] as String;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('P1 a deleted training completion queued again does not overtake the '
      'conflict-marked successor (strict order behind a conflict)', () async {
    final h = await Harness.open();
    h.authenticated = false;
    await h.sync.queueTrainingCompletion(day,
        trainingId: 'training-circuit', sessionId: 's1');
    await h.sync.queueMealCompletion('meal-1', day, completed: true);
    final completion = completionId(h);
    await h.sync.discardAction(completion);
    final meal = h.action('meal_id', 'meal-1');
    expect(meal['last_error'], 'progress_conflict_review_required');
    expect(meal['predecessor_id'], isNot(completion),
        reason: 'no entry keeps naming the deleted action');
    await h.sync.queueTrainingCompletion(day,
        trainingId: 'training-circuit', sessionId: 's1');
    final queue = h.store.getPendingSyncActions();
    expect(queue.map((a) => a['id']), [meal['id'], completion],
        reason: 'the restored completion keeps its operation id, at the end');
    expect(forwardLinks(queue), isEmpty);
    expect(queue.last['predecessor_id'], meal['id']);
    h.authenticated = true;
    await h.sync.syncPendingActions();
    expect(h.sentIds, isEmpty,
        reason: 'nothing of the day goes behind a conflict-marked action');
    await h.close();
  });

  test('P2 E + queue the completion again while its video is still failed: '
      'the meal is sent and no forward link is left', () async {
    final h = await Harness.open();
    h.authenticated = false;
    await uploadRow(h, 'fb-c', 'failed');
    await h.sync.queueTrainingCompletion(day,
        trainingId: 'training-circuit', sessionId: 's1');
    await h.sync.queueMealCompletion('meal-1', day, completed: true);
    final completion = completionId(h);
    expect(h.action('id', completion)['depends_on_feedback_ids'], ['fb-c']);
    await h.sync.discardAction(completion);
    final meal = h.action('meal_id', 'meal-1');
    expect(meal['status'], 'queued');
    expect(meal.containsKey('predecessor_id'), isFalse,
        reason: 'the deleted action was the head of the day');
    await h.sync.queueTrainingCompletion(day,
        trainingId: 'training-circuit', sessionId: 's1');
    expect(forwardLinks(h.store.getPendingSyncActions()), isEmpty);
    h.authenticated = true;
    await h.sync.syncPendingActions();
    expect(h.api.sent.map((s) => s.path), ['/progress/meals/complete']);
    expect(h.store.getPendingSyncActions().map((a) => a['id']), [completion]);
    await h.close();
  });

  test('P3 a deleted exercise completion queued again with the same '
      'operation id keeps the strict order', () async {
    final h = await Harness.open();
    h.authenticated = false;
    await h.sync.queueExerciseCompletion('te-sentadilla', day,
        completed: true,
        exerciseId: 'ex-sentadilla',
        trainingId: 'training-video-a',
        operationId: 'op-sentadilla');
    await h.sync.queueMealCompletion('meal-1', day, completed: true);
    await h.sync.discardAction('op-sentadilla');
    await h.sync.queueExerciseCompletion('te-sentadilla', day,
        completed: true,
        exerciseId: 'ex-sentadilla',
        trainingId: 'training-video-a',
        operationId: 'op-sentadilla');
    expect(forwardLinks(h.store.getPendingSyncActions()), isEmpty);
    h.authenticated = true;
    await h.sync.syncPendingActions();
    expect(h.sentIds, isEmpty);
    await h.close();
  });

  test('a link persisted by an earlier build that names an id queued again '
      'is released, so the re-queued action keeps the strict order',
      () async {
    final h = await Harness.open();
    h.authenticated = false;
    await h.sync.queueMealCompletion('meal-1', day, completed: true);
    final meal = h.action('meal_id', 'meal-1');
    // Earlier builds left the successor of a deleted action naming it.
    await h.store.savePendingSyncActions([
      {...meal, 'predecessor_id': 'op-sentadilla'},
    ]);
    await h.sync.queueExerciseCompletion('te-sentadilla', day,
        completed: true,
        exerciseId: 'ex-sentadilla',
        trainingId: 'training-video-a',
        operationId: 'op-sentadilla');
    expect(forwardLinks(h.store.getPendingSyncActions()), isEmpty);
    h.authenticated = true;
    await h.sync.syncPendingActions();
    expect(h.sentIds, [meal['id'], 'op-sentadilla']);
    expect(h.api.sent.map((s) => s.revision), [0, 1]);
    await h.close();
  });

  for (final state in <String, Map<String, Object?>>{
    'conflict-marked': {
      'status': 'failed',
      'last_error': 'progress_conflict_review_required',
    },
    'already attempted': {'status': 'queued', 'attempts': 1},
  }.entries) {
    test('a forward link from a ${state.key} action is not an overtaking '
        'record', () async {
      final h = await Harness.open();
      h.authenticated = false;
      await h.sync.queueMealCompletion('meal-1', day, completed: true);
      await h.sync.queueExerciseCompletion('te-sentadilla', day,
          completed: true,
          exerciseId: 'ex-sentadilla',
          trainingId: 'training-video-a',
          operationId: 'op-sentadilla');
      final queue = h.store.getPendingSyncActions();
      // Whatever path wrote it, the earlier action names the later one.
      await h.store.savePendingSyncActions([
        {...queue.first, ...state.value, 'predecessor_id': 'op-sentadilla'},
        queue.last,
      ]);
      h.authenticated = true;
      await h.sync.syncPendingActions();
      if (state.value['status'] == 'failed') {
        expect(h.sentIds, isEmpty);
      } else {
        expect(h.sentIds, [queue.first['id'], 'op-sentadilla'],
            reason: 'the earlier action that may have reached the server '
                'goes first');
      }
      await h.close();
    });
  }
}
