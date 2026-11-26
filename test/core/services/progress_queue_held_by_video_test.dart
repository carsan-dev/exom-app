// COLA: a same-day progress action held by a last-set video that is not
// confirmed (failed or still pending) must not hold independent progress of
// the same day (other trainings, meals). Regression for COLA-RETENIDA plus the
// interleavings of the overtaking rule, against a fake API that enforces the
// server contract: exact day revision (409 PROGRESS_VERSION_CONFLICT) and
// durable receipts per operation id whose payload hash excludes the revision.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'offline_sync_service_test.dart' show respondingClient;

const day = '2026-11-26';
const ownerA = LocalAuthSession(uid: 'owner-a', generation: 1);
const ownerB = LocalAuthSession(uid: 'owner-b', generation: 2);

typedef Sent = ({
  String id,
  Object? revision,
  String path,
  String outcome,
  Object? expectedOwner,
  String session,
});

/// Fake progress API with the server rules of `progress.service.ts`
/// (`withLockedDayProgress`) and `progress-command.ts`: one revision per
/// (client, date); a known operation id answers from its receipt (same
/// payload) without applying twice; otherwise the revision must match.
class StrictProgressApi {
  StrictProgressApi(this.currentSession);

  final String Function() currentSession;
  final revisions = <String, Map<String, int>>{};
  final receipts = <String, ({String hash, String date, int revision})>{};
  final applied = <String>[];
  final sent = <Sent>[];

  /// Operation ids whose next request is applied but whose response is lost.
  final loseResponse = <String>{};

  /// Called before handling a request (to snapshot the queue or switch user).
  void Function(String id)? beforeHandle;

  int revisionOf(String owner, String date) => revisions[owner]?[date] ?? 0;

  void bumpFromOtherDevice(String owner, String date) {
    revisions.putIfAbsent(owner, () => {})[date] = revisionOf(owner, date) + 1;
  }

  ApiClient client() => respondingClient((options, handler) {
    final id = options.headers['x-exom-operation-id'] as String;
    beforeHandle?.call(id);
    final owner = options.extra['exom.auth.expectedOwner'] as String;
    final revision = options.headers['x-exom-revision'] as int;
    final data = options.data is Map ? options.data as Map : const {};
    final date =
        (data['date'] ?? options.queryParameters['date']) as String;
    final hash = jsonEncode({
      'method': options.method,
      'path': options.path,
      'data': options.data,
      'query': options.queryParameters,
    });
    void record(String outcome) => sent.add((
      id: id,
      revision: revision,
      path: options.path,
      outcome: outcome,
      expectedOwner: owner,
      session: currentSession(),
    ));
    Response<dynamic> ok(int operationRevision) => Response(
      requestOptions: options,
      statusCode: 200,
      data: {
        'date': date,
        'sync_revision': revisionOf(owner, date),
        'operation_revision': operationRevision,
        'exercises_completed': <Map<String, dynamic>>[],
        'meals_completed': <String>[],
      },
    );
    final receiptKey = '$owner/$id';
    final receipt = receipts[receiptKey];
    if (receipt != null) {
      if (receipt.hash != hash || receipt.date != date) {
        record('409 operation');
        handler.reject(_conflict(options, 'PROGRESS_OPERATION_CONFLICT'));
        return;
      }
      record('receipt');
      handler.resolve(ok(receipt.revision));
      return;
    }
    final current = revisionOf(owner, date);
    if (current != revision) {
      record('409 version');
      handler.reject(_conflict(options, 'PROGRESS_VERSION_CONFLICT',
          current: current, date: date));
      return;
    }
    final next = current + 1;
    revisions.putIfAbsent(owner, () => {})[date] = next;
    receipts[receiptKey] = (hash: hash, date: date, revision: next);
    applied.add(id);
    if (loseResponse.remove(id)) {
      record('applied, response lost');
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      ));
      return;
    }
    record('applied');
    handler.resolve(ok(next));
  });

  DioException _conflict(RequestOptions options, String code,
      {int? current, String? date}) {
    return DioException.badResponse(
      statusCode: 409,
      requestOptions: options,
      response: Response(requestOptions: options, statusCode: 409, data: {
        'code': code,
        'current_revision': ?current,
        if (current != null)
          'current_progress': {
            'date': date,
            'sync_revision': current,
            'exercises_completed': <Map<String, dynamic>>[],
            'meals_completed': <String>[],
          },
      }),
    );
  }
}

class Harness {
  Harness._(this.directory);

  final Directory directory;
  LocalAuthSession session = ownerA;
  bool authenticated = true;
  late LocalStorage store;
  late StrictProgressApi api;
  late OfflineSyncService sync;

  static Future<Harness> open() async {
    // A failed earlier test may leave its box open.
    await Hive.close();
    final directory = await Directory.systemTemp.createTemp('exom-cola-');
    Hive.init(directory.path);
    await Hive.openBox('cache_box');
    final harness = Harness._(directory);
    harness.store = LocalStorage(currentSession: () => harness.session);
    harness.api = StrictProgressApi(() => harness.session.uid);
    harness.sync = harness.service();
    return harness;
  }

  OfflineSyncService service() => OfflineSyncService(
    api.client(),
    store,
    isAuthenticated: () => authenticated,
    authenticationChanges: const Stream<bool>.empty(),
    connectivityChanges: const Stream<bool>.empty(),
  );

  /// Process restart: a new service over the same Hive files.
  Future<void> restart() async {
    await sync.dispose();
    await Hive.close();
    await Hive.openBox('cache_box');
    store = LocalStorage(currentSession: () => session);
    sync = service();
  }

  Future<void> close() async {
    await sync.dispose();
    await Hive.close();
  }

  Future<void> video(String id, String status, {String training = 'training-circuit'}) async {
    final queue = store.getFeedbackUploadQueue()
      ..removeWhere((row) => row['id'] == id);
    queue.add({
      'id': id,
      'status': status,
      ...store.queueIdentity,
      if (status == 'failed') 'last_error': 'file_missing',
      'training_id': training,
      'assignment_date': day,
    });
    await store.saveFeedbackUploadQueue(queue);
  }

  /// Retry delay elapsed (`next_attempt_at` reached).
  Future<void> elapse() async {
    await store.savePendingSyncActions([
      for (final action in store.getPendingSyncActions())
        Map<String, dynamic>.from(action)..remove('next_attempt_at'),
    ]);
  }

  Map<String, dynamic> action(String key, String value) =>
      store.getPendingSyncActions().singleWhere((a) => a[key] == value);

  List<String> get sentIds => api.sent.map((s) => s.id).toList();
}

/// The COLA-RETENIDA scenario: circuit member with its mandatory last-set
/// video, then an exercise of ANOTHER training and a meal, same day.
Future<Harness> retained({
  required String videoStatus,
  String? sentadillaTraining = 'training-video-a',
}) async {
  final h = await Harness.open();
  // Offline while recording: nothing is sent before the test syncs.
  h.authenticated = false;
  await h.video('fb-burpees', videoStatus);
  await h.sync.queueExerciseCompletion('te-burpees', day,
      completed: true,
      exerciseId: 'ex-burpees',
      trainingId: 'training-circuit',
      lastSetFeedbackClientUploadId: 'fb-burpees',
      operationId: 'op-burpees');
  await h.sync.queueExerciseCompletion('te-sentadilla', day,
      completed: true,
      exerciseId: 'ex-sentadilla',
      trainingId: sentadillaTraining,
      operationId: 'op-sentadilla');
  await h.sync.queueMealCompletion('meal-1', day, completed: true);
  h.authenticated = true;
  return h;
}

String mealId(Harness h) => h.action('meal_id', 'meal-1')['id'] as String;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final status in ['failed', 'queued']) {
    test('a $status last-set video no longer holds independent same-day '
        'progress, and the held action is sent later without 409', () async {
      final h = await retained(videoStatus: status);
      final meal = mealId(h);
      await h.sync.syncPendingActions();
      await h.sync.syncPendingActions(); // second wake (timer / reconnect)
      expect(h.sentIds, ['op-sentadilla', meal]);
      expect(h.api.sent.map((s) => s.revision), [0, 1]);
      final burpees = h.action('id', 'op-burpees');
      expect(burpees['status'], 'queued');
      expect(burpees['attempts'], 0);
      expect(burpees['expected_revision'], 2,
          reason: 'the revision confirmed for the day reaches the held action');
      expect(h.store.getPendingSyncActions(), hasLength(1));

      await h.video('fb-burpees', 'completed');
      await h.sync.syncPendingActions();
      expect(h.sentIds, ['op-sentadilla', meal, 'op-burpees']);
      expect(h.api.sent.map((s) => s.outcome), everyElement('applied'));
      expect(h.api.sent.last.revision, 2);
      expect(h.api.revisionOf('owner-a', day), 3);
      expect(h.store.getPendingSyncActions(), isEmpty);
      await h.close();
    });
  }

  test('control: once the video is completed everything goes in queue order',
      () async {
    final h = await retained(videoStatus: 'completed');
    final meal = mealId(h);
    await h.sync.syncPendingActions();
    expect(h.sentIds, ['op-burpees', 'op-sentadilla', meal]);
    expect(h.api.sent.map((s) => s.revision), [0, 1, 2]);
    await h.close();
  });

  test('control: work of another date never waited for the video', () async {
    final h = await Harness.open();
    h.authenticated = false;
    await h.video('fb-burpees', 'failed');
    await h.sync.queueExerciseCompletion('te-burpees', day,
        completed: true,
        exerciseId: 'ex-burpees',
        trainingId: 'training-circuit',
        lastSetFeedbackClientUploadId: 'fb-burpees',
        operationId: 'op-burpees');
    await h.sync.queueExerciseCompletion('te-sentadilla', '2026-11-27',
        completed: true,
        exerciseId: 'ex-sentadilla',
        trainingId: 'training-video-a',
        operationId: 'op-sentadilla');
    h.authenticated = true;
    await h.sync.syncPendingActions();
    expect(h.sentIds, ['op-sentadilla']);
    expect(h.api.sent.single.revision, 0);
    expect(h.action('id', 'op-burpees')['expected_revision'], 0,
        reason: 'another date has its own revision');
    await h.close();
  });

  test('work of the held training stays behind it; the other training '
      'completion is not blocked', () async {
    final h = await retained(videoStatus: 'failed');
    final meal = mealId(h);
    await h.sync.queueExerciseCompletion('te-jump', day,
        completed: true,
        exerciseId: 'ex-jump',
        trainingId: 'training-circuit',
        operationId: 'op-jump');
    await h.sync.queueTrainingCompletion(day, trainingId: 'training-circuit');
    await h.sync.queueTrainingCompletion(day, trainingId: 'training-video-a');
    expect(
        h.sync.completionBlocker('training-video-a', day, null), isNull);
    expect(h.sync.completionBlocker('training-circuit', day, null)?.kind,
        CompletionSyncBlockerKind.feedbackFailed);
    await h.sync.syncPendingActions();
    final circuitCompletion = h.store.getPendingSyncActions().singleWhere(
        (a) => a['type'] == 'complete_training' &&
            a['training_id'] == 'training-circuit')['id'];
    expect(h.sentIds, hasLength(3));
    expect(h.sentIds.take(2), ['op-sentadilla', meal]);
    expect(h.api.sent.map((s) => s.outcome), everyElement('applied'));
    expect(
        h.store.getPendingSyncActions().map((a) => a['id']),
        ['op-burpees', 'op-jump', circuitCompletion]);

    await h.video('fb-burpees', 'completed');
    await h.sync.syncPendingActions();
    expect(h.sentIds.skip(3), ['op-burpees', 'op-jump', circuitCompletion]);
    expect(h.api.sent.map((s) => s.outcome), everyElement('applied'));
    expect(h.store.getPendingSyncActions(), isEmpty);
    await h.close();
  });

  test('legacy actions without a training keep strict day order', () async {
    final h = await retained(videoStatus: 'failed', sentadillaTraining: null);
    final meal = mealId(h);
    await h.sync.syncPendingActions();
    // The meal may overtake (independent of any exercise); the exercise of an
    // unknown training may not, and stays behind the held circuit action.
    expect(h.sentIds, [meal]);
    expect(h.action('id', 'op-sentadilla')['status'], 'queued');
    await h.video('fb-burpees', 'completed');
    await h.sync.syncPendingActions();
    expect(h.sentIds.skip(1), ['op-burpees', 'op-sentadilla']);
    expect(h.api.sent.map((s) => s.outcome), everyElement('applied'));
    await h.close();
  });

  test('a later action based on another revision keeps strict order', () async {
    final h = await Harness.open();
    await h.video('fb-burpees', 'failed');
    await h.sync.queueExerciseCompletion('te-burpees', day,
        completed: true,
        exerciseId: 'ex-burpees',
        trainingId: 'training-circuit',
        lastSetFeedbackClientUploadId: 'fb-burpees',
        operationId: 'op-burpees');
    // A refresh pulled a newer day revision (another device) before this one.
    await h.store.cacheData('day_progress_$day', {
      'date': day,
      'sync_revision': 5,
      'exercises_completed': <Map<String, dynamic>>[],
      'meals_completed': <String>[],
    });
    await h.sync.queueExerciseCompletion('te-sentadilla', day,
        completed: true,
        exerciseId: 'ex-sentadilla',
        trainingId: 'training-video-a',
        operationId: 'op-sentadilla');
    await h.sync.syncPendingActions();
    expect(h.sentIds, isEmpty);
    await h.close();
  });

  test('lost response of the overtaking action: the held one never goes '
      'first, and the retry resolves by receipt', () async {
    final h = await retained(videoStatus: 'failed');
    final meal = mealId(h);
    h.api.loseResponse.add('op-sentadilla');
    await h.sync.syncPendingActions();
    expect(h.sentIds, ['op-sentadilla']);
    expect(h.api.applied, ['op-sentadilla']);
    expect(h.action('id', 'op-sentadilla')['attempts'], 1);

    await h.video('fb-burpees', 'completed');
    await h.sync.syncPendingActions();
    expect(h.sentIds, ['op-sentadilla'],
        reason: 'the circuit action must wait for the unconfirmed overtaker');

    await h.elapse();
    await h.sync.syncPendingActions();
    expect(h.sentIds, ['op-sentadilla', 'op-sentadilla', 'op-burpees', meal]);
    expect(h.api.sent.map((s) => s.outcome),
        ['applied, response lost', 'receipt', 'applied', 'applied']);
    expect(h.api.sent.map((s) => s.revision), [0, 0, 1, 2]);
    expect(h.api.applied, ['op-sentadilla', 'op-burpees', meal]);
    expect(h.store.getPendingSyncActions(), isEmpty);
    await h.close();
  });

  test('crash after the server confirmed the overtaker and before the local '
      'acknowledgement replays it by receipt after restart', () async {
    final h = await retained(videoStatus: 'failed');
    final meal = mealId(h);
    List<Map<String, dynamic>>? atCommit;
    h.api.beforeHandle = (id) {
      if (id == 'op-sentadilla' && atCommit == null) {
        // Persisted state while the request is in flight; the process dies
        // once the server has committed (nothing else runs afterwards).
        atCommit = h.store.getPendingSyncActions();
        h.authenticated = false;
      }
    };
    await h.sync.syncPendingActions();
    expect(h.api.applied, ['op-sentadilla']);
    expect(atCommit!.singleWhere((a) => a['id'] == 'op-sentadilla')['status'],
        'uploading');
    // The acknowledgement (and its revision propagation, the same queue
    // write) never reached the disk.
    await h.store.savePendingSyncActions(atCommit!);
    h.authenticated = true;
    await h.video('fb-burpees', 'completed');
    await h.restart();
    await h.sync.syncPendingActions();
    expect(h.sentIds, ['op-sentadilla', 'op-sentadilla', 'op-burpees', meal]);
    expect(h.api.sent.map((s) => s.outcome),
        ['applied', 'receipt', 'applied', 'applied']);
    expect(h.api.sent.map((s) => s.revision), [0, 0, 1, 2]);
    expect(h.api.applied, ['op-sentadilla', 'op-burpees', meal]);
    expect(h.api.sent.where((s) => s.outcome.startsWith('409')), isEmpty);
    expect(h.store.getPendingSyncActions(), isEmpty);
    await h.close();
  });

  test('crash after claiming the overtaker and before sending it does not '
      'deadlock once the held video completes', () async {
    final h = await retained(videoStatus: 'failed');
    final meal = mealId(h);
    List<Map<String, dynamic>>? claimed;
    h.api.beforeHandle = (id) {
      if (id == 'op-sentadilla' && claimed == null) {
        claimed = h.store.getPendingSyncActions();
      }
    };
    await h.sync.syncPendingActions();
    // Roll the device and server back to "claimed, never sent".
    await h.store.savePendingSyncActions(claimed!);
    h.api
      ..revisions.clear()
      ..receipts.clear()
      ..applied.clear()
      ..sent.clear()
      ..beforeHandle = null;
    await h.video('fb-burpees', 'completed');
    await h.restart();
    await h.sync.syncPendingActions();
    expect(h.sentIds, ['op-sentadilla', 'op-burpees', meal]);
    expect(h.api.sent.map((s) => s.revision), [0, 1, 2]);
    expect(h.api.sent.map((s) => s.outcome), everyElement('applied'));
    expect(h.store.getPendingSyncActions(), isEmpty);
    await h.close();
  });

  test('a real 409 on the overtaker stops the day without sending the held '
      'action', () async {
    final h = await retained(videoStatus: 'failed');
    h.api.bumpFromOtherDevice('owner-a', day);
    await h.sync.syncPendingActions();
    expect(h.sentIds, ['op-sentadilla']);
    expect(h.api.sent.single.outcome, '409 version');
    final sentadilla = h.action('id', 'op-sentadilla');
    expect(sentadilla['status'], 'failed');
    expect(sentadilla['last_error'], 'progress_conflict_review_required');
    await h.video('fb-burpees', 'completed');
    await h.sync.syncPendingActions();
    expect(h.sentIds, ['op-sentadilla'],
        reason: 'nothing else of the day is sent behind a real conflict');
    expect(h.api.applied, isEmpty);
    await h.close();
  });

  test('account switch while the overtaker is in flight: no work of A is '
      'acknowledged or sent under B, A resumes by receipt', () async {
    final h = await retained(videoStatus: 'failed');
    final meal = mealId(h);
    h.api.beforeHandle = (id) {
      if (id == 'op-sentadilla' && h.session == ownerA) h.session = ownerB;
    };
    await h.sync.syncPendingActions();
    expect(h.sentIds, ['op-sentadilla']);
    expect(h.store.getPendingSyncActions(), isEmpty, reason: 'B sees nothing');
    await h.sync.syncPendingActions(); // B's own sync
    expect(h.sentIds, ['op-sentadilla']);

    h.api.beforeHandle = null;
    h.session = const LocalAuthSession(uid: 'owner-a', generation: 3);
    await h.restart();
    expect(h.action('id', 'op-sentadilla')['status'], 'uploading',
        reason: 'the acknowledgement under B was refused');
    await h.sync.syncPendingActions();
    expect(h.sentIds, ['op-sentadilla', 'op-sentadilla', meal]);
    expect(h.api.sent.map((s) => s.outcome), ['applied', 'receipt', 'applied']);
    expect(h.api.sent.map((s) => s.expectedOwner), everyElement('owner-a'));
    expect(h.api.sent.skip(1).map((s) => s.session), everyElement('owner-a'));
    expect(h.action('id', 'op-burpees')['expected_revision'], 2);
    await h.close();
  });

  test('a duplicate enqueue of the same operation is one action and one '
      'server write', () async {
    final h = await retained(videoStatus: 'failed');
    await h.sync.queueExerciseCompletion('te-sentadilla', day,
        completed: true,
        exerciseId: 'ex-sentadilla',
        trainingId: 'training-video-a',
        operationId: 'op-sentadilla');
    expect(h.store.getPendingSyncActions()
        .where((a) => a['id'] == 'op-sentadilla'), hasLength(1));
    await h.sync.syncPendingActions();
    await h.sync.syncPendingActions();
    expect(h.api.applied.where((id) => id == 'op-sentadilla'), hasLength(1));
    await h.close();
  });

  test('persisted chain after overtaking stays strict-order coherent for an '
      'older build', () async {
    final h = await retained(videoStatus: 'failed');
    final meal = mealId(h);
    h.api.loseResponse.add(meal);
    await h.sync.syncPendingActions();
    // Sentadilla acknowledged; the meal (second overtaker) is unconfirmed.
    await h.elapse();
    await h.sync.syncPendingActions();
    final queue = h.store.getPendingSyncActions();
    expect(queue.map((a) => a['id']), ['op-burpees']);
    expect(queue.single.containsKey('predecessor_id'), isFalse);
    expect(queue.single['expected_revision'], h.api.revisionOf('owner-a', day));
    await h.close();

    // Same shape after a single overtake with work left on both sides.
    final g = await Harness.open();
    await g.video('fb-burpees', 'failed');
    await g.sync.queueExerciseCompletion('te-burpees', day,
        completed: true, exerciseId: 'ex-burpees',
        trainingId: 'training-circuit',
        lastSetFeedbackClientUploadId: 'fb-burpees', operationId: 'op-burpees');
    await g.sync.queueExerciseCompletion('te-sentadilla', day,
        completed: true, exerciseId: 'ex-sentadilla',
        trainingId: 'training-video-a', operationId: 'op-sentadilla');
    await g.sync.queueExerciseCompletion('te-jump', day,
        completed: true, exerciseId: 'ex-jump',
        trainingId: 'training-circuit', operationId: 'op-jump');
    await g.sync.syncPendingActions();
    final left = g.store.getPendingSyncActions();
    expect(left.map((a) => a['id']), ['op-burpees', 'op-jump']);
    expect(left.first.containsKey('predecessor_id'), isFalse);
    expect(left.last['predecessor_id'], 'op-burpees');
    expect(left.map((a) => a['expected_revision']), everyElement(1));
    await g.close();
  });

  test('deleting the held action (never sent) does not turn the rest of the '
      'day into conflicts', () async {
    final h = await retained(videoStatus: 'failed');
    final meal = mealId(h);
    await h.sync.discardAction('op-burpees');
    for (final a in h.store.getPendingSyncActions()) {
      expect(a['status'], 'queued');
      expect(a['last_error'], isNull);
    }
    await h.sync.syncPendingActions();
    expect(h.sentIds, ['op-sentadilla', meal]);
    expect(h.store.getPendingSyncActions(), isEmpty);
    await h.close();
  });

  test('deleting an action that may have reached the server still marks the '
      'rest of the day for review', () async {
    final h = await retained(videoStatus: 'failed');
    final meal = mealId(h);
    h.api.loseResponse.add('op-sentadilla');
    await h.sync.syncPendingActions();
    expect(h.action('id', 'op-sentadilla')['attempts'], 1);
    await h.sync.discardAction('op-sentadilla');
    expect(h.store.getPendingSyncActions().map((a) => a['id']),
        ['op-burpees', meal]);
    expect(h.action('id', meal)['last_error'],
        'progress_conflict_review_required');
    expect(h.action('id', 'op-burpees')['status'], 'queued');
    // The held action was before it and never sent: the server decides it.
    expect(h.action('id', 'op-burpees')['last_error'], isNull);
    await h.close();
  });

  test('an action failed because its video was discarded does not hold '
      'independent work', () async {
    final h = await retained(videoStatus: 'failed');
    final meal = mealId(h);
    await h.sync.removeActionsDependingOnFeedback('fb-burpees');
    expect(h.action('id', 'op-burpees')['last_error'], 'feedback_discarded');
    await h.sync.syncPendingActions();
    expect(h.sentIds, ['op-sentadilla', meal]);
    expect(h.store.getPendingSyncActions().map((a) => a['id']), ['op-burpees']);
    await h.close();
  });
}
