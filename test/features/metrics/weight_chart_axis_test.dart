import 'package:exom_app/features/metrics/presentation/widgets/weight_chart_axis.dart';
import 'package:flutter_test/flutter_test.dart';

void _expectValidAxis(WeightAxis axis, double dataMin, double dataMax) {
  expect(axis.min, lessThanOrEqualTo(dataMin));
  expect(axis.max, greaterThanOrEqualTo(dataMax));
  expect(axis.interval, greaterThan(0));
  expect(const [
    1.0,
    2.0,
    5.0,
    10.0,
    20.0,
    50.0,
    100.0,
    200.0,
    500.0,
  ], contains(axis.interval));
  final ticks = axis.ticks;
  expect(ticks.length, inInclusiveRange(2, 5));
  expect(ticks.first, axis.min);
  expect(ticks.last, axis.max);
  for (var i = 1; i < ticks.length; i++) {
    expect(ticks[i] - ticks[i - 1], closeTo(axis.interval, 1e-9));
  }
}

void main() {
  group('weightAxis', () {
    test('78.6-82.2 gets a uniform interval of 2 from 78 to 84', () {
      final axis = weightAxis(78.6, 82.2);
      _expectValidAxis(axis, 78.6, 82.2);
      expect(axis.interval, 2);
      expect(axis.ticks, [78, 80, 82, 84]);
    });

    test('all values equal are centred with room above and below', () {
      final axis = weightAxis(80, 80);
      _expectValidAxis(axis, 80, 80);
      expect(axis.min, lessThan(80));
      expect(axis.max, greaterThan(80));
    });

    test('equal values that are not whole numbers', () {
      final axis = weightAxis(80.4, 80.4);
      _expectValidAxis(axis, 80.4, 80.4);
      expect(axis.min, lessThan(80.4));
      expect(axis.max, greaterThan(80.4));
    });

    test('a single point is the same as all values equal', () {
      final axis = weightAxis(72.3, 72.3);
      _expectValidAxis(axis, 72.3, 72.3);
      expect(axis.min, lessThan(72.3));
      expect(axis.max, greaterThan(72.3));
    });

    test('range under 1 kg inside one whole kilo', () {
      final axis = weightAxis(80.2, 80.7);
      _expectValidAxis(axis, 80.2, 80.7);
      expect(axis.interval, 1);
      expect(axis.ticks, [80, 81]);
    });

    test('range under 1 kg across a whole kilo', () {
      final axis = weightAxis(80.8, 81.3);
      _expectValidAxis(axis, 80.8, 81.3);
      expect(axis.ticks, [80, 81, 82]);
    });

    test('large range 60-110 uses a round interval of 20', () {
      final axis = weightAxis(60, 110);
      _expectValidAxis(axis, 60, 110);
      expect(axis.interval, 20);
      expect(axis.ticks, [60, 80, 100, 120]);
    });

    test('data on exact multiples are covered without extra room', () {
      final axis = weightAxis(70, 72);
      _expectValidAxis(axis, 70, 72);
      expect(axis.ticks, [70, 71, 72]);
    });

    test('pounds-sized values stay uniform and within 5 ticks', () {
      final axis = weightAxis(150.4, 181.9);
      _expectValidAxis(axis, 150.4, 181.9);
    });
  });
}
