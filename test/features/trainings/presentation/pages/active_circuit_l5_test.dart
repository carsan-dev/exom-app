// L5-E5 «Circuito» (docs/plans/rediseno-app-l5-contrato-v2.md, block E): the
// active circuit repainted after the sketch frame «Circuito activo»
// (e-migradas.html, f-circ). Presentation only: the round is the protagonist
// (numeral «2/3» at 120, kicker, two-line headline and a rule of one segment
// per round), the target and the last time go in columns, and «Esta ronda» is
// a list numbered by position with «Ahora» marked by a rule. DA1–DA5 and every
// behaviour test stay in active_circuit_redesign_test.dart.
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/widgets/prescription_hero.dart';
import 'package:exom_app/features/trainings/presentation/widgets/set_value_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/exom_component_harness.dart';
import '../../../../core/widgets/expect_no_lime_ink.dart';
import 'circuit_test_harness.dart';

final _a = circuitExercise('a', 'Burpees', targetRir: 2, restSeconds: 30);
final _b = circuitExercise('b', 'Sentadilla con salto', restSeconds: 20);
final _c = circuitExercise('c', 'Remo con mancuerna', targetValue: 10);

const _footer = ValueKey('circuit-executing-footer');
const _step = Key('circuit-step');

/// Round 2 of 3, second exercise: the first one logged in this round, the
/// third still to do.
Map<String, Object?> _midRound2() => preL3State(
  round: 2,
  exerciseIndex: 1,
  performances: {
    'a': [
      {'set_number': 1, 'reps': 12},
      {'set_number': 2, 'reps': 11, 'weight_kg': 12.5},
    ],
    'b': [
      {'set_number': 1, 'reps': 12},
    ],
    'c': [
      {'set_number': 1, 'reps': 10},
    ],
  },
);

Finder _row(int index) => find.byKey(ValueKey('circuit-row-$index'));

Finder _inRow(int index, Finder matching) =>
    find.descendant(of: _row(index), matching: matching);

ExomThemePalette _palette(WidgetTester tester) => Theme.of(
  tester.element(find.byKey(_footer)),
).extension<ExomThemePalette>()!;

TrainingExerciseEntity _withOrder(TrainingExerciseEntity e, int order) =>
    TrainingExerciseEntity(
      id: e.id,
      order: order,
      sets: e.sets,
      repsOrDuration: e.repsOrDuration,
      measureType: e.measureType,
      targetValue: e.targetValue,
      targetRir: e.targetRir,
      restSeconds: e.restSeconds,
      requestSetTracking: e.requestSetTracking,
      blockId: e.blockId,
      exercise: e.exercise,
    );

void main() {
  group('executing', () {
    testWidgets('the round is the protagonist: numeral «2/3» at 120, kicker, '
        'two-line headline and one rule segment per round', (tester) async {
      await pumpCircuit(
        tester,
        exercises: [_a, _b, _c],
        rounds: 3,
        restored: _midRound2(),
      );
      final l10n = circuitL10n(tester);
      expect(tester.takeException(), isNull);

      final numeral = tester.widget<ExomNumeral>(
        find.descendant(
          of: find.byKey(_step),
          matching: find.byType(ExomNumeral),
        ),
      );
      expect(numeral.value, '2');
      expect(numeral.unit, '/3');
      expect(numeral.size, ExomNumeralSize.hero120);

      final rule = tester.widget<ExomProgressRule>(
        find.descendant(
          of: find.byKey(_step),
          matching: find.byType(ExomProgressRule),
        ),
      );
      expect(rule.segments, 3);
      expect(rule.value, closeTo(2 / 3, 1e-9));

      expect(
        tester.widget<ExomKicker>(find.byKey(const Key('circuit-round'))).text,
        l10n.circuitRoundOf(2, 3),
      );
      // The round moved from the header to the step: painted once, in the
      // kicker's upper case.
      expect(find.text(l10n.circuitRoundOf(2, 3)), findsNothing);
      expect(
        find.text(l10n.circuitRoundOf(2, 3).toUpperCase()),
        findsOneWidget,
      );

      final headline = tester.widget<ExomTwoLineHeadline>(
        find.byKey(const Key('circuit-exercise-name')),
      );
      expect(headline.first, l10n.circuitStepExercise('Sentadilla con salto'));
      expect(headline.second, l10n.circuitStepPosition(2, 3));
    });

    testWidgets('target and last time go in columns with the labels above '
        '(«Objetivo» 64 in data, «Última vez» 56 in text with «× 22,5 kg · '
        'RIR 2» below); no «Anterior» line; «Tu peso» and the rest after stay '
        'as lines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCircuit(
        tester,
        exercises: [_a, _b],
        previous: {
          'a': const [
            SetPerformance(setNumber: 1, reps: 10, weightKg: 22.5, rir: 2),
          ],
        },
      );
      final l10n = circuitL10n(tester);
      final columns = tester.widget<ExomFigureColumns>(
        find.byType(ExomFigureColumns),
      );
      expect(columns.labelsAbove, isTrue);
      expect(columns.numbered, isFalse);
      expect(
        [
          for (final f in columns.items)
            (f.value, f.unit, f.label, f.size, f.tone, f.detail),
        ],
        [
          (
            '12',
            l10n.activeExerciseUnitReps,
            l10n.circuitTargetLabel,
            ExomFigureSize.s64,
            ExomFigureTone.data,
            l10n.activeExerciseRir(2),
          ),
          (
            '10',
            l10n.activeExerciseUnitReps,
            l10n.exerciseLastTimeLabel,
            ExomFigureSize.s56,
            ExomFigureTone.text,
            '× 22,5 kg · RIR 2',
          ),
        ],
      );
      expect(find.byKey(const Key('circuit-target')), findsOneWidget);
      expect(find.byKey(const Key('circuit-last-time')), findsOneWidget);
      expect(find.text('× 22,5 kg · RIR 2'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          '${l10n.exerciseLastTimeLabel}: 10 × 22,5 kg · RIR 2',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Anterior'), findsNothing);
      expect(find.byKey(const Key('circuit-previous')), findsNothing);
      expect(find.text('Tu peso: 22,5\u00a0kg'), findsOneWidget);
      expect(find.text(l10n.activeExerciseRestAfter(30)), findsOneWidget);
      handle.dispose();
    });

    for (final brightness in Brightness.values) {
      testWidgets('at text 1.6 the «Objetivo» label stays on one line and the '
          'figures of both columns share a baseline, RIR in the detail '
          '(${brightness.name})', (tester) async {
        await pumpCircuit(
          tester,
          exercises: [_a, _b],
          textScale: 1.6,
          brightness: brightness,
          previous: {
            'a': const [
              SetPerformance(setNumber: 1, reps: 14, weightKg: 14, rir: 2),
            ],
          },
        );
        final l10n = circuitL10n(tester);
        // The label sits in the row of labels, above the keyed figure cell.
        final label = find.text('OBJETIVO');
        expect(label, findsOneWidget);
        final labelBox = tester.renderObject<RenderBox>(label);
        // One line of the kicker at 1.6, not two.
        final oneLine =
            ExomType.kicker.fontSize! * (ExomType.kicker.height ?? 1.3) * 1.6;
        expect(labelBox.size.height, lessThan(oneLine * 1.5));
        expect(
          find.descendant(
            of: find.byKey(const Key('circuit-target')),
            matching: find.text(l10n.activeExerciseRir(2)),
          ),
          findsOneWidget,
        );
        // Real baseline of each figure's RenderParagraph mapped to global (a
        // FittedBox scale included), not a TextPainter re-layout: those
        // matched in the test while the device showed 2-3 dp of difference.
        double baseline(Key cell) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byKey(cell),
              matching: find.byWidgetPredicate(
                (w) => w is RichText && w.text.toPlainText().contains('reps'),
              ),
            ),
          );
          final distance = paragraph.getDryBaseline(
            paragraph.constraints,
            TextBaseline.alphabetic,
          )!;
          return paragraph.localToGlobal(Offset(0, distance)).dy;
        }

        final target = baseline(const Key('circuit-target'));
        final last = baseline(const Key('circuit-last-time'));
        expect((target - last).abs(), lessThan(0.5));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('«Última vez» detail in the user unit (imperial)', (
      tester,
    ) async {
      await pumpCircuit(
        tester,
        exercises: [_a, _b],
        unitSystem: UnitSystem.imperial,
        previous: {
          'a': const [
            SetPerformance(setNumber: 1, reps: 10, weightKg: 22.5, rir: 2),
          ],
        },
      );
      final lb = const WeightText(UnitSystem.imperial, ',')(22.5);
      expect(lb, contains('lb'));
      expect(find.text('× $lb · RIR 2'), findsOneWidget);
    });

    testWidgets('a previous set without a count (only weight and RIR) goes in '
        'the «Última vez» detail, without a figure', (tester) async {
      await pumpCircuit(
        tester,
        exercises: [_a, _b],
        previous: {
          'a': const [SetPerformance(setNumber: 1, weightKg: 20, rir: 1)],
        },
      );
      final l10n = circuitL10n(tester);
      final columns = tester.widget<ExomFigureColumns>(
        find.byType(ExomFigureColumns),
      );
      final last = columns.items.last;
      expect(last.label, l10n.exerciseLastTimeLabel);
      expect(last.value, '');
      expect(last.detail, '20 kg · RIR 1');
      expect(find.textContaining('Anterior'), findsNothing);
    });

    // Follow-up of the review: both time branches of `_lastTimeFigure`.
    testWidgets('«Última vez» of a target in minutes: whole minutes in min, '
        'otherwise seconds', (tester) async {
      final timed = circuitExercise(
        't',
        'Plancha',
        targetValue: null,
        measureType: null,
        repsOrDuration: '2 min',
      );
      await pumpCircuit(
        tester,
        exercises: [timed, _b],
        previous: {
          't': const [SetPerformance(setNumber: 1, seconds: 120)],
        },
      );
      final l10n = circuitL10n(tester);
      var columns = tester.widget<ExomFigureColumns>(
        find.byType(ExomFigureColumns),
      );
      expect(columns.items.first.unit, l10n.activeExerciseUnitMinutes);
      expect(
        (columns.items.last.value, columns.items.last.unit),
        ('2', l10n.activeExerciseUnitMinutes),
      );

      await pumpCircuit(
        tester,
        exercises: [timed, _b],
        previous: {
          't': const [SetPerformance(setNumber: 1, seconds: 90)],
        },
      );
      columns = tester.widget<ExomFigureColumns>(
        find.byType(ExomFigureColumns),
      );
      expect(
        (columns.items.last.value, columns.items.last.unit),
        ('90', l10n.activeExerciseUnitSeconds),
      );
    });

    testWidgets('«Última vez» of a target in seconds: seconds', (tester) async {
      final timed = circuitExercise(
        't',
        'Plancha',
        targetValue: null,
        measureType: null,
        repsOrDuration: '45 s',
      );
      await pumpCircuit(
        tester,
        exercises: [timed, _b],
        previous: {
          't': const [SetPerformance(setNumber: 1, seconds: 40, rir: 1)],
        },
      );
      final l10n = circuitL10n(tester);
      final columns = tester.widget<ExomFigureColumns>(
        find.byType(ExomFigureColumns),
      );
      expect(columns.items.first.unit, l10n.activeExerciseUnitSeconds);
      expect(
        (
          columns.items.last.value,
          columns.items.last.unit,
          columns.items.last.detail,
        ),
        ('40', l10n.activeExerciseUnitSeconds, 'RIR 1'),
      );
    });

    testWidgets('«Ver técnica» is a text link: play icon with a video, no '
        'icon with only texts; 48 dp target', (tester) async {
      TrainingExerciseEntity withTechnique({String? video, String? text}) =>
          TrainingExerciseEntity(
            id: 'v',
            order: 0,
            sets: 1,
            repsOrDuration: '12',
            measureType: ExerciseMeasureType.reps,
            targetValue: 12,
            restSeconds: 0,
            blockId: _a.blockId,
            exercise: ExerciseEntity(
              id: 'ex-v',
              name: 'Burpees',
              muscleGroups: const [],
              videoUrl: video,
              techniqueText: text,
            ),
          );
      const link = Key('circuit-technique');

      for (final (video, text, icon) in const [
        ('https://example.com/v.mp4', null, ExomIcons.play),
        (null, 'Pecho al suelo.', null),
      ]) {
        await pumpCircuit(
          tester,
          exercises: [
            withTechnique(video: video, text: text),
            _b,
          ],
        );
        final l10n = circuitL10n(tester);
        await tester.scrollUntilVisible(
          find.byKey(link),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        final widget = tester.widget<ExomTextLink>(find.byKey(link));
        expect(widget.label, l10n.activeExerciseTechniqueButton);
        expect(widget.icon, icon);
        final size = tester.getSize(
          find.descendant(of: find.byKey(link), matching: find.byType(InkWell)),
        );
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('without a previous count only the target column is shown', (
      tester,
    ) async {
      await pumpCircuit(tester, exercises: [_b, _a]);
      final l10n = circuitL10n(tester);
      final columns = tester.widget<ExomFigureColumns>(
        find.byType(ExomFigureColumns),
      );
      expect(
        [for (final f in columns.items) (f.value, f.unit, f.label)],
        [('12', l10n.activeExerciseUnitReps, l10n.circuitTargetLabel)],
      );
      expect(find.text(l10n.activeExerciseNoPrevious), findsOneWidget);
    });
  });

  group('«Esta ronda»', () {
    testWidgets('section header with the logged count; rows numbered «01», '
        '«02», «03»; done with a data check, «Ahora» with a rule, later ones '
        'with «Después»', (tester) async {
      await pumpCircuit(
        tester,
        exercises: [_a, _b, _c],
        rounds: 3,
        restored: _midRound2(),
      );
      final l10n = circuitL10n(tester);
      final palette = _palette(tester);
      await tester.scrollUntilVisible(
        _row(2),
        100,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text(l10n.circuitThisRound.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.circuitRoundLogged(1, 3)), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        expect(
          tester
              .widget<ExomIndexNumber>(_inRow(i, find.byType(ExomIndexNumber)))
              .n,
          i + 1,
        );
      }

      // Done: check in the data colour (D19: «hecha» is client data), value
      // in the text colour; the device icon stays on the status line only.
      final check = tester.widget<Icon>(
        _inRow(0, find.byIcon(ExomIcons.check)),
      );
      expect(check.color, palette.data);
      expect(_inRow(0, find.byIcon(ExomIcons.phone)), findsNothing);

      // Now: «Ahora · 12 reps» and the 3 dp rule in the text colour.
      expect(
        _inRow(
          1,
          find.text(
            '${l10n.activeExerciseSetNow} · 12 reps',
            findRichText: true,
          ),
        ),
        findsOneWidget,
      );
      final nowRule = tester.widget<ColoredBox>(
        _inRow(1, find.byKey(const Key('circuit-row-now-rule'))),
      );
      expect(nowRule.color, palette.textPrimary);
      expect(
        tester
            .getSize(_inRow(1, find.byKey(const Key('circuit-row-now-rule'))))
            .width,
        3,
      );
      expect(
        _inRow(0, find.byKey(const Key('circuit-row-now-rule'))),
        findsNothing,
      );

      // Later: «Después · 10 reps».
      expect(
        _inRow(
          2,
          find.text('${l10n.circuitRowLater} · 10 reps', findRichText: true),
        ),
        findsOneWidget,
      );
    });

    // Follow-up of the review: the «Ahora» row reads the target it paints.
    testWidgets('the «Ahora» row semantics read the painted target', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCircuit(
        tester,
        exercises: [_a, _b, _c],
        rounds: 3,
        restored: _midRound2(),
      );
      final l10n = circuitL10n(tester);
      await tester.scrollUntilVisible(
        _row(1),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.getSemantics(_row(1)),
        matchesSemantics(
          label: l10n.circuitRowNowWithTargetA11y(
            'Sentadilla con salto',
            PrescriptionTarget.of(_b).shortLabel(l10n)!,
          ),
        ),
      );
      expect(
        l10n.circuitRowNowWithTargetA11y('Sentadilla con salto', 'X'),
        'Sentadilla con salto: ahora, X',
      );
      handle.dispose();
    });

    testWidgets('rows are numbered by position, never by the raw order', (
      tester,
    ) async {
      await pumpCircuit(
        tester,
        exercises: [
          _withOrder(_a, 0),
          _withOrder(_b, 1000),
          _withOrder(_c, 2000),
        ],
      );
      for (var i = 0; i < 3; i++) {
        expect(
          tester
              .widget<ExomIndexNumber>(_inRow(i, find.byType(ExomIndexNumber)))
              .n,
          i + 1,
        );
      }
      expect(find.text('00'), findsNothing);
      expect(find.text('1000'), findsNothing);
      expect(find.text('2000'), findsNothing);
    });

    for (final brightness in Brightness.values) {
      testWidgets('a done row marks «hecha» in the data colour (D19, '
          '${brightness.name})', (tester) async {
        await pumpCircuit(
          tester,
          exercises: [_a, _b, _c],
          rounds: 3,
          restored: _midRound2(),
          brightness: brightness,
        );
        final palette = _palette(tester);
        expect(
          tester.widget<Icon>(_inRow(0, find.byIcon(ExomIcons.check))).color,
          palette.data,
        );
      });
    }
  });

  testWidgets('rest: the round stays on screen as the kicker', (tester) async {
    final end = DateTime.now().add(const Duration(seconds: 60));
    await pumpCircuit(
      tester,
      exercises: [_a, _b],
      restBetweenRounds: 60,
      restored: preL3State(
        round: 1,
        exerciseIndex: 1,
        status: 'roundResting',
        restEndsAt: end,
        performances: {
          'a': [
            {'set_number': 1, 'reps': 12},
          ],
          'b': [
            {'set_number': 1, 'reps': 12},
          ],
        },
      ),
    );
    final l10n = circuitL10n(tester);
    expect(
      tester.widget<ExomKicker>(find.byKey(const Key('circuit-round'))).text,
      l10n.circuitRoundOf(1, 2),
    );
    expect(find.text(l10n.circuitRoundRestTitle.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.circuitRoundLogged(2, 2)), findsOneWidget);
  });

  testWidgets('ready: the numeral shows the last round and the rule is full', (
    tester,
  ) async {
    await pumpCircuit(
      tester,
      exercises: [_a, _b],
      restored: preL3State(
        round: 2,
        exerciseIndex: 1,
        readyToFinish: true,
        performances: {
          'a': [
            {'set_number': 1, 'reps': 12},
            {'set_number': 2, 'reps': 12},
          ],
          'b': [
            {'set_number': 1, 'reps': 12},
            {'set_number': 2, 'reps': 12},
          ],
        },
      ),
    );
    final l10n = circuitL10n(tester);
    final numeral = tester.widget<ExomNumeral>(
      find.descendant(
        of: find.byKey(_step),
        matching: find.byType(ExomNumeral),
      ),
    );
    expect(numeral.value, '2');
    expect(numeral.unit, '/2');
    final rule = tester.widget<ExomProgressRule>(
      find.descendant(
        of: find.byKey(_step),
        matching: find.byType(ExomProgressRule),
      ),
    );
    expect(rule.value, 1);
    expect(find.text(l10n.circuitReadyTitle.toUpperCase()), findsOneWidget);
    expect(find.byType(ExomFigureColumns), findsNothing);
  });

  // CC 4: every scene of the batch with a golden (circuito_activo,
  // descanso_circuito, circuito_listo, hoja_circuito) in both themes: no lime
  // ink in light and tap targets. Text contrast of those four golden scenes in
  // both themes is asserted by test/a11y/redesign_baseline_guidelines_test.dart,
  // which resolves each sampled label deterministically: the raw
  // textContrastGuideline sampler reports antialiased edge shades of the 14 px
  // DM Sans lines here (1.36 / 2.40) already on the base 55b3048.
  group('CC 4', () {
    final scenes = <String, Map<String, Object?>? Function()>{
      'circuito_activo': _midRound2,
      'descanso_circuito': () => preL3State(
        round: 1,
        exerciseIndex: 2,
        status: 'roundResting',
        restEndsAt: DateTime.now().add(const Duration(seconds: 60)),
        performances: {
          'a': [
            {'set_number': 1, 'reps': 12},
          ],
          'b': [
            {'set_number': 1, 'reps': 12, 'weight_kg': 16.0, 'rir': 1},
          ],
          'c': [
            {'set_number': 1, 'reps': 10, 'weight_kg': 20.0},
          ],
        },
      ),
      'circuito_listo': () => preL3State(
        round: 3,
        exerciseIndex: 2,
        readyToFinish: true,
        performances: {
          for (final id in const ['a', 'b', 'c'])
            id: [
              for (var round = 1; round <= 3; round++)
                {'set_number': round, 'reps': 10},
            ],
        },
      ),
      'hoja_circuito': _midRound2,
    };
    for (final brightness in Brightness.values) {
      for (final scene in scenes.entries) {
        testWidgets('${scene.key} (${brightness.name}): no lime ink and tap '
            'targets', (tester) async {
          await pumpCircuit(
            tester,
            exercises: [_a, _b, _c],
            rounds: 3,
            restBetweenRounds: 60,
            restored: scene.value(),
            brightness: brightness,
          );
          if (scene.key == 'hoja_circuito') {
            await tester.tap(find.byKey(_footer));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          expect(tester.takeException(), isNull);
          if (brightness == Brightness.light) expectNoLimeInk(tester);
          await expectTapTargetGuidelines(tester);
        });
      }
    }
  });
}
