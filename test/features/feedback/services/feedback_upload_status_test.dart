import 'dart:ui' as ui;
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_operation_bar.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_upload_status.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/expect_no_lime_ink.dart';

/// Sending label with the same megabyte format as the widget.
String _sendingLabel(AppLocalizations l10n, String locale, int sent, int total) {
  final mb = NumberFormat('0.0', locale);
  return l10n.pendingUploadSendingBytes(
    total == 0 ? 0 : (sent * 100) ~/ total,
    mb.format(sent / 1000000),
    mb.format(total / 1000000),
  );
}

/// One upload state of the L5-C2 contract (six states plus the variants that
/// must not claim more than the queue knows).
class _Case {
  const _Case(this.name, this.status, {this.notice, this.lastError});

  final String name;
  final String status;
  final FeedbackUploadNotice? notice;
  final String? lastError;
}

const _total = 13500000;
const _preparing = _Case(
  'preparing',
  'uploading',
  notice: FeedbackUploadNotice('id', FeedbackUploadNoticeKind.preparing),
);
const _sending = _Case(
  'sending',
  'uploading',
  notice: FeedbackUploadNotice(
    'id',
    FeedbackUploadNoticeKind.uploading,
    sentBytes: 8400000,
    totalBytes: _total,
  ),
);
const _processing = _Case(
  'processing',
  'processing',
  notice: FeedbackUploadNotice('id', FeedbackUploadNoticeKind.processing),
);
const _confirmed = _Case(
  'confirmed',
  'completed',
  notice: FeedbackUploadNotice('id', FeedbackUploadNoticeKind.completed),
);
const _failed = _Case('failed', 'failed', lastError: 'upload_request_failed');
const _offline = _Case(
  'offline',
  'queued',
  notice: FeedbackUploadNotice('id', FeedbackUploadNoticeKind.queued),
  lastError: 'network_connectionError_0',
);

void main() {
  Future<void> show(
    WidgetTester tester,
    _Case c, {
    ThemeData? theme,
    String locale = 'es',
    VoidCallback? onRetry,
    double? width,
  }) {
    final status = FeedbackUploadStatus(
      status: c.status,
      progress: c.notice,
      lastError: c.lastError,
      onRetry: onRetry,
    );
    return tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.dark,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: width == null
                ? status
                : SizedBox(width: width, child: status),
          ),
        ),
      ),
    );
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(FeedbackUploadStatus)));

  List<String> textsOf(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(FeedbackUploadStatus),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .toList();

  Set<IconData?> iconsOf(WidgetTester tester) => tester
      .widgetList<Icon>(
        find.descendant(
          of: find.byType(FeedbackUploadStatus),
          matching: find.byType(Icon),
        ),
      )
      .map((icon) => icon.icon)
      .toSet();

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'paint distinguishes sent bytes from remaining track in ${theme.brightness}',
      (tester) async {
        final boundaryKey = GlobalKey();
        Future<void> paint(FeedbackUploadNotice notice) async {
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

        final palette = theme.extension<ExomThemePalette>()!;
        for (final sent in [0, 25, 75]) {
          await paint(
            FeedbackUploadNotice(
              'id',
              FeedbackUploadNoticeKind.uploading,
              sentBytes: sent * _total ~/ 100,
              totalBytes: _total,
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
              (tester.getRect(find.byType(ExomOperationBar)).bottom -
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

          // D19: the sent share is a system operation, in the text colour;
          // the far right is still the pending track at 0, 25 and 75 %.
          expect(pixel(180), palette.borderSoft.toARGB32());
          if (sent > 0) expect(pixel(10), palette.textPrimary.toARGB32());
          rendered!.dispose();
          expect(
            find.text(
              _sendingLabel(l10nOf(tester), 'es', sent * _total ~/ 100, _total),
            ),
            findsOneWidget,
          );
        }
        await paint(
          const FeedbackUploadNotice('id', FeedbackUploadNoticeKind.preparing),
        );
        expect(
          tester.widget<ExomOperationBar>(find.byType(ExomOperationBar)).value,
          isNull,
        );
        expect(find.textContaining('75 %'), findsNothing);
      },
    );

    testWidgets('byte progress, processing and retry use ${theme.brightness}', (
      tester,
    ) async {
      var retries = 0;
      await show(tester, _sending, theme: theme, onRetry: () => retries++);
      final l10n = l10nOf(tester);
      expect(
        find.text(_sendingLabel(l10n, 'es', 8400000, _total)),
        findsOneWidget,
      );
      expect(
        tester.widget<ExomOperationBar>(find.byType(ExomOperationBar)).value,
        closeTo(8400000 / _total, 1e-9),
      );
      // An upload in flight cannot be retried (the queue refuses it too).
      expect(find.byType(ExomTextLink), findsNothing);

      await show(tester, _preparing, theme: theme);
      expect(find.text('Preparando archivo'), findsOneWidget);
      expect(find.textContaining('62 %'), findsNothing);
      expect(
        tester.widget<ExomOperationBar>(find.byType(ExomOperationBar)).value,
        isNull,
      );

      await show(tester, _processing, theme: theme);
      expect(find.text(l10n.feedbackUploadProcessingTitle), findsOneWidget);
      expect(find.textContaining('62 %'), findsNothing);
      expect(
        tester.widget<ExomOperationBar>(find.byType(ExomOperationBar)).value,
        isNull,
      );

      await show(tester, _failed, theme: theme, onRetry: () => retries++);
      final retry = find.widgetWithText(ExomTextLink, l10n.pendingUploadRetry);
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      expect(retries, 1);
      if (theme.brightness == Brightness.light) expectNoLimeInk(tester);
    });

    testWidgets('confirmed is text colour with a check, never lime (D19) in '
        '${theme.brightness}', (tester) async {
      await show(tester, _confirmed, theme: theme);
      final l10n = l10nOf(tester);
      final palette = theme.extension<ExomThemePalette>()!;
      final title = tester.widget<Text>(find.text(l10n.syncStatusConfirmed));
      expect(title.style?.color, palette.textPrimary);
      final check = tester.widget<Icon>(
        find.descendant(
          of: find.byType(FeedbackUploadStatus),
          matching: find.byIcon(ExomIcons.check),
        ),
      );
      expect(check.color, palette.textPrimary);
      expect(check.color, isNot(palette.limeFill));
      expect(find.text(l10n.feedbackUploadConfirmedBody), findsOneWidget);
      if (theme.brightness == Brightness.light) expectNoLimeInk(tester);
    });
  }

  for (final locale in ['es', 'en']) {
    testWidgets('six upload states have distinct text and icon in $locale', (
      tester,
    ) async {
      final texts = <String, String>{};
      final icons = <String, Set<IconData?>>{};
      for (final c in [
        _preparing,
        _sending,
        _processing,
        _confirmed,
        _failed,
        _offline,
      ]) {
        await show(tester, c, locale: locale, onRetry: () {});
        texts[c.name] = textsOf(tester).join(' | ');
        icons[c.name] = iconsOf(tester);
        expect(
          icons[c.name],
          isNotEmpty,
          reason: '${c.name} must not rely on colour alone',
        );
      }
      expect(texts.values.toSet(), hasLength(6), reason: '$texts');
      final firstIcons = icons.values.map((set) => set.first).toSet();
      expect(firstIcons, hasLength(6), reason: '$icons');

      final l10n = l10nOf(tester);
      expect(texts['preparing'], contains(l10n.pendingUploadPreparingStatus));
      expect(texts['preparing'], contains(l10n.feedbackUploadPreparingBody));
      expect(
        texts['sending'],
        contains(_sendingLabel(l10n, locale, 8400000, _total)),
      );
      expect(texts['processing'], contains(l10n.feedbackUploadProcessingTitle));
      expect(texts['processing'], contains(l10n.feedbackUploadProcessingBody));
      expect(texts['confirmed'], contains(l10n.syncStatusConfirmed));
      expect(texts['confirmed'], contains(l10n.feedbackUploadConfirmedBody));
      expect(texts['failed'], contains(l10n.feedbackUploadFailedTitle));
      expect(texts['failed'], contains(l10n.feedbackUploadKeptBody));
      expect(texts['offline'], contains(l10n.pendingUploadQueuedStatus));
      expect(texts['offline'], contains(l10n.feedbackUploadOfflineBody));
      // Bytes sent and processing are never presented as confirmation.
      for (final name in ['preparing', 'sending', 'processing']) {
        expect(texts[name], isNot(contains(l10n.syncStatusConfirmed)));
        expect(texts[name], isNot(contains(l10n.feedbackUploadConfirmedBody)));
      }
    });

    testWidgets('all bytes sent is still not confirmed in $locale', (
      tester,
    ) async {
      await show(
        tester,
        const _Case(
          'sent-all',
          'uploading',
          notice: FeedbackUploadNotice(
            'id',
            FeedbackUploadNoticeKind.uploading,
            sentBytes: _total,
            totalBytes: _total,
          ),
        ),
        locale: locale,
      );
      final l10n = l10nOf(tester);
      final texts = textsOf(tester).join(' | ');
      expect(texts, contains(_sendingLabel(l10n, locale, _total, _total)));
      expect(texts, isNot(contains(l10n.syncStatusConfirmed)));
      expect(texts, isNot(contains(l10n.feedbackUploadConfirmedBody)));
    });

    testWidgets('a small file reads in KB, never 0,0 of 0,0 MB (D2) in '
        '$locale', (tester) async {
      await show(
        tester,
        const _Case(
          'small',
          'uploading',
          notice: FeedbackUploadNotice(
            'id',
            FeedbackUploadNoticeKind.uploading,
            sentBytes: 38000,
            totalBytes: 38000,
          ),
        ),
        locale: locale,
      );
      final texts = textsOf(tester).join(' | ');
      expect(
        texts,
        contains(
          locale == 'es'
              ? 'Enviando 100 % · 38,0 de 38,0 KB'
              : 'Sending 100% · 38.0 of 38.0 KB',
        ),
      );
      expect(texts, isNot(contains('MB')));
    });

    testWidgets('an unknown or zero total shows no "of" part (D2) in $locale', (
      tester,
    ) async {
      for (final total in [0, -1]) {
        await show(
          tester,
          _Case(
            'no-total',
            'uploading',
            notice: FeedbackUploadNotice(
              'id',
              FeedbackUploadNoticeKind.uploading,
              sentBytes: 38000,
              totalBytes: total,
            ),
          ),
          locale: locale,
        );
        final texts = textsOf(tester).join(' | ');
        expect(texts, isNot(contains(locale == 'es' ? ' de ' : ' of ')));
        expect(texts, isNot(contains('MB')));
        expect(texts, isNot(contains('KB')));
      }
    });

    testWidgets('only a no-response network error reads as offline in '
        '$locale', (tester) async {
      await show(
        tester,
        const _Case('queued', 'queued'),
        locale: locale,
        onRetry: () {},
      );
      final l10n = l10nOf(tester);
      expect(textsOf(tester), contains(l10n.pendingUploadQueuedStatus));
      expect(
        textsOf(tester).join(),
        isNot(contains(l10n.feedbackUploadOfflineBody)),
      );
      await show(
        tester,
        const _Case(
          'server',
          'queued',
          lastError: 'network_badResponse_503',
        ),
        locale: locale,
      );
      expect(
        textsOf(tester).join(),
        isNot(contains(l10n.feedbackUploadOfflineBody)),
      );
      for (final error in const [
        'network_connectionTimeout_0',
        'network_sendTimeout_0',
        'network_receiveTimeout_0',
        'network_unknown_0',
      ]) {
        await show(
          tester,
          _Case('offline', 'queued', lastError: error),
          locale: locale,
        );
        expect(
          textsOf(tester).join(),
          contains(l10n.feedbackUploadOfflineBody),
          reason: error,
        );
      }
    });

    testWidgets('failed only claims the evidence is kept when it is in '
        '$locale', (tester) async {
      await show(
        tester,
        const _Case('missing', 'failed', lastError: 'file_missing'),
        locale: locale,
        onRetry: () {},
      );
      final l10n = l10nOf(tester);
      expect(textsOf(tester), contains(l10n.feedbackUploadFailedTitle));
      expect(
        textsOf(tester).join(),
        isNot(contains(l10n.feedbackUploadKeptBody)),
      );
      await show(tester, const _Case('discarding', 'discarding'), locale: locale);
      expect(
        textsOf(tester).join(),
        isNot(contains(l10n.feedbackUploadKeptBody)),
      );
      expect(find.byType(ExomTextLink), findsNothing);
    });
  }
}
