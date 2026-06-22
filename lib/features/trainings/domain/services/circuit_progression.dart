enum CircuitRestKind { none, exercise, round, done }

class CircuitProgression {
  final int nextRound;
  final int nextExerciseIndex;
  final CircuitRestKind restKind;
  final int restSeconds;

  const CircuitProgression({
    required this.nextRound,
    required this.nextExerciseIndex,
    required this.restKind,
    required this.restSeconds,
  });
}

CircuitProgression advanceCircuit({
  required int currentRound,
  required int totalRounds,
  required int currentExerciseIndex,
  required int exerciseCount,
  required int exerciseRestSeconds,
  required int roundRestSeconds,
}) {
  final isLastExercise = currentExerciseIndex >= exerciseCount - 1;
  final isLastRound = currentRound >= totalRounds;

  if (!isLastExercise) {
    final rest = exerciseRestSeconds.clamp(0, 3600);
    return CircuitProgression(
      nextRound: currentRound,
      nextExerciseIndex: currentExerciseIndex + 1,
      restKind: rest > 0 ? CircuitRestKind.exercise : CircuitRestKind.none,
      restSeconds: rest,
    );
  }

  if (isLastRound) {
    return CircuitProgression(
      nextRound: currentRound,
      nextExerciseIndex: currentExerciseIndex,
      restKind: CircuitRestKind.done,
      restSeconds: 0,
    );
  }

  final rest = roundRestSeconds.clamp(0, 3600);
  return CircuitProgression(
    nextRound: currentRound + 1,
    nextExerciseIndex: 0,
    restKind: rest > 0 ? CircuitRestKind.round : CircuitRestKind.none,
    restSeconds: rest,
  );
}
