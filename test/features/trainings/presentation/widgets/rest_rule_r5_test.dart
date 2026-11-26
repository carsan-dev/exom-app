// L5-E3e, round r5: never two adjacent tall marks.
//
// When a duration is not a multiple of the step, the rule ends with a short
// section. If that section fits in a single slice, the mark closing the last
// whole step and the mark at the end of the rule were both tall and adjacent
// (39, 41, 61, 195, 241 s…). The end mark stays tall because it frames the
// rule; the mark before it becomes short. The boundary marker at 0 (round r4)
// and the tall marks on the other exact multiples of the step do not change.
import 'package:exom_app/features/trainings/presentation/widgets/rest_countdown.dart';
import 'package:flutter_test/flutter_test.dart';

/// Problems of the layout of [seconds]; empty when it is right.
List<String> _problems(int seconds) {
  final layout = RestTickLayout.forSeconds(seconds);
  final marks = layout.marks;
  final totalMs = seconds * 1000;
  final stepMs = layout.stepSeconds * 1000;
  final problems = <String>[];

  final first = marks.first;
  if (!(first.tall && first.startMs == 0 && first.endMs == 0)) {
    problems.add('no tall marker at 0');
  }
  if (!(marks.last.tall && marks.last.endMs == totalMs)) {
    problems.add('end mark not tall');
  }
  for (var i = 1; i < marks.length; i++) {
    if (marks[i].tall && marks[i - 1].tall) {
      problems.add('adjacent tall marks ${i - 1}-$i');
    }
  }
  for (var i = 1; i < marks.length - 1; i++) {
    final mark = marks[i];
    if (mark.tall && mark.endMs % stepMs != 0) {
      problems.add('inner tall mark $i off the step (${mark.endMs} ms)');
    }
    // Every other whole step stays tall; only the one right before the end
    // mark may give way to it.
    if (!mark.tall && mark.endMs % stepMs == 0 && i != marks.length - 2) {
      problems.add('whole step at ${mark.endMs} ms not tall');
    }
  }
  final expectedMin = seconds * 5 + 1 < 40 ? seconds * 5 + 1 : 40;
  if (marks.length > RestTickLayout.maxMarks || marks.length < expectedMin) {
    problems.add('${marks.length} marks (expected $expectedMin..60)');
  }
  return problems;
}

void main() {
  test('every duration of 1..3600 s: tall at 0 and at the end, inner tall '
      'marks on exact multiples of the step, never two adjacent, at most 60 '
      'marks', () {
    final failures = <String>[];
    for (var seconds = 1; seconds <= 3600; seconds++) {
      final problems = _problems(seconds);
      if (problems.isNotEmpty) failures.add('$seconds s: ${problems.join('; ')}');
    }
    expect(
      failures,
      isEmpty,
      reason: '${failures.length} durations fail:\n${failures.join('\n')}',
    );
  });

  test('the table rows keep their step, parts and marks', () {
    const rows = <int, List<int>>{
      10: [1, 5, 51],
      15: [1, 3, 46],
      20: [1, 2, 41],
      30: [2, 3, 46],
      40: [2, 2, 41],
      45: [5, 5, 46],
      47: [5, 5, 48],
      60: [5, 4, 49],
      90: [5, 3, 55],
      120: [10, 4, 49],
      180: [10, 3, 55],
      300: [15, 2, 41],
      600: [30, 2, 41],
      1440: [120, 4, 49],
      3600: [300, 4, 49],
    };
    rows.forEach((seconds, row) {
      final layout = RestTickLayout.forSeconds(seconds);
      expect(
        [layout.stepSeconds, layout.subdivisions, layout.marks.length],
        row,
        reason: '$seconds s',
      );
    });
  });

  test('39 s: the last whole step before a single short slice is short', () {
    final marks = RestTickLayout.forSeconds(39).marks;
    final last = marks[marks.length - 1];
    final before = marks[marks.length - 2];
    expect([last.startMs, last.endMs, last.tall], [38000, 39000, true]);
    expect([before.endMs, before.tall], [38000, false]);
  });
}
