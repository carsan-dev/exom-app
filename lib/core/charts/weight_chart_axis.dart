import 'dart:math' as math;

/// Vertical axis of the weight chart: [min] and [max] are multiples of
/// [interval] and cover the data, so every mark is evenly spaced.
class WeightAxis {
  const WeightAxis({
    required this.min,
    required this.max,
    required this.interval,
  });

  final double min;
  final double max;
  final double interval;

  /// Values of the marks, from [min] to [max] inclusive.
  List<double> get ticks {
    final count = ((max - min) / interval).round();
    return [for (var i = 0; i <= count; i++) min + i * interval];
  }
}

/// Round steps tried in order; the smallest one that needs at most
/// [_maxTicks] marks wins.
const List<double> _steps = [1, 2, 5, 10, 20, 50, 100, 200, 500];

const int _maxTicks = 5;

/// Evenly spaced, round marks for data between [dataMin] and [dataMax]
/// (display units). A flat series gets one whole unit above and below.
WeightAxis weightAxis(double dataMin, double dataMax) {
  if (dataMax - dataMin < 1e-9) {
    return WeightAxis(
      min: dataMin.floorToDouble() - 1,
      max: dataMax.ceilToDouble() + 1,
      interval: 1,
    );
  }
  for (final step in _steps) {
    final min = (dataMin / step).floorToDouble() * step;
    var max = (dataMax / step).ceilToDouble() * step;
    if (max == min) max = min + step;
    if ((max - min) / step + 1 <= _maxTicks) {
      return WeightAxis(min: min, max: max, interval: step);
    }
  }
  final step = _steps.last;
  return WeightAxis(
    min: (dataMin / step).floorToDouble() * step,
    max: math.max((dataMax / step).ceilToDouble() * step, step),
    interval: step,
  );
}
