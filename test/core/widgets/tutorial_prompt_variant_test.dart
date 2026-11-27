// L5-F3 r2: TutorialPromptDialog is shared with the Sunday recap reminder
// (C5b), so the repaint is opt-in. The default keeps the exact a7d60be look
// (radius 28, shadow, centred, explore icon, ElevatedButton); only
// `redesigned: true` (the quick-tour prompt) paints the flat L5 card.
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/recap_sunday_prompt_dialog.dart';
import 'package:exom_app/core/widgets/tutorial_prompt_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';

const _cardKey = Key('tutorial-prompt-card');

Finder get _legacyCard => find
    .descendant(
      of: find.byType(TutorialPromptDialog),
      matching: find.byType(Container),
    )
    .first;

void main() {
  group('default variant keeps the pre-F3 look', () {
    testWidgets('explore icon, radius 28, shadow, mixed-case title, '
        'ElevatedButton', (tester) async {
      await pumpComponent(
        tester,
        TutorialPromptDialog(onStart: () {}, onSkip: () {}),
        wrapInScaffold: false,
      );
      expect(find.byIcon(ExomIcons.explore), findsOneWidget);
      expect(find.byKey(_cardKey), findsNothing);
      final decoration =
          tester.widget<Container>(_legacyCard).decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(28));
      expect(decoration.boxShadow, isNotEmpty);
      expect(find.text('¿Quieres un recorrido rápido?'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(ExomPrimaryButton), findsNothing);
      expect(find.byType(ExomQuietButton), findsNothing);
    });

    testWidgets('Sunday reminder: own icon, same card as before', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        RecapSundayPromptDialog(
          onFill: () {},
          onSkip: () {},
          dontShowAgain: false,
          onDontShowAgainChanged: (_) {},
        ),
        wrapInScaffold: false,
      );
      expect(find.byIcon(ExomIcons.barChart), findsOneWidget);
      expect(find.byKey(_cardKey), findsNothing);
      final decoration =
          tester.widget<Container>(_legacyCard).decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(28));
      expect(find.text('Hoy toca tu recap'), findsOneWidget);
      expect(find.text('Rellenar recap'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  testWidgets(
    'redesigned: flat radius-4 card without icon when the icon is null',
    (tester) async {
      await pumpComponent(
        tester,
        TutorialPromptDialog(
          redesigned: true,
          icon: null,
          onStart: () {},
          onSkip: () {},
        ),
        wrapInScaffold: false,
      );
      expect(find.byKey(_cardKey), findsOneWidget);
      expect(find.byIcon(ExomIcons.explore), findsNothing);
      expect(find.byType(ExomPrimaryButton), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    },
  );
}
