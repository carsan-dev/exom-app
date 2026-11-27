import 'dart:async';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/injection_container.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';
import 'package:exom_app/features/trainings/domain/usecases/complete_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_completed_exercises_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_previous_exercise_performances_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_today_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_trainings_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/mark_exercise_completed_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/unmark_exercise_completed_usecase.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';

class _Repository extends Fake implements TrainingRepository {
  final progressStarted = Completer<void>();
  final previousStarted = Completer<void>();
  final progress = Completer<TrainingDayProgress>();
  final previous = Completer<Map<String, List<SetPerformance>>>();
  int previousCalls = 0;
  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async =>
      const TrainingEntity(
        id: 't',
        name: 'Fixture',
        types: [],
        level: 'beginner',
        tags: [],
        exercises: [
          TrainingExerciseEntity(
            id: 'te',
            order: 1,
            sets: 1,
            repsOrDuration: '10',
            restSeconds: 60,
            exercise: ExerciseEntity(
              id: 'ex',
              name: 'Fixture exercise',
              muscleGroups: [],
            ),
          ),
        ],
      );
  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) {
    expect(date, '2026-11-04');
    progressStarted.complete();
    return progress.future;
  }

  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
    List<String> ids,
    String date,
  ) {
    expect(ids, ['ex']);
    expect(date, '2026-11-04');
    previousCalls++;
    previousStarted.complete();
    return previous.future;
  }
}

TrainingBloc _createBloc(_Repository r) => TrainingBloc(
  getTodayTrainingUseCase: GetTodayTrainingUseCase(r),
  getTrainingsUseCase: GetTrainingsUseCase(r),
  getTrainingUseCase: GetTrainingUseCase(r),
  markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(r),
  unmarkExerciseCompletedUseCase: UnmarkExerciseCompletedUseCase(r),
  completeTrainingUseCase: CompleteTrainingUseCase(r),
  getCompletedExercisesUseCase: GetCompletedExercisesUseCase(r),
  getPreviousExercisePerformancesUseCase:
      GetPreviousExercisePerformancesUseCase(r),
);
void main() {
  setUp(() async {
    await sl.reset();
    sl.registerSingleton<LocalStorage>(LocalStorage());
  });
  tearDown(sl.reset);
  for (final failure in ['none', 'progress', 'previous', 'both']) {
    test(
      'training auxiliary read barrier and optional failure=$failure',
      () async {
        final r = _Repository();
        final bloc = _createBloc(r);
        final loaded = bloc.stream.firstWhere((s) => s is TrainingDetailLoaded);
        bloc.add(const TrainingDetailLoadRequested('t', date: '2026-11-04'));
        await r.progressStarted.future;
        await pumpEventQueue();
        final beforeRelease = r.previousCalls;
        if (failure == 'progress' || failure == 'both') {
          r.progress.completeError(StateError('fixture progress failure'));
        } else {
          r.progress.complete(
            const TrainingDayProgress(ids: {'te'}, note: 'retained'),
          );
        }
        await r.previousStarted.future;
        expect(bloc.state, isA<TrainingLoading>());
        if (failure == 'previous' || failure == 'both') {
          r.previous.completeError(StateError('fixture previous failure'));
        } else {
          r.previous.complete({
            'ex': const [SetPerformance(setNumber: 1, reps: 10)],
          });
        }
        final state = await loaded as TrainingDetailLoaded;
        expect(r.previousCalls, 1);
        expect(state.selectedDate, '2026-11-04');
        expect(
          state.completedExerciseIds,
          failure == 'progress' || failure == 'both' ? isEmpty : {'te'},
        );
        expect(
          state.clientNote,
          failure == 'progress' || failure == 'both' ? isNull : 'retained',
        );
        expect(
          state.previousPerformances.keys,
          failure == 'previous' || failure == 'both' ? isEmpty : ['te'],
        );
        await bloc.close();
        expect(
          beforeRelease,
          1,
          reason:
              'Independent history read must start while progress is pending',
        );
      },
    );
  }
}
