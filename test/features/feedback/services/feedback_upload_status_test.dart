import 'dart:ui' as ui;
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_upload_status.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'paint distinguishes sent bytes from remaining track in ${theme.brightness}',
      (tester) async {
        final boundaryKey = GlobalKey();
        Future<void> show(FeedbackUploadNotice notice) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              locale: const Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 200,
                    child: RepaintBoundary(
                      key: boundaryKey,
                      child: FeedbackUploadStatus(
                        status: 'uploading',
                        progress: notice,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        for (final sent in [0, 25, 75]) {
          await show(
            FeedbackUploadNotice(
              'id',
              FeedbackUploadNoticeKind.uploading,
              sentBytes: sent,
              totalBytes: 100,
            ),
          );
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final rendered = await tester.runAsync(
            () => boundary.toImage(pixelRatio: 1),
          );
          final pixels = await tester.runAsync(
            () => rendered!.toByteData(format: ui.ImageByteFormat.rawRgba),
          );
          final data = pixels!.buffer.asUint8List();
          final y =
              (tester.getRect(find.byType(LinearProgressIndicator)).bottom -
                      tester.getTopLeft(find.byKey(boundaryKey)).dy -
                      2)
                  .floor();
          int pixel(int x) {
            final offset = (y * rendered!.width + x) * 4;
            return (data[offset + 3] << 24) |
                (data[offset] << 16) |
                (data[offset + 1] << 8) |
                data[offset + 2];
          }

          // At 0, 25 and 75 percent the far right is still the pending track.
          expect(pixel(180), isNot(theme.colorScheme.primary.toARGB32()));
          if (sent > 0) expect(pixel(10), theme.colorScheme.primary.toARGB32());
          rendered!.dispose();
          expect(find.text('$sent%'), findsOneWidget);
        }
        await show(
          const FeedbackUploadNotice('id', FeedbackUploadNoticeKind.preparing),
        );
        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(indicator.value, isNull);
        final track =
            indicator.backgroundColor ??
            theme.progressIndicatorTheme.linearTrackColor ??
            theme.colorScheme.secondaryContainer;
        expect(track, isNot(theme.colorScheme.primary));
        expect(find.text('75%'), findsNothing);
      },
    );

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
        'uploading',
        const FeedbackUploadNotice('id', FeedbackUploadNoticeKind.preparing),
      );
      expect(find.text('Preparando archivo'), findsOneWidget);
      expect(find.text('25%'), findsNothing);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
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
