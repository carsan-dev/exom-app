import 'package:exom_app/features/trainings/presentation/pages/training_detail_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool? dialogResult;

  Future<void> openDialog(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    dialogResult = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        locale: const Locale('es'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              dialogResult = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => CompleteTrainingConfirmationDialog(
                  l10n: AppLocalizations.of(dialogContext),
                ),
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('cancel closes confirmation without approving completion', (
    tester,
  ) async {
    await openDialog(tester);
    expect(
      find.byKey(const Key('complete-training-confirmation')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('cancel-complete-training')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('complete-training-confirmation')),
      findsNothing,
    );
    expect(dialogResult, isFalse);
  });

  testWidgets('confirm action is explicit', (tester) async {
    await openDialog(tester);
    expect(find.text('Completar todo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-complete-training')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('complete-training-confirmation')),
      findsNothing,
    );
    expect(dialogResult, isTrue);
  });

  testWidgets('uses the active dark theme', (tester) async {
    await openDialog(tester, brightness: Brightness.dark);

    final context = tester.element(
      find.byKey(const Key('complete-training-confirmation')),
    );
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
