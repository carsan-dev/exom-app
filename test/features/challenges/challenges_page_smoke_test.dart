// L5-B2 «Retos» smoke (docs/plans/rediseno-app-l5-contrato-v2.md, L5-B2:
// "sin tests de página hoy: smoke antes"). Written and run green on the base
// (2e43ef4) before the repaint, and kept green after it: it only checks what
// the page shows and does, never how it is painted.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'challenges_test_support.dart';

bool _anyTextContains(WidgetTester tester, String part) => tester
    .widgetList<Text>(find.byType(Text))
    .any((t) => (t.data ?? t.textSpan?.toPlainText() ?? '').contains(part));

void main() {
  testWidgets('loaded: title, streak, goal, weekly and achievements', (
    tester,
  ) async {
    await pumpChallengesPage(tester, FakeChallengesRepository());

    expect(findTextCi('Mis Retos'), findsOneWidget);
    expect(_anyTextContains(tester, '12'), isTrue);
    expect(findTextCi(kMainGoal.title), findsOneWidget);
    for (final challenge in kWeekly) {
      expect(findTextCi(challenge.title), findsOneWidget);
    }
    expect(find.text('34 / 50 km'), findsOneWidget);
    expect(find.text('3/4 entrenos'), findsOneWidget);
    for (final achievement in kUnlocked) {
      expect(findTextCi(achievement.name), findsOneWidget);
    }
    expect(findTextCi('Ver todos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('«Ver todos» opens every achievement of the catalog', (
    tester,
  ) async {
    await pumpChallengesPage(tester, FakeChallengesRepository());
    expect(findTextCi('50 sesiones'), findsNothing);

    await openAchievementsBoard(tester, 'Ver todos');
    for (final achievement in kCatalog) {
      expect(findTextCi(achievement.name), findsWidgets);
    }
    expect(findTextCi('50 sesiones'), findsOneWidget);
    expect(findTextCi('Racha de 30 días'), findsOneWidget);

    // System back closes it.
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(findTextCi('50 sesiones'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty: no active challenges, achievements still shown', (
    tester,
  ) async {
    await pumpChallengesPage(
      tester,
      FakeChallengesRepository(challenges: const []),
    );
    expect(findTextCi('Sin retos activos'), findsOneWidget);
    expect(
      find.textContaining('Tu entrenador aún no te ha asignado retos'),
      findsOneWidget,
    );
    for (final achievement in kUnlocked) {
      expect(findTextCi(achievement.name), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('no achievements: the empty achievements copy', (tester) async {
    await pumpChallengesPage(
      tester,
      FakeChallengesRepository(achievements: const []),
    );
    expect(findTextCi('Aún no tienes logros desbloqueados'), findsOneWidget);
    expect(findTextCi('Ver todos'), findsOneWidget);
  });

  testWidgets('error: message and retry reloads', (tester) async {
    final repository = FakeChallengesRepository()..failLoad = true;
    await pumpChallengesPage(tester, repository);
    expect(find.text('Error al cargar los retos'), findsOneWidget);

    repository.failLoad = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(findTextCi(kMainGoal.title), findsOneWidget);
  });

  testWidgets('loading: placeholders, then the content', (tester) async {
    final repository = FakeChallengesRepository()..gate = Completer<void>();
    await pumpChallengesPage(tester, repository, settle: false);
    await tester.pump();
    expect(findTextCi(kMainGoal.title), findsNothing);
    expect(tester.takeException(), isNull);

    repository.gate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(findTextCi(kMainGoal.title), findsOneWidget);
  });
}
