import 'package:exom_app/features/trainings/domain/services/circuit_progression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses exercise rest before next exercise', () {
    final result = advanceCircuit(
      currentRound: 1,
      totalRounds: 3,
      currentExerciseIndex: 0,
      exerciseCount: 2,
      exerciseRestSeconds: 20,
      roundRestSeconds: 60,
    );

    expect(result.restKind, CircuitRestKind.exercise);
    expect(result.restSeconds, 20);
    expect(result.nextExerciseIndex, 1);
  });

  test('advances immediately when exercise rest is zero', () {
    final result = advanceCircuit(
      currentRound: 1,
      totalRounds: 3,
      currentExerciseIndex: 0,
      exerciseCount: 2,
      exerciseRestSeconds: 0,
      roundRestSeconds: 60,
    );

    expect(result.restKind, CircuitRestKind.none);
    expect(result.nextExerciseIndex, 1);
  });

  test('uses only round rest after last exercise', () {
    final result = advanceCircuit(
      currentRound: 1,
      totalRounds: 3,
      currentExerciseIndex: 1,
      exerciseCount: 2,
      exerciseRestSeconds: 20,
      roundRestSeconds: 60,
    );

    expect(result.restKind, CircuitRestKind.round);
    expect(result.restSeconds, 60);
    expect(result.nextRound, 2);
    expect(result.nextExerciseIndex, 0);
  });

  test('finishes last round without rest', () {
    final result = advanceCircuit(
      currentRound: 3,
      totalRounds: 3,
      currentExerciseIndex: 1,
      exerciseCount: 2,
      exerciseRestSeconds: 20,
      roundRestSeconds: 60,
    );

    expect(result.restKind, CircuitRestKind.done);
    expect(result.restSeconds, 0);
  });
}
