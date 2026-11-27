import 'package:exom_app/core/storage/local_storage.dart';
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
import 'package:exom_app/injection_container.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage extends LocalStorage {
  @override
  String? get sessionStamp => 'A:1:test';
}

TrainingEntity _training(String id) => TrainingEntity(
  id: id,
  name: 'Fixture $id',
  types: const [],
  level: 'beginner',
  tags: const [],
  exercises: const [],
);

/// Models the wire cost of the list screen: one day request and two month
/// requests (assignments + calendar) per history load.
class _Repository extends Fake implements TrainingRepository {
  Duration dayLatency = const Duration(milliseconds: 100);
  Duration historyLatency = const Duration(milliseconds: 800);
  bool historyFails = false;
  int dayCalls = 0;
  int historyCalls = 0;
  final days = <String?>[];
  final months = <String?>[];

  int get getRequests => dayCalls + historyCalls * 2;

  @override
  Future<List<TrainingEntity>> getDayTrainings({String? date}) async {
    dayCalls++;
    days.add(date);
    await Future<void>.delayed(dayLatency);
    return [_training('day-${date ?? 'today'}')];
  }

  @override
  Future<List<TrainingHistoryEntity>> getTrainings({String? date}) async {
    historyCalls++;
    months.add(date);
    await Future<void>.delayed(historyLatency);
    if (historyFails) throw StateError('history down');
    return const [];
  }
}

TrainingBloc _bloc(TrainingRepository r) => TrainingBloc(
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

Future<int> _msUntil(
  WidgetTester tester,
  bool Function() done, {
  int limit = 5000,
}) async {
  var elapsed = 0;
  while (!done() && elapsed < limit) {
    await tester.pump(const Duration(milliseconds: 10));
    elapsed += 10;
  }
  return elapsed;
}

void main() {
  setUp(() async {
    await sl.reset();
    sl.registerSingleton<LocalStorage>(_Storage());
  });
  tearDown(sl.reset);

  testWidgets('day content is emitted when the day request completes', (
    tester,
  ) async {
    final repository = _Repository();
    final bloc = _bloc(repository);
    addTearDown(bloc.close);
    bloc.add(const TrainingsLoadRequested(date: '2026-11-05'));
    final ms = await _msUntil(
      tester,
      () => bloc.state is TrainingsLoaded,
    );
    // ignore: avoid_print
    print('TRAININGS_MS_TO_DAY_CONTENT=$ms');
    final state = bloc.state as TrainingsLoaded;
    expect(state.todayTrainings.single.id, 'day-2026-11-05');
    expect(ms, lessThanOrEqualTo(120));
    expect(state.isHistoryLoading, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect((bloc.state as TrainingsLoaded).isHistoryLoading, isFalse);
  });

  testWidgets('month change only refreshes history', (tester) async {
    final repository = _Repository();
    final bloc = _bloc(repository);
    addTearDown(bloc.close);
    bloc.add(const TrainingsLoadRequested(date: '2026-11-05'));
    await _msUntil(
      tester,
      () => repository.historyCalls == 1 && bloc.state is TrainingsLoaded,
    );
    await tester.pump(const Duration(seconds: 2));
    bloc.add(
      const TrainingsLoadRequested(
        date: '2026-11-05',
        historyDate: '2026-10-01',
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    // ignore: avoid_print
    print(
      'TRAININGS_MONTH_CHANGE_CALLS day=${repository.dayCalls} '
      'history=${repository.historyCalls} GET=${repository.getRequests}',
    );
    expect(repository.dayCalls, 1);
    expect(repository.historyCalls, 2);
    expect(repository.getRequests, 5);
  });

  testWidgets('history failure does not hide day content', (tester) async {
    final repository = _Repository()..historyFails = true;
    final bloc = _bloc(repository);
    addTearDown(bloc.close);
    bloc.add(const TrainingsLoadRequested(date: '2026-11-05'));
    await tester.pump(const Duration(seconds: 1));
    final state = bloc.state as TrainingsLoaded;
    expect(state.todayTrainings.single.id, 'day-2026-11-05');
    expect(state.isHistoryLoading, isFalse);
    expect(state.historyFailed, isTrue);
    expect(state.history, isEmpty);
  });

  testWidgets('month change keeps the day visible while history loads', (
    tester,
  ) async {
    final repository = _Repository();
    final bloc = _bloc(repository);
    addTearDown(bloc.close);
    bloc.add(const TrainingsLoadRequested(date: '2026-11-05'));
    await tester.pump(const Duration(seconds: 1));
    final states = <TrainingState>[];
    final subscription = bloc.stream.listen(states.add);
    addTearDown(subscription.cancel);
    bloc.add(
      const TrainingsLoadRequested(
        date: '2026-11-05',
        historyDate: '2026-10-01',
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(states.whereType<TrainingLoading>(), isEmpty);
    final loaded = states.whereType<TrainingsLoaded>().toList();
    expect(loaded.first.isHistoryLoading, isTrue);
    expect(loaded.first.historyDate, '2026-10-01');
    expect(loaded.first.todayTrainings.single.id, 'day-2026-11-05');
    expect(loaded.last.isHistoryLoading, isFalse);
  });

  testWidgets('pull to refresh and date change still reload the day', (
    tester,
  ) async {
    final repository = _Repository();
    final bloc = _bloc(repository);
    addTearDown(bloc.close);
    bloc.add(const TrainingsLoadRequested(date: '2026-11-05'));
    await tester.pump(const Duration(seconds: 1));
    bloc.add(
      const TrainingsLoadRequested(
        date: '2026-11-05',
        historyDate: '2026-11-05',
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(repository.dayCalls, 2);
    bloc.add(
      const TrainingsLoadRequested(
        date: '2026-11-06',
        historyDate: '2026-10-01',
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(repository.dayCalls, 3);
  });
}
