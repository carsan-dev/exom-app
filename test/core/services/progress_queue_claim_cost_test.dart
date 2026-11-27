// COLA r2 (R4): cost of the overtaking rule on large persisted queues. Worst
// case for a claim pass: every day starts with an action held by its video
// and the rest of the day is work of the same training, so every candidate is
// examined and none can be claimed (each day head is claimed and returned,
// as with the strict rule). Figures are written to stdout. The bound only
// catches a return to the cubic scan (3.4 s for 500 actions in 10 days before
// R4, 0.15 s after, as with the strict rule alone), not machine speed.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'progress_queue_held_by_video_test.dart' show Harness;

const _budget = Duration(seconds: 2);

Future<Harness> _queue({required int actions, required int days}) async {
  final h = await Harness.open();
  h.authenticated = false;
  await h.video('fb-held', 'failed');
  final queue = <Map<String, dynamic>>[];
  final perDay = actions ~/ days;
  for (var d = 0; d < days; d++) {
    final date = '2026-11-${(d + 1).toString().padLeft(2, '0')}';
    String? previous;
    for (var i = 0; i < perDay; i++) {
      final id = 'op-$d-$i';
      queue.add({
        'type': 'mark_exercise_completed',
        'training_exercise_id': 'te-$d-$i',
        'exercise_id': 'ex-$i',
        'date': date,
        'training_id': 'training-circuit',
        if (i == 0) 'last_set_feedback_client_upload_id': 'fb-held',
        'expected_revision': 0,
        'predecessor_id': ?previous,
        ...h.store.queueIdentity,
        'id': id,
        'status': 'queued',
        'attempts': 0,
        'queued_at': DateTime.utc(2026, 11, d + 1, 8, 0, i).toIso8601String(),
      });
      previous = id;
    }
  }
  await h.store.savePendingSyncActions(queue);
  h.authenticated = true;
  return h;
}

Duration _median(List<Duration> runs) {
  final sorted = [...runs]..sort();
  return sorted[sorted.length ~/ 2];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in [
    (actions: 50, days: 1),
    (actions: 200, days: 1),
    (actions: 500, days: 1),
    (actions: 500, days: 10),
  ]) {
    test('claim pass over ${size.actions} actions in ${size.days} day(s)',
        () async {
      final h = await _queue(actions: size.actions, days: size.days);
      final passes = <Duration>[];
      for (var run = 0; run < 5; run++) {
        final watch = Stopwatch()..start();
        await h.sync.syncPendingActions();
        passes.add(watch.elapsed);
      }
      expect(h.sentIds, isEmpty, reason: 'every day waits for its video');

      final rows = h.sync.pendingActions;
      final watch = Stopwatch()..start();
      for (final row in rows) {
        h.sync.feedbackWaitOf(row);
      }
      final waits = watch.elapsed;

      final pass = _median(passes);
      stdout.writeln('R4 claim pass ${size.actions} actions/${size.days} '
          'day(s): median ${pass.inMicroseconds} us '
          '(runs ${passes.map((p) => p.inMicroseconds).join(', ')} us); '
          'feedbackWaitOf x${rows.length}: ${waits.inMicroseconds} us');
      expect(pass, lessThan(_budget));
      await h.close();
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}
