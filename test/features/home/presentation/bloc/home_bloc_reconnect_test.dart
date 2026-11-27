// L5 INICIO-RED (A1): when the network comes back and Inicio shows stale data
// or an error, the bloc reloads by itself, as «Reintentar» does: once per
// reconnection, after a debounce, never over fresh data nor over a reload
// already in flight.
import 'dart:async';

import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/repositories/home_repository.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Each call takes the next scripted answer; unanswered calls stay pending.
class _HomeRepository implements HomeRepository {
  final _answers = <Completer<HomeSummaryEntity>>[];
  final dates = <DateTime?>[];

  int get calls => dates.length;

  Completer<HomeSummaryEntity> _slot(int index) {
    while (_answers.length <= index) {
      _answers.add(Completer<HomeSummaryEntity>());
    }
    return _answers[index];
  }

  void answer(int index, HomeSummaryEntity summary) =>
      _slot(index).complete(summary);

  void fail(int index) {
    final slot = _slot(index);
    // Handled by the bloc once it asks; not reported as unhandled before.
    slot.future.ignore();
    slot.completeError(StateError('ApiException(0): offline'));
  }

  @override
  Future<HomeSummaryEntity> getHomeSummary({
    DateTime? date,
    bool includeSharedData = true,
  }) {
    final index = dates.length;
    dates.add(date);
    return _slot(index).future;
  }
}

const _stale = HomeSummaryEntity(staleReason: 'ApiException(0): offline');
const _fresh = HomeSummaryEntity();
const _staleRest = HomeSummaryEntity(
  isRestDay: true,
  staleReason: 'ApiException(0): offline',
);
const _debounce = Duration(seconds: 2);

class _Harness {
  _Harness(this.repo, this.network, this.bloc);
  final _HomeRepository repo;
  final StreamController<bool> network;
  final HomeBloc bloc;
}

Future<_Harness> _start(
  WidgetTester tester,
  void Function(_HomeRepository repo) firstAnswer,
) async {
  final repo = _HomeRepository();
  firstAnswer(repo);
  final network = StreamController<bool>();
  final bloc = HomeBloc(
    getHomeSummaryUseCase: GetHomeSummaryUseCase(repo),
    connectivityChanges: network.stream,
    reconnectDebounce: _debounce,
  )..add(const HomeLoadRequested());
  addTearDown(() async {
    await bloc.close();
    await network.close();
  });
  await tester.pump();
  await tester.pump();
  return _Harness(repo, network, bloc);
}

Future<void> _emit(WidgetTester tester, _Harness h, bool online) async {
  h.network.add(online);
  await tester.pump();
}

void main() {
  testWidgets('stale Inicio: offline -> online reloads once, after the '
      'debounce, the day on screen', (tester) async {
    final h = await _start(tester, (repo) => repo.answer(0, _fresh));
    // Another day picked in the week strip, answered from the saved copy.
    final shown = DateTime(2026, 11, 20);
    h.repo.answer(1, _stale);
    h.bloc.add(HomeDateSelected(shown));
    await tester.pump();
    await tester.pump();
    expect((h.bloc.state as HomeLoaded).selectedDate, shown);
    expect((h.bloc.state as HomeLoaded).refreshError, isNotNull);
    h.repo.answer(2, _fresh);

    await _emit(tester, h, false);
    await _emit(tester, h, true);
    await tester.pump(_debounce - const Duration(milliseconds: 1));
    expect(h.repo.calls, 2, reason: 'still inside the debounce');

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(h.repo.calls, 3);
    expect(h.repo.dates.last, shown);
    final state = h.bloc.state as HomeLoaded;
    expect(state.selectedDate, shown);
    expect(state.refreshError, isNull);

    await tester.pump(_debounce * 3);
    expect(h.repo.calls, 3);
  });

  testWidgets('stale rest day: a reconnection reloads it once', (tester) async {
    final h = await _start(tester, (repo) => repo.answer(0, _staleRest));
    expect(h.bloc.state, isA<HomeRestDay>());
    final shown = (h.bloc.state as HomeRestDay).selectedDate;
    h.repo.answer(1, const HomeSummaryEntity(isRestDay: true));

    await _emit(tester, h, false);
    await _emit(tester, h, true);
    await tester.pump(_debounce);
    await tester.pump();
    expect(h.repo.calls, 2);
    expect(h.repo.dates.last, shown);
    expect((h.bloc.state as HomeRestDay).refreshError, isNull);

    await tester.pump(_debounce * 3);
    expect(h.repo.calls, 2);
  });

  testWidgets('fresh Inicio: a reconnection reloads nothing', (tester) async {
    final h = await _start(tester, (repo) => repo.answer(0, _fresh));

    await _emit(tester, h, false);
    await _emit(tester, h, true);
    await tester.pump(_debounce * 3);
    expect(h.repo.calls, 1);
  });

  testWidgets('network flicker inside the debounce: a single reload', (
    tester,
  ) async {
    final h = await _start(tester, (repo) => repo.answer(0, _stale));
    h.repo.answer(1, _fresh);

    for (var i = 0; i < 3; i++) {
      await _emit(tester, h, false);
      await tester.pump(const Duration(milliseconds: 300));
      await _emit(tester, h, true);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(_debounce * 3);
    expect(h.repo.calls, 2);
  });

  testWidgets('back offline before the debounce ends: no reload', (
    tester,
  ) async {
    final h = await _start(tester, (repo) => repo.answer(0, _stale));

    await _emit(tester, h, false);
    await _emit(tester, h, true);
    await tester.pump(const Duration(milliseconds: 500));
    await _emit(tester, h, false);
    await tester.pump(_debounce * 3);
    expect(h.repo.calls, 1);
  });

  testWidgets('repeated "online" without going offline: one reload', (
    tester,
  ) async {
    final h = await _start(tester, (repo) => repo.answer(0, _stale));
    h.repo.answer(1, _stale);

    await _emit(tester, h, false);
    await _emit(tester, h, true);
    await tester.pump(_debounce);
    await tester.pump();
    await _emit(tester, h, true);
    await tester.pump(_debounce * 3);
    expect(h.repo.calls, 2);
  });

  testWidgets('each reconnection while Inicio stays stale reloads once', (
    tester,
  ) async {
    final h = await _start(tester, (repo) => repo.answer(0, _stale));
    h.repo.answer(1, _stale);
    h.repo.answer(2, _fresh);

    await _emit(tester, h, false);
    await _emit(tester, h, true);
    await tester.pump(_debounce);
    await tester.pump();
    expect(h.repo.calls, 2);

    await _emit(tester, h, false);
    await _emit(tester, h, true);
    await tester.pump(_debounce);
    await tester.pump();
    expect(h.repo.calls, 3);
    expect((h.bloc.state as HomeLoaded).refreshError, isNull);
  });

  testWidgets('error without content: a reconnection reloads once, as '
      '«Reintentar» does', (tester) async {
    final h = await _start(tester, (repo) => repo.fail(0));
    expect(h.bloc.state, isA<HomeError>());
    h.repo.answer(1, _fresh);

    await _emit(tester, h, false);
    await _emit(tester, h, true);
    await tester.pump(_debounce);
    await tester.pump();
    expect(h.repo.calls, 2);
    // «Reintentar» on the error asks for today, as the first load did.
    expect(h.repo.dates.last, h.repo.dates.first);
    expect(h.bloc.state, isA<HomeLoaded>());
  });

  testWidgets('a reload already in flight: the reconnection does not start '
      'another one', (tester) async {
    final h = await _start(tester, (repo) => repo.answer(0, _stale));

    // Pull to refresh started and has not answered yet.
    h.bloc.add(const HomeLoadRequested());
    await tester.pump();
    expect(h.repo.calls, 2);

    await _emit(tester, h, false);
    await _emit(tester, h, true);
    await tester.pump(_debounce * 3);
    expect(h.repo.calls, 2);

    h.repo.answer(1, _fresh);
    await tester.pump();
    expect((h.bloc.state as HomeLoaded).refreshError, isNull);
    await tester.pump(_debounce * 3);
    expect(h.repo.calls, 2, reason: 'fresh after it: nothing to retry');
  });

  testWidgets('reload in flight ends stale with the network back: one '
      'reload right after it, and no more', (tester) async {
    final h = await _start(tester, (repo) => repo.answer(0, _stale));

    // Started without network; it answers from the saved copy later.
    h.bloc.add(const HomeLoadRequested());
    await tester.pump();
    await _emit(tester, h, false);
    await _emit(tester, h, true);
    await tester.pump(_debounce);
    expect(h.repo.calls, 2, reason: 'the debounce met a reload in flight');

    h.repo.answer(1, _stale);
    h.repo.answer(2, _stale);
    await tester.pump();
    // The check runs on a zero timer, once the stale state was emitted.
    await tester.pump(Duration.zero);
    await tester.pump();
    expect((h.bloc.state as HomeLoaded).refreshError, isNotNull);
    expect(h.repo.calls, 3);

    await tester.pump(_debounce * 3);
    expect(h.repo.calls, 3, reason: 'at most one reload per reconnection');
  });

  testWidgets('reload in flight ends stale after the network left again: '
      'no reload', (tester) async {
    final h = await _start(tester, (repo) => repo.answer(0, _stale));

    h.bloc.add(const HomeLoadRequested());
    await tester.pump();
    await _emit(tester, h, false);
    await _emit(tester, h, true);
    await tester.pump(_debounce);
    await _emit(tester, h, false);

    h.repo.answer(1, _stale);
    await tester.pump();
    await tester.pump(_debounce * 3);
    expect(h.repo.calls, 2);
  });

  // Real time: closing a bloc inside the fake clock of a widget test never
  // settles. The bloc is built in a zone that records its timers, so the
  // test sees the debounce cancelled by close() itself, not merely ignored
  // when it fires.
  test('closed bloc: close() cancels the pending debounce and stops '
      'listening', () async {
    const debounce = Duration(seconds: 30);
    final repo = _HomeRepository()..answer(0, _stale);
    final network = StreamController<bool>.broadcast();
    addTearDown(network.close);
    final timers = <Timer>[];
    final bloc = runZoned(
      () => HomeBloc(
        getHomeSummaryUseCase: GetHomeSummaryUseCase(repo),
        connectivityChanges: network.stream,
        reconnectDebounce: debounce,
      ),
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          final timer = parent.createTimer(zone, duration, callback);
          if (duration == debounce) timers.add(timer);
          return timer;
        },
      ),
    )..add(const HomeLoadRequested());
    await bloc.stream.firstWhere((state) => state is HomeLoaded);

    network
      ..add(false)
      ..add(true);
    await Future<void>.delayed(Duration.zero);
    expect(timers, hasLength(1));
    expect(timers.single.isActive, isTrue);

    await bloc.close();
    expect(timers.single.isActive, isFalse);
    expect(network.hasListener, isFalse);
    expect(repo.calls, 1);
  });

  testWidgets('without a connectivity stream nothing changes', (tester) async {
    final repo = _HomeRepository()..answer(0, _stale);
    final bloc = HomeBloc(getHomeSummaryUseCase: GetHomeSummaryUseCase(repo))
      ..add(const HomeLoadRequested());
    addTearDown(bloc.close);
    await tester.pump(_debounce * 3);
    expect(repo.calls, 1);
  });
}
