// L5-C2 «Feedback»: the scene in both themes and languages (CC 3, 4, 10), the
// inline messages that replace this screen's SnackBars (D14-3), the numbered
// circuit questions with the button in the footer and the history with the
// coach reply.
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/features/feedback/presentation/feedback_notice_snack_bars.dart';
import 'package:exom_app/features/feedback/presentation/inline_upload_status_scope.dart';
import 'package:exom_app/features/feedback/presentation/pages/feedback_page.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_media_picker.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_upload_status.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../core/widgets/exom_component_harness.dart'
    show expectNoOverflow, expectTapTargetGuidelines;
import '../../../../core/widgets/expect_no_lime_ink.dart';
import 'feedback_page_scene.dart';

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

/// Texts of every upload status line in the queue panel.
List<String> _statusTexts(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(FeedbackUploadStatus),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
    .toList();

/// The page body list (the queue panel and the footer scroll too).
Finder get _body => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

DioException _offline() => DioException(
  requestOptions: RequestOptions(path: '/feedback/my'),
  type: DioExceptionType.connectionError,
  error: const SocketException('Failed host lookup: api.exom.test'),
);

void main() {
  for (final locale in const ['es', 'en']) {
    group('L5-C2 scene $locale', () {
      testWidgets('draws questions, status, footer and history with the coach '
          'reply', (tester) async {
        await pumpFeedbackScene(tester, locale: Locale(locale));
        final l10n = _l10n(tester);
        expect(find.byType(GlassCard), findsNothing);
        // Numbered questions 01-03 of the form.
        for (final n in [1, 2, 3]) {
          expect(
            find.byWidgetPredicate((w) => w is ExomIndexNumber && w.n == n),
            findsWidgets,
          );
        }
        expect(find.text(l10n.feedbackQuestionType), findsOneWidget);
        expect(find.text(l10n.feedbackQuestionFile), findsOneWidget);
        // The send action is the primary button of the pinned footer.
        expect(
          find.descendant(
            of: find.byType(ExomPinnedFooter),
            matching: find.byKey(const Key('send-feedback')),
          ),
          findsOneWidget,
        );
        // Upload status: bytes and percentage in text.
        expect(find.byType(FeedbackUploadStatus), findsOneWidget);
        expect(find.textContaining('62'), findsWidgets);
        // History: the reviewed item carries the coach reply block.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('feedback-row-f2')),
          200,
          scrollable: _body,
        );
        final reply = tester.widget<ExomReplyBlock>(
          find.byType(ExomReplyBlock),
        );
        expect(reply.text, startsWith('Buena profundidad'));
        expect(reply.author, l10n.trainerReply);
        expect(find.text(l10n.reviewed), findsOneWidget);
        expect(find.text(l10n.pending), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('empty history: «Sin feedback. / Todavía.» with the existing '
          'sentence', (tester) async {
        await pumpFeedbackScene(tester, locale: Locale(locale), history: []);
        final l10n = _l10n(tester);
        await tester.scrollUntilVisible(
          find.byType(ExomEmptyState),
          200,
          scrollable: _body,
        );
        final empty = tester.widget<ExomEmptyState>(
          find.byType(ExomEmptyState),
        );
        expect(empty.first, l10n.feedbackEmptyFirst);
        expect(empty.second, l10n.feedbackEmptySecond);
        expect(empty.lead, l10n.noFeedbackYet);
      });

      testWidgets('history offline failure is an inline message', (
        tester,
      ) async {
        await pumpFeedbackScene(
          tester,
          locale: Locale(locale),
          historyError: _offline(),
        );
        final l10n = _l10n(tester);
        expect(
          find.widgetWithText(ExomInlineMessage, l10n.feedbackOfflineMessage),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('enqueue failure is an inline message', (tester) async {
        await pumpFeedbackScene(
          tester,
          locale: Locale(locale),
          enqueueError: StateError('copy failed'),
        );
        final l10n = _l10n(tester);
        tester
            .widget<FeedbackMediaPicker>(find.byType(FeedbackMediaPicker))
            .onFileSelected(File('evidence.jpg'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('send-feedback')));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(ExomInlineMessage, l10n.feedbackUploadFailed),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
        // The file stays selected so the user can send it again.
        expect(
          tester
              .widget<FeedbackMediaPicker>(find.byType(FeedbackMediaPicker))
              .selectedFile
              ?.path,
          'evidence.jpg',
        );
      });

      testWidgets('circuit: numbered exercises, button in the footer, failure '
          'in line', (tester) async {
        await pumpFeedbackScene(
          tester,
          locale: Locale(locale),
          args: sceneCircuit,
          enqueueError: StateError('copy failed'),
        );
        final l10n = _l10n(tester);
        expect(find.byType(GlassCard), findsNothing);
        expect(find.text('Sentadilla goblet'), findsOneWidget);
        expect(
          find.byWidgetPredicate((w) => w is ExomIndexNumber && w.n == 2),
          findsWidgets,
        );
        final send = find.descendant(
          of: find.byType(ExomPinnedFooter),
          matching: find.byKey(const Key('send-circuit-feedback')),
        );
        expect(send, findsOneWidget);
        expect(tester.widget<ExomPrimaryButton>(send).onPressed, isNull);
        tester
            .widget<FeedbackMediaPicker>(find.byType(FeedbackMediaPicker).first)
            .onFileSelected(File('goblet.mp4'));
        await tester.pumpAndSettle();
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(ExomInlineMessage, l10n.feedbackUploadFailed),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
      });

      for (final (width, scale) in const [
        (320.0, 1.3),
        (320.0, 1.6),
        (360.0, 1.6),
      ]) {
        testWidgets('no overflow at ${width}dp x $scale (Android scaler)', (
          tester,
        ) async {
          await pumpFeedbackScene(
            tester,
            locale: Locale(locale),
            width: width,
            height: 640,
            textScaler: AndroidNonlinearTextScaler(scale),
          );
          expectNoOverflow(tester);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('feedback-row-f2')),
            200,
            scrollable: _body,
          );
          expectNoOverflow(tester);
        });

        testWidgets('circuit: no overflow at ${width}dp x $scale', (
          tester,
        ) async {
          await pumpFeedbackScene(
            tester,
            locale: Locale(locale),
            args: sceneCircuit,
            width: width,
            height: 640,
            textScaler: AndroidNonlinearTextScaler(scale),
          );
          expectNoOverflow(tester);
        });
      }

      testWidgets('at 2.0x everything is reachable by scrolling', (
        tester,
      ) async {
        await pumpFeedbackScene(
          tester,
          locale: Locale(locale),
          width: 320,
          height: 640,
          textScaler: const AndroidNonlinearTextScaler(2.0),
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('feedback-row-f2')),
          200,
          scrollable: _body,
        );
        expectNoOverflow(tester);
        expect(
          find.byKey(const Key('send-feedback')).hitTestable(),
          findsOneWidget,
        );
      });

      for (final brightness in Brightness.values) {
        testWidgets('guidelines in ${brightness.name}', (tester) async {
          await pumpFeedbackScene(
            tester,
            locale: Locale(locale),
            brightness: brightness,
          );
          // With a file chosen, so the send button is enabled: the disabled
          // primary button of the base measures 4.25:1 in dark (inactive
          // control, outside WCAG 1.4.3; reported in the C2 evidence).
          tester
              .widget<FeedbackMediaPicker>(find.byType(FeedbackMediaPicker))
              .onFileSelected(File('sentadilla-bulgara-s4.mp4'));
          await tester.pumpAndSettle();
          expectNoOverflow(tester);
          if (brightness == Brightness.light) expectNoLimeInk(tester);
          await expectTapTargetGuidelines(tester);
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        });
      }
    });
  }

  testWidgets('the page suppresses the app-wide upload notices only while it '
      'is the current route', (tester) async {
    final router = await pumpFeedbackScene(tester);
    expect(InlineUploadStatusScope.isActive, isTrue);
    router.go('/other');
    await tester.pumpAndSettle();
    expect(InlineUploadStatusScope.isActive, isFalse);
  });

  testWidgets('a route pushed on top of the page brings the app-wide notices '
      'back; popping it suppresses them again', (tester) async {
    final router = await pumpFeedbackScene(tester);
    expect(InlineUploadStatusScope.isActive, isTrue);
    unawaited(router.push('/other'));
    await tester.pumpAndSettle();
    // The page is still alive under the pushed route.
    expect(
      find.byType(FeedbackUploadStatus, skipOffstage: false),
      findsWidgets,
    );
    expect(InlineUploadStatusScope.isActive, isFalse);
    final messenger = tester.state<ScaffoldMessengerState>(
      find.byType(ScaffoldMessenger).first,
    );
    FeedbackNoticeSnackBars.show(messenger, message: 'Aviso global');
    await tester.pump();
    expect(find.text('Aviso global'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(InlineUploadStatusScope.isActive, isTrue);
  });

  testWidgets('entering the page closes the app-wide feedback notices shown '
      'before', (tester) async {
    final router = await pumpFeedbackScene(tester);
    router.go('/other');
    await tester.pumpAndSettle();
    final messenger = tester.state<ScaffoldMessengerState>(
      find.byType(ScaffoldMessenger).first,
    );
    FeedbackNoticeSnackBars.show(messenger, message: 'Aviso global');
    await tester.pump();
    expect(find.text('Aviso global'), findsOneWidget);
    router.go('/');
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackPage), findsOneWidget);
    expect(find.text('Aviso global'), findsNothing);
  });

  testWidgets('a discard whose file cleanup failed reads as being discarded, '
      'not as a send failure', (tester) async {
    await pumpFeedbackScene(
      tester,
      uploads: [
        {
          'id': 'discarded',
          'media_type': 'VIDEO',
          // What the queue writes when the deletion of a discarded upload
          // fails (FeedbackUploadQueueService cleanup).
          'status': 'failed',
          'discard_requested': true,
          'last_error': 'cleanup_failed: FileSystemException: locked',
        },
      ],
    );
    final l10n = _l10n(tester);
    final texts = _statusTexts(tester);
    expect(texts, isNot(contains(l10n.feedbackUploadFailedTitle)));
    expect(texts, isNot(contains(l10n.feedbackUploadKeptBody)));
    expect(texts, contains(l10n.pendingUploadFailedStatus));
    expect(find.text(l10n.pendingUploadRetry), findsNothing);
  });

  group('the connection sentence only while the queue waits for the '
      'network', () {
    final claimed = DateTime.utc(2026, 11, 21, 10);
    String at(Duration offset) => claimed.add(offset).toIso8601String();

    Future<String> statusOf(
      WidgetTester tester,
      Map<String, dynamic> item,
    ) async {
      await pumpFeedbackScene(
        tester,
        uploads: [
          {
            'id': 'queued',
            'media_type': 'VIDEO',
            'status': 'queued',
            'last_error': 'network_connectionError_0',
            ...item,
          },
        ],
      );
      return _statusTexts(tester).join(' | ');
    }

    testWidgets('offline backoff after the last claim: sentence shown', (
      tester,
    ) async {
      final texts = await statusOf(tester, {
        'claimed_at': at(Duration.zero),
        'next_attempt_at': at(const Duration(seconds: 30)),
      });
      expect(texts, contains(_l10n(tester).feedbackUploadOfflineBody));
    });

    testWidgets('session pause after a new claim keeps the old network error: '
        'no connection sentence', (tester) async {
      // The claim needs next_attempt_at <= now; the auth pause puts the row
      // back to queued without touching last_error or next_attempt_at.
      final texts = await statusOf(tester, {
        'claimed_at': at(Duration.zero),
        'next_attempt_at': at(const Duration(minutes: -1)),
      });
      final l10n = _l10n(tester);
      expect(texts, contains(l10n.pendingUploadQueuedStatus));
      expect(texts, isNot(contains(l10n.feedbackUploadOfflineBody)));
    });

    testWidgets('connection back (wait removed by the reconnect): no '
        'connection sentence', (tester) async {
      final texts = await statusOf(tester, {'claimed_at': at(Duration.zero)});
      final l10n = _l10n(tester);
      expect(texts, contains(l10n.pendingUploadQueuedStatus));
      expect(texts, isNot(contains(l10n.feedbackUploadOfflineBody)));
    });
  });

  testWidgets('circuit mode keeps the app-wide notices (the page closes '
      'after queueing)', (tester) async {
    await pumpFeedbackScene(tester, args: sceneCircuit);
    expect(InlineUploadStatusScope.isActive, isFalse);
    final queue = sl<FeedbackUploadQueueService>() as SceneFeedbackQueue;
    expect(queue.enqueued, isEmpty);
  });
}
