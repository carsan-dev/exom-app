// L5-E1 «Inicio» (docs/plans/rediseno-app-l5-contrato-v2.md, row E1 and the
// CC of 3.0): rest day versus no plan (L5-D27), «hecha» in the data colour
// (D19), the reload error inline (D14-3), figures in numbered columns, «Tu
// semana» with its count, rich rows and skeletons with the final shape.
import 'dart:async';

import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_rich_row.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/home/presentation/widgets/home_row.dart';
import 'package:exom_app/features/home/presentation/widgets/today_training_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../core/widgets/expect_no_lime_ink.dart';
import 'home_e1_harness.dart';

ExomThemePalette _palette(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first).exomPalette;

ExomTwoLineHeadline? _headline(WidgetTester tester) {
  final found = find.byType(ExomTwoLineHeadline);
  if (found.evaluate().isEmpty) return null;
  return tester.widget<ExomTwoLineHeadline>(found.first);
}

/// Week of 16-22 Nov: Monday done, Wednesday and Friday pending, Thursday a
/// rest day, the rest without assignment.
InicioE1Calendar _week() => InicioE1Calendar(
  InicioE1Calendar.week({
    '2026-11-16': InicioE1Calendar.day('2026-11-16', training: true, done: true),
    '2026-11-18': InicioE1Calendar.day('2026-11-18', training: true),
    '2026-11-19': InicioE1Calendar.day('2026-11-19', rest: true),
    '2026-11-20': InicioE1Calendar.day('2026-11-20', training: true),
  }),
);

Future<void> _scrollToEnd(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 12; i++) {
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }
}

void main() {
  group('rest day versus no plan (L5-D27)', () {
    testWidgets('a day without assignment says «Sin plan. / Todavía.»', (
      tester,
    ) async {
      await pumpInicioE1(
        tester,
        repository: InicioE1Repository((_) => inicioE1Empty),
        calendar: InicioE1Calendar(InicioE1Calendar.week(const {})),
      );
      final empty = tester.widget<ExomEmptyState>(find.byType(ExomEmptyState));
      expect(empty.first, 'Sin plan.');
      expect(empty.second, 'Todavía.');
      expect(empty.lead, 'Tu entrenador aún no te ha asignado un plan');
      expect(empty.body, 'Cuando lo haga, aquí verás la sesión de cada día.');
      expect(find.text('Hoy no tienes entrenamiento asignado.'), findsNothing);
      expect(find.text('Ver calendario'), findsOneWidget);
    });

    testWidgets('a calendar rest day says «Descanso. / También cuenta.»', (
      tester,
    ) async {
      final harness = await pumpInicioE1(
        tester,
        repository: InicioE1Repository((_) => inicioE1Empty),
        calendar: _week(),
        date: DateTime(2026, 11, 19),
      );
      expect(find.byType(ExomEmptyState), findsNothing);
      final headline = _headline(tester)!;
      expect(headline.first, 'Descanso.');
      expect(headline.second, 'También cuenta.');
      expect(
        find.text('Este día no tienes entrenamiento asignado.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Ver calendario'));
      await tester.pumpAndSettle();
      expect(harness.opened?.path, '/calendar');
    });

    for (final (label, calendar) in [
      ('without a calendar', null),
      (
        'when the calendar fails',
        InicioE1Calendar(const {}, error: Exception('offline')),
      ),
    ]) {
      testWidgets('$label the day keeps the single state (Q11)', (
        tester,
      ) async {
        await pumpInicioE1(
          tester,
          repository: InicioE1Repository((_) => inicioE1Empty),
          calendar: calendar,
        );
        expect(find.byType(ExomEmptyState), findsNothing);
        expect(_headline(tester)?.first, 'Descanso.');
        expect(find.text('Hoy no tienes entrenamiento asignado.'), findsOneWidget);
      });
    }
  });

  group('«hecha» is data (D19)', () {
    for (final brightness in Brightness.values) {
      testWidgets('HomeDoneStatus paints icon and text in data, '
          '${brightness.name}', (tester) async {
        await pumpInicioE1(
          tester,
          repository: InicioE1Repository((_) => inicioE1Done),
          brightness: brightness,
        );
        final data = _palette(tester).data;
        final status = find.byType(HomeDoneStatus);
        expect(status, findsOneWidget);
        final icon = tester.widget<Icon>(
          find.descendant(of: status, matching: find.byType(Icon)),
        );
        expect(icon.color, data);
        final text = tester.widget<Text>(
          find.descendant(of: status, matching: find.byType(Text)),
        );
        expect(text.style?.color, data);
        if (brightness == Brightness.light) {
          expectNoLimeInk(tester, brightness: Brightness.light);
        }
      });

      testWidgets('the week strip marks a done day in data, '
          '${brightness.name}', (tester) async {
        await pumpInicioE1(
          tester,
          repository: InicioE1Repository((_) => inicioE1Training),
          calendar: _week(),
          brightness: brightness,
        );
        final check = tester.widget<Icon>(
          find.byKey(const ValueKey('home-week-mark-done-16')),
        );
        expect(check.color, _palette(tester).data);
        // A 3 dp data rule under the done day.
        expect(
          find.byKey(const ValueKey('home-week-done-rule-16')),
          findsOneWidget,
        );
        if (brightness == Brightness.light) {
          expectNoLimeInk(tester, brightness: Brightness.light);
        }
      });
    }
  });

  group('session figures in numbered columns', () {
    List<ExomFigure> figures(WidgetTester tester) => tester
        .widget<ExomFigureColumns>(find.byType(ExomFigureColumns))
        .items;

    testWidgets('before starting: exercises, sets and minutes', (tester) async {
      await pumpInicioE1(
        tester,
        repository: InicioE1Repository((_) => inicioE1Training),
      );
      final items = figures(tester);
      expect(items.map((f) => f.value), ['6', '22', '55']);
      expect(items.map((f) => f.label), ['ejercicios', 'series', 'min aprox.']);
      expect(
        tester.widget<ExomFigureColumns>(find.byType(ExomFigureColumns)).numbered,
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byType(TodayTrainingCard),
          matching: find.byType(ExomProgressRule),
        ),
        findsNothing,
      );
    });

    testWidgets('in progress: done of total, minutes left and a 4 dp rule', (
      tester,
    ) async {
      await pumpInicioE1(
        tester,
        repository: InicioE1Repository((_) => inicioE1InProgress),
      );
      final items = figures(tester);
      expect(items.map((f) => f.value), ['2', '22', '≈30']);
      expect(items.first.unit, '/6');
      expect(items.map((f) => f.label), [
        'ejercicios',
        'series',
        'min restantes',
      ]);
      final rule = tester.widget<ExomProgressRule>(
        find.descendant(
          of: find.byType(TodayTrainingCard),
          matching: find.byType(ExomProgressRule),
        ),
      );
      expect(rule.value, closeTo(2 / 6, 1e-9));
      expect(rule.thickness, 4);
      expect(find.text('CONTINUAR SESIÓN'), findsOneWidget);
    });

    testWidgets('done: exercises and sets, quiet status, no minutes', (
      tester,
    ) async {
      await pumpInicioE1(
        tester,
        repository: InicioE1Repository((_) => inicioE1Done),
      );
      expect(figures(tester).map((f) => f.value), ['6', '22']);
      expect(find.byType(HomeDoneStatus), findsOneWidget);
      expect(find.text('Ver entrenamiento'), findsOneWidget);
    });
  });

  group('«Tu semana»', () {
    testWidgets('title and count of done sessions from the marks', (
      tester,
    ) async {
      await pumpInicioE1(
        tester,
        repository: InicioE1Repository((_) => inicioE1Training),
        calendar: _week(),
      );
      expect(find.text('TU SEMANA'), findsOneWidget);
      expect(find.text('1 de 3 sesiones hechas'), findsOneWidget);
    });

    testWidgets('without marks there is no count', (tester) async {
      await pumpInicioE1(
        tester,
        repository: InicioE1Repository((_) => inicioE1Training),
      );
      expect(find.text('TU SEMANA'), findsOneWidget);
      expect(find.textContaining('sesiones hechas'), findsNothing);
    });
  });

  group('rich rows', () {
    testWidgets('diet with its kcal, meals and segments; streak with its days', (
      tester,
    ) async {
      final harness = await pumpInicioE1(
        tester,
        repository: InicioE1Repository((_) => inicioE1Training),
      );
      final rows = tester
          .widgetList<ExomRichRow>(find.byType(ExomRichRow))
          .toList();
      final diet = rows.firstWhere((r) => r.title.startsWith('Definición'));
      expect(diet.title, 'Definición · 2.150 kcal');
      expect(diet.facts, contains('1 de 4 comidas hechas'));
      final segments = tester.widget<ExomProgressRule>(
        find.descendant(
          of: find.byWidget(diet),
          matching: find.byType(ExomProgressRule),
        ),
      );
      expect(segments.segments, 4);
      expect(segments.value, closeTo(1 / 4, 1e-9));

      final streak = rows.firstWhere((r) => r.title == 'Racha de 12 días');
      expect(streak.facts, 'Retos y logros');
      final leading = streak.leading as ExomRowDate;
      expect(leading.day, '12');
      expect(leading.label, 'días');

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Racha de 12 días'));
      await tester.pumpAndSettle();
      expect(harness.opened?.path, '/challenges');
    });
  });

  group('reload error inline (D14-3)', () {
    testWidgets('a failed refresh leaves an inline line with retry, no '
        'SnackBar, and the data stays', (tester) async {
      final harness = await pumpInicioE1(
        tester,
        repository: InicioE1Repository((_) => inicioE1Training),
        calendar: _week(),
      );
      harness.repository.error = Exception('boom');
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      final line = tester.widget<ExomInlineMessage>(
        find.byType(ExomInlineMessage),
      );
      expect(line.kind, ExomMessageKind.pendiente);
      expect(line.title, 'No se pudo cargar el resumen. Vuelve a intentarlo.');
      expect(line.actionLabel, 'Reintentar');
      expect(find.text('PIERNA FUERZA'), findsOneWidget);
      // The week marks arriving again keep the line.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExomInlineMessage), findsOneWidget);

      harness.repository.error = null;
      final loads = harness.repository.dates.length;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(harness.repository.dates.length, loads + 1);
      expect(find.byType(ExomInlineMessage), findsNothing);
    });

    testWidgets('without network it says «Sin conexión · datos guardados»', (
      tester,
    ) async {
      final harness = await pumpInicioE1(
        tester,
        repository: InicioE1Repository((_) => inicioE1Training),
      );
      harness.repository.error = const ApiException(
        statusCode: 0,
        message: 'offline',
      );
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ExomInlineMessage>(find.byType(ExomInlineMessage)).title,
        'Sin conexión · datos guardados',
      );
    });
  });

  testWidgets('loading: skeletons with the final shape, announced once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = InicioE1Repository((_) => inicioE1Training)
      ..gate = Completer();
    // Released before the bloc closes, even when an expectation fails.
    addTearDown(() {
      if (!repository.gate!.isCompleted) repository.gate!.complete();
    });
    await pumpInicioE1(tester, repository: repository, settle: false);
    await tester.pump();
    expect(find.byType(ShimmerCard), findsNothing);
    expect(find.byType(ExomSkeleton), findsWidgets);
    expect(find.bySemanticsLabel('Cargando el resumen de hoy'), findsOneWidget);
    repository.gate!.complete();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ExomSkeleton), findsNothing);
    semantics.dispose();
  });

  group('2.0x at 320 dp: everything reachable by scrolling (CC 3)', () {
    for (final (label, summary, calendar) in [
      ('session', inicioE1Training, null),
      ('no plan', inicioE1Empty, InicioE1Calendar(InicioE1Calendar.week({}))),
    ]) {
      testWidgets(label, (tester) async {
        await pumpInicioE1(
          tester,
          repository: InicioE1Repository((_) => summary),
          calendar: calendar,
          width: 320,
          height: 568,
          textScaler: const AndroidNonlinearTextScaler(2.0),
        );
        expect(tester.takeException(), isNull);
        await _scrollToEnd(tester);
        expect(find.textContaining('Sueño').hitTestable(), findsOneWidget);
      });
    }
  });

  group('contrast, tap targets and no lime ink (CC 4)', () {
    for (final brightness in Brightness.values) {
      for (final (label, summary, calendar, date) in [
        ('session', inicioE1Training, _week(), null),
        ('rest day', inicioE1Empty, _week(), DateTime(2026, 11, 19)),
        (
          'no plan',
          inicioE1Empty,
          InicioE1Calendar(InicioE1Calendar.week({})),
          null,
        ),
      ]) {
        testWidgets('$label, ${brightness.name}', (tester) async {
          await pumpInicioE1(
            tester,
            repository: InicioE1Repository((_) => summary),
            calendar: calendar,
            date: date,
            brightness: brightness,
          );
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          if (brightness == Brightness.light) {
            expectNoLimeInk(tester, brightness: Brightness.light);
          }
        });
      }
    }
  });
}
