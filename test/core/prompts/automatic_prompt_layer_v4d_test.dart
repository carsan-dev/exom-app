// L5-F3 with L5-D3: the launch mounts Inicio under the X (V4dHandoff) and the
// opening plays over it. The automatic prompt (quick tour or Sunday recap) must
// not be asked for, nor shown, until the opening has finished and Inicio is
// usable (the curtain clears the hand-off at that moment). Red before F3: the
// layer checked on the first frame on /home, so the prompt was revealed by
// the opening.
import 'package:exom_app/core/prompts/automatic_prompt_coordinator.dart';
import 'package:exom_app/core/prompts/automatic_prompt_layer.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/splash/presentation/v4d/v4d_handoff.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'automatic_prompt_fakes.dart';

const _due = AutomaticPromptSession(
  uid: 'uid-A',
  email: 'a@exom.test',
  tutorialDue: true,
);

Finder get _tutorialPrompt =>
    find.textContaining(RegExp('quieres un recorrido', caseSensitive: false));

/// Counts the calls to [nextPrompt].
class CountingCoordinator extends AutomaticPromptCoordinator {
  CountingCoordinator({
    required super.store,
    required super.loadRecaps,
    required super.clock,
  });

  int calls = 0;

  @override
  Future<AutomaticPrompt> nextPrompt({
    required String uid,
    String? email,
    required bool tutorialDue,
    bool Function()? isStillCurrent,
  }) {
    calls++;
    return super.nextPrompt(
      uid: uid,
      email: email,
      tutorialDue: tutorialDue,
      isStillCurrent: isStillCurrent,
    );
  }
}

void main() {
  late FakeAutomaticPromptStore store;
  late FakeRecapLoader loader;
  late int sessionReads;
  late CountingCoordinator coordinator;

  setUp(() {
    store = FakeAutomaticPromptStore();
    loader = FakeRecapLoader();
    sessionReads = 0;
    coordinator = CountingCoordinator(
      store: store,
      loadRecaps: loader.call,
      // A Monday: only the tour can be offered.
      clock: () => DateTime(2026, 11, 23, 10),
    );
    V4dHandoff.reset();
  });
  tearDown(V4dHandoff.reset);

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: [
              const SizedBox.expand(child: Text('HOME')),
              AutomaticPromptLayer(
                coordinator: coordinator,
                active: true,
                readSession: () {
                  sessionReads++;
                  return _due;
                },
                onStartTutorial: () {},
                onOpenRecap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('during the opening nothing is asked or shown; once Inicio is '
      'usable the prompt appears', (tester) async {
    V4dHandoff.current.value = const V4dOpening.waiting(
      centre: Offset(195, 422),
      reduced: false,
    );
    await pump(tester);
    expect(_tutorialPrompt, findsNothing);
    expect(sessionReads, 0);
    expect(coordinator.calls, 0);

    // The opening plays: still nothing.
    V4dHandoff.current.value = const V4dOpening(
      elapsed: 400,
      centre: Offset(195, 422),
      reduced: false,
    );
    await tester.pump();
    await tester.pump();
    expect(_tutorialPrompt, findsNothing);
    expect(sessionReads, 0);

    // The curtain finishes: Inicio is usable.
    V4dHandoff.clear();
    await tester.pump();
    await tester.pump();
    expect(_tutorialPrompt, findsOneWidget);
    // Exactly one coordinator call after clear(), not one per build.
    expect(coordinator.calls, 1);
  });

  testWidgets('without a hand-off the prompt appears after the first frame, '
      'as before', (tester) async {
    await pump(tester);
    expect(_tutorialPrompt, findsOneWidget);
  });
}
