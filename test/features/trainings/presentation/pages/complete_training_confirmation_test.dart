import 'package:exom_app/features/trainings/presentation/pages/training_detail_page.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TrainingCompletionInput? dialogResult;
  final storage = _DraftStorage();

  Future<void> openDialog(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('es'),
  }) async {
    dialogResult = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        locale: locale,
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
              dialogResult = await showDialog<TrainingCompletionInput>(
                context: context,
                builder: (dialogContext) => CompleteTrainingConfirmationDialog(
                  l10n: AppLocalizations.of(dialogContext),
                  storage: storage,
                  trainingId: 'training', date: '2026-09-05',
                  executionId: 'execution', sessionStamp: storage.sessionStamp,
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

  testWidgets('explains RPE in both locales without layout errors', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final (locale, label, explanation) in [
      (const Locale('es'), 'RPE (obligatorio, 1–10)', 'El RPE indica cuánto esfuerzo sentiste al entrenar: 1 es muy fácil y 10 es tu máximo esfuerzo.'),
      (const Locale('en'), 'RPE (required, 1–10)', 'RPE measures how hard the workout felt to you: 1 is very easy, 10 is your maximum effort.'),
    ]) {
      await openDialog(tester, locale: locale);
      expect(find.text(label), findsOneWidget);
      expect(find.text(explanation), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.widget<FilledButton>(
        find.byKey(const Key('confirm-complete-training'))).onPressed, isNull);
      await tester.tap(find.byKey(const Key('cancel-complete-training')));
      await tester.pumpAndSettle();
      expect(dialogResult, isNull);
      expect(tester.takeException(), isNull);
    }
  });

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
    expect(dialogResult, isNull);
  });

  testWidgets('confirm action is explicit', (tester) async {
    await openDialog(tester);
    expect(find.text('Completar todo'), findsOneWidget);
    expect(find.byKey(const Key('completion-rpe-selected')), findsNothing);
    expect(tester.widget<FilledButton>(
      find.byKey(const Key('confirm-complete-training'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('confirm-complete-training')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('complete-training-confirmation')), findsOneWidget);
    expect(dialogResult, isNull);
    await tester.tap(find.byKey(const Key('completion-rpe-10')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-complete-training')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('complete-training-confirmation')), findsNothing);
    expect(dialogResult?.rpe, 10);
    expect(dialogResult?.notes, isNull);
  });

  testWidgets('uses the active dark theme', (tester) async {
    await openDialog(tester, brightness: Brightness.dark);

    final context = tester.element(
      find.byKey(const Key('complete-training-confirmation')),
    );
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}

class _DraftStorage extends LocalStorage {
  Map<String, dynamic>? draft;

  @override
  Map<String, dynamic>? getTrainingCompletionDraft(
      String trainingId, String date, String executionId) => draft;

  @override
  Future<void> saveTrainingCompletionDraft(
      String trainingId, String date, String executionId,
      {int? rpe, String? notes}) async {
    draft = {'rpe': ?rpe, 'notes': ?notes};
  }
}
