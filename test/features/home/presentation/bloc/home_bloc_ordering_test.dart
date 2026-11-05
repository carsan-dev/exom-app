import 'dart:async';

import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/repositories/home_repository.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Call {
  _Call(this.date, this.includeSharedData);
  final DateTime? date;
  final bool includeSharedData;
  final result = Completer<HomeSummaryEntity>();
}

class _Repository implements HomeRepository {
  final calls = <_Call>[];

  @override
  Future<HomeSummaryEntity> getHomeSummary({
    DateTime? date,
    bool includeSharedData = true,
  }) {
    final call = _Call(date, includeSharedData);
    calls.add(call);
    return call.result.future;
  }
}

HomeSummaryEntity _summary(String training, {String? name}) =>
    HomeSummaryEntity(trainingName: training, clientName: name);

HomeSummaryEntity _loaded(HomeBloc bloc) =>
    (bloc.state as HomeLoaded).summary;

Future<void> _flush() => pumpEventQueue();

({HomeBloc bloc, _Repository repo}) _fixture() {
  final repo = _Repository();
  final bloc = HomeBloc(getHomeSummaryUseCase: GetHomeSummaryUseCase(repo));
  addTearDown(bloc.close);
  return (bloc: bloc, repo: repo);
}

Future<void> _initial(({HomeBloc bloc, _Repository repo}) f) async {
  f.bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 1)));
  await _flush();
  f.repo.calls[0].result.complete(_summary('day1', name: 'v1'));
  await _flush();
}

void main() {
  test('slow date A then fast date B: B stays on screen', () async {
    final f = _fixture();
    await _initial(f);
    f.bloc.add(HomeDateSelected(DateTime(2026, 11, 2)));
    await _flush();
    f.bloc.add(HomeDateSelected(DateTime(2026, 11, 3)));
    await _flush();
    f.repo.calls[2].result.complete(_summary('B'));
    await _flush();
    expect(_loaded(f.bloc).trainingName, 'B');
    f.repo.calls[1].result.complete(_summary('A'));
    await _flush();
    expect(_loaded(f.bloc).trainingName, 'B');
    expect(_loaded(f.bloc).clientName, 'v1');
  });

  test('date request holding v1 cannot overwrite a newer refresh (v2)', () async {
    final f = _fixture();
    await _initial(f);
    f.bloc.add(HomeDateSelected(DateTime(2026, 11, 2)));
    await _flush();
    expect(f.repo.calls[1].includeSharedData, isFalse);
    f.bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 2)));
    await _flush();
    expect(f.repo.calls[2].includeSharedData, isTrue);
    f.repo.calls[2].result.complete(_summary('refresh', name: 'v2'));
    await _flush();
    expect(_loaded(f.bloc).clientName, 'v2');
    f.repo.calls[1].result.complete(_summary('stale'));
    await _flush();
    expect(_loaded(f.bloc).trainingName, 'refresh');
    expect(_loaded(f.bloc).clientName, 'v2');
    // Cache is v2: a later date change reuses it.
    f.bloc.add(HomeDateSelected(DateTime(2026, 11, 3)));
    await _flush();
    expect(f.repo.calls[3].includeSharedData, isFalse);
    f.repo.calls[3].result.complete(_summary('next'));
    await _flush();
    expect(_loaded(f.bloc).clientName, 'v2');
  });

  test('date request started during a pending refresh fetches full data', () async {
    final f = _fixture();
    await _initial(f);
    f.bloc.add(HomeLoadRequested(date: DateTime(2026, 11, 1)));
    await _flush();
    f.bloc.add(HomeDateSelected(DateTime(2026, 11, 2)));
    await _flush();
    expect(f.repo.calls[2].includeSharedData, isTrue);
    f.repo.calls[2].result.complete(_summary('B', name: 'v3'));
    await _flush();
    f.repo.calls[1].result.complete(_summary('refresh', name: 'v2'));
    await _flush();
    expect(_loaded(f.bloc).trainingName, 'B');
    expect(_loaded(f.bloc).clientName, 'v3');
  });
}
