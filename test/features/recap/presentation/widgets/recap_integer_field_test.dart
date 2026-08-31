import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('accepts valid values and shows an error above max', (
    tester,
  ) async {
    int? value = 8500;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecapIntegerField(
            label: 'Media diaria de pasos',
            helperText: 'Consulta tu móvil',
            hintText: '8500',
            maxErrorText: 'Valor no válido',
            value: value,
            max: 200000,
            onChanged: (nextValue) => value = nextValue,
          ),
        ),
      ),
    );

    final field = find.byType(TextField);
    await tester.enterText(field, '12000');
    expect(value, 12000);

    await tester.enterText(field, '250000');
    await tester.pump();
    expect(value, 250000);
    expect(find.text('Valor no válido'), findsOneWidget);

    await tester.enterText(field, '2000000');
    await tester.pump();
    expect(value, 2000000);
    expect(find.text('Valor no válido'), findsOneWidget);

    await tester.enterText(field, '');
    expect(value, isNull);
  });
}
