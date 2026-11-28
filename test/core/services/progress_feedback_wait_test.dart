// COLA (option A): the reason a queued progress action waits for a video,
// read by «Subidas pendientes».
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progress_queue_held_by_video_test.dart' show Harness, day, retained;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('own video, behind a video, or no video wait', () async {
    final h = await retained(videoStatus: 'failed');
    await h.sync.queueExerciseCompletion('te-jump', day,
        completed: true,
        exerciseId: 'ex-jump',
        trainingId: 'training-circuit',
        operationId: 'op-jump');
    expect(h.sync.feedbackWaitOf(h.action('id', 'op-burpees')),
        ProgressFeedbackWait.ownVideo);
    expect(h.sync.feedbackWaitOf(h.action('id', 'op-jump')),
        ProgressFeedbackWait.behindVideo);
    expect(h.sync.feedbackWaitOf(h.action('id', 'op-sentadilla')), isNull);
    expect(h.sync.feedbackWaitOf(h.action('meal_id', 'meal-1')), isNull);
    await h.video('fb-burpees', 'completed');
    expect(h.sync.feedbackWaitOf(h.action('id', 'op-burpees')), isNull);
    expect(h.sync.feedbackWaitOf(h.action('id', 'op-jump')), isNull);
    await h.close();
  });
  test('behind a video of an unknown training: the generic wait', () async {
    // An exercise without a training (earlier builds) behind the held one.
    final h = await retained(videoStatus: 'failed', sentadillaTraining: null);
    expect(h.sync.feedbackWaitOf(h.action('id', 'op-sentadilla')),
        ProgressFeedbackWait.behindDayVideo);
    await h.close();

    // A held exercise of an unknown training holds one of a known training.
    final g = await Harness.open();
    g.authenticated = false;
    await g.video('fb-old', 'failed');
    await g.sync.queueExerciseCompletion('te-old', day,
        completed: true,
        exerciseId: 'ex-old',
        lastSetFeedbackClientUploadId: 'fb-old',
        operationId: 'op-old');
    await g.sync.queueExerciseCompletion('te-jump', day,
        completed: true,
        exerciseId: 'ex-jump',
        trainingId: 'training-circuit',
        operationId: 'op-jump');
    expect(g.sync.feedbackWaitOf(g.action('id', 'op-old')),
        ProgressFeedbackWait.ownVideo);
    expect(g.sync.feedbackWaitOf(g.action('id', 'op-jump')),
        ProgressFeedbackWait.behindDayVideo);
    await g.close();
  });
}
