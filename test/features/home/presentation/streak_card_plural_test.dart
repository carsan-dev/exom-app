import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/widgets/streak_card.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, String lang, int days) {
  return tester.pumpWidget(
    MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: StreakCard(summary: HomeSummaryEntity(streakDays: days))),
    ),
  );
}

void main() {
  const expectedEs = {0: 'días de racha', 1: 'día de racha', 2: 'días de racha'};
  const expectedEn = {0: 'day streak', 1: 'day streak', 2: 'day streak'};

  for (final entry in expectedEs.entries) {
    testWidgets('es streak label for ${entry.key}', (tester) async {
      await _pump(tester, 'es', entry.key);
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('1 días de racha'), findsNothing);
    });
  }
  for (final entry in expectedEn.entries) {
    testWidgets('en streak label for ${entry.key}', (tester) async {
      await _pump(tester, 'en', entry.key);
      expect(find.text(entry.value), findsOneWidget);
    });
  }
}
