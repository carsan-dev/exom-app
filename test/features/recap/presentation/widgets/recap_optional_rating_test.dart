import 'package:exom_app/features/recap/presentation/widgets/recap_optional_rating.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['es', 'en']) {
    testWidgets(
      'optional scale $locale: no preset, selection and explicit clear',
      (tester) async {
        int? value;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: RecapOptionalRating(
                  label: 'Hambre',
                  helper: '1–10',
                  value: value,
                  onChanged: (next) => setState(() => value = next),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '1'))
              .selected,
          isFalse,
        );
        await tester.tap(find.widgetWithText(ChoiceChip, '10'));
        await tester.pump();
        expect(value, 10);
        await tester.tap(
          find.widgetWithText(
            ChoiceChip,
            locale == 'es' ? 'Sin dato' : 'No data',
          ),
        );
        await tester.pump();
        expect(value, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'historical stress zero stays selected and differs from missing',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RecapOptionalRating(
              label: 'Estrés',
              helper: '0–5',
              value: 0,
              min: 0,
              max: 5,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '0'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '1'))
            .selected,
        isFalse,
      );
    },
  );
}
