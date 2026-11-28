// L5-C1 «Subidas pendientes»: the scene in both themes and languages (CC 3, 4,
// 11) and the sketch elements drawn from data the page already has (L5-D36).
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_grow_bar.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/exom_component_harness.dart'
    show expectNoOverflow, expectTapTargetGuidelines;
import '../../../../core/widgets/expect_no_lime_ink.dart';
import 'pending_uploads_scene.dart';

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

void main() {
  for (final locale in const ['es', 'en']) {
    group('L5-C1 scene $locale', () {
      testWidgets('draws headline, summary, sections, rows and states', (
        tester,
      ) async {
        await pumpScene(tester, locale: Locale(locale));
        final l10n = _l10n(tester);
        expect(
          find.text(l10n.pendingUploadsTitle.toUpperCase()),
          findsOneWidget,
        );
        expect(
          find.text(
            '${l10n.pendingUploadsCountSubtitle(1)} · '
            '${l10n.pendingUploadsErrorCount(1)}',
          ),
          findsOneWidget,
        );
        // L5-D66: the hero counts pending + failed (1 sending + 1 failed).
        expect(find.text('2'), findsOneWidget, reason: 'hero count at 96');
        expect(find.text(l10n.pendingUploadsHeroLabel(2)), findsOneWidget);
        expect(
          find.text(l10n.pendingUploadsSectionEvidence.toUpperCase()),
          findsOneWidget,
        );
        // Sending: bytes in the label and a bar that follows them.
        expect(
          find.text(
            locale == 'es'
                ? l10n.pendingUploadSendingBytes(62, '8,4', '13,5')
                : l10n.pendingUploadSendingBytes(62, '8.4', '13.5'),
          ),
          findsOneWidget,
        );
        expect(find.byType(ExomGrowBar), findsOneWidget);
        // Failed: its own text (not colour alone), raw diagnostic hidden.
        expect(find.text(l10n.pendingUploadFailedStatus), findsOneWidget);
        expect(find.textContaining('technical diagnostic'), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('empty state has the headline and the existing sentence', (
        tester,
      ) async {
        await pumpScene(
          tester,
          locale: Locale(locale),
          items: [],
          syncFailures: [],
        );
        final l10n = _l10n(tester);
        expect(find.byType(ExomEmptyState), findsOneWidget);
        expect(find.text(l10n.pendingUploadsEmpty), findsOneWidget);
        expect(find.text(l10n.pendingUploadsNone), findsOneWidget);
      });

      for (final (width, scale) in const [
        (320.0, 1.3),
        (320.0, 1.6),
        (360.0, 1.6),
      ]) {
        testWidgets('no overflow at ${width}dp x $scale', (tester) async {
          await pumpScene(
            tester,
            locale: Locale(locale),
            width: width,
            height: 640,
            textScale: scale,
          );
          expectNoOverflow(tester);
        });
      }

      testWidgets('at 2.0x everything is reachable by scrolling', (
        tester,
      ) async {
        await pumpScene(
          tester,
          locale: Locale(locale),
          width: 320,
          height: 640,
          textScale: 2.0,
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('pending-delete-sync-1')),
          200,
        );
        expectNoOverflow(tester);
        expect(find.byKey(const Key('pending-delete-sync-1')), findsOneWidget);
      });

      for (final brightness in Brightness.values) {
        testWidgets('guidelines in ${brightness.name}', (tester) async {
          await pumpScene(
            tester,
            locale: Locale(locale),
            brightness: brightness,
          );
          expectNoOverflow(tester);
          if (brightness == Brightness.light) expectNoLimeInk(tester);
          await expectTapTargetGuidelines(tester);
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        });
      }

      testWidgets('delete sheet closes on a router location change without '
          'discarding (CC 11)', (tester) async {
        final router = await pumpScene(tester, locale: Locale(locale));
        final queue = sl<FeedbackUploadQueueService>() as SceneQueue;
        await tester.tap(find.byKey(const Key('pending-delete-failed')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('pending-delete-confirm')), findsOneWidget);
        router.go('/other');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('pending-delete-confirm')), findsNothing);
        expect(find.text('Otra'), findsOneWidget);
        expect(queue.discarded, isNull);
      });
    });
  }
}
