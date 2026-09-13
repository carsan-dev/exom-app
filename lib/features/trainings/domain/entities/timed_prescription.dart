enum TimeDisplayUnit { seconds, minutes }

class TimedSegment {
  final String action;
  final int seconds;
  final TimeDisplayUnit unit;
  const TimedSegment({
    required this.action,
    required this.seconds,
    required this.unit,
  });
  Map<String, Object> toJson() => {
    'action': action,
    'seconds': seconds,
    'unit': unit == TimeDisplayUnit.minutes ? 'MINUTES' : 'SECONDS',
  };
}

class TimedPrescription {
  final TimeDisplayUnit unit;
  final List<TimedSegment> segments;
  const TimedPrescription({required this.unit, this.segments = const []});

  static TimedPrescription? tryParse(Object? raw) {
    if (raw is! Map || raw['version'] != 1) return null;
    TimeDisplayUnit? readUnit(Object? value) => switch (value) {
      'MINUTES' => TimeDisplayUnit.minutes,
      'SECONDS' => TimeDisplayUnit.seconds,
      _ => null,
    };
    final unit = readUnit(raw['unit']);
    final list = raw['segments'];
    if (unit == null || list is! List || list.length > 20) return null;
    final segments = <TimedSegment>[];
    for (final item in list) {
      if (item is! Map) return null;
      final action = item['action'];
      final seconds = item['seconds'];
      final segmentUnit = readUnit(item['unit']);
      if (action is! String ||
          action.trim().isEmpty ||
          action.length > 80 ||
          seconds is! int ||
          seconds < 1 ||
          seconds > 2147483647 ||
          segmentUnit == null) {
        return null;
      }
      segments.add(
        TimedSegment(
          action: action.trim(),
          seconds: seconds,
          unit: segmentUnit,
        ),
      );
    }
    return TimedPrescription(unit: unit, segments: List.unmodifiable(segments));
  }

  Map<String, Object> toJson() => {
    'version': 1,
    'unit': unit == TimeDisplayUnit.minutes ? 'MINUTES' : 'SECONDS',
    'segments': segments.map((s) => s.toJson()).toList(),
  };

  String instructions(int total) {
    final base = '${formatDurationValue(total, unit)} en total.';
    if (segments.isEmpty) return base;
    final sequence = segments
        .map((s) => '${s.action}: ${formatDurationValue(s.seconds, s.unit)}')
        .join('; ');
    final cycle = segments.fold<int>(0, (sum, s) => sum + s.seconds);
    var tail = total % cycle;
    var ending = '';
    for (final s in segments) {
      if (tail > 0 && tail < s.seconds) {
        ending =
            ' Último tramo recortado: ${s.action}, ${formatDurationValue(tail, s.unit)}.';
        break;
      }
      tail -= s.seconds;
      if (tail <= 0) break;
    }
    return '$base $sequence; repetir hasta terminar.$ending';
  }

  TimedPhase phase(int totalSeconds, int elapsedMilliseconds) {
    final totalMs = totalSeconds * 1000;
    final elapsed = elapsedMilliseconds.clamp(0, totalMs);
    if (elapsed >= totalMs) {
      return const TimedPhase(
        action: 'Finalizado',
        remainingMilliseconds: 0,
        totalRemainingMilliseconds: 0,
      );
    }
    if (segments.isEmpty) {
      return TimedPhase(
        action: 'Ejercicio',
        remainingMilliseconds: totalMs - elapsed,
        totalRemainingMilliseconds: totalMs - elapsed,
      );
    }
    final cycleMs = segments.fold<int>(0, (sum, s) => sum + s.seconds * 1000);
    var position = elapsed % cycleMs;
    for (var i = 0; i < segments.length; i++) {
      final duration = segments[i].seconds * 1000;
      if (position < duration) {
        final remaining = (duration - position).clamp(0, totalMs - elapsed);
        return TimedPhase(
          action: segments[i].action,
          nextAction: remaining < totalMs - elapsed
              ? segments[(i + 1) % segments.length].action
              : null,
          remainingMilliseconds: remaining,
          totalRemainingMilliseconds: totalMs - elapsed,
        );
      }
      position -= duration;
    }
    throw StateError('Invalid timed sequence');
  }
}

class TimedPhase {
  final String action;
  final String? nextAction;
  final int remainingMilliseconds;
  final int totalRemainingMilliseconds;
  const TimedPhase({
    required this.action,
    this.nextAction,
    required this.remainingMilliseconds,
    required this.totalRemainingMilliseconds,
  });
}

String formatDurationValue(int seconds, TimeDisplayUnit unit) {
  if (unit == TimeDisplayUnit.seconds) return '$seconds s';
  if (seconds % 60 == 0) return '${seconds ~/ 60} min';
  if (seconds % 3 == 0) {
    return '${(seconds / 60).toString().replaceAll('.', ',')} min';
  }
  return '${seconds ~/ 60} min ${seconds % 60} s';
}
