import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/core/widgets/exom_scale_chips.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_optional_rating.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// D14-4 (L5-C5a): the optional scale is made of `ExomScaleChips` and a «sin
// dato» chip instead of `ChoiceChip`s. The cases are the same as before: no
// preset, selection, explicit clear and a historical 0 that is not «missing».
void main() {
  ExomScaleChips scale(WidgetTester tester) =>
      tester.widget<ExomScaleChips>(find.byType(ExomScaleChips));

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
        expect(scale(tester).selected, isNull);
        expect(scale(tester).min, 1);
        expect(scale(tester).max, 10);
        await tester.tap(find.text('10'));
        await tester.pump();
        expect(value, 10);
        expect(scale(tester).selected, 10);
        await tester.tap(find.text(locale == 'es' ? 'Sin dato' : 'No data'));
        await tester.pump();
        expect(value, isNull);
        expect(scale(tester).selected, isNull);
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
      expect(scale(tester).selected, 0);
      // The stored 0 is a rating: «Sin dato» is not the chosen chip.
      final noData = tester.widget<ExomChoiceChips<bool>>(
        find.byType(ExomChoiceChips<bool>),
      );
      expect(noData.selected, isNull);
      expect(scale(tester).min, 0);
      expect(scale(tester).max, 5);
    },
  );

  testWidgets('each value is spoken with the question and the maximum', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RecapOptionalRating(
            label: 'Hambre',
            helper: '1–10',
            value: 3,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final three = tester.getSemantics(find.text('3'));
    expect(three.label, 'Hambre: 3 / 10');
    expect(tester.getSemantics(find.text('10')).label, 'Hambre: 10 / 10');
    handle.dispose();
  });
}
