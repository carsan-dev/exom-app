import 'package:exom_app/core/widgets/recap_sunday_prompt_dialog.dart';
import 'package:exom_app/core/widgets/tutorial_prompt_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'android_nonlinear_text_scaler.dart';
import 'exom_component_harness.dart';

/// Applies the Android 14 nonlinear text scaler under the harness.
Widget _scaled(Widget child, double scale) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: AndroidNonlinearTextScaler(scale)),
    child: child,
  ),
);

Widget _sunday({bool value = false, ValueChanged<bool>? onChanged}) =>
    RecapSundayPromptDialog(
      onFill: () {},
      onSkip: () {},
      dontShowAgain: value,
      onDontShowAgainChanged: onChanged ?? (_) {},
    );

Widget _tutorialWithCheckbox() => TutorialPromptDialog(
  onStart: () {},
  onSkip: () {},
  dontShowAgain: false,
  onDontShowAgainChanged: (_) {},
);

void main() {
  testWidgets('default TutorialPromptDialog has no «No volver a mostrar» row', (
    tester,
  ) async {
    await pumpComponent(
      tester,
      TutorialPromptDialog(onStart: () {}, onSkip: () {}),
      wrapInScaffold: false,
    );
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('No volver a mostrar'), findsNothing);
    expect(find.text('¿Quieres un recorrido rápido?'), findsOneWidget);
  });

  testWidgets('checkbox row: whole row toggles, hit area >= 48 dp', (
    tester,
  ) async {
    var value = false;
    await pumpComponent(
      tester,
      StatefulBuilder(
        builder: (context, setState) =>
            _sunday(value: value, onChanged: (v) => setState(() => value = v)),
      ),
      wrapInScaffold: false,
    );
    final row = find.byKey(const ValueKey('prompt-dont-show-again'));
    expect(row, findsOneWidget);
    final size = tester.getSize(row);
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));

    await tester.tap(find.text('No volver a mostrar'));
    await tester.pump();
    expect(value, isTrue);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(value, isFalse);
    await expectTapTargetGuidelines(tester);
  });

  testWidgets('Sunday reminder copy in Spanish', (tester) async {
    await pumpComponent(tester, _sunday(), wrapInScaffold: false);
    expect(find.text('Hoy toca tu recap'), findsOneWidget);
    expect(
      find.text('Cuéntame cómo ha ido la semana. Son cinco pasos.'),
      findsOneWidget,
    );
    expect(find.text('Rellenar recap'), findsOneWidget);
    expect(find.text('Omitir'), findsOneWidget);
    expect(find.text('No volver a mostrar'), findsOneWidget);
  });

  testWidgets('Sunday reminder copy in English', (tester) async {
    await pumpComponent(
      tester,
      _sunday(),
      wrapInScaffold: false,
      locale: const Locale('en'),
    );
    expect(find.text("It's recap day"), findsOneWidget);
    expect(
      find.text('Tell me how your week went. It takes five steps.'),
      findsOneWidget,
    );
    expect(find.text('Fill in recap'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text("Don't show again"), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    for (final (name, builder) in [
      ('sunday', _sunday),
      ('tutorial', _tutorialWithCheckbox),
    ]) {
      testWidgets('$name prompt at 360 dp, nonlinear x2.0, '
          '${brightness.name}: no overflow', (tester) async {
        await pumpComponent(
          tester,
          _scaled(builder(), 2.0),
          brightness: brightness,
          width: 360,
          height: 800,
          wrapInScaffold: false,
        );
        expectNoOverflow(tester);
        expect(find.byType(Checkbox), findsOneWidget);
      });
    }
  }
}
