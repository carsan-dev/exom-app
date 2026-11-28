// L5-F3 (R1): smoke tests of the quick tour and its prompt, written before
// touching them. They pin the behaviour the repaint must keep: the eight steps
// in their order and destinations, the drawer opened once for the last two
// steps, «Listo» completing the tour, no skip or back inside the tour, and the
// prompt's same text and two actions. Button labels are matched without case
// because the design system paints the lime action in upper case.
import 'package:exom_app/core/widgets/tutorial_overlay.dart';
import 'package:exom_app/core/widgets/tutorial_prompt_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';

Finder _label(String text) => find.textContaining(
  RegExp('^${RegExp.escape(text)}\$', caseSensitive: false),
);

const _titles = [
  'Inicio',
  'Entrenamientos',
  'Dietas',
  'Calendario',
  'Retos',
  'Perfil',
  'Recap semanal',
  'Feedback',
];

Finder _title(String text) => find.textContaining(
  RegExp('^${RegExp.escape(text)}\$', caseSensitive: false),
);

class _Calls {
  final routes = <String>[];
  int opened = 0;
  int closed = 0;
  int completed = 0;
}

Future<_Calls> _pumpOverlay(
  WidgetTester tester, {
  bool disableAnimations = false,
  Locale locale = const Locale('es'),
}) async {
  final calls = _Calls();
  await pumpComponent(
    tester,
    TutorialOverlay(
      onNavigate: calls.routes.add,
      onOpenDrawer: () => calls.opened++,
      onCloseDrawer: () => calls.closed++,
      onComplete: () => calls.completed++,
      drawerItemKeys: const [],
    ),
    wrapInScaffold: false,
    disableAnimations: disableAnimations,
    locale: locale,
  );
  return calls;
}

/// Taps the step's single action and lets the drawer waits (350/250 ms) and
/// the bubble switch finish.
Future<void> _next(WidgetTester tester, String label) async {
  await tester.tap(_label(label));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('TutorialOverlay smoke', () {
    for (final reduced in [false, true]) {
      testWidgets('eight steps in order, drawer for the last two, «Listo» '
          'completes (reduced: $reduced)', (tester) async {
        final calls = await _pumpOverlay(tester, disableAnimations: reduced);
        for (var i = 0; i < _titles.length; i++) {
          expect(_title(_titles[i]), findsOneWidget, reason: 'step ${i + 1}');
          // No skip and no back inside the tour.
          expect(
            find.textContaining(
              RegExp('omitir|atrás|volver', caseSensitive: false),
            ),
            findsNothing,
          );
          final last = i == _titles.length - 1;
          expect(_label(last ? 'Listo' : 'Siguiente'), findsOneWidget);
          await _next(tester, last ? 'Listo' : 'Siguiente');
        }
        expect(calls.routes, [
          '/trainings',
          '/diets',
          '/calendar',
          '/challenges',
        ]);
        expect(calls.opened, 1);
        expect(calls.closed, 0);
        expect(calls.completed, 1);
      });
    }

    testWidgets('English copy of the first step', (tester) async {
      await _pumpOverlay(tester, locale: const Locale('en'));
      expect(_title('Home'), findsOneWidget);
      expect(_label('Next'), findsOneWidget);
    });

    testWidgets('taps outside the bubble do nothing', (tester) async {
      final calls = await _pumpOverlay(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_title('Inicio'), findsOneWidget);
      expect(calls.routes, isEmpty);
      expect(calls.completed, 0);
    });
  });

  group('TutorialPromptDialog smoke', () {
    testWidgets('same text and two actions', (tester) async {
      var started = 0;
      var skipped = 0;
      await pumpComponent(
        tester,
        TutorialPromptDialog(onStart: () => started++, onSkip: () => skipped++),
        wrapInScaffold: false,
      );
      expect(_title('¿Quieres un recorrido rápido?'), findsOneWidget);
      expect(
        find.text(
          'Te enseñamos las secciones principales de la app en unos segundos.',
        ),
        findsOneWidget,
      );
      await tester.tap(_label('Empezar guía'));
      await tester.pump();
      await tester.tap(_label('Omitir'));
      await tester.pump();
      expect(started, 1);
      expect(skipped, 1);
    });

    testWidgets('English copy', (tester) async {
      await pumpComponent(
        tester,
        TutorialPromptDialog(onStart: () {}, onSkip: () {}),
        wrapInScaffold: false,
        locale: const Locale('en'),
      );
      expect(_title('Want a quick tour?'), findsOneWidget);
      expect(_label('Start guide'), findsOneWidget);
      expect(_label('Skip'), findsOneWidget);
    });
  });
}
