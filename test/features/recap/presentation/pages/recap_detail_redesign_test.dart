// L5-C3 · Recap, detalle: visible structure of sketch C5 (numbered sections
// with figures in columns, «Nuevo» as a text label, empty values in the
// secondary colour, coach reply) in both themes and under large text.
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';
import 'package:exom_app/features/recap/presentation/pages/recap_detail_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../core/widgets/expect_no_lime_ink.dart';
import '../bloc/recap_bloc_test.dart'
    show RecapTestRepository, recapTestBloc, recapFixture;

/// A recap with answers, an unread trainer comment and a long note.
const recapDetailFilled = <String, Object?>{
  'training_effort': 4,
  'training_sessions': 3,
  'average_daily_steps': 8500,
  'training_progress': 'BETTER',
  'training_notes': 'La última serie de sentadilla se me hizo larga.',
  'food_quality': 4,
  'nutrition_notes': 'Dos cenas fuera de casa.',
  'energy_level': 7,
  'improvement_app_rating': 4,
  'improvement_service_rating': 5,
  'improvement_feedback_text': 'Me gustaría ver los vídeos en pantalla completa.',
  'client_feedback_text': 'Gran semana. Mantén el volumen de pierna.',
  'client_feedback_sent_at': '2026-10-12T10:00:00Z',
};

/// The full scene for large text: long unbroken words and every optional block.
final recapDetailRich = <String, Object?>{
  ...recapDetailFilled,
  'published_changes':
      'Cambios confirmados palabralarga palabralarga palabralarga palabralarga '
      'palabralarga palabralarga palabralarga palabralarga palabralarga '
      'palabralarga palabralarga palabralarga',
  'training_notes':
      'Nota PalabralargaPalabralargaPalabralargaPalabralargaPalabralarga'
      'PalabralargaPalabralargaPalabralargaPalabralargaPalabralarga',
  'hunger_level': 5,
  'digestion_level': 6,
  'stress_enabled': true,
  'stress_level': 3,
  'muscle_pain_zones': ['shoulders', 'hips'],
};

Future<void> pumpDetail(
  WidgetTester tester, {
  Map<String, Object?> extra = const {},
  bool dark = false,
  double width = 360,
  double height = 9000,
  Locale locale = const Locale('es'),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  sl.registerSingleton<LocalStorage>(LocalStorage());
  final repository = RecapTestRepository();
  final bloc = recapTestBloc(repository);
  sl.registerFactory<RecapBloc>(() => bloc);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.dark : AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: const RecapDetailPage(recapId: 'A'),
    ),
  );
  await tester.pump();
  repository.details['A']!.complete(recapFixture(extra: extra));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Color? _colorOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text).first).style?.color;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });
  tearDown(() async => sl.reset());

  testWidgets('sections are numbered 01 to 05 with their title', (tester) async {
    await pumpDetail(tester, extra: recapDetailFilled);
    expect(find.byType(ExomNumberedSectionHeader), findsNWidgets(5));
    for (final entry in {
      '01': 'ENTRENO',
      '02': 'NUTRICIÓN',
      '03': 'RECUPERACIÓN',
      '04': 'SENSACIONES',
      '05': 'MEJORA',
    }.entries) {
      expect(find.text(entry.key), findsOneWidget, reason: entry.key);
      expect(find.text(entry.value), findsOneWidget, reason: entry.value);
    }
  });

  testWidgets('numeric answers are figures in columns, not label/value pairs', (
    tester,
  ) async {
    await pumpDetail(tester, extra: recapDetailFilled);
    expect(find.byType(ExomFigureColumns), findsWidgets);
    final figures = tester
        .widgetList<ExomFigureColumns>(find.byType(ExomFigureColumns))
        .expand((columns) => columns.items)
        .toList();
    expect(
      figures.map((figure) => figure.label),
      containsAll(['Esfuerzo', 'Sesiones', 'Calidad comidas', 'App', 'Servicio']),
    );
    final effort = figures.firstWhere((figure) => figure.label == 'Esfuerzo');
    expect(effort.value, '4');
    final app = figures.firstWhere((figure) => figure.label == 'App');
    expect((app.value, app.unit), ('4', '/5'));
    // The section index is the section's: the figures carry none of their own.
    for (final columns in tester.widgetList<ExomFigureColumns>(
      find.byType(ExomFigureColumns),
    )) {
      expect(columns.numbered, isFalse);
    }
  });

  testWidgets('header has no status pill and the reply uses ExomReplyBlock', (
    tester,
  ) async {
    await pumpDetail(tester, extra: recapDetailFilled);
    expect(find.byType(ExomReplyBlock), findsOneWidget);
    expect(find.text('Gran semana. Mantén el volumen de pierna.'), findsOneWidget);
    expect(find.textContaining('Revisado'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.textContaining('Revisado'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).borderRadius != null,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('«Nuevo» is a text label, not a pill', (tester) async {
    await pumpDetail(tester, extra: recapDetailFilled);
    expect(find.text('Nuevo'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Nuevo'),
        matching: find.byWidgetPredicate(
          (w) =>
              (w is DecoratedBox &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).borderRadius != null) ||
              (w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).borderRadius != null),
        ),
      ),
      findsNothing,
    );
  });

  for (final dark in [false, true]) {
    testWidgets('empty values use the secondary colour (dark=$dark)', (
      tester,
    ) async {
      await pumpDetail(tester, extra: {'training_progress': 'BETTER'}, dark: dark);
      final palette = tester.element(find.byType(Scaffold).first).exomPalette;
      for (final empty in ['No valorado', 'Sin dato', 'Sin zonas']) {
        expect(find.text(empty), findsWidgets, reason: empty);
        for (final element in find.text(empty).evaluate()) {
          final text = element.widget as Text;
          expect(text.style?.color, palette.textSecondary, reason: empty);
        }
      }
      expect(_colorOf(tester, '—'), palette.textSecondary);
      // A real answer is not secondary.
      expect(_colorOf(tester, 'Better'), palette.textPrimary);
    });
  }

  for (final locale in const [Locale('es'), Locale('en')]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      for (final width in [320.0, 360.0]) {
        testWidgets(
          'width $width text x$scale ${locale.languageCode}: no overflow or overlap',
          (tester) async {
            await pumpDetail(
              tester,
              extra: recapDetailRich,
              width: width,
              locale: locale,
              textScaler: AndroidNonlinearTextScaler(scale),
            );
            expect(tester.takeException(), isNull);
            for (final paragraph in tester.renderObjectList<RenderParagraph>(
              find.byType(RichText),
            )) {
              final left = paragraph.localToGlobal(Offset.zero).dx;
              expect(left, greaterThanOrEqualTo(-0.5));
              expect(left + paragraph.size.width, lessThanOrEqualTo(width + 0.5));
              expect(paragraph.didExceedMaxLines, isFalse);
            }
          },
        );
      }
    }
  }

  group('header status line', () {
    testWidgets('SUBMITTED reads «Enviado»', (tester) async {
      await pumpDetail(tester, extra: {'status': 'SUBMITTED'});
      expect(find.text('Enviado'), findsOneWidget);
      expect(find.text('Borrador'), findsNothing);
      expect(find.textContaining('Revisado'), findsNothing);
    });

    testWidgets('DRAFT reads «Borrador»', (tester) async {
      await pumpDetail(tester, extra: {'status': 'DRAFT'});
      expect(find.text('Borrador'), findsOneWidget);
      expect(find.text('Enviado'), findsNothing);
      expect(find.textContaining('Revisado'), findsNothing);
    });

    testWidgets('REVIEWED without date reads «Revisado»', (tester) async {
      await pumpDetail(tester, extra: {'status': 'REVIEWED'});
      expect(find.text('Revisado'), findsOneWidget);
    });

    testWidgets('REVIEWED with date reads «Revisado el dd MMM yyyy»', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        extra: {'status': 'REVIEWED', 'reviewed_at': '2026-10-12T12:00:00'},
      );
      expect(find.text('Revisado el 12 oct 2026'), findsOneWidget);
    });

    for (final (locale, expected) in const [
      (Locale('es'), '05 ENE - 11 ENE 2026'),
      (Locale('en'), '05 JAN - 11 JAN 2026'),
    ]) {
      testWidgets('week range month follows ${locale.languageCode}', (
        tester,
      ) async {
        await pumpDetail(
          tester,
          locale: locale,
          extra: {
            'week_start_date': '2026-01-05',
            'week_end_date': '2026-01-11',
          },
        );
        expect(find.text(expected), findsOneWidget);
      });
    }

    testWidgets('REVIEWED with date uses English months in en', (tester) async {
      await pumpDetail(
        tester,
        locale: const Locale('en'),
        extra: {'status': 'REVIEWED', 'reviewed_at': '2026-10-12T12:00:00'},
      );
      expect(find.textContaining('12 Oct 2026'), findsOneWidget);
    });
  });

  group('feedback read line', () {
    testWidgets('read feedback shows «Leído el…» and no «Nuevo»', (tester) async {
      await pumpDetail(
        tester,
        extra: {
          ...recapDetailFilled,
          'client_feedback_read_at': '2026-10-13T12:00:00',
        },
      );
      expect(find.text('Leído el 13 oct 2026, 12:00'), findsOneWidget);
      expect(find.text('Nuevo'), findsNothing);
    });

    testWidgets('read feedback uses English months in en', (tester) async {
      await pumpDetail(
        tester,
        locale: const Locale('en'),
        extra: {
          ...recapDetailFilled,
          'client_feedback_read_at': '2026-10-13T12:00:00',
        },
      );
      expect(find.textContaining('13 Oct 2026, 12:00'), findsOneWidget);
    });

    testWidgets('unread feedback shows no «Leído el…»', (tester) async {
      await pumpDetail(tester, extra: recapDetailFilled);
      expect(find.textContaining('Leído el'), findsNothing);
      expect(find.text('Nuevo'), findsOneWidget);
    });
  });

  testWidgets('2.0x text at 320 dp scrolls to the end without overflow', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      extra: recapDetailFilled,
      width: 320,
      height: 640,
      textScaler: AndroidNonlinearTextScaler(2.0),
    );
    final last = find.text('Me gustaría ver los vídeos en pantalla completa.');
    await tester.scrollUntilVisible(
      last,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(last.hitTestable(), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('guidelines and no lime ink (dark=$dark)', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpDetail(
        tester,
        extra: recapDetailFilled,
        height: 844,
        width: 390,
        dark: dark,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      if (!dark) expectNoLimeInk(tester);
      semantics.dispose();
    });
  }
}
