import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_step_general.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('stores stress rating as a 1 to 5 value', (tester) async {
    final changes = <MapEntry<String, dynamic>>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: RecapStepGeneral(
            formData: const {
              'mood': 'NORMAL',
              'stress_enabled': true,
              'stress_level': 3,
            },
            onChanged: (field, value) {
              changes.add(MapEntry(field, value));
            },
          ),
        ),
      ),
    );

    final stressRating = find.text('🙂');
    expect(stressRating, findsOneWidget);
    await tester.ensureVisible(stressRating);
    await tester.pumpAndSettle();
    await tester.tap(stressRating);
    await tester.pump();

    expect(
      changes.any(
        (change) => change.key == 'stress_level' && change.value == 4,
      ),
      isTrue,
    );
  });
}
