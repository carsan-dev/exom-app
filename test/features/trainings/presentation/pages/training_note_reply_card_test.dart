import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/trainings/presentation/pages/training_detail_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows client note and trainer reply', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(
          body: TrainingNoteReplyCard(
            note: 'Me molestó la rodilla',
            reply: 'Reduce el peso',
          ),
        ),
      ),
    );

    expect(find.text('Tu nota'), findsOneWidget);
    expect(find.text('Me molestó la rodilla'), findsOneWidget);
    expect(find.text('Respuesta de tu entrenador'), findsOneWidget);
    expect(find.text('Reduce el peso'), findsOneWidget);
  });
}
