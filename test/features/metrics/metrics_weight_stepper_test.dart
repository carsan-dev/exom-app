// L5-E9b, D14-4 (docs/plans/rediseno-app-l5-contrato-v2.md, block E and the
// table «Rangos de los steppers» after T0.4): the only slider of the metrics
// form (weight) becomes an ExomNumeralStepper with today's range, step, typed
// entry and `_weightTouched`, and the payload does not change:
//
// * ± move the weight by 0.5 kg within 40–160 kg (the slider had 240
//   divisions over 40–160 kg). In imperial the figure is shown in lb, but the
//   stored step stays 0.5 kg.
// * Typing works as the old manual mode: comma or point, in the user's unit,
//   lb converted with UnitConverters.weightFromDisplay, any value (no range
//   cap); empty or not a number blocks the save with validWeightRequired.
// * Untouched, the save sends the loaded currentWeightKg, not the stepper.
//
// Presentation only: the bloc and the use cases are the real ones; the
// repository is a recording fake.
import 'package:exom_app/core/formatters/unit_converters.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_numeral_stepper.dart';
import 'package:exom_app/core/widgets/exom_stepper.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:exom_app/features/metrics/domain/usecases/save_metric_usecase.dart';
import 'package:exom_app/features/metrics/presentation/bloc/metrics_bloc.dart';
import 'package:exom_app/features/metrics/presentation/pages/metrics_page.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _stepperKey = Key('metrics-weight-stepper');

BodyMetricEntity _metricWithWeight(double weightKg) => BodyMetricEntity(
  id: 'metric-1',
  date: DateTime(2026, 11, 18),
  weightKg: weightKg,
  heightCm: 180,
);

class _Repository extends Fake implements MetricsRepository {
  _Repository(this.latest, {this.onDate});

  final BodyMetricEntity? latest;

  /// The metric of any explicit date (a date picked in the form); [latest]
  /// when null.
  final BodyMetricEntity? onDate;
  final saved = <Map<String, dynamic>>[];

  @override
  Future<BodyMetricEntity?> getLatestMetric({String? date}) async =>
      date != null && onDate != null ? onDate : latest;

  @override
  Future<BodyMetricEntity> saveMetric(Map<String, dynamic> data) async {
    saved.add({...data});
    return latest ?? _metricWithWeight(70);
  }
}

class _Profile extends Fake implements ProfileEntity {}

class _ProfileRepository extends Fake implements ProfileRepository {
  @override
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data) async =>
      _Profile();
}

class _Storage extends LocalStorage {
  _Storage(this.unitSystem);

  final UnitSystem unitSystem;

  @override
  ThemeMode getThemeModePreference() => ThemeMode.dark;
  @override
  Locale? getLocalePreference() => null;
  @override
  UnitSystem getUnitSystemPreference() => unitSystem;
  @override
  Map<String, dynamic>? getCachedMap(String key) => null;
}

Future<_Repository> _mount(
  WidgetTester tester, {
  required Locale locale,
  required UnitSystem unitSystem,
  BodyMetricEntity? latest,
  BodyMetricEntity? onDate,
}) async {
  // Tall enough to show the whole form without scrolling.
  tester.view.physicalSize = const Size(390, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await sl.reset();
  final storage = _Storage(unitSystem);
  final repository = _Repository(latest, onDate: onDate);
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerFactory<MetricsBloc>(
    () => MetricsBloc(
      saveMetricUseCase: SaveMetricUseCase(repository),
      metricsRepository: repository,
      updateProfileUseCase: UpdateProfileUseCase(_ProfileRepository()),
    ),
  );
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    BlocProvider<AppPreferencesCubit>(
      create: (_) => AppPreferencesCubit(storage),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(builder: (_) => const MetricsFormPage()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return repository;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(MetricsFormPage)));

Finder _stepper() => find.byKey(_stepperKey);

Future<void> _tapStep(WidgetTester tester, IconData icon) async {
  final button = find.descendant(of: _stepper(), matching: find.byIcon(icon));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

Future<void> _type(WidgetTester tester, String text) async {
  final numeral = find.descendant(
    of: _stepper(),
    matching: find.byKey(ExomNumeralStepper.valueKey),
  );
  await tester.ensureVisible(numeral);
  await tester.tap(numeral);
  await tester.pump();
  await tester.enterText(
    find.descendant(
      of: _stepper(),
      matching: find.byKey(ExomNumeralStepper.fieldKey),
    ),
    text,
  );
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

/// Starts typing and leaves [text] in the field, without submitting.
Future<void> _typeOpen(WidgetTester tester, String text) async {
  final numeral = find.descendant(
    of: _stepper(),
    matching: find.byKey(ExomNumeralStepper.valueKey),
  );
  await tester.ensureVisible(numeral);
  await tester.tap(numeral);
  await tester.pump();
  await tester.enterText(
    find.descendant(
      of: _stepper(),
      matching: find.byKey(ExomNumeralStepper.fieldKey),
    ),
    text,
  );
  await tester.pump();
}

/// Picks another day than today in the date picker (the form reloads the
/// metric of that date).
Future<void> _pickOtherDay(WidgetTester tester) async {
  final l10n = _l10n(tester);
  final dateField = find.text(l10n.todayLabel);
  await tester.ensureVisible(dateField);
  await tester.tap(dateField);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  final dialog = find.byType(DatePickerDialog);
  if (DateTime.now().day == 1) {
    final previous = MaterialLocalizations.of(
      tester.element(dialog),
    ).previousMonthTooltip;
    await tester.tap(find.byTooltip(previous));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.tap(find.descendant(of: dialog, matching: find.text('1')).first);
  await tester.pump();
  final ok = MaterialLocalizations.of(tester.element(dialog)).okButtonLabel;
  await tester.tap(find.descendant(of: dialog, matching: find.text(ok)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

ExomStepper<double> _rawStepper(WidgetTester tester) =>
    tester.widget<ExomStepper<double>>(
      find.descendant(
        of: _stepper(),
        matching: find.byType(ExomStepper<double>),
      ),
    );

/// [text] in the snackbar (the inline error under the stepper has the same
/// text since the PARADA).
Finder _snackbarText(String text) =>
    find.descendant(of: find.byType(SnackBar), matching: find.text(text));

Future<void> _save(WidgetTester tester) async {
  final wanted = _l10n(tester).saveMetricsButton.toLowerCase();
  await tester.tap(
    find.byWidgetPredicate(
      (widget) => widget is Text && widget.data?.toLowerCase() == wanted,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// L6-UX4: the save needs a change. A «9 h» chip is one that does not touch
/// the weight, so the weight sent is the loaded one.
Future<void> _changeSleep(WidgetTester tester) async {
  final chip = find.widgetWithText(ActionChip, '9 h');
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pump();
}

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<ExomPrimaryButton>(find.byType(ExomPrimaryButton)).onPressed !=
    null;

void main() {
  tearDown(sl.reset);

  for (final locale in const [Locale('es'), Locale('en')]) {
    for (final unit in UnitSystem.values) {
      final imperial = unit == UnitSystem.imperial;
      final tag = '${locale.languageCode} ${unit.name}';
      // The decimal separator of the locale, for typed values.
      String typed(String value) =>
          locale.languageCode == 'es' ? value.replaceAll('.', ',') : value;

      group('D14-4 weight stepper ($tag)', () {
        testWidgets('replaces the slider and the manual switch, with the '
            'range and step of today in the display unit', (tester) async {
          await _mount(
            tester,
            locale: locale,
            unitSystem: unit,
            latest: _metricWithWeight(68.4),
          );
          expect(find.byType(Slider), findsNothing);
          expect(find.byType(Switch), findsNothing);
          final stepper = tester.widget<ExomNumeralStepper>(_stepper());
          expect(stepper.min, UnitConverters.weightToDisplay(40, unit));
          expect(stepper.max, UnitConverters.weightToDisplay(160, unit));
          expect(stepper.step, UnitConverters.weightToDisplay(0.5, unit));
          expect(stepper.unit, imperial ? 'lb' : 'kg');
          expect(stepper.acceptsTypedOutOfRange, isTrue);
          expect(stepper.value, UnitConverters.weightToDisplay(68.4, unit));
        });

        testWidgets('untouched, the save is disabled and sends nothing', (
          tester,
        ) async {
          final repository = await _mount(
            tester,
            locale: locale,
            unitSystem: unit,
            latest: _metricWithWeight(68.4),
          );
          expect(_saveEnabled(tester), isFalse);
          await _save(tester);
          expect(repository.saved, isEmpty);
        });

        testWidgets('+ sends 0.5 kg more, in kilograms', (tester) async {
          final repository = await _mount(
            tester,
            locale: locale,
            unitSystem: unit,
            latest: _metricWithWeight(70),
          );
          await _tapStep(tester, ExomIcons.add);
          await _save(tester);
          expect(repository.saved.single['weight_kg'], 70.5);
        });

        testWidgets('− stops at the minimum of 40 kg', (tester) async {
          final repository = await _mount(
            tester,
            locale: locale,
            unitSystem: unit,
            latest: _metricWithWeight(40.5),
          );
          await _tapStep(tester, ExomIcons.remove);
          await _tapStep(tester, ExomIcons.remove);
          await _save(tester);
          expect(repository.saved.single['weight_kg'], 40.0);
        });

        testWidgets('+ stops at the maximum of 160 kg', (tester) async {
          final repository = await _mount(
            tester,
            locale: locale,
            unitSystem: unit,
            latest: _metricWithWeight(159.5),
          );
          await _tapStep(tester, ExomIcons.add);
          await _tapStep(tester, ExomIcons.add);
          await _save(tester);
          expect(repository.saved.single['weight_kg'], 160.0);
        });

        for (final value in const ['72.5', '200', '20']) {
          testWidgets('typed "${typed(value)}" is sent as the manual mode '
              'did (no range cap, user unit)', (tester) async {
            final repository = await _mount(
              tester,
              locale: locale,
              unitSystem: unit,
              latest: _metricWithWeight(68.4),
            );
            await _type(tester, typed(value));
            await _save(tester);
            expect(
              repository.saved.single['weight_kg'],
              UnitConverters.weightFromDisplay(double.parse(value), unit),
            );
          });
        }

        testWidgets('typed in the other separator is accepted too', (
          tester,
        ) async {
          final repository = await _mount(
            tester,
            locale: locale,
            unitSystem: unit,
            latest: _metricWithWeight(68.4),
          );
          await _type(tester, locale.languageCode == 'es' ? '72.5' : '72,5');
          await _save(tester);
          expect(
            repository.saved.single['weight_kg'],
            UnitConverters.weightFromDisplay(72.5, unit),
          );
        });

        testWidgets('typed empty blocks the save with validWeightRequired', (
          tester,
        ) async {
          final repository = await _mount(
            tester,
            locale: locale,
            unitSystem: unit,
            latest: _metricWithWeight(68.4),
          );
          await _type(tester, '');
          await _save(tester);
          expect(repository.saved, isEmpty);
          expect(
            _snackbarText(_l10n(tester).validWeightRequired),
            findsOneWidget,
          );
        });

        testWidgets('a step after a typed value moves 0.5 kg from it', (
          tester,
        ) async {
          final repository = await _mount(
            tester,
            locale: locale,
            unitSystem: unit,
            latest: _metricWithWeight(68.4),
          );
          await _type(tester, typed('100'));
          await _tapStep(tester, ExomIcons.remove);
          await _save(tester);
          expect(
            repository.saved.single['weight_kg'],
            closeTo(UnitConverters.weightFromDisplay(100, unit) - 0.5, 1e-9),
          );
        });

        // Behaviour change against the base 8ea32f2: its manual field parsed
        // the text with `_parseDouble`, which took a sign, so "-5" was sent
        // as -5 kg. The stepper does not take a sign.
        for (final value in const ['-5', '+5']) {
          testWidgets('typed "$value" is not taken as a signed weight', (
            tester,
          ) async {
            final repository = await _mount(
              tester,
              locale: locale,
              unitSystem: unit,
              latest: _metricWithWeight(68.4),
            );
            await _type(tester, value);
            await _save(tester);
            expect(repository.saved, isEmpty);
            expect(
              _snackbarText(_l10n(tester).validWeightRequired),
              findsOneWidget,
            );
          });
        }

        // A loaded weight outside the ± range of 40–160 kg (no clamp on load).
        for (final (loadedKg, limitKg) in const [
          (30.0, 40.0),
          (170.0, 160.0),
        ]) {
          final below = loadedKg < limitKg;
          testWidgets('a loaded ${loadedKg.round()} kg is shown and, '
              'untouched, sent as is with another change', (tester) async {
            final repository = await _mount(
              tester,
              locale: locale,
              unitSystem: unit,
              latest: _metricWithWeight(loadedKg),
            );
            expect(
              tester.widget<ExomNumeralStepper>(_stepper()).value,
              UnitConverters.weightToDisplay(loadedKg, unit),
            );
            await _changeSleep(tester);
            await _save(tester);
            expect(repository.saved.single['weight_kg'], loadedKg);
          });

          testWidgets('from a loaded ${loadedKg.round()} kg the button away '
              'from the range is disabled and the first step jumps to '
              '${limitKg.round()} kg', (tester) async {
            final repository = await _mount(
              tester,
              locale: locale,
              unitSystem: unit,
              latest: _metricWithWeight(loadedKg),
            );
            final raw = _rawStepper(tester);
            expect(below ? raw.onDecrement : raw.onIncrement, isNull);
            await _tapStep(tester, below ? ExomIcons.add : ExomIcons.remove);
            expect(
              tester.widget<ExomNumeralStepper>(_stepper()).value,
              UnitConverters.weightToDisplay(limitKg, unit),
            );
            await _save(tester);
            expect(repository.saved.single['weight_kg'], limitKg);
          });
        }

        testWidgets('invalid typed text, then another date with a metric: the '
            'field shows the loaded weight and the save sends it', (
          tester,
        ) async {
          final repository = await _mount(
            tester,
            locale: locale,
            unitSystem: unit,
            latest: _metricWithWeight(68.4),
            onDate: _metricWithWeight(81),
          );
          await _typeOpen(tester, '');
          await _pickOtherDay(tester);
          expect(
            find.descendant(
              of: _stepper(),
              matching: find.byKey(ExomNumeralStepper.fieldKey),
            ),
            findsNothing,
          );
          expect(
            tester.widget<ExomNumeralStepper>(_stepper()).value,
            UnitConverters.weightToDisplay(81, unit),
          );
          await _changeSleep(tester);
          await _save(tester);
          expect(repository.saved.single['weight_kg'], 81.0);
        });
      });
    }
  }

  testWidgets('a day without a weight keeps the touched rule: untouched sends '
      'no weight', (tester) async {
    final repository = await _mount(
      tester,
      locale: const Locale('es'),
      unitSystem: UnitSystem.metric,
    );
    expect(_stepper(), findsOneWidget);
    await _changeSleep(tester);
    await _save(tester);
    expect(repository.saved.single.containsKey('weight_kg'), isFalse);
  });

  // PARADA 2026-11-25 (owner-approved changes), in es and en.
  for (final locale in const [Locale('es'), Locale('en')]) {
    final es = locale.languageCode == 'es';
    final hint = es
        ? 'Toca la cifra para escribirla.'
        : 'Tap the number to type it.';
    final weightError = es
        ? 'Introduce un peso válido antes de guardar.'
        : 'Enter a valid weight before saving.';

    group('PARADA (${locale.languageCode})', () {
      testWidgets('1: a muted hint under the weight stepper, in the same '
          'style as the other helps and in the semantics', (tester) async {
        final semantics = tester.ensureSemantics();
        await _mount(
          tester,
          locale: locale,
          unitSystem: UnitSystem.metric,
          latest: _metricWithWeight(68.4),
        );
        final hintFinder = find.text(hint);
        expect(hintFinder, findsOneWidget);
        final note = find.text(_l10n(tester).weightUpdateNote);
        expect(
          tester.widget<Text>(hintFinder).style,
          tester.widget<Text>(note).style,
        );
        // Below the stepper and above the note.
        final stepperBottom = tester.getBottomLeft(_stepper()).dy;
        expect(
          tester.getTopLeft(hintFinder).dy,
          greaterThanOrEqualTo(stepperBottom),
        );
        expect(
          tester.getTopLeft(hintFinder).dy,
          lessThan(tester.getTopLeft(note).dy),
        );
        final label = tester.getSemantics(hintFinder).label;
        // Read once, by the hint's own node, not repeated by the stepper's.
        expect(label, contains(hint));
        expect(tester.getSemantics(_stepper()).label, isNot(contains(hint)));
        expect(RegExp(RegExp.escape(hint)).allMatches(label), hasLength(1));
        semantics.dispose();
      });

      testWidgets('2: no sleep emoji; the 6-9 h chips stay with their value', (
        tester,
      ) async {
        final repository = await _mount(
          tester,
          locale: locale,
          unitSystem: UnitSystem.metric,
          latest: _metricWithWeight(68.4),
        );
        for (final emoji in const ['😴', '😕', '😊', '😪']) {
          expect(find.textContaining(emoji), findsNothing);
        }
        for (final hours in const [6, 7, 8, 9]) {
          expect(find.widgetWithText(ActionChip, '$hours h'), findsOneWidget);
        }
        final chip = find.widgetWithText(ActionChip, '9 h');
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pump();
        await _save(tester);
        expect(repository.saved.single['sleep_hours'], 9.0);
      });

      for (final value in const ['-5', '', 'abc']) {
        testWidgets('3: Enter with "$value" shows the error inline and stays '
            'editing, without pressing Save', (tester) async {
          final repository = await _mount(
            tester,
            locale: locale,
            unitSystem: UnitSystem.metric,
            latest: _metricWithWeight(68.4),
          );
          expect(find.text(weightError), findsNothing);
          await _type(tester, value);
          expect(find.text(weightError), findsOneWidget);
          expect(find.byType(SnackBar), findsNothing);
          expect(
            find.descendant(
              of: _stepper(),
              matching: find.byKey(ExomNumeralStepper.fieldKey),
            ),
            findsOneWidget,
          );
          // The error clears as soon as the text is valid again.
          await tester.enterText(
            find.descendant(
              of: _stepper(),
              matching: find.byKey(ExomNumeralStepper.fieldKey),
            ),
            es ? '72,5' : '72.5',
          );
          await tester.pump();
          expect(find.text(weightError), findsNothing);
          await _save(tester);
          expect(repository.saved.single['weight_kg'], 72.5);
        });
      }

      testWidgets('3: Enter with a valid value leaves editing, no error', (
        tester,
      ) async {
        await _mount(
          tester,
          locale: locale,
          unitSystem: UnitSystem.metric,
          latest: _metricWithWeight(68.4),
        );
        await _type(tester, es ? '72,5' : '72.5');
        expect(find.text(weightError), findsNothing);
        expect(
          find.descendant(
            of: _stepper(),
            matching: find.byKey(ExomNumeralStepper.fieldKey),
          ),
          findsNothing,
        );
      });
    });
  }
}
