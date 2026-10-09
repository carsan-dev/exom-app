import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_published_review_card.dart';
import 'package:exom_app/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../pages/recap_detail_page_test.dart' show pumpRecapPage;
import '../bloc/recap_bloc_test.dart' show recapFixture;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '320px $platform dark=$dark font=$scale reads full publication',
          (tester) async {
            tester.view.physicalSize = const Size(320, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final semantics = tester.ensureSemantics();
            // Dispose before Flutter's end-of-test verification, not test teardown.
            try {
              final longText =
                  'Párrafo con saltos.\n\n${'Palabralarga' * 60}\nÚltimo objetivo.';
              await tester.pumpWidget(
                MaterialApp(
                  theme: (dark ? AppTheme.dark : AppTheme.light).copyWith(
                    platform: platform,
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: RecapPublishedReviewCard(
                        recap: recapFixture(
                          extra: {
                            'published_coach_summary': '  Resumen confirmado  ',
                            'published_changes': 'Cambios confirmados',
                            'published_next_week_goals': longText,
                            'client_feedback_text': 'LEGACY NOT IN THIS CARD',
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
              expect(find.text('Resumen confirmado'), findsOneWidget);
              expect(find.text('Cambios confirmados'), findsOneWidget);
              expect(find.text(longText), findsOneWidget);
              expect(find.textContaining('PRIVATE'), findsNothing);
              expect(find.text('LEGACY NOT IN THIS CARD'), findsNothing);
              for (final heading in [
                'Resumen del coach',
                'Cambios realizados',
                'Objetivos próxima semana',
              ]) {
                expect(
                  tester
                      .getSemantics(find.text(heading))
                      .getSemanticsData()
                      .flagsCollection
                      .isHeader,
                  isTrue,
                );
              }
              await tester.drag(
                find.byType(SingleChildScrollView),
                const Offset(0, -10000),
              );
              await tester.pumpAndSettle();
              for (final paragraph in tester.renderObjectList<RenderParagraph>(
                find.byType(RichText),
              )) {
                expect(paragraph.didExceedMaxLines, isFalse);
                final left = paragraph.localToGlobal(Offset.zero).dx;
                expect(left, greaterThanOrEqualTo(0));
                expect(left + paragraph.size.width, lessThanOrEqualTo(320));
              }
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }

  testWidgets(
    'absent, null and blank publications render nothing, even with drafts',
    (tester) async {
      for (final values in [
        {
          'published_coach_summary': null,
          'published_changes': null,
          'published_next_week_goals': null,
        },
        {
          'published_coach_summary': ' \n ',
          'published_changes': '\t',
          'published_next_week_goals': '',
        },
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: RecapPublishedReviewCard(recap: recapFixture(extra: values)),
          ),
        );
        expect(find.byType(Text), findsNothing);
        expect(find.byType(Container), findsNothing);
      }
    },
  );
  tearDown(() async => sl.reset());
  testWidgets('only a nonblank published changes field renders its section', (
    tester,
  ) async {
    final repository = await pumpRecapPage(
      tester,
      extra: {
        'published_coach_summary': ' \n\t ',
        'published_changes': 'Cambio confirmado',
        'published_next_week_goals': null,
        'draft_changes': 'PRIVATE CHANGES',
        'draft_next_week_goals': 'PRIVATE GOALS',
      },
    );
    expect(find.text('Cambios realizados'), findsOneWidget);
    expect(find.text('Cambio confirmado'), findsOneWidget);
    expect(find.text('Resumen del coach'), findsNothing);
    expect(find.text('Objetivos próxima semana'), findsNothing);
    expect(find.textContaining('PRIVATE'), findsNothing);
    expect(repository.readCalls, isEmpty);
  });
}
