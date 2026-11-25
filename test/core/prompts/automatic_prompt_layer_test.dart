import 'dart:async';

import 'package:exom_app/core/prompts/automatic_prompt_coordinator.dart';
import 'package:exom_app/core/prompts/automatic_prompt_layer.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'automatic_prompt_fakes.dart';

const _sundayTitle = 'Hoy toca tu recap';
const _tutorialTitle = '¿Quieres un recorrido rápido?';
const _dontShowAgain = 'No volver a mostrar';

/// The prompt layer as MainShell mounts it: on /home, over the shell, with a
/// real router so «Rellenar recap» can be followed to /recap.
class _Harness {
  _Harness({required this.coordinator, this.session});

  final AutomaticPromptCoordinator coordinator;
  AutomaticPromptSession? session;
  int tutorialStarts = 0;

  /// The shell is on /home.
  final active = ValueNotifier<bool>(true);

  late final GoRouter router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => Scaffold(
          body: Stack(
            children: [
              const SizedBox.expand(child: Text('HOME')),
              ValueListenableBuilder<bool>(
                valueListenable: active,
                builder: (context, isActive, _) => AutomaticPromptLayer(
                  coordinator: coordinator,
                  active: isActive,
                  readSession: () => session,
                  onStartTutorial: () => tutorialStarts++,
                  onOpenRecap: () => router.push('/recap'),
                ),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/recap',
        builder: (context, state) => const Scaffold(body: Text('RECAP PAGE')),
      ),
    ],
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pump();
    await tester.pump();
  }
}

const _sessionA = AutomaticPromptSession(
  uid: 'uid-A',
  email: 'a@exom.test',
  tutorialDue: false,
);

void main() {
  late FakeAutomaticPromptStore store;
  late FakeRecapLoader loader;
  late DateTime now;

  AutomaticPromptCoordinator launch() => AutomaticPromptCoordinator(
    store: store,
    loadRecaps: loader.call,
    clock: () => now,
  );

  setUp(() {
    store = FakeAutomaticPromptStore();
    loader = FakeRecapLoader();
    now = sunday;
  });

  testWidgets('Sunday, recap not sent: reminder shown; Omitir closes it', (
    tester,
  ) async {
    final harness = _Harness(coordinator: launch(), session: _sessionA);
    await harness.pump(tester);
    expect(find.text(_sundayTitle), findsOneWidget);
    expect(
      find.text('Cuéntame cómo ha ido la semana. Son cinco pasos.'),
      findsOneWidget,
    );
    expect(find.text('Rellenar recap'), findsOneWidget);
    expect(find.text(_dontShowAgain), findsOneWidget);
    expect(find.textContaining('Con eso ajusto tu plan'), findsNothing);

    await tester.tap(find.text('Omitir'));
    await tester.pump();
    expect(find.text(_sundayTitle), findsNothing);
    expect(store.sundayOff, isEmpty);
    expect(store.sundayLast['a@exom.test'], '2026-11-22');
  });

  testWidgets('checkbox + Rellenar recap: goes to /recap, never again', (
    tester,
  ) async {
    final harness = _Harness(coordinator: launch(), session: _sessionA);
    await harness.pump(tester);
    await tester.tap(find.text(_dontShowAgain));
    await tester.pump();
    await tester.tap(find.text('Rellenar recap'));
    await tester.pumpAndSettle();
    expect(find.text('RECAP PAGE'), findsOneWidget);
    expect(store.sundayOff, {'a@exom.test'});
  });

  testWidgets('checkbox + Omitir: persisted as never again', (tester) async {
    final harness = _Harness(coordinator: launch(), session: _sessionA);
    await harness.pump(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Omitir'));
    await tester.pump();
    expect(store.sundayOff, {'a@exom.test'});
  });

  testWidgets('recap already sent: no reminder', (tester) async {
    loader.recaps = [recapOfWeek(thisWeekMonday, 'SUBMITTED')];
    final harness = _Harness(coordinator: launch(), session: _sessionA);
    await harness.pump(tester);
    expect(find.text(_sundayTitle), findsNothing);
  });

  testWidgets('session not settled yet: nothing until it is', (tester) async {
    final harness = _Harness(coordinator: launch());
    await harness.pump(tester);
    expect(find.text(_sundayTitle), findsNothing);
    expect(loader.calls, 0);
  });

  testWidgets('left /home mid-fetch: nothing shown, checked again on return', (
    tester,
  ) async {
    final pending = Completer<List<RecapEntity>>();
    var calls = 0;
    final coordinator = AutomaticPromptCoordinator(
      store: store,
      loadRecaps: () {
        calls++;
        return calls == 1 ? pending.future : Future.value(const []);
      },
      clock: () => now,
    );
    final harness = _Harness(coordinator: coordinator, session: _sessionA);
    await harness.pump(tester);
    expect(calls, 1);

    harness.active.value = false;
    await tester.pump();
    pending.complete(const []);
    await tester.pump();
    await tester.pump();
    expect(find.text(_sundayTitle), findsNothing);
    expect(store.sundayLast, isEmpty);

    harness.active.value = true;
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
    expect(find.text(_sundayTitle), findsOneWidget);
  });

  group('quick-tour prompt', () {
    const due = AutomaticPromptSession(
      uid: 'uid-A',
      email: 'a@exom.test',
      tutorialDue: true,
    );

    setUp(() => now = monday);

    testWidgets('tutorial due on a Monday: the tutorial prompt with the '
        'checkbox', (tester) async {
      final harness = _Harness(coordinator: launch(), session: due);
      await harness.pump(tester);
      expect(find.text(_tutorialTitle), findsOneWidget);
      expect(find.text(_sundayTitle), findsNothing);
      expect(find.text(_dontShowAgain), findsOneWidget);
      expect(loader.calls, 0);
    });

    testWidgets('tutorial due on a Sunday with the recap not sent: only the '
        'Sunday reminder', (tester) async {
      now = sunday;
      final harness = _Harness(coordinator: launch(), session: due);
      await harness.pump(tester);
      expect(find.text(_sundayTitle), findsOneWidget);
      expect(find.text(_tutorialTitle), findsNothing);
    });

    testWidgets('Omitir without checkbox: not persisted, not again this '
        'session, offered on the next launch', (tester) async {
      final coordinator = launch();
      await _Harness(coordinator: coordinator, session: due).pump(tester);
      await tester.tap(find.text('Omitir'));
      await tester.pump();
      expect(find.text(_tutorialTitle), findsNothing);
      expect(store.tutorialComplete, isEmpty);

      // Shell rebuilt in the same session.
      await tester.pumpWidget(const SizedBox());
      await _Harness(coordinator: coordinator, session: due).pump(tester);
      expect(find.text(_tutorialTitle), findsNothing);
      expect(find.text(_sundayTitle), findsNothing);

      // Next launch.
      await tester.pumpWidget(const SizedBox());
      await _Harness(coordinator: launch(), session: due).pump(tester);
      expect(find.text(_tutorialTitle), findsOneWidget);
    });

    testWidgets('Omitir with checkbox: never again', (tester) async {
      await _Harness(coordinator: launch(), session: due).pump(tester);
      await tester.tap(find.text(_dontShowAgain));
      await tester.pump();
      await tester.tap(find.text('Omitir'));
      await tester.pump();
      expect(store.tutorialComplete, {'a@exom.test'});
    });

    testWidgets('Empezar guía: starts the tour, persists nothing', (
      tester,
    ) async {
      final harness = _Harness(coordinator: launch(), session: due);
      await harness.pump(tester);
      await tester.tap(find.text(_dontShowAgain));
      await tester.pump();
      await tester.tap(find.text('Empezar guía'));
      await tester.pump();
      expect(harness.tutorialStarts, 1);
      expect(find.text(_tutorialTitle), findsNothing);
      expect(store.tutorialComplete, isEmpty);
    });

    testWidgets('tutorial complete on a Monday: nothing offered', (
      tester,
    ) async {
      now = monday;
      await _Harness(coordinator: launch(), session: _sessionA).pump(tester);
      expect(find.text(_tutorialTitle), findsNothing);
      expect(find.text(_sundayTitle), findsNothing);
    });
  });
}
