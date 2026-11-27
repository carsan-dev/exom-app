// L4 unit 4: MetricsBloc gains an additive history load for the «Progreso»
// view. The existing load/save events keep their exact state sequences.
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

BodyMetricEntity _weight(String id, DateTime date, double kg) =>
    BodyMetricEntity(id: id, date: date, weightKg: kg);

final _latest = BodyMetricEntity(
  id: 'latest',
  date: DateTime(2026, 11, 18),
  weightKg: 68.4,
  waistCm: 74,
);

class _Repository extends Fake implements MetricsRepository {
  final historyCalls = <Completer<List<BodyMetricEntity>>>[];
  final latestCalls = <String?>[];
  BodyMetricEntity? latest = _latest;
  Object? latestError;
  final saved = <Map<String, dynamic>>[];

  @override
  Future<List<BodyMetricEntity>> getWeightHistory() {
    final completer = Completer<List<BodyMetricEntity>>();
    historyCalls.add(completer);
    return completer.future;
  }

  @override
  Future<BodyMetricEntity?> getLatestMetric({String? date}) async {
    latestCalls.add(date);
    final error = latestError;
    if (error != null) throw error;
    return latest;
  }

  @override
  Future<BodyMetricEntity> saveMetric(Map<String, dynamic> data) async {
    saved.add({...data});
    return _latest;
  }
}

/// A repository that also reports where each «Progreso» read came from, as
/// the real one does (L4-I12).
class _SourcedRepository extends _Repository implements MetricsHistorySource {
  final sourcedHistoryCalls =
      <Completer<MetricsRead<List<BodyMetricEntity>>>>[];
  bool latestFromCache = false;

  @override
  Future<MetricsRead<List<BodyMetricEntity>>> getWeightHistoryWithSource() {
    final completer = Completer<MetricsRead<List<BodyMetricEntity>>>();
    sourcedHistoryCalls.add(completer);
    return completer.future;
  }

  @override
  Future<MetricsRead<BodyMetricEntity?>> getLatestMetricWithSource() async {
    latestCalls.add(null);
    final error = latestError;
    if (error != null) throw error;
    return MetricsRead(latest, fromCache: latestFromCache);
  }
}

class _Profile extends Fake implements ProfileEntity {}

class _ProfileRepository extends Fake implements ProfileRepository {
  @override
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data) async =>
      _Profile();
}

MetricsBloc _bloc(_Repository repository) => MetricsBloc(
  saveMetricUseCase: SaveMetricUseCase(repository),
  metricsRepository: repository,
  updateProfileUseCase: UpdateProfileUseCase(_ProfileRepository()),
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('history load', () {
    test(
      'success emits loading then the history and the latest record',
      () async {
        final repository = _Repository();
        final bloc = _bloc(repository);
        final states = <MetricsState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const MetricsHistoryRequested());
        await _settle();
        final history = [
          _weight('a', DateTime(2026, 11, 11), 68.8),
          _weight('b', DateTime(2026, 11, 18), 68.4),
        ];
        repository.historyCalls.single.complete(history);
        await _settle();

        expect(states, hasLength(2));
        expect(states.first, isA<MetricsHistoryLoading>());
        final loaded = states.last as MetricsHistoryLoaded;
        expect(loaded.weightHistory, same(history));
        expect(loaded.latest, same(_latest));
        // Latest of all time: no date filter.
        expect(repository.latestCalls, [null]);
        await sub.cancel();
        await bloc.close();
      },
    );

    test('empty history is a loaded state with no points', () async {
      final repository = _Repository()..latest = null;
      final bloc = _bloc(repository);
      bloc.add(const MetricsHistoryRequested());
      await _settle();
      repository.historyCalls.single.complete(const []);
      await _settle();

      final loaded = bloc.state as MetricsHistoryLoaded;
      expect(loaded.weightHistory, isEmpty);
      expect(loaded.latest, isNull);
      await bloc.close();
    });

    test('a failure emits a failure state and a retry loads again', () async {
      final repository = _Repository()..latestError = Exception('boom');
      final bloc = _bloc(repository);
      bloc.add(const MetricsHistoryRequested());
      await _settle();
      repository.historyCalls.single.complete(const []);
      await _settle();

      final failure = bloc.state as MetricsHistoryFailure;
      expect(failure.offline, isFalse);

      repository.latestError = null;
      bloc.add(const MetricsHistoryRequested());
      await _settle();
      expect(bloc.state, isA<MetricsHistoryLoading>());
      repository.historyCalls.last.complete([
        _weight('a', DateTime(2026, 11, 18), 68.4),
      ]);
      await _settle();
      expect(bloc.state, isA<MetricsHistoryLoaded>());
      expect(repository.historyCalls, hasLength(2));
      await bloc.close();
    });

    test('a connection error is reported as offline', () async {
      final repository = _Repository()
        ..latestError = DioException(
          requestOptions: RequestOptions(path: '/metrics/latest'),
          type: DioExceptionType.connectionError,
        );
      final bloc = _bloc(repository);
      bloc.add(const MetricsHistoryRequested());
      await _settle();
      repository.historyCalls.single.complete(const []);
      await _settle();

      expect((bloc.state as MetricsHistoryFailure).offline, isTrue);
      await bloc.close();
    });

    test('a response from an older overlapping load is discarded', () async {
      final repository = _Repository();
      final bloc = _bloc(repository);
      final states = <MetricsState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const MetricsHistoryRequested());
      await _settle();
      bloc.add(const MetricsHistoryRequested());
      await _settle();
      expect(repository.historyCalls, hasLength(2));

      final fresh = [_weight('new', DateTime(2026, 11, 18), 68.4)];
      final stale = [_weight('old', DateTime(2026, 11, 11), 70)];
      repository.historyCalls[1].complete(fresh);
      await _settle();
      repository.historyCalls[0].complete(stale);
      await _settle();

      final loaded = states.whereType<MetricsHistoryLoaded>().toList();
      expect(loaded, hasLength(1));
      expect(loaded.single.weightHistory, same(fresh));
      expect((bloc.state as MetricsHistoryLoaded).weightHistory, same(fresh));
      await sub.cancel();
      await bloc.close();
    });

    test('a load interrupted by a session change shows no data', () async {
      final repository = _Repository()
        ..latestError = const LocalSessionChanged();
      final bloc = _bloc(repository);
      bloc.add(const MetricsHistoryRequested());
      await _settle();
      repository.historyCalls.single.complete([
        _weight('other-user', DateTime(2026, 11, 18), 90),
      ]);
      await _settle();

      expect(bloc.state, isA<MetricsHistoryFailure>());
      expect(bloc.state, isNot(isA<MetricsHistoryLoaded>()));
      await bloc.close();
    });
  });

  // L4-I12: the loaded state says what comes from the offline cache and why
  // the latest record is missing.
  group('history load: origin and missing latest', () {
    final weights = [
      _weight('a', DateTime(2026, 11, 11), 68.8),
      _weight('b', DateTime(2026, 11, 18), 68.4),
    ];

    Future<MetricsHistoryLoaded> loadSourced(
      _SourcedRepository repository, {
      required bool historyFromCache,
    }) async {
      final bloc = _bloc(repository);
      addTearDown(bloc.close);
      bloc.add(const MetricsHistoryRequested());
      await _settle();
      repository.sourcedHistoryCalls.single.complete(
        MetricsRead(weights, fromCache: historyFromCache),
      );
      await _settle();
      // The plain reads are not used when the repository reports origin.
      expect(repository.historyCalls, isEmpty);
      return bloc.state as MetricsHistoryLoaded;
    }

    test('both from the network → no marks', () async {
      final loaded = await loadSourced(
        _SourcedRepository(),
        historyFromCache: false,
      );
      expect(loaded.weightHistory, same(weights));
      expect(loaded.latest, same(_latest));
      expect(loaded.historyFromCache, isFalse);
      expect(loaded.latestFromCache, isFalse);
      expect(loaded.latestUnavailability, MetricsLatestUnavailability.none);
    });

    test('the origin of each half is propagated', () async {
      final cachedHistory = await loadSourced(
        _SourcedRepository(),
        historyFromCache: true,
      );
      expect(cachedHistory.historyFromCache, isTrue);
      expect(cachedHistory.latestFromCache, isFalse);

      final cachedLatest = await loadSourced(
        _SourcedRepository()..latestFromCache = true,
        historyFromCache: false,
      );
      expect(cachedLatest.historyFromCache, isFalse);
      expect(cachedLatest.latestFromCache, isTrue);
      expect(cachedLatest.latest, same(_latest));
      expect(
        cachedLatest.latestUnavailability,
        MetricsLatestUnavailability.none,
      );
    });

    test('latest failing offline with a history → offline', () async {
      final loaded = await loadSourced(
        _SourcedRepository()
          ..latestError = DioException(
            requestOptions: RequestOptions(path: '/metrics/latest'),
            type: DioExceptionType.connectionError,
          ),
        historyFromCache: true,
      );
      expect(loaded.weightHistory, same(weights));
      expect(loaded.latest, isNull);
      expect(loaded.historyFromCache, isTrue);
      expect(loaded.latestFromCache, isFalse);
      expect(loaded.latestUnavailability, MetricsLatestUnavailability.offline);
    });

    for (final entry in <String, Object>{
      '5xx': DioException(
        requestOptions: RequestOptions(path: '/metrics/latest'),
        response: Response<Object?>(
          requestOptions: RequestOptions(path: '/metrics/latest'),
          statusCode: 503,
        ),
        type: DioExceptionType.badResponse,
      ),
      'FormatException': const FormatException('Unexpected'),
    }.entries) {
      test('latest failing with ${entry.key} with a history → error', () async {
        final loaded = await loadSourced(
          _SourcedRepository()..latestError = entry.value,
          historyFromCache: false,
        );
        expect(loaded.latest, isNull);
        expect(loaded.latestUnavailability, MetricsLatestUnavailability.error);
      });
    }

    test('a repository without origin reads as the network', () async {
      final repository = _Repository()
        ..latestError = DioException(
          requestOptions: RequestOptions(path: '/metrics/latest'),
          type: DioExceptionType.connectionError,
        );
      final bloc = _bloc(repository);
      addTearDown(bloc.close);
      bloc.add(const MetricsHistoryRequested());
      await _settle();
      repository.historyCalls.single.complete(weights);
      await _settle();
      final loaded = bloc.state as MetricsHistoryLoaded;
      expect(loaded.historyFromCache, isFalse);
      expect(loaded.latestFromCache, isFalse);
      expect(loaded.latestUnavailability, MetricsLatestUnavailability.offline);
    });

    test('an older cached response is discarded by the epoch', () async {
      final repository = _SourcedRepository();
      final bloc = _bloc(repository);
      addTearDown(bloc.close);
      final states = <MetricsState>[];
      final sub = bloc.stream.listen(states.add);
      addTearDown(sub.cancel);

      bloc.add(const MetricsHistoryRequested());
      await _settle();
      bloc.add(const MetricsHistoryRequested());
      await _settle();
      expect(repository.sourcedHistoryCalls, hasLength(2));

      final fresh = [_weight('new', DateTime(2026, 11, 18), 68.4)];
      repository.sourcedHistoryCalls[1].complete(MetricsRead(fresh));
      await _settle();
      repository.sourcedHistoryCalls[0].complete(
        MetricsRead([
          _weight('old', DateTime(2026, 11, 11), 70),
        ], fromCache: true),
      );
      await _settle();

      final loaded = states.whereType<MetricsHistoryLoaded>().toList();
      expect(loaded, hasLength(1));
      expect(loaded.single.weightHistory, same(fresh));
      expect(loaded.single.historyFromCache, isFalse);
    });

    test('a session change in the latest half shows no data', () async {
      final repository = _SourcedRepository()
        ..latestError = const LocalSessionChanged();
      final bloc = _bloc(repository);
      addTearDown(bloc.close);
      bloc.add(const MetricsHistoryRequested());
      await _settle();
      repository.sourcedHistoryCalls.single.complete(
        MetricsRead([
          _weight('other-user', DateTime(2026, 11, 18), 90),
        ], fromCache: true),
      );
      await _settle();
      expect(bloc.state, isA<MetricsHistoryFailure>());
    });

    test('the day form keeps the plain dated read', () async {
      final repository = _SourcedRepository();
      final bloc = _bloc(repository);
      addTearDown(bloc.close);
      bloc.add(const MetricsLoadRequested(date: '2026-11-18'));
      await _settle();
      await _settle();
      expect((bloc.state as MetricsLoaded).current, same(_latest));
      expect(repository.latestCalls, ['2026-11-18']);
      expect(repository.sourcedHistoryCalls, isEmpty);
    });

    test('a cancelled latest request shows no data', () async {
      final repository = _SourcedRepository()
        ..latestError = DioException(
          requestOptions: RequestOptions(path: '/metrics/latest'),
          type: DioExceptionType.cancel,
        );
      final bloc = _bloc(repository);
      addTearDown(bloc.close);
      bloc.add(const MetricsHistoryRequested());
      await _settle();
      repository.sourcedHistoryCalls.single.complete(MetricsRead(weights));
      await _settle();
      expect(bloc.state, isA<MetricsHistoryFailure>());
    });
  });

  group('existing events keep their sequences', () {
    test('load: Loading then Loaded(current)', () async {
      final repository = _Repository();
      final bloc = _bloc(repository);
      final states = <MetricsState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const MetricsLoadRequested(date: '2026-11-18'));
      await _settle();
      await _settle();
      expect(states.map((s) => s.runtimeType), [MetricsLoading, MetricsLoaded]);
      expect((states.last as MetricsLoaded).current, same(_latest));
      expect(repository.latestCalls, ['2026-11-18']);
      expect(repository.historyCalls, isEmpty);
      await sub.cancel();
      await bloc.close();
    });

    test('load failure still degrades to Loaded(null)', () async {
      final repository = _Repository()..latestError = Exception('x');
      final bloc = _bloc(repository);
      bloc.add(const MetricsLoadRequested());
      await _settle();
      await _settle();
      expect(bloc.state, isA<MetricsLoaded>());
      expect((bloc.state as MetricsLoaded).current, isNull);
      await bloc.close();
    });

    test('save: Saving then Saved', () async {
      final repository = _Repository();
      final bloc = _bloc(repository);
      final states = <MetricsState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const MetricsSaveRequested({'date': '2026-11-18'}));
      await _settle();
      await _settle();
      expect(states.map((s) => s.runtimeType), [MetricsSaving, MetricsSaved]);
      expect(repository.saved, [
        {'date': '2026-11-18'},
      ]);
      await sub.cancel();
      await bloc.close();
    });
  });
}
