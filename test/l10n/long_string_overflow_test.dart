import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _codes = [
  'progress_conflict_review_required',
  'PROGRESS_VERSION_CONFLICT',
  'PROGRESS_HISTORY_AMBIGUOUS',
  'progress_receipt_missing',
  'feedback_discarded',
  'sync_failed',
  'compression_cancelled',
  'compression_invalid_input',
  'compression_timeout',
  'compression_busy',
  'compression_failed',
  'UPLOAD_EXPIRED',
  'UPLOAD_OBJECT_MISSING',
  'upload_session_changed',
  'UPLOAD_OPERATION_CONFLICT',
];

Future<void> _pump(WidgetTester tester, Widget Function(BuildContext) child) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: app!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: Builder(builder: child))),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('error and upload states do not overflow at 320dp, 1.3x text', (tester) async {
    await _pump(tester, (context) {
      final l10n = AppLocalizations.of(context);
      return Column(
        children: [
          for (final code in _codes)
            ErrorWidget2(message: localizedErrorCode(l10n, code)!, onRetry: () {}),
          ErrorWidget2(message: l10n.errorBadRequest, onRetry: () {}),
          ErrorWidget2(message: l10n.errorConflict, onRetry: () {}),
          ErrorWidget2(message: l10n.errorRateLimited, onRetry: () {}),
          ErrorWidget2(message: l10n.trainingProgressSaveError, onRetry: () {}),
          ErrorWidget2(message: l10n.activeExerciseContextMissing),
        ],
      );
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('execution picker dialog and notices do not overflow', (tester) async {
    await _pump(tester, (context) {
      final l10n = AppLocalizations.of(context);
      return Column(
        children: [
          Text(l10n.quarantinedWorkoutNotice),
          Text(l10n.circuitSummary(12, 12)),
          Text(l10n.optionsCount(5)),
          Text(l10n.timerSegmentRemaining('10:00', '120:00')),
          AlertDialog(
            title: Text(l10n.selectTrainingExecution),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(l10n.recoverSavedExerciseDraft),
                  subtitle: Text(l10n.restoreSavedSetsNewExecution),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () {}, child: Text(l10n.cancel)),
              FilledButton(onPressed: () {}, child: Text(l10n.newTrainingExecution)),
            ],
          ),
        ],
      );
    });
    expect(tester.takeException(), isNull);
  });
}
