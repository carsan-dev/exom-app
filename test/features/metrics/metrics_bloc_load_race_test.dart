// L6-UX6: day-form loads overlap (bloc 9 runs MetricsLoadRequested
// concurrently). An older load that answers after a newer one used to emit its
// metric, and the form of the new date was filled (and saved) with the values
// of another day. Only the newest load may emit, whether it succeeds or fails.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:exom_app/features/metrics/domain/usecases/save_metric_usecase.dart';
import 'package:exom_app/features/metrics/presentation/bloc/metrics_bloc.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

final _dayA = BodyMetricEntity(
  id: 'day-a',
  date: DateTime(2026, 11, 10),
  weightKg: 68.4,
  waistCm: 74,
);

final _dayB = BodyMetricEntity(
  id: 'day-b',
  date: DateTime(2026, 11, 20),
  weightKg: 80,
  waistCm: 90,
);

/// Every load waits for its own completer, so the test decides the order in
/// which the answers arrive.
class _GatedRepository extends Fake implements MetricsRepository {
  final loads = <({String? date, Completer<BodyMetricEntity?> reply})>[];
  final saved = <Map<String, dynamic>>[];

  @override
  Future<BodyMetricEntity?> getLatestMetric({String? date}) {
    final reply = Completer<BodyMetricEntity?>();
    loads.add((date: date, reply: reply));
    return reply.future;
  }

  @override
  Future<BodyMetricEntity> saveMetric(Map<String, dynamic> data) async {
    saved.add({...data});
    return _dayB;
  }
}

class _Profile extends Fake implements ProfileEntity {}

class _ProfileRepository extends Fake implements ProfileRepository {
  @override
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data) async =>
      _Profile();
}

MetricsBloc _bloc(_GatedRepository repository) => MetricsBloc(
  saveMetricUseCase: SaveMetricUseCase(repository),
  metricsRepository: repository,
  updateProfileUseCase: UpdateProfileUseCase(_ProfileRepository()),
);

Future<void> _settle() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// The metrics of every [MetricsLoaded] in [states], in order.
List<BodyMetricEntity?> _loaded(List<MetricsState> states) => [
  for (final state in states)
    if (state is MetricsLoaded) state.current,
];

void main() {
  late _GatedRepository repository;
  late MetricsBloc bloc;
  late List<MetricsState> states;
  late StreamSubscription<MetricsState> sub;

  setUp(() {
    repository = _GatedRepository();
    bloc = _bloc(repository);
    states = <MetricsState>[];
    sub = bloc.stream.listen(states.add);
  });

  tearDown(() async {
    await sub.cancel();
    await bloc.close();
  });

  test(
    'two dated loads, the second answers first: only the second emits',
    () async {
      bloc.add(const MetricsLoadRequested(date: '2026-11-10'));
      bloc.add(const MetricsLoadRequested(date: '2026-11-20'));
      await _settle();
      expect(repository.loads.map((l) => l.date), ['2026-11-10', '2026-11-20']);

      repository.loads[1].reply.complete(_dayB);
      await _settle();
      repository.loads[0].reply.complete(_dayA);
      await _settle();

      expect(_loaded(states), [same(_dayB)]);
      expect((bloc.state as MetricsLoaded).current, same(_dayB));
    },
  );

  test(
    'the initial «latest» load answering after a dated one is ignored',
    () async {
      bloc.add(const MetricsLoadRequested());
      bloc.add(const MetricsLoadRequested(date: '2026-11-20'));
      await _settle();
      expect(repository.loads.map((l) => l.date), [null, '2026-11-20']);

      repository.loads[1].reply.complete(_dayB);
      await _settle();
      repository.loads[0].reply.complete(_dayA);
      await _settle();

      expect(_loaded(states), [same(_dayB)]);
      expect((bloc.state as MetricsLoaded).current, same(_dayB));
    },
  );

  test(
    'an older load answering first does not emit before the newer one',
    () async {
      bloc.add(const MetricsLoadRequested(date: '2026-11-10'));
      bloc.add(const MetricsLoadRequested(date: '2026-11-20'));
      await _settle();

      repository.loads[0].reply.complete(_dayA);
      await _settle();
      expect(_loaded(states), isEmpty);
      expect(bloc.state, isA<MetricsLoading>());

      repository.loads[1].reply.complete(_dayB);
      await _settle();
      expect(_loaded(states), [same(_dayB)]);
    },
  );

  test('a stale load error after the newer load is ignored', () async {
    bloc.add(const MetricsLoadRequested(date: '2026-11-10'));
    bloc.add(const MetricsLoadRequested(date: '2026-11-20'));
    await _settle();

    repository.loads[1].reply.complete(_dayB);
    await _settle();
    repository.loads[0].reply.completeError(Exception('timeout of day A'));
    await _settle();

    // The failure of day A would read as «day without metrics» (Loaded(null))
    // and wipe the form of day B.
    expect(_loaded(states), [same(_dayB)]);
    expect((bloc.state as MetricsLoaded).current, same(_dayB));
  });

  test(
    'a stale load error while the newer load is pending is ignored',
    () async {
      bloc.add(const MetricsLoadRequested(date: '2026-11-10'));
      bloc.add(const MetricsLoadRequested(date: '2026-11-20'));
      await _settle();

      repository.loads[0].reply.completeError(Exception('timeout of day A'));
      await _settle();
      expect(_loaded(states), isEmpty);

      repository.loads[1].reply.complete(_dayB);
      await _settle();
      expect(_loaded(states), [same(_dayB)]);
    },
  );

  // L6-UX7 (a): a failed load used to degrade to Loaded(null), which the form
  // read as a day without metrics (profile weight preloaded, save offered).
  test(
    'the newest load failing emits MetricsLoadFailed, never Loaded(null)',
    () async {
      bloc.add(const MetricsLoadRequested(date: '2026-11-10'));
      bloc.add(const MetricsLoadRequested(date: '2026-11-20'));
      await _settle();

      repository.loads[0].reply.complete(_dayA);
      await _settle();
      repository.loads[1].reply.completeError(Exception('day B failed'));
      await _settle();

      expect(_loaded(states), isEmpty);
      expect(
        bloc.state,
        isA<MetricsLoadFailed>()
            .having((s) => s.date, 'date', '2026-11-20')
            .having((s) => s.offline, 'offline', isFalse)
            .having((s) => s.sessionChanged, 'sessionChanged', isFalse),
      );
    },
  );

  test('a failed load without connection is marked offline', () async {
    bloc.add(const MetricsLoadRequested());
    await _settle();
    repository.loads[0].reply.completeError(
      DioException(
        requestOptions: RequestOptions(path: '/metrics/latest'),
        type: DioExceptionType.connectionError,
      ),
    );
    await _settle();

    expect(
      bloc.state,
      isA<MetricsLoadFailed>()
          .having((s) => s.date, 'date', isNull)
          .having((s) => s.offline, 'offline', isTrue),
    );
  });

  test(
    'a session change during the load is a failure, not an empty day',
    () async {
      bloc.add(const MetricsLoadRequested(date: '2026-11-20'));
      await _settle();
      repository.loads[0].reply.completeError(const LocalSessionChanged());
      await _settle();

      expect(_loaded(states), isEmpty);
      expect(
        bloc.state,
        isA<MetricsLoadFailed>().having(
          (s) => s.sessionChanged,
          'sessionChanged',
          isTrue,
        ),
      );
    },
  );

  test(
    'a stale load failure after the newer load answered is ignored',
    () async {
      bloc.add(const MetricsLoadRequested(date: '2026-11-10'));
      bloc.add(const MetricsLoadRequested(date: '2026-11-20'));
      await _settle();
      repository.loads[1].reply.complete(_dayB);
      await _settle();
      repository.loads[0].reply.completeError(Exception('timeout of day A'));
      await _settle();

      expect(states.whereType<MetricsLoadFailed>(), isEmpty);
    },
  );

  test('each answer carries the date and the request it answers', () async {
    bloc.add(const MetricsLoadRequested());
    await _settle();
    repository.loads[0].reply.complete(_dayA);
    await _settle();
    final initial = bloc.state as MetricsLoaded;
    expect(initial.date, isNull);

    bloc.add(const MetricsLoadRequested(date: '2026-11-20'));
    await _settle();
    repository.loads[1].reply.completeError(Exception('day B failed'));
    await _settle();
    final failed = bloc.state as MetricsLoadFailed;
    expect(failed.date, '2026-11-20');
    expect(failed.request, greaterThan(initial.request));
  });

  test('a stale load answering during a save does not interrupt it', () async {
    bloc.add(const MetricsLoadRequested());
    bloc.add(const MetricsLoadRequested(date: '2026-11-20'));
    await _settle();
    repository.loads[1].reply.complete(_dayB);
    await _settle();

    bloc.add(
      const MetricsSaveRequested({'date': '2026-11-20', 'waist_cm': 91}),
    );
    repository.loads[0].reply.complete(_dayA);
    await _settle();

    expect(_loaded(states), [same(_dayB)]);
    expect(states.last, isA<MetricsSaved>());
    expect(repository.saved, [
      {'date': '2026-11-20', 'waist_cm': 91},
    ]);
  });
}
