// L5-B4 «Perfil» (docs/plans/rediseno-app-l5-contrato-v2.md, ficha L5-B4;
// sketch b-cuenta.html «B1 · Perfil»): error in line keeping the profile
// (EX-Q7), flat muscle mass and sleep blocks (D14-7), muscle mass goal in a
// square sheet with ExomNumeralStepper (D17-2, L5-D31), the visual repaint and
// the common criteria CC 3, CC 4 and CC 11.
import 'dart:async';
import 'dart:io';

import 'package:exom_app/core/formatters/unit_converters.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_index_list.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_line_chart.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_numeral_stepper.dart';
import 'package:exom_app/core/widgets/exom_operation_bar.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:exom_app/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../core/widgets/expect_no_lime_ink.dart';
import '../../challenges/challenges_test_support.dart'
    show expectNoBrokenWords, expectParagraphContrast;
import 'profile_scene.dart';

const _inlineError = Key('profile-inline-error');
const _fullError = Key('profile-full-error');
const _retry = Key('profile-retry');
const _goalEdit = Key('profile-muscle-goal-edit');
const _goalSave = Key('profile-goal-save');
const _goalCancel = Key('profile-goal-cancel');
const _muscleBlock = Key('profile-muscle-block');
const _sleepBlock = Key('profile-sleep-block');
const _sheetPanel = Key('exom-sheet-panel');

const _operationError =
    'No se pudo completar la operación del perfil. Inténtalo de nuevo.';

Finder _textCi(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data ?? w.textSpan?.toPlainText() ?? '').toLowerCase() ==
          text.toLowerCase(),
  description: 'Text "$text" (any case)',
);

/// Loaded scene whose next load fails, refreshed by pulling the list.
Future<ProfileScene> _reloadFails(
  WidgetTester tester, {
  Object error = const SocketException('offline'),
  double width = 390,
  double height = 844,
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('es'),
  Brightness brightness = Brightness.dark,
}) async {
  final scene = await pumpProfileScene(
    tester,
    profiles: SceneProfileRepository(loads: [sceneProfile, error]),
    width: width,
    height: height,
    textScaler: textScaler,
    locale: locale,
    brightness: brightness,
  );
  scene.bloc.add(const ProfileLoadRequested());
  await tester.pumpAndSettle();
  return scene;
}

double _fill(WidgetTester tester, Finder block) {
  final rule = tester.widget<ExomProgressRule>(
    find.descendant(of: block, matching: find.byType(ExomProgressRule)),
  );
  return rule.value;
}

Future<void> _openGoalSheet(WidgetTester tester) async {
  await revealInProfile(tester, find.byKey(_goalEdit));
  await tester.tap(find.byKey(_goalEdit));
  await tester.pumpAndSettle();
}

String _numeral(WidgetTester tester) => tester
    .widget<ExomNumeral>(
      find.descendant(
        of: find.byType(ExomNumeralStepper),
        matching: find.byType(ExomNumeral),
      ),
    )
    .value;

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byKey(_goalSave));
  await tester.pumpAndSettle();
}

void main() {
  group('EX-Q7 error in line', () {
    testWidgets('(b) a failed reload keeps name, headline, figures and the '
        'index, with the error in line and «Reintentar»', (tester) async {
      await _reloadFails(tester, height: 3000);
      expect(find.byKey(_fullError), findsNothing);
      expect(find.byType(ErrorWidget2), findsNothing);
      expect(_textCi('Ana Ruiz'), findsOneWidget);
      expect(_textCi('Mira atrás.'), findsOneWidget);
      expect(_textCi('Sigue adelante.'), findsOneWidget);
      final message = tester.widget<ExomInlineMessage>(
        find.byKey(_inlineError),
      );
      expect(message.kind, ExomMessageKind.error);
      expect(message.title, _operationError);
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.byType(ExomIndexList), findsOneWidget);
      await revealInProfile(tester, find.byKey(_muscleBlock));
      expect(find.byKey(_muscleBlock), findsOneWidget);
    });

    testWidgets('(b) the weight block stays with the error in line (M3)', (
      tester,
    ) async {
      await _reloadFails(tester, height: 3000);
      expect(find.byKey(_inlineError), findsOneWidget);
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.byKey(const Key('profile-weight-hero')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('profile-weight-hero')),
          matching: find.textContaining('68,4', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(find.byType(ExomLineChart), findsOneWidget);
      expect(_textCi('Mira atrás.'), findsOneWidget);
      expect(_textCi('Sigue adelante.'), findsOneWidget);
      expect(find.byType(ExomIndexList), findsOneWidget);
    });

    testWidgets('«Reintentar» reloads and the message goes away', (
      tester,
    ) async {
      final scene = await pumpProfileScene(
        tester,
        profiles: SceneProfileRepository(
          loads: [sceneProfile, const SocketException('x'), sceneProfile],
        ),
      );
      scene.bloc.add(const ProfileLoadRequested());
      await tester.pumpAndSettle();
      expect(find.byKey(_inlineError), findsOneWidget);
      await tester.tap(find.byKey(_retry));
      await tester.pumpAndSettle();
      expect(scene.profiles.calls, 3);
      expect(find.byKey(_inlineError), findsNothing);
      expect(_textCi('Ana Ruiz'), findsOneWidget);
    });

    testWidgets('pull to refresh still reloads, also from the error in line', (
      tester,
    ) async {
      final scene = await pumpProfileScene(
        tester,
        profiles: SceneProfileRepository(
          loads: [sceneProfile, const SocketException('x'), sceneProfile],
        ),
      );
      await pullToRefresh(tester);
      expect(scene.profiles.calls, 2);
      expect(find.byKey(_inlineError), findsOneWidget);
      await pullToRefresh(tester);
      expect(scene.profiles.calls, 3);
      expect(find.byKey(_inlineError), findsNothing);
    });

    testWidgets('a goal that fails to save is shown in line with the profile', (
      tester,
    ) async {
      final profiles = SceneProfileRepository()
        ..updateResult = const SocketException('x');
      await pumpProfileScene(tester, profiles: profiles, height: 3000);
      await _openGoalSheet(tester);
      await tester.tap(find.byIcon(ExomIcons.add));
      await tester.pump();
      await _save(tester);
      expect(find.byKey(_inlineError), findsOneWidget);
      expect(_textCi('Ana Ruiz'), findsOneWidget);
    });

    testWidgets('(c) a first load that fails shows the full-screen error', (
      tester,
    ) async {
      final scene = await pumpProfileScene(
        tester,
        profiles: SceneProfileRepository(
          loads: [const SocketException('x'), sceneProfile],
        ),
      );
      expect(find.byKey(_fullError), findsOneWidget);
      expect(find.byKey(_inlineError), findsNothing);
      expect(_textCi('Ana Ruiz'), findsNothing);
      expect(find.byType(ExomIndexList), findsNothing);
      expect(find.text(_operationError), findsOneWidget);
      expect(find.byType(ErrorWidget2), findsNothing);
      await tester.tap(find.byKey(_retry));
      await tester.pumpAndSettle();
      expect(scene.profiles.calls, 2);
      expect(_textCi('Ana Ruiz'), findsOneWidget);
    });

    testWidgets('a session change during the reload never shows the previous '
        'profile (R12)', (tester) async {
      await _reloadFails(tester, error: const LocalSessionChanged());
      expect(find.byKey(_fullError), findsOneWidget);
      expect(_textCi('Ana Ruiz'), findsNothing);
    });

    testWidgets('each page mount gets its own bloc: the kept profile never '
        'reaches a new page (R12)', (tester) async {
      final scene = await _reloadFails(tester);
      expect(find.byKey(_inlineError), findsOneWidget);
      final first = scene.bloc;
      // Leave the page (as a logout or user switch does) and open it again
      // for another owner whose first load fails.
      scene.router.go('/start');
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsNothing);
      final second = registerProfileBloc(
        SceneProfileRepository(loads: [const SocketException('b')]),
        SceneMetricsRepository(),
      );
      scene.router.push('/profile');
      await tester.pumpAndSettle();
      expect(second.single, isNot(same(first)));
      expect(find.byKey(_fullError), findsOneWidget);
      expect(_textCi('Ana Ruiz'), findsNothing);
    });
  });

  group('D14-7 flat blocks', () {
    for (final (locale, muscle, sleep, share) in const [
      (Locale('es'), '31,2', '7,5', '78\u00A0% del objetivo'),
      (Locale('en'), '31.2', '7.5', '78% of goal'),
    ]) {
      testWidgets('muscle mass and sleep as figure and 4 px bar, '
          '${locale.languageCode}', (tester) async {
        await pumpProfileScene(tester, locale: locale, height: 3000);
        final muscleBlock = find.byKey(_muscleBlock);
        final sleepBlock = find.byKey(_sleepBlock);
        expect(
          find.descendant(
            of: muscleBlock,
            matching: find.textContaining(muscle, findRichText: true),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sleepBlock,
            matching: find.textContaining(sleep, findRichText: true),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: muscleBlock, matching: find.text(share)),
          findsOneWidget,
        );
        expect(_fill(tester, muscleBlock), closeTo(31.2 / 40, 1e-9));
        expect(_fill(tester, sleepBlock), closeTo(7.5 / 8, 1e-9));
        for (final rule in tester.widgetList<ExomProgressRule>(
          find.byType(ExomProgressRule),
        )) {
          expect(rule.thickness, ExomRule.bar);
        }
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter.runtimeType.toString() == '_CircularProgressPainter',
          ),
          findsNothing,
        );
      });
    }

    testWidgets(
      'without data: dashes, no filled bar and «Define tu objetivo»',
      (tester) async {
        await pumpProfileScene(
          tester,
          profiles: SceneProfileRepository(
            loads: [const ProfileEntity(id: 'user-a', firstName: 'Ana')],
          ),
          metrics: SceneMetricsRepository(),
          height: 3000,
        );
        expect(_fill(tester, find.byKey(_muscleBlock)), 0);
        expect(_fill(tester, find.byKey(_sleepBlock)), 0);
        expect(
          find.descendant(
            of: find.byKey(_muscleBlock),
            matching: find.text('Define tu objetivo'),
          ),
          findsOneWidget,
        );
        expect(_textCi('Sin datos'), findsWidgets);
        expect(find.text('Registrar métricas'), findsOneWidget);
      },
    );
  });

  group('D17-2 muscle mass goal sheet', () {
    testWidgets('opens a square sheet with the stepper, not a dialog', (
      tester,
    ) async {
      await pumpProfileScene(tester);
      await _openGoalSheet(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(_sheetPanel), findsOneWidget);
      final stepper = tester.widget<ExomNumeralStepper>(
        find.byType(ExomNumeralStepper),
      );
      expect(stepper.step, 0.5);
      expect(stepper.unit, 'kg');
      expect(stepper.acceptsTypedOutOfRange, isTrue);
      expect(_numeral(tester), '40');
      expect(find.text('Última medición: 31,2\u00A0kg'), findsOneWidget);
    });

    testWidgets('metric: + adds 0,5 kg and saves the same value as today', (
      tester,
    ) async {
      final scene = await pumpProfileScene(tester);
      await _openGoalSheet(tester);
      await tester.tap(find.byIcon(ExomIcons.add));
      await tester.pump();
      expect(_numeral(tester), '40,5');
      await _save(tester);
      expect(scene.profiles.updates.single, {'muscle_mass_goal': 40.5});
    });

    testWidgets('«−» never leaves the goal at 0 or below', (tester) async {
      final scene = await pumpProfileScene(
        tester,
        profiles: SceneProfileRepository(
          loads: [const ProfileEntity(id: 'user-a', muscleMassGoalKg: 0.5)],
        ),
      );
      await _openGoalSheet(tester);
      expect(_numeral(tester), '0,5');
      final stepper = tester.widget<ExomNumeralStepper>(
        find.byType(ExomNumeralStepper),
      );
      expect(stepper.min, greaterThan(0));
      await tester.tap(find.byIcon(ExomIcons.remove), warnIfMissed: false);
      await tester.pump();
      expect(_numeral(tester), '0,5');
      await _save(tester);
      expect(scene.profiles.updates.single, {'muscle_mass_goal': 0.5});
    });

    testWidgets('typed «68,4» in es is saved as 68.4', (tester) async {
      final scene = await pumpProfileScene(tester);
      await _openGoalSheet(tester);
      await tester.tap(find.byKey(ExomNumeralStepper.valueKey));
      await tester.pump();
      await tester.enterText(find.byKey(ExomNumeralStepper.fieldKey), '68,4');
      await tester.pump();
      await _save(tester);
      expect(scene.profiles.updates.single, {'muscle_mass_goal': 68.4});
    });

    testWidgets('typed «68.4» in en is saved as 68.4', (tester) async {
      final scene = await pumpProfileScene(tester, locale: const Locale('en'));
      await _openGoalSheet(tester);
      expect(_numeral(tester), '40');
      await tester.tap(find.byKey(ExomNumeralStepper.valueKey));
      await tester.pump();
      await tester.enterText(find.byKey(ExomNumeralStepper.fieldKey), '68.4');
      await tester.pump();
      await _save(tester);
      expect(scene.profiles.updates.single, {'muscle_mass_goal': 68.4});
    });

    testWidgets('typed 0 is refused as today (> 0) and nothing is saved', (
      tester,
    ) async {
      final scene = await pumpProfileScene(tester);
      await _openGoalSheet(tester);
      await tester.tap(find.byKey(ExomNumeralStepper.valueKey));
      await tester.pump();
      await tester.enterText(find.byKey(ExomNumeralStepper.fieldKey), '0');
      await tester.pump();
      await tester.tap(find.byKey(_goalSave));
      await tester.pumpAndSettle();
      expect(scene.profiles.updates, isEmpty);
      expect(find.byKey(_sheetPanel), findsOneWidget);
    });

    testWidgets('no cap: a typed 900 is saved as today', (tester) async {
      final scene = await pumpProfileScene(tester);
      await _openGoalSheet(tester);
      await tester.tap(find.byKey(ExomNumeralStepper.valueKey));
      await tester.pump();
      await tester.enterText(find.byKey(ExomNumeralStepper.fieldKey), '900');
      await tester.pump();
      await _save(tester);
      expect(scene.profiles.updates.single, {'muscle_mass_goal': 900.0});
    });

    testWidgets('imperial: 1 lb step, clean numeral and the same kilograms as '
        'the dialog', (tester) async {
      // 32 kg = 70.547… lb: the dialog started at «70.5» (one decimal).
      final scene = await pumpProfileScene(
        tester,
        unitSystem: UnitSystem.imperial,
        profiles: SceneProfileRepository(
          loads: [const ProfileEntity(id: 'user-a', muscleMassGoalKg: 32)],
        ),
      );
      await _openGoalSheet(tester);
      final stepper = tester.widget<ExomNumeralStepper>(
        find.byType(ExomNumeralStepper),
      );
      expect(stepper.step, 1);
      expect(stepper.unit, 'lb');
      expect(_numeral(tester), '70,5');
      await tester.tap(find.byIcon(ExomIcons.add));
      await tester.pump();
      expect(_numeral(tester), '71,5');
      // No floating point noise anywhere in the sheet (E9b: «70,50000002»).
      expect(
        find.textContaining(RegExp(r'\d[.,]\d{3,}'), findRichText: true),
        findsNothing,
      );
      await _save(tester);
      expect(scene.profiles.updates.single, {
        'muscle_mass_goal': UnitConverters.weightFromDisplay(
          71.5,
          UnitSystem.imperial,
        ),
      });
    });

    testWidgets('imperial: saving untouched sends what the dialog sent', (
      tester,
    ) async {
      final scene = await pumpProfileScene(
        tester,
        unitSystem: UnitSystem.imperial,
        profiles: SceneProfileRepository(
          loads: [const ProfileEntity(id: 'user-a', muscleMassGoalKg: 32)],
        ),
      );
      await _openGoalSheet(tester);
      await _save(tester);
      expect(scene.profiles.updates.single, {
        'muscle_mass_goal': UnitConverters.weightFromDisplay(
          70.5,
          UnitSystem.imperial,
        ),
      });
    });

    testWidgets('imperial typed «150» saves lb → kg as today', (tester) async {
      final scene = await pumpProfileScene(
        tester,
        unitSystem: UnitSystem.imperial,
        locale: const Locale('en'),
      );
      await _openGoalSheet(tester);
      await tester.tap(find.byKey(ExomNumeralStepper.valueKey));
      await tester.pump();
      await tester.enterText(find.byKey(ExomNumeralStepper.fieldKey), '150');
      await tester.pump();
      await _save(tester);
      expect(scene.profiles.updates.single, {
        'muscle_mass_goal': UnitConverters.weightFromDisplay(
          150,
          UnitSystem.imperial,
        ),
      });
    });

    group('no saved goal: untouched draft (I1)', () {
      SceneProfileRepository noGoal() => SceneProfileRepository(
        loads: [
          const ProfileEntity(id: 'user-a', firstName: 'Ana', lastName: 'Ruiz'),
        ],
      );

      testWidgets('(a) «Guardar» untouched sends nothing and is disabled', (
        tester,
      ) async {
        final scene = await pumpProfileScene(tester, profiles: noGoal());
        await _openGoalSheet(tester);
        // The latest measured mass is only the starting point.
        expect(_numeral(tester), '31,2');
        await tester.tap(find.byKey(_goalSave), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(scene.profiles.updates, isEmpty);
        expect(scene.blocs.single.state, isA<ProfileLoaded>());
        expect(
          tester.widget<ExomPrimaryButton>(find.byKey(_goalSave)).onPressed,
          isNull,
        );
      });

      testWidgets(
        '(a) without any measure the example value is untouched too',
        (tester) async {
          final scene = await pumpProfileScene(
            tester,
            profiles: noGoal(),
            metrics: SceneMetricsRepository(),
          );
          await _openGoalSheet(tester);
          expect(_numeral(tester), '34');
          await tester.tap(find.byKey(_goalSave), warnIfMissed: false);
          await tester.pumpAndSettle();
          expect(scene.profiles.updates, isEmpty);
        },
      );

      testWidgets('(b) metric: one «+» enables «Guardar» and sends the kg', (
        tester,
      ) async {
        final scene = await pumpProfileScene(tester, profiles: noGoal());
        await _openGoalSheet(tester);
        await tester.tap(find.byIcon(ExomIcons.add));
        await tester.pump();
        expect(_numeral(tester), '31,7');
        expect(
          tester.widget<ExomPrimaryButton>(find.byKey(_goalSave)).onPressed,
          isNotNull,
        );
        await _save(tester);
        expect(scene.profiles.updates.single, {'muscle_mass_goal': 31.7});
      });

      testWidgets('(b) imperial: one «+» sends the same kg as the base', (
        tester,
      ) async {
        // 31.2 kg = 68.78… lb: the base dialog started at «68.8» (one decimal).
        final scene = await pumpProfileScene(
          tester,
          unitSystem: UnitSystem.imperial,
          profiles: noGoal(),
        );
        await _openGoalSheet(tester);
        expect(_numeral(tester), '68,8');
        await tester.tap(find.byIcon(ExomIcons.add));
        await tester.pump();
        expect(_numeral(tester), '69,8');
        await _save(tester);
        expect(scene.profiles.updates.single, {
          'muscle_mass_goal': UnitConverters.weightFromDisplay(
            69.8,
            UnitSystem.imperial,
          ),
        });
      });

      testWidgets('(c) a typed value enables «Guardar» and is sent', (
        tester,
      ) async {
        final scene = await pumpProfileScene(tester, profiles: noGoal());
        await _openGoalSheet(tester);
        await tester.tap(find.byKey(ExomNumeralStepper.valueKey));
        await tester.pump();
        await tester.enterText(find.byKey(ExomNumeralStepper.fieldKey), '45,5');
        await tester.pump();
        await _save(tester);
        expect(scene.profiles.updates.single, {'muscle_mass_goal': 45.5});
      });

      testWidgets('with a saved goal «Guardar» is enabled from the start', (
        tester,
      ) async {
        await pumpProfileScene(tester);
        await _openGoalSheet(tester);
        expect(
          tester.widget<ExomPrimaryButton>(find.byKey(_goalSave)).onPressed,
          isNotNull,
        );
      });
    });

    testWidgets('«Cancelar» saves nothing', (tester) async {
      final scene = await pumpProfileScene(tester);
      await _openGoalSheet(tester);
      await tester.tap(find.byIcon(ExomIcons.add));
      await tester.pump();
      await tester.tap(find.byKey(_goalCancel));
      await tester.pumpAndSettle();
      expect(scene.profiles.updates, isEmpty);
      expect(find.byKey(_sheetPanel), findsNothing);
    });

    testWidgets('CC 11: the sheet closes when the location changes', (
      tester,
    ) async {
      final scene = await pumpProfileScene(tester);
      await _openGoalSheet(tester);
      scene.router.push('/other');
      await tester.pumpAndSettle();
      expect(find.byKey(_sheetPanel), findsNothing);
      expect(scene.profiles.updates, isEmpty);
    });
  });

  group('round 3 (emulator O3-O5)', () {
    testWidgets('O3: without weight history the chart area is drawn (grid and '
        'base), bounded to the sketch height, right under the kicker', (
      tester,
    ) async {
      await pumpProfileScene(
        tester,
        profiles: SceneProfileRepository(
          loads: [const ProfileEntity(id: 'user-a', firstName: 'Ana')],
        ),
        metrics: SceneMetricsRepository(),
        height: 3000,
      );
      final chart = find.byType(ExomLineChart);
      expect(chart, findsOneWidget);
      // Base rule plus the sketch's two grid rules: not a blank area.
      expect(
        find.byKey(ExomLineChart.painterKey),
        paintsExactlyCountTimes(#drawLine, 3),
      );
      final size = tester.getSize(chart);
      expect(size.height, closeTo(size.width * 0.4, 0.01));
      final kicker = tester.getBottomLeft(find.text('PROGRESO DEL PESO'));
      expect(tester.getTopLeft(chart).dy - kicker.dy, lessThan(24));
      expect(_textCi('Sin datos'), findsWidgets);
    });

    testWidgets('O4: height and unit never split at 1.6x (imperial)', (
      tester,
    ) async {
      await pumpProfileScene(
        tester,
        unitSystem: UnitSystem.imperial,
        width: 360,
        textScaler: const AndroidNonlinearTextScaler(1.6),
      );
      final identity = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('\u00A0in'),
        description: 'identity line with a no-break «66 in»',
      );
      expect(identity, findsOneWidget);
      expect(
        (tester.widget<Text>(identity).data ?? '').contains('66\u00A0in'),
        isTrue,
      );
      expectNoBrokenWords(tester);
    });

    for (final scale in const [1.0, 1.6]) {
      testWidgets('O5: imperial band labels share one y at ${scale}x', (
        tester,
      ) async {
        await pumpProfileScene(
          tester,
          unitSystem: UnitSystem.imperial,
          height: 3000,
          textScaler: AndroidNonlinearTextScaler(scale),
        );
        final band = find.byKey(const Key('profile-body-data'));
        await revealInProfile(tester, band);
        double top(String label) => tester
            .getTopLeft(find.descendant(of: band, matching: find.text(label)))
            .dy;
        final weight = top('Peso');
        expect(top('Altura'), closeTo(weight, 0.5));
        expect(top('Cintura'), closeTo(weight, 0.5));
      });
    }
  });

  group('solo visual', () {
    testWidgets('index 01-03 opens metrics, photos and recap', (tester) async {
      final scene = await pumpProfileScene(tester, height: 3000);
      final list = tester.widget<ExomIndexList>(find.byType(ExomIndexList));
      expect(list.items.map((i) => i.title), [
        'Actualizar peso y medidas',
        'Fotos de progreso',
        'ReCap semanal',
      ]);
      await revealInProfile(tester, find.byType(ExomIndexList));
      await tester.tap(_textCi('Fotos de progreso'));
      await tester.pumpAndSettle();
      expect(find.text('Fotos'), findsOneWidget);
      scene.router.pop();
      await tester.pumpAndSettle();
      await tester.tap(_textCi('Actualizar peso y medidas'));
      await tester.pumpAndSettle();
      expect(find.text('Métricas'), findsOneWidget);
      final before = scene.profiles.calls;
      scene.router.pop();
      await tester.pumpAndSettle();
      expect(scene.profiles.calls, before + 1);
    });

    testWidgets('identity, headline, weight hero and no legacy cards', (
      tester,
    ) async {
      await pumpProfileScene(tester);
      expect(_textCi('Ana Ruiz'), findsOneWidget);
      expect(
        find.text('Intermedio · Ganar músculo · 168\u00A0cm'),
        findsOneWidget,
      );
      expect(find.text('Racha de 12 días'), findsOneWidget);
      final hero = tester.widget<ExomNumeral>(
        find.byKey(const Key('profile-weight-hero')),
      );
      expect(hero.value, '68,4');
      expect(hero.unit, 'kg');
      expect(find.text('−3,0\u00A0kg'), findsOneWidget);
      expect(find.text('desde 71,4\u00A0kg'), findsOneWidget);
      expect(find.byType(GlassCard), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('avatar uploading: «Enviando» with an indeterminate bar', (
      tester,
    ) async {
      final profiles = SceneProfileRepository()
        ..avatar = Completer<ProfileEntity>();
      final scene = await pumpProfileScene(tester, profiles: profiles);
      scene.bloc.add(ProfileAvatarUploadRequested(File('a.jpg')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Enviando foto de perfil'), findsOneWidget);
      final bar = tester.widget<ExomOperationBar>(
        find.byType(ExomOperationBar),
      );
      expect(bar.value, isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      profiles.avatar!.complete(sceneProfile);
      await tester.pumpAndSettle();
      expect(find.byType(ExomOperationBar), findsNothing);
    });

    testWidgets('loading: skeletons with the final shape, no shimmer cards', (
      tester,
    ) async {
      final profiles = SceneProfileRepository()..gate = Completer<void>();
      await pumpProfileScene(tester, profiles: profiles, settle: false);
      expect(find.byType(ExomSkeleton), findsWidgets);
      expect(find.byType(ShimmerCard), findsNothing);
      expect(find.byType(GlassCard), findsNothing);
      profiles.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ExomSkeleton), findsNothing);
    });
  });

  group('large text (CC 3)', () {
    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets('390 dp, 1.0, ${locale.languageCode}: loaded, error in line '
          'and sheet', (tester) async {
        await pumpProfileScene(tester, locale: locale, height: 3000);
        expect(tester.takeException(), isNull);
        expectNoBrokenWords(tester);
        await _openGoalSheet(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(_goalCancel));
        await tester.pumpAndSettle();
        await _reloadFails(tester, locale: locale, height: 3000);
        expect(tester.takeException(), isNull);
        expectNoBrokenWords(tester);
      });
    }

    for (final (width, scale) in const [
      (320.0, 1.3),
      (320.0, 1.6),
      (360.0, 1.6),
    ]) {
      for (final brightness in Brightness.values) {
        for (final locale in const [Locale('es'), Locale('en')]) {
          testWidgets('no overflow nor broken words: ${width.toInt()} dp, '
              '$scale, ${brightness.name}, ${locale.languageCode}', (
            tester,
          ) async {
            await pumpProfileScene(
              tester,
              width: width,
              height: 6000,
              brightness: brightness,
              locale: locale,
              textScaler: AndroidNonlinearTextScaler(scale),
            );
            expect(tester.takeException(), isNull);
            expectNoBrokenWords(tester);
            await _reloadFails(
              tester,
              width: width,
              height: 6000,
              brightness: brightness,
              locale: locale,
              textScaler: AndroidNonlinearTextScaler(scale),
            );
            expect(tester.takeException(), isNull);
            expectNoBrokenWords(tester);
          });
        }
      }
    }

    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets('sheet, empty and first-load error at 320 dp and 1.6, '
          '${locale.languageCode}', (tester) async {
        await pumpProfileScene(
          tester,
          width: 320,
          height: 700,
          locale: locale,
          unitSystem: UnitSystem.imperial,
          textScaler: const AndroidNonlinearTextScaler(1.6),
        );
        await _openGoalSheet(tester);
        expect(tester.takeException(), isNull);
        expectNoBrokenWords(tester);
        await pumpProfileScene(
          tester,
          width: 320,
          height: 6000,
          locale: locale,
          metrics: SceneMetricsRepository(),
          profiles: SceneProfileRepository(
            loads: [const ProfileEntity(id: 'user-a', firstName: 'Ana')],
          ),
          textScaler: const AndroidNonlinearTextScaler(1.6),
        );
        expect(tester.takeException(), isNull);
        expectNoBrokenWords(tester);
        await pumpProfileScene(
          tester,
          width: 320,
          height: 6000,
          locale: locale,
          profiles: SceneProfileRepository(loads: [const SocketException('x')]),
          textScaler: const AndroidNonlinearTextScaler(1.6),
        );
        expect(tester.takeException(), isNull);
        expectNoBrokenWords(tester);
      });
    }

    testWidgets('2.0x on a 360 dp screen scrolls to the end', (tester) async {
      await pumpProfileScene(
        tester,
        width: 360,
        height: 780,
        textScaler: const AndroidNonlinearTextScaler(2.0),
      );
      final list = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(list).position;
      // The list lays its children out lazily: a single drag stops at the
      // extent estimated before the last block was laid out, so keep
      // dragging (bounded) until the scroll no longer moves.
      for (var i = 0; i < 4; i++) {
        final before = position.pixels;
        await tester.drag(list, const Offset(0, -8000));
        await tester.pumpAndSettle();
        if (position.pixels == before) break;
      }
      expect(tester.takeException(), isNull);
      expect(position.pixels, position.maxScrollExtent);
      expect(
        find.byKey(const Key('profile-body-data')).hitTestable(),
        findsOneWidget,
      );
    });
  });

  group('themes and accessibility (CC 4, D13)', () {
    for (final brightness in Brightness.values) {
      testWidgets('page guidelines, ${brightness.name}', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpProfileScene(tester, brightness: brightness);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        tester.view.physicalSize = const Size(390, 4000);
        await tester.pumpAndSettle();
        final background = tester
            .element(find.byType(Scaffold).first)
            .exomPalette
            .background;
        expectParagraphContrast(
          tester,
          find.byType(ExomIndexList),
          fallback: background,
        );
        if (brightness == Brightness.light) expectNoLimeInk(tester);
        semantics.dispose();
      });

      testWidgets('error in line and sheet, ${brightness.name}', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _reloadFails(tester, brightness: brightness);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        if (brightness == Brightness.light) expectNoLimeInk(tester);
        await pumpProfileScene(tester, brightness: brightness);
        await _openGoalSheet(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        expect(find.byType(ExomPrimaryButton), findsOneWidget);
        if (brightness == Brightness.light) expectNoLimeInk(tester);
        semantics.dispose();
      });
    }
  });
}
