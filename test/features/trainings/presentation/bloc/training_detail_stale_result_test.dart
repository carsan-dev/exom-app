import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/injection_container.dart';
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

class _Storage extends LocalStorage {
  String? stamp = 'A:1:test';
  @override
  String? get sessionStamp => stamp;
}

TrainingEntity _training(String id) => TrainingEntity(
  id: id,
  name: 'Fixture',
  types: const [],
  level: 'beginner',
  tags: const [],
  exercises: const [],
);

class _ControlledRepository extends Fake implements TrainingRepository {
  Future<TrainingEntity> Function(String id, String? date)? load;
  Future<TrainingDayProgress> Function(String? date)? progress;
  Future<Map<String, List<SetPerformance>>> Function()? history;
  Completer<void>? listGate;
  Future<void> Function()? listDispatch;
  int requiredCalls = 0;
  int progressCalls = 0;
  int historyCalls = 0;
  final requestSessions = <String?>[];

  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) {
    requiredCalls++;
    requestSessions.add(LocalStorage.requestSessionKey);
    return load?.call(id, date) ?? Future.value(_training(id));
  }

  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) {
    progressCalls++;
    requestSessions.add(LocalStorage.requestSessionKey);
    return progress?.call(date) ?? Future.value(const TrainingDayProgress());
  }

  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
    List<String> ids,
    String date,
  ) {
    historyCalls++;
    requestSessions.add(LocalStorage.requestSessionKey);
    return history?.call() ?? Future.value({});
  }

  @override
  Future<List<TrainingEntity>> getDayTrainings({String? date}) async {
    requestSessions.add(LocalStorage.requestSessionKey);
    await listGate?.future;
    await listDispatch?.call();
    return [_training('list')];
  }

  @override
  Future<List<TrainingHistoryEntity>> getTrainings({String? date}) async {
    requestSessions.add(LocalStorage.requestSessionKey);
    await listGate?.future;
    await listDispatch?.call();
    return [];
  }
}

class _TokenProvider implements AuthTokenProvider {
  LocalAuthSession? session = const LocalAuthSession(uid: 'A', generation: 1);
  @override
  LocalAuthSession? get currentSession => session;
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => 'fixture';
}

class _CountingAdapter implements HttpClientAdapter {
  int requests = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

class _Repository extends Fake implements TrainingRepository {
  final progressStarted = Completer<void>();
  final progress = Completer<TrainingDayProgress>();
  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async =>
      TrainingEntity(
        id: id,
        name: 'Fixture',
        types: const [],
        level: 'beginner',
        tags: const [],
        exercises: const [],
      );
  @override
  Future<TrainingDayProgress> getCompletedExerciseIds({String? date}) {
    if (date == '2026-11-04') {
      progressStarted.complete();
      return progress.future;
    }
    return Future.value(const TrainingDayProgress(note: 'new request'));
  }

  @override
  Future<Map<String, List<SetPerformance>>> getPreviousExercisePerformances(
    List<String> ids,
    String date,
  ) async => {};
}

TrainingBloc _createBloc(TrainingRepository r) => TrainingBloc(
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
  late _Storage storage;
  setUp(() async {
    await sl.reset();
    storage = _Storage();
    sl.registerSingleton<LocalStorage>(storage);
  });
  tearDown(sl.reset);
  test(
    'superseded detail success cannot replace newer selected date',
    () async {
      final r = _Repository();
      final bloc = _createBloc(r);
      bloc.add(const TrainingDetailLoadRequested('old', date: '2026-11-04'));
      await r.progressStarted.future;
      final newer = bloc.stream.firstWhere(
        (s) => s is TrainingDetailLoaded && s.selectedDate == '2026-11-05',
      );
      bloc.add(const TrainingDetailLoadRequested('new', date: '2026-11-05'));
      await newer;
      r.progress.complete(const TrainingDayProgress(note: 'old request'));
      await pumpEventQueue();
      final state = bloc.state;
      await bloc.close();
      expect(state, isA<TrainingDetailLoaded>());
      expect((state as TrainingDetailLoaded).selectedDate, '2026-11-05');
      expect(state.training.id, 'new');
      expect(state.clientNote, 'new request');
    },
  );
  test(
    'session switch while detail reads pending cannot publish old data',
    () async {
      final r = _Repository();
      final bloc = _createBloc(r);
      bloc.add(const TrainingDetailLoadRequested('old', date: '2026-11-04'));
      await r.progressStarted.future;
      storage.stamp = 'B:2:test';
      r.progress.complete(const TrainingDayProgress(note: 'private A note'));
      await pumpEventQueue();
      final state = bloc.state;
      await bloc.close();
      expect(state, isNot(isA<TrainingDetailLoaded>()));
      expect(state, isNot(isA<TrainingError>()));
    },
  );

  for (final identity in ['date', 'id', 'both']) {
    for (final oldFails in [false, true]) {
      for (final newFails in [false, true]) {
        test(
          'latest detail wins $identity oldError=$oldFails newError=$newFails',
          () async {
            final old = Completer<TrainingEntity>();
            final r = _ControlledRepository();
            r.load = (id, date) {
              if (r.requiredCalls == 1) return old.future;
              return newFails
                  ? Future.error(StateError('new required failure'))
                  : Future.value(_training(id));
            };
            final bloc = _createBloc(r);
            bloc.add(
              const TrainingDetailLoadRequested('old', date: '2026-11-04'),
            );
            await pumpEventQueue();
            final next = bloc.stream.firstWhere(
              (s) => s is TrainingDetailLoaded || s is TrainingError,
            );
            bloc.add(
              TrainingDetailLoadRequested(
                identity == 'date' ? 'old' : 'new',
                date: identity == 'id' ? '2026-11-04' : '2026-11-05',
              ),
            );
            final latest = await next;
            if (oldFails) {
              old.completeError(StateError('old required failure'));
            } else {
              old.complete(_training('old'));
            }
            await pumpEventQueue();
            await bloc.close();
            expect(bloc.state, same(latest));
            expect(
              latest,
              newFails ? isA<TrainingError>() : isA<TrainingDetailLoaded>(),
            );
            expect(r.progressCalls, newFails ? 0 : 1);
            expect(r.historyCalls, newFails ? 0 : 1);
          },
        );
      }
    }
  }

  for (final stamp in <String?>['B:2:test', 'A:2:test', null]) {
    for (final failure in [false, true]) {
      test(
        'session $stamp during required fetch error=$failure stops auxiliaries',
        () async {
          final required = Completer<TrainingEntity>();
          final r = _ControlledRepository()..load = (_, _) => required.future;
          final bloc = _createBloc(r);
          bloc.add(const TrainingDetailLoadRequested('old'));
          await pumpEventQueue();
          expect(r.requiredCalls, 1);
          storage.stamp = stamp;
          if (failure) {
            required.completeError(StateError('private required failure'));
          } else {
            required.complete(_training('old'));
          }
          await pumpEventQueue();
          await bloc.close();
          expect(r.progressCalls, 0);
          expect(r.historyCalls, 0);
          expect(bloc.state, isA<TrainingLoading>());
        },
      );

      test(
        'session $stamp during auxiliary reads error=$failure stays silent',
        () async {
          final progress = Completer<TrainingDayProgress>();
          final history = Completer<Map<String, List<SetPerformance>>>();
          final r = _ControlledRepository();
          r.progress = (_) => progress.future;
          r.history = () => history.future;
          final bloc = _createBloc(r);
          bloc.add(const TrainingDetailLoadRequested('old'));
          await pumpEventQueue();
          expect((r.progressCalls, r.historyCalls), (1, 1));
          storage.stamp = stamp;
          if (failure) {
            progress.completeError(StateError('private progress failure'));
            history.completeError(StateError('private history failure'));
          } else {
            progress.complete(
              const TrainingDayProgress(note: 'private A note'),
            );
            history.complete({});
          }
          await pumpEventQueue();
          await bloc.close();
          expect(bloc.state, isA<TrainingLoading>());
        },
      );
    }
  }

  test('signed-out detail load never starts required request', () async {
    storage.stamp = null;
    final r = _ControlledRepository();
    final bloc = _createBloc(r);
    bloc.add(const TrainingDetailLoadRequested('old'));
    await pumpEventQueue();
    await bloc.close();
    expect(r.requiredCalls, 0);
    expect(bloc.state, isA<TrainingInitial>());
  });

  test(
    'closing emitter during required fetch prevents auxiliary requests',
    () async {
      final required = Completer<TrainingEntity>();
      final r = _ControlledRepository()..load = (_, _) => required.future;
      final bloc = _createBloc(r);
      bloc.add(const TrainingDetailLoadRequested('old'));
      await pumpEventQueue();
      final closing = bloc.close();
      await pumpEventQueue();
      required.complete(_training('old'));
      await closing;
      expect(r.progressCalls, 0);
      expect(r.historyCalls, 0);
    },
  );

  for (final listEvent in <TrainingEvent>[
    const TodayTrainingLoadRequested(date: '2026-11-05'),
    const TrainingsLoadRequested(date: '2026-11-05'),
  ]) {
    for (final stamp in <String?>['B:2:test', 'A:2:test', null]) {
      for (final failure in [false, true]) {
        test(
          '${listEvent.runtimeType} session=$stamp error=$failure stays silent',
          () async {
            final gate = Completer<void>();
            final r = _ControlledRepository()..listGate = gate;
            final bloc = _createBloc(r);
            bloc.add(listEvent);
            await pumpEventQueue();
            expect(
              r.requestSessions.length,
              listEvent is TrainingsLoadRequested ? 2 : 1,
            );
            storage.stamp = stamp;
            if (failure) {
              gate.completeError(StateError('private list failure'));
            } else {
              gate.complete();
            }
            await pumpEventQueue();
            await bloc.close();
            expect(bloc.state, isA<TrainingLoading>());
          },
        );
      }
    }

    for (final failure in [false, true]) {
      test(
        '${listEvent.runtimeType} closed emitter ignores error=$failure',
        () async {
          final gate = Completer<void>();
          final r = _ControlledRepository()..listGate = gate;
          final bloc = _createBloc(r);
          bloc.add(listEvent);
          await pumpEventQueue();
          final closing = bloc.close();
          await pumpEventQueue();
          if (failure) {
            gate.completeError(StateError('closed list failure'));
          } else {
            gate.complete();
          }
          await closing;
          expect(bloc.state, isA<TrainingLoading>());
        },
      );

      for (final newer in <TrainingEvent>[
        const TrainingDetailLoadRequested('new', date: '2026-11-06'),
        const TodayTrainingLoadRequested(date: '2026-11-06'),
        const TrainingsLoadRequested(date: '2026-11-06'),
      ]) {
        test(
          'late ${listEvent.runtimeType} error=$failure cannot replace ${newer.runtimeType}',
          () async {
            final gate = Completer<void>();
            final r = _ControlledRepository()..listGate = gate;
            final bloc = _createBloc(r);
            bloc.add(listEvent);
            await pumpEventQueue();
            r.listGate = null;
            final next = bloc.stream.firstWhere(
              (s) =>
                  s is TrainingDetailLoaded ||
                  s is TodayTrainingLoaded ||
                  (s is TrainingsLoaded && !s.isHistoryLoading),
            );
            bloc.add(newer);
            final latest = await next;
            if (failure) {
              gate.completeError(StateError('stale list failure'));
            } else {
              gate.complete();
            }
            await pumpEventQueue();
            await bloc.close();
            expect(bloc.state, same(latest));
          },
        );
      }
    }

    test('signed-out ${listEvent.runtimeType} never starts requests', () async {
      storage.stamp = null;
      final r = _ControlledRepository();
      final bloc = _createBloc(r);
      bloc.add(listEvent);
      await pumpEventQueue();
      await bloc.close();
      expect(r.requestSessions, isEmpty);
      expect(bloc.state, isA<TrainingInitial>());
    });

    for (final session in <LocalAuthSession?>[
      const LocalAuthSession(uid: 'B', generation: 2),
      const LocalAuthSession(uid: 'A', generation: 2),
      null,
    ]) {
      test(
        'delayed ${listEvent.runtimeType} dispatch stays bound after ${session?.uid}:${session?.generation}',
        () async {
          final provider = _TokenProvider();
          await sl.unregister<LocalStorage>();
          sl.registerSingleton<LocalStorage>(
            LocalStorage(currentSession: () => provider.currentSession),
          );
          final adapter = _CountingAdapter();
          final client = ApiClient(authTokenProvider: provider)
            ..dio.httpClientAdapter = adapter;
          final dispatch = Completer<void>();
          final dispatchedSessions = <String?>[];
          final r = _ControlledRepository()..listGate = dispatch;
          r.listDispatch = () async {
            dispatchedSessions.add(LocalStorage.requestSessionKey);
            await client.dio.get<void>('/fixture-training-list');
          };
          final bloc = _createBloc(r);
          bloc.add(listEvent);
          await pumpEventQueue();
          final expectedSessions = List.filled(
            listEvent is TrainingsLoadRequested ? 2 : 1,
            'A:1',
          );
          expect(r.requestSessions, expectedSessions);
          provider.session = session;
          dispatch.complete();
          await pumpEventQueue();
          await bloc.close();
          client.dio.close();
          expect(dispatchedSessions, expectedSessions);
          expect(adapter.requests, 0);
          expect(bloc.state, isA<TrainingLoading>());
        },
      );
    }

    test('late ${listEvent.runtimeType} cannot replace newer detail', () async {
      final gate = Completer<void>();
      final r = _ControlledRepository()..listGate = gate;
      final bloc = _createBloc(r);
      bloc.add(listEvent);
      await pumpEventQueue();
      final next = bloc.stream.firstWhere((s) => s is TrainingDetailLoaded);
      bloc.add(const TrainingDetailLoadRequested('new', date: '2026-11-04'));
      final latest = await next;
      gate.complete();
      await pumpEventQueue();
      await bloc.close();
      expect(bloc.state, same(latest));
    });

    test('late detail cannot replace newer ${listEvent.runtimeType}', () async {
      final progress = Completer<TrainingDayProgress>();
      final r = _ControlledRepository()..progress = (_) => progress.future;
      final bloc = _createBloc(r);
      bloc.add(const TrainingDetailLoadRequested('old', date: '2026-11-04'));
      await pumpEventQueue();
      final next = bloc.stream.firstWhere(
        (s) => s is TodayTrainingLoaded || (s is TrainingsLoaded && !s.isHistoryLoading),
      );
      bloc.add(listEvent);
      final latest = await next;
      progress.complete(const TrainingDayProgress(note: 'old'));
      await pumpEventQueue();
      await bloc.close();
      expect(bloc.state, same(latest));
    });
  }

  for (final session in <LocalAuthSession?>[
    const LocalAuthSession(uid: 'B', generation: 2),
    const LocalAuthSession(uid: 'A', generation: 2),
    null,
  ]) {
    test(
      'delayed auxiliary dispatch cannot send after session ${session?.uid}:${session?.generation}',
      () async {
        final provider = _TokenProvider();
        await sl.unregister<LocalStorage>();
        sl.registerSingleton<LocalStorage>(
          LocalStorage(currentSession: () => provider.currentSession),
        );
        final adapter = _CountingAdapter();
        final client = ApiClient(authTokenProvider: provider)
          ..dio.httpClientAdapter = adapter;
        final dispatch = Completer<void>();
        final r = _ControlledRepository()
          ..history = () async {
            await dispatch.future;
            await client.dio.get<void>('/fixture-detail-history');
            return {};
          };
        final bloc = _createBloc(r);
        bloc.add(const TrainingDetailLoadRequested('old'));
        await pumpEventQueue();
        expect(r.historyCalls, 1);
        provider.session = session;
        dispatch.complete();
        await pumpEventQueue();
        await bloc.close();
        client.dio.close();
        expect(r.requestSessions, ['A:1', 'A:1', 'A:1']);
        expect(adapter.requests, 0);
        expect(bloc.state, isA<TrainingLoading>());
      },
    );
  }
}
