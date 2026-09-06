import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_upload_status.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('byte progress, processing and retry use ${theme.brightness}', (
      tester,
    ) async {
      Future<void> show(String status, FeedbackUploadNotice notice) =>
          tester.pumpWidget(
            MaterialApp(
              theme: theme,
              locale: const Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: FeedbackUploadStatus(
                  status: status,
                  progress: notice,
                  onRetry: () => {},
                ),
              ),
            ),
          );
      await show(
        'uploading',
        const FeedbackUploadNotice(
          'id',
          FeedbackUploadNoticeKind.uploading,
          sentBytes: 25,
          totalBytes: 100,
        ),
      );
      expect(find.text('25%'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        .25,
      );
      final retry = tester.widget<TextButton>(find.byType(TextButton));
      expect(
        retry.style!.foregroundColor!.resolve({}),
        theme.colorScheme.primary,
      );
      await show(
        'processing',
        const FeedbackUploadNotice('id', FeedbackUploadNoticeKind.processing),
      );
      expect(find.text('Procesando'), findsOneWidget);
      expect(find.text('25%'), findsNothing);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
    });
  }
}
