// L6 C-D1: a summary load that never answers (opened without network, the
// request stuck below the bloc) must not hold Inicio forever. The reconnection
// reload waits for a load in flight (INICIO-RED r2), so the wait is bounded:
// past [HomeBloc.summaryTimeout] the load counts as a connectivity failure,
// Inicio reports it and the pending reconnection reloads. «Reintentar» always
// asks again, and a late answer never replaces a newer one.
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

  /// Answers every request still pending, so closing the bloc (which waits
  /// for its handlers) never hangs the test.
  void releaseAll() {
    for (final slot in _answers) {
      if (!slot.isCompleted) slot.complete(_stale);
    }
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
const _debounce = Duration(seconds: 2);
const _timeout = Duration(seconds: 20);

class _Harness {
  _Harness(this.repo, this.network, this.bloc);
  final _HomeRepository repo;
  final StreamController<bool> network;
  final HomeBloc bloc;

  Future<void> online(WidgetTester tester, bool value) async {
    network.add(value);
    await tester.pump();
  }

  /// Answers what is still pending and lets every bound and timer run out,
  /// so the test ends without work in flight.
  Future<void> finish(WidgetTester tester) async {
    repo.releaseAll();
    await _settle(tester);
    await tester.pump(_timeout * 2);
    await _settle(tester);
  }
}

Future<_Harness> _start(
  WidgetTester tester, {
  void Function(_HomeRepository repo)? answers,
}) async {
  final repo = _HomeRepository();
  answers?.call(repo);
  final network = StreamController<bool>();
  final bloc = HomeBloc(
    getHomeSummaryUseCase: GetHomeSummaryUseCase(repo),
    connectivityChanges: network.stream,
    reconnectDebounce: _debounce,
    summaryTimeout: _timeout,
  )..add(const HomeLoadRequested());
  // Not awaited: close() waits for the handlers, and a handler stuck on a
  // load (what these tests are about) only resumes inside the fake clock,
  // which no longer runs here. Each test ends through [_Harness.finish], so
  // nothing is pending by then.
  addTearDown(() {
    repo.releaseAll();
    unawaited(bloc.close());
    unawaited(network.close());
  });
  await tester.pump();
  await tester.pump();
  return _Harness(repo, network, bloc);
}

/// Lets the timed-out load emit and the zero timer of the pending
/// reconnection run.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(Duration.zero);
  await tester.pump();
}

void main() {
  testWidgets('cold start without network, first load never answers: the '
      'network back reloads once the wait ends, not never', (tester) async {
    // Opening Inicio: the first summary is stuck below the bloc.
    final h = await _start(tester);
    expect(h.bloc.state, isA<HomeLoading>());
    h.repo.answer(1, _fresh);

    await h.online(tester, false);
    await h.online(tester, true);
    await tester.pump(_debounce);
    expect(h.repo.calls, 1, reason: 'the debounce met the load in flight');

    await tester.pump(_timeout - _debounce);
    await _settle(tester);
    expect(h.repo.calls, 2, reason: 'the stuck load no longer holds Inicio');
    expect(h.bloc.state, isA<HomeLoaded>());
    expect((h.bloc.state as HomeLoaded).refreshError, isNull);

    await tester.pump(_timeout * 2);
    expect(h.repo.calls, 2, reason: 'one reload per reconnection');
    await h.finish(tester);
  });

  testWidgets('stale Inicio, a reload stuck in flight: the reconnection '
      'reloads once the wait ends', (tester) async {
    final h = await _start(tester, answers: (repo) => repo.answer(0, _stale));
    expect((h.bloc.state as HomeLoaded).refreshError, isNotNull);

    // A reload started without network («Reintentar», pull to refresh or a
    // previous reconnection) that never answers.
    h.bloc.add(const HomeLoadRequested());
    await tester.pump();
    expect(h.repo.calls, 2);
    h.repo.answer(2, _fresh);

    await h.online(tester, false);
    await h.online(tester, true);
    await tester.pump(_debounce);
    expect(h.repo.calls, 2);

    await tester.pump(_timeout - _debounce);
    await _settle(tester);
    expect(h.repo.calls, 3);
    expect((h.bloc.state as HomeLoaded).refreshError, isNull);
    await h.finish(tester);
  });

  testWidgets('the stuck load ends as a connectivity failure: content kept '
      'and flagged, or the error without content', (tester) async {
    final h = await _start(tester, answers: (repo) => repo.answer(0, _fresh));
    h.bloc.add(const HomeLoadRequested());
    await tester.pump();

    await tester.pump(_timeout);
    await _settle(tester);
    final loaded = h.bloc.state as HomeLoaded;
    expect(loaded.refreshError, startsWith('ApiException(0)'));

    final cold = await _start(tester);
    await tester.pump(_timeout);
    await _settle(tester);
    expect(cold.bloc.state, isA<HomeError>());
    expect(
      (cold.bloc.state as HomeError).message,
      startsWith('ApiException(0)'),
    );
    await h.finish(tester);
    await cold.finish(tester);
  });

  testWidgets('a slow load inside the bound is not cut', (tester) async {
    final h = await _start(tester);
    await tester.pump(_timeout - const Duration(milliseconds: 1));
    h.repo.answer(0, _fresh);
    await _settle(tester);
    expect(h.bloc.state, isA<HomeLoaded>());
    expect((h.bloc.state as HomeLoaded).refreshError, isNull);
    await tester.pump(_timeout);
    expect((h.bloc.state as HomeLoaded).refreshError, isNull);
    await h.finish(tester);
  });

  testWidgets('«Reintentar» asks again at once, even with a load stuck in '
      'flight', (tester) async {
    final h = await _start(tester, answers: (repo) => repo.answer(0, _stale));
    h.bloc.add(const HomeLoadRequested());
    await tester.pump();
    expect(h.repo.calls, 2);

    h.repo.answer(2, _fresh);
    h.bloc.add(const HomeLoadRequested());
    await tester.pump();
    await tester.pump();
    expect(h.repo.calls, 3);
    expect((h.bloc.state as HomeLoaded).refreshError, isNull);
    await h.finish(tester);
  });

  testWidgets('a late answer of an older load never replaces the newer one', (
    tester,
  ) async {
    final h = await _start(tester, answers: (repo) => repo.answer(0, _stale));
    // Older reload, still in flight.
    h.bloc.add(const HomeLoadRequested());
    await tester.pump();
    // «Reintentar»: answered fresh.
    h.repo.answer(2, _fresh);
    h.bloc.add(const HomeLoadRequested());
    await tester.pump();
    await tester.pump();
    expect((h.bloc.state as HomeLoaded).refreshError, isNull);

    // The older one answers from the saved copy, before and after its bound.
    h.repo.answer(1, _stale);
    await _settle(tester);
    expect((h.bloc.state as HomeLoaded).refreshError, isNull);
    await tester.pump(_timeout * 2);
    await _settle(tester);
    expect((h.bloc.state as HomeLoaded).refreshError, isNull);
    await h.finish(tester);
  });

  testWidgets('a load answered after its bound is ignored', (tester) async {
    final h = await _start(tester, answers: (repo) => repo.answer(0, _fresh));
    h.bloc.add(const HomeLoadRequested());
    await tester.pump();
    await tester.pump(_timeout);
    await _settle(tester);
    final failed = h.bloc.state as HomeLoaded;
    expect(failed.refreshError, startsWith('ApiException(0)'));

    // «Reintentar» answered fresh, then the timed-out load lands stale.
    h.repo.answer(2, _fresh);
    h.bloc.add(const HomeLoadRequested());
    await _settle(tester);
    expect((h.bloc.state as HomeLoaded).refreshError, isNull);
    h.repo.answer(1, _stale);
    await _settle(tester);
    expect((h.bloc.state as HomeLoaded).refreshError, isNull);
    await h.finish(tester);
  });

  testWidgets('closing the bloc with a load in flight cancels its bound: no '
      'timer outlives the bloc', (tester) async {
    // Signing out or switching account disposes the shell while the summary
    // is still in flight. The bound of that wait belongs to the bloc: once it
    // is closed nothing may keep a timer running (the test binding fails the
    // test on any timer still pending at its end).
    final repo = _HomeRepository();
    final bloc = HomeBloc(
      getHomeSummaryUseCase: GetHomeSummaryUseCase(repo),
      summaryTimeout: _timeout,
    )..add(const HomeLoadRequested());
    await tester.pump();
    expect(repo.calls, 1);
    expect(bloc.state, isA<HomeLoading>());

    // Not awaited, as the shell does not await it: close() waits for the
    // handler, which stays on the load that never answers.
    unawaited(bloc.close());
    await tester.pump();
  });
}
