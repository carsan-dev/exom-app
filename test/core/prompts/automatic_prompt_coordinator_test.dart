import 'dart:async';

import 'package:exom_app/core/prompts/automatic_prompt_coordinator.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'automatic_prompt_fakes.dart';

const _uidA = 'uid-A';
const _emailA = 'a@exom.test';
const _uidB = 'uid-B';
const _emailB = 'b@exom.test';

void main() {
  late FakeAutomaticPromptStore store;
  late FakeRecapLoader loader;
  late DateTime now;

  AutomaticPromptCoordinator launch() => AutomaticPromptCoordinator(
    store: store,
    loadRecaps: loader.call,
    clock: () => now,
  );

  Future<AutomaticPrompt> next(
    AutomaticPromptCoordinator coordinator, {
    String uid = _uidA,
    String? email = _emailA,
    bool tutorialDue = false,
  }) =>
      coordinator.nextPrompt(uid: uid, email: email, tutorialDue: tutorialDue);

  setUp(() {
    store = FakeAutomaticPromptStore();
    loader = FakeRecapLoader();
    now = sunday;
  });

  group('Sunday recap reminder', () {
    test('Sunday without recap: shown once and the day is recorded', () async {
      final coordinator = launch();
      expect(await next(coordinator), AutomaticPrompt.recapSunday);
      expect(store.sundayLast['a@exom.test'], '2026-11-22');
      // Same session, same Sunday: never twice.
      expect(await next(coordinator), AutomaticPrompt.none);
    });

    test('second open on the same Sunday: not shown, no fetch', () async {
      expect(await next(launch()), AutomaticPrompt.recapSunday);
      final calls = loader.calls;
      expect(await next(launch()), AutomaticPrompt.none);
      expect(loader.calls, calls);
    });

    test('Monday: not shown, nothing fetched or recorded', () async {
      now = monday;
      expect(await next(launch()), AutomaticPrompt.none);
      expect(loader.calls, 0);
      expect(store.sundayLast, isEmpty);
    });

    for (final status in ['SUBMITTED', 'REVIEWED']) {
      test('recap $status this week: not shown, nothing recorded', () async {
        loader.recaps = [recapOfWeek(thisWeekMonday, status)];
        expect(await next(launch()), AutomaticPrompt.none);
        expect(store.sundayLast, isEmpty);
      });
    }

    test('only a draft this week: shown', () async {
      loader.recaps = [recapOfWeek(thisWeekMonday, 'DRAFT')];
      expect(await next(launch()), AutomaticPrompt.recapSunday);
    });

    test('a sent recap of another week does not count', () async {
      loader.recaps = [recapOfWeek(DateTime(2026, 11, 9), 'SUBMITTED')];
      expect(await next(launch()), AutomaticPrompt.recapSunday);
    });

    test(
      'fetch error: not shown, nothing recorded, next open retries',
      () async {
        loader.error = Exception('offline');
        expect(await next(launch()), AutomaticPrompt.none);
        expect(store.sundayLast, isEmpty);
        loader.error = null;
        expect(await next(launch()), AutomaticPrompt.recapSunday);
      },
    );

    test(
      '«No volver a mostrar» + Omitir: never again for that user only',
      () async {
        final coordinator = launch();
        expect(await next(coordinator), AutomaticPrompt.recapSunday);
        await coordinator.resolveRecapSundayPrompt(
          uid: _uidA,
          email: _emailA,
          dontShowAgain: true,
        );
        now = nextSunday;
        expect(await next(launch()), AutomaticPrompt.none);
        expect(
          await next(launch(), uid: _uidB, email: _emailB),
          AutomaticPrompt.recapSunday,
        );
      },
    );

    test('Omitir without the checkbox: back next Sunday', () async {
      final coordinator = launch();
      expect(await next(coordinator), AutomaticPrompt.recapSunday);
      await coordinator.resolveRecapSundayPrompt(
        uid: _uidA,
        email: _emailA,
        dontShowAgain: false,
      );
      expect(store.sundayOff, isEmpty);
      now = nextSunday;
      expect(await next(launch()), AutomaticPrompt.recapSunday);
      expect(store.sundayLast['a@exom.test'], '2026-11-29');
    });

    test('identity that cannot be resolved: nothing shown', () async {
      expect(await next(launch(), uid: ' ', email: null), AutomaticPrompt.none);
      expect(loader.calls, 0);
    });

    test(
      'identity changed while fetching: nothing shown or recorded',
      () async {
        final coordinator = launch();
        final result = await coordinator.nextPrompt(
          uid: _uidA,
          email: _emailA,
          tutorialDue: false,
          isStillCurrent: () => false,
        );
        expect(result, AutomaticPrompt.none);
        expect(store.sundayLast, isEmpty);
      },
    );
  });

  group('quick-tour prompt and staging', () {
    test('Sunday, tour due, recap not sent: only the Sunday reminder this '
        'session; the tour comes on the next launch', () async {
      final coordinator = launch();
      expect(
        await next(coordinator, tutorialDue: true),
        AutomaticPrompt.recapSunday,
      );
      expect(await next(coordinator, tutorialDue: true), AutomaticPrompt.none);
      expect(await next(launch(), tutorialDue: true), AutomaticPrompt.tutorial);
    });

    test('Sunday, tour due, recap sent: the tour', () async {
      loader.recaps = [recapOfWeek(thisWeekMonday, 'REVIEWED')];
      final coordinator = launch();
      expect(
        await next(coordinator, tutorialDue: true),
        AutomaticPrompt.tutorial,
      );
      expect(store.sundayLast, isEmpty);
      expect(await next(coordinator), AutomaticPrompt.none);
    });

    test(
      'Sunday, tour due, fetch error: the tour in the same session',
      () async {
        loader.error = Exception('offline');
        expect(
          await next(launch(), tutorialDue: true),
          AutomaticPrompt.tutorial,
        );
        expect(store.sundayLast, isEmpty);
      },
    );

    test(
      'Sunday, tour due, fetch never answers: the tour after the timeout',
      () async {
        final coordinator = AutomaticPromptCoordinator(
          store: store,
          loadRecaps: () => Completer<List<RecapEntity>>().future,
          clock: () => now,
          recapFetchTimeout: const Duration(milliseconds: 20),
        );
        expect(
          await next(coordinator, tutorialDue: true),
          AutomaticPrompt.tutorial,
        );
        expect(store.sundayLast, isEmpty);
      },
    );

    test('Sunday reminder switched off: the tour without any fetch', () async {
      store.sundayOff.add('a@exom.test');
      expect(await next(launch(), tutorialDue: true), AutomaticPrompt.tutorial);
      expect(loader.calls, 0);
    });

    test(
      'Monday, tour skipped without checkbox: not again this session',
      () async {
        now = monday;
        final coordinator = launch();
        expect(
          await next(coordinator, tutorialDue: true),
          AutomaticPrompt.tutorial,
        );
        await coordinator.resolveTutorialSkip(
          uid: _uidA,
          email: _emailA,
          dontShowAgain: false,
        );
        expect(
          await next(coordinator, tutorialDue: true),
          AutomaticPrompt.none,
        );
        expect(loader.calls, 0);
      },
    );

    test('Omitir without checkbox: offered again on the next launch', () async {
      now = monday;
      final coordinator = launch();
      expect(
        await next(coordinator, tutorialDue: true),
        AutomaticPrompt.tutorial,
      );
      await coordinator.resolveTutorialSkip(
        uid: _uidA,
        email: _emailA,
        dontShowAgain: false,
      );
      expect(store.tutorialComplete, isEmpty);
      expect(await next(launch(), tutorialDue: true), AutomaticPrompt.tutorial);
    });

    test('Omitir with checkbox: persisted as tutorial complete', () async {
      now = monday;
      final coordinator = launch();
      await next(coordinator, tutorialDue: true);
      await coordinator.resolveTutorialSkip(
        uid: _uidA,
        email: _emailA,
        dontShowAgain: true,
      );
      expect(store.tutorialComplete, {'a@exom.test'});
    });

    test('tutorial already complete on a Monday: nothing offered', () async {
      now = monday;
      expect(await next(launch()), AutomaticPrompt.none);
    });
  });

  group('isRecapSentForWeekOf', () {
    test('matches the Monday..Sunday week of the given day', () {
      final recaps = [recapOfWeek(thisWeekMonday, 'SUBMITTED')];
      expect(isRecapSentForWeekOf(recaps, sunday), isTrue);
      expect(isRecapSentForWeekOf(recaps, DateTime(2026, 11, 16)), isTrue);
      expect(isRecapSentForWeekOf(recaps, monday), isFalse);
      expect(
        isRecapSentForWeekOf([recapOfWeek(thisWeekMonday, 'DRAFT')], sunday),
        isFalse,
      );
    });
  });
}
