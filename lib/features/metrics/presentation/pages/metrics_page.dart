import 'dart:math' as math;

import 'package:exom_app/core/formatters/input_example.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/formatters/unit_converters.dart';
import 'package:exom_app/core/formatters/unit_formatters.dart';
import 'package:exom_app/core/formatters/weight_input.dart'
    show decimalSeparatorFor, formatDisplayDecimal, roundToHundredths;
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/models/body_zone.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_numeral_stepper.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_segmented_control.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/core/widgets/exom_app_bar.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/utils/seen_muscle_mass_estimator.dart';
import 'package:exom_app/features/metrics/presentation/bloc/metrics_bloc.dart';
import 'package:exom_app/features/home/presentation/widgets/home_headline.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_anatomy_selector.dart';

/// Day form of Métricas (record date, height, weight, muscle mass, sleep and
/// measures). Opened from «Añadir medida» in the «Progreso» view; a
/// successful save pops it.
class MetricsFormPage extends StatelessWidget {
  const MetricsFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MetricsBloc>(),
      child: const _MetricsView(),
    );
  }
}

class _MetricsView extends StatefulWidget {
  const _MetricsView();

  @override
  State<_MetricsView> createState() => _MetricsViewState();
}

class _MetricsViewState extends State<_MetricsView> {
  static final Uri _seenSourceUri = Uri.parse(
    'https://www.seen.es/calculadoras/calculadora-masa-muscular-esqueletica',
  );

  /// Weight of the form in kilograms (D14-4: the stepper replaces the slider
  /// and the manual switch). Only sent when [_weightTouched].
  double _weightKg = 75.0;

  /// Whether the typed weight does not parse (empty or not a number): the
  /// save is blocked with `validWeightRequired`, as the manual mode did.
  bool _weightInputInvalid = false;

  /// Whether the invalid typed weight shows its error inline: set when the
  /// keyboard action is pressed on invalid text, cleared by a valid value or
  /// a reload.
  bool _weightErrorShown = false;

  /// Range and step of the ± of the weight, in kilograms (the old slider:
  /// 40–160 kg, 240 divisions). In imperial they are shown in pounds and the
  /// step stays 0.5 kg (contract, table «Rangos de los steppers»).
  static const double _weightMinKg = 40.0;
  static const double _weightMaxKg = 160.0;
  static const double _weightStepKg = 0.5;

  final _sleepController = TextEditingController();
  final _heightController = TextEditingController();
  final _muscleMassController = TextEditingController();
  DateTime _selectedMetricDate = DateUtils.dateOnly(DateTime.now());
  bool _heightTouched = false;
  bool _weightTouched = false;

  /// Bumped whenever the form is filled from a load, so the weight stepper
  /// is rebuilt and leaves any typing: the field then shows exactly the
  /// weight that would be sent, as the old manual field did when its
  /// controller was refilled.
  int _weightFieldGeneration = 0;
  bool _muscleMassTouched = false;
  bool _sleepTouched = false;
  final Set<String> _touchedMeasures = <String>{};

  bool _bodyMapMode = false;
  BodyZone? _selectedMeasure;

  /// Zones of section 06 in the order of the sketch (L6-D2): Cuello, Hombros,
  /// Pecho, Cintura, Caderas, Brazo, Antebrazo, Muslo, Gemelo.
  static const _measureZones = <_MeasureZoneConfig>[
    _MeasureZoneConfig.single(zone: BodyZone.neck, fieldKey: 'neck_cm'),
    _MeasureZoneConfig.single(
      zone: BodyZone.shoulders,
      fieldKey: 'shoulders_cm',
    ),
    _MeasureZoneConfig.single(zone: BodyZone.chest, fieldKey: 'chest_cm'),
    _MeasureZoneConfig.single(zone: BodyZone.waist, fieldKey: 'waist_cm'),
    _MeasureZoneConfig.single(zone: BodyZone.hips, fieldKey: 'hips_cm'),
    _MeasureZoneConfig.bilateral(
      zone: BodyZone.upperArm,
      leftFieldKey: 'arm_left_cm',
      rightFieldKey: 'arm_right_cm',
    ),
    _MeasureZoneConfig.bilateral(
      zone: BodyZone.forearm,
      leftFieldKey: 'forearm_left_cm',
      rightFieldKey: 'forearm_right_cm',
    ),
    _MeasureZoneConfig.bilateral(
      zone: BodyZone.thigh,
      leftFieldKey: 'thigh_left_cm',
      rightFieldKey: 'thigh_right_cm',
    ),
    _MeasureZoneConfig.bilateral(
      zone: BodyZone.calf,
      leftFieldKey: 'calf_left_cm',
      rightFieldKey: 'calf_right_cm',
    ),
  ];

  late final Map<String, TextEditingController> _measureControllers = {
    for (final zone in _measureZones)
      for (final fieldKey in zone.fieldKeys) fieldKey: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadLatestMetric();
      }
    });
  }

  bool _fallbackPopulated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs the locale (inherited), so it cannot run in initState.
    if (!_fallbackPopulated) {
      _fallbackPopulated = true;
      _populateFallbackValuesFromCachedProfile();
    }
  }

  @override
  void dispose() {
    _sleepController.dispose();
    _heightController.dispose();
    _muscleMassController.dispose();
    for (final c in _measureControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _localizedZoneLabel(BuildContext context, BodyZone zone) {
    return zone.label(AppLocalizations.of(context));
  }

  _MeasureZoneConfig _measureZone(BodyZone zone) {
    return _measureZones.firstWhere((config) => config.zone == zone);
  }

  BodyZone _zoneForFieldKey(String fieldKey) {
    return _measureZones
        .firstWhere((config) => config.fieldKeys.contains(fieldKey))
        .zone;
  }

  TextEditingController _controllerForField(String fieldKey) {
    return _measureControllers[fieldKey]!;
  }

  void _markMeasureTouched(String fieldKey) {
    _touchedMeasures.add(fieldKey);
  }

  String _preferredSeenCalfText() {
    final leftText = _controllerForField('calf_left_cm').text.trim();
    final rightText = _controllerForField('calf_right_cm').text.trim();
    final leftValue = _parseDouble(leftText);
    final rightValue = _parseDouble(rightText);

    if (leftValue == null) {
      return rightText;
    }
    if (rightValue == null) {
      return leftText;
    }
    return leftValue >= rightValue ? leftText : rightText;
  }

  String _heightHint(AppLocalizations l10n, UnitSystem unitSystem) {
    final imperial = unitSystem == UnitSystem.imperial;
    return localizedInputExample(
      l10n,
      imperial ? 70.9 : 180,
      decimals: imperial ? 1 : 0,
    );
  }

  String _apiDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  String _selectedDateLabel(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    if (_selectedMetricDate == today) {
      return AppLocalizations.of(context).todayLabel;
    }
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return isEn
        ? DateFormat('MMMM d', 'en').format(_selectedMetricDate)
        : DateFormat("d 'de' MMMM", 'es').format(_selectedMetricDate);
  }

  Future<void> _pickMetricDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMetricDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: Localizations.localeOf(context),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedMetricDate = DateUtils.dateOnly(picked);
      _selectedMeasure = null;
    });
    _loadMetricForSelectedDate();
  }

  void _loadMetricForSelectedDate() {
    context.read<MetricsBloc>().add(
      MetricsLoadRequested(date: _apiDate(_selectedMetricDate)),
    );
  }

  void _loadLatestMetric() {
    context.read<MetricsBloc>().add(const MetricsLoadRequested());
  }

  void _setSleepValue(double value) {
    setState(() {
      _sleepController.text = _fieldNumber(value.toStringAsFixed(1));
      _sleepTouched = true;
    });
  }

  /// A value from the weight stepper, in the display unit. A ± in imperial
  /// arrives in pounds; it is taken as the 0.5 kg step itself so the sent
  /// kilograms do not carry the pound round trip (the old slider sent exact
  /// multiples of its step). Anything else was typed and is converted as the
  /// manual mode did.
  void _onWeightChanged(double display, UnitSystem unitSystem) {
    final kg =
        _steppedWeightKg(display, unitSystem) ??
        UnitConverters.weightFromDisplay(display, unitSystem);
    setState(() {
      _weightKg = kg;
      _weightTouched = true;
      _weightInputInvalid = false;
      _weightErrorShown = false;
    });
  }

  /// The kilograms of a ± from the current weight when [display] is that
  /// step shown in pounds; null otherwise (metric needs no conversion). The
  /// stepper rounds its stepped value to 1e-6, so a typed value only matches
  /// with six exact decimals, and then differs from it by less than 1e-6 kg.
  double? _steppedWeightKg(double display, UnitSystem unitSystem) {
    if (unitSystem != UnitSystem.imperial) return null;
    for (final direction in const [-1, 1]) {
      final kg = (_weightKg + direction * _weightStepKg)
          .clamp(_weightMinKg, _weightMaxKg)
          .toDouble();
      if ((UnitConverters.weightToDisplay(kg, unitSystem) - display).abs() <
          1e-6) {
        return kg;
      }
    }
    return null;
  }

  void _onWeightInvalidInput(String _) {
    setState(() {
      _weightTouched = true;
      _weightInputInvalid = true;
    });
  }

  void _onWeightSubmittedInvalid(String _) {
    setState(() {
      _weightTouched = true;
      _weightInputInvalid = true;
      _weightErrorShown = true;
    });
  }

  double? _cachedProfileNumber(String key) {
    final rawValue = _getCachedProfile()?[key];
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    return double.tryParse(rawValue?.toString() ?? '');
  }

  void _populateFallbackValuesFromCachedProfile() {
    final unitSystem = context.read<AppPreferencesCubit>().state.unitSystem;
    final heightCm = _cachedProfileNumber('height');
    final weightKg = _cachedProfileNumber('current_weight');

    if (heightCm != null && _heightController.text.isEmpty) {
      _heightController.text = _lengthField(heightCm, unitSystem);
    }

    if (weightKg != null && !_weightTouched) {
      _weightKg = weightKg;
    }
  }

  void _populateEmptyMetricState() {
    final unitSystem = context.read<AppPreferencesCubit>().state.unitSystem;
    final profileHeightCm = _cachedProfileNumber('height');
    final profileWeightKg = _cachedProfileNumber('current_weight');

    setState(() {
      _weightKg = profileWeightKg ?? 75.0;
      _weightInputInvalid = false;
      _weightErrorShown = false;
      _weightFieldGeneration++;
      _heightTouched = false;
      _weightTouched = false;
      _muscleMassTouched = false;
      _sleepTouched = false;
      _touchedMeasures.clear();
    });
    _heightController.text = profileHeightCm != null
        ? _lengthField(profileHeightCm, unitSystem)
        : '';
    _muscleMassController.clear();
    _sleepController.clear();
    for (final controller in _measureControllers.values) {
      controller.clear();
    }
  }

  /// Plates of the C5b figure that stand for each measure (L6-D2 mapping of
  /// the sketch «L6 · 06 Medidas corporales»). Every other plate is muted and
  /// inert in the body view.
  static const _measurePlates = <BodyZone, List<String>>{
    BodyZone.neck: ['neck_front'],
    BodyZone.shoulders: [
      'shoulder_left_front',
      'shoulder_right_front',
      'shoulder_left_back',
      'shoulder_right_back',
    ],
    BodyZone.chest: ['chest_left', 'chest_right'],
    BodyZone.waist: ['abdomen'],
    BodyZone.hips: ['hip_flexors', 'glutes_left', 'glutes_right'],
    BodyZone.upperArm: [
      'biceps_left',
      'biceps_right',
      'triceps_left',
      'triceps_right',
    ],
    BodyZone.forearm: [
      'forearm_left_front',
      'forearm_right_front',
      'forearm_left_back',
      'forearm_right_back',
    ],
    BodyZone.thigh: [
      'quadriceps_left',
      'quadriceps_right',
      'hamstrings_left',
      'hamstrings_right',
    ],
    BodyZone.calf: ['shin_left', 'shin_right', 'calves_left', 'calves_right'],
  };

  /// Starting value of the stepper of a side without data, in centimetres:
  /// an adult reference so ± starts near a plausible figure. It is never
  /// sent unless the client changes it.
  static const _measureSeedCm = <BodyZone, double>{
    BodyZone.neck: 38,
    BodyZone.shoulders: 110,
    BodyZone.chest: 95,
    BodyZone.waist: 80,
    BodyZone.hips: 95,
    BodyZone.upperArm: 30,
    BodyZone.forearm: 26,
    BodyZone.thigh: 55,
    BodyZone.calf: 37,
  };

  /// Range and step of the measure steppers, in the display unit. A typed
  /// value is taken as the old fields took it (any number).
  static const double _measureStep = 0.5;
  static const double _measureMaxCm = 300;

  BodyZone? _zoneForPlate(String plateId) {
    for (final MapEntry(key: zone, value: plates) in _measurePlates.entries) {
      if (plates.contains(plateId)) return zone;
    }
    return null;
  }

  /// Draft value of [fieldKey] in the display unit; null when empty.
  double? _draftValue(String fieldKey) =>
      _parseDouble(_controllerForField(fieldKey).text);

  bool _zoneHasDraft(BodyZone zone) =>
      _measureZone(zone).fieldKeys.any((key) => _draftValue(key) != null);

  bool _zoneEdited(BodyZone zone) =>
      _measureZone(zone).fieldKeys.any(_touchedMeasures.contains);

  String _decimalSeparator() =>
      decimalSeparatorFor(Localizations.localeOf(context).languageCode);

  /// A measure as shown: at least one decimal, at most two, with the locale
  /// separator («38,0», «33,25»).
  String _measureNumber(double value) {
    final separator = _decimalSeparator();
    final text = formatDisplayDecimal(value, decimalSeparator: separator);
    return text.contains(separator) ? text : '$text${separator}0';
  }

  /// A value from the sheet as draft text: the exact number with the locale
  /// separator, parsed back by [_parseDouble] as the old fields were.
  String _draftText(double value) =>
      value.toString().replaceFirst('.', _decimalSeparator());

  /// Value spans of a zone: «38,0 cm», «I 33,5 · D 34,0 cm», «I 55,0 · D —»
  /// or «Sin dato». No-break spaces keep «I 33,5» and «D 34,0 cm» whole, so a
  /// narrow line can only break after the middle dot. [values] holds one
  /// value (single zone) or the left and right ones, in the display unit.
  List<InlineSpan> _measureSpans(
    AppLocalizations l10n,
    List<double?> values,
    String unit,
    TextStyle muted,
  ) {
    const nbsp = ' ';
    if (values.every((value) => value == null)) {
      return [TextSpan(text: l10n.optionalRatingNoData, style: muted)];
    }
    if (values.length == 1) {
      return [TextSpan(text: '${_measureNumber(values.single!)}$nbsp$unit')];
    }
    InlineSpan side(String initial, double? value, {required bool last}) =>
        value == null
        ? TextSpan(
            children: [
              TextSpan(text: '$initial$nbsp'),
              TextSpan(text: '—', style: muted),
            ],
          )
        : TextSpan(
            text:
                '$initial$nbsp${_measureNumber(value)}'
                '${last ? '$nbsp$unit' : ''}',
          );
    return [
      side(l10n.metricsMeasureLeftInitial, values.first, last: false),
      const TextSpan(text: '$nbsp· '),
      side(l10n.metricsMeasureRightInitial, values.last, last: true),
    ];
  }

  /// Spoken value of a zone: «Izquierda 33,5 cm, Derecha —».
  String _measureSpoken(
    AppLocalizations l10n,
    List<double?> values,
    String unit,
  ) {
    if (values.every((value) => value == null)) {
      return l10n.optionalRatingNoData;
    }
    String one(double? value) =>
        value == null ? '—' : '${_measureNumber(value)} $unit';
    if (values.length == 1) return one(values.single);
    return '${l10n.leftSideLabel} ${one(values.first)}, '
        '${l10n.rightSideLabel} ${one(values.last)}';
  }

  /// Stored values of [metric] by field key, in centimetres.
  static Map<String, double?> _storedMeasures(BodyMetricEntity? metric) => {
    'neck_cm': metric?.neckCm,
    'shoulders_cm': metric?.shouldersCm,
    'chest_cm': metric?.chestCm,
    'arm_left_cm': metric?.armLeftCm,
    'arm_right_cm': metric?.armRightCm,
    'forearm_left_cm': metric?.forearmLeftCm,
    'forearm_right_cm': metric?.forearmRightCm,
    'waist_cm': metric?.waistCm,
    'hips_cm': metric?.hipsCm,
    'thigh_left_cm': metric?.thighLeftCm,
    'thigh_right_cm': metric?.thighRightCm,
    'calf_left_cm': metric?.calfLeftCm,
    'calf_right_cm': metric?.calfRightCm,
  };

  /// «Última: I 33,0 · D 33,5 cm · 19 nov»: the stored values of the loaded
  /// record and its date; null when the zone has none stored.
  String? _lastMeasureLine(
    AppLocalizations l10n,
    BodyZone zone,
    UnitSystem unitSystem,
  ) {
    final metric = _currentMetricSnapshot();
    if (metric == null) return null;
    final stored = _storedMeasures(metric);
    final values = [
      for (final key in _measureZone(zone).fieldKeys)
        stored[key] == null
            ? null
            : UnitConverters.lengthToDisplay(stored[key]!, unitSystem),
    ];
    if (values.every((value) => value == null)) return null;
    final text = TextSpan(
      children: _measureSpans(
        l10n,
        values,
        lengthUnitSymbol(unitSystem),
        const TextStyle(),
      ),
    ).toPlainText();
    final languageCode = Localizations.localeOf(context).languageCode;
    final date = languageCode == 'en'
        ? DateFormat('MMM d', 'en').format(metric.date)
        : DateFormat('d MMM', 'es').format(metric.date);
    return l10n.metricsMeasureLast(text, date);
  }

  void _onPlateSelected(String plateId) {
    final zone = _zoneForPlate(plateId);
    if (zone == null) return;
    _openMeasureSheet(zone);
  }

  /// Opens the sheet of [zone] (from its row or its plates). «Hecho» writes
  /// the sides the client changed into the draft and marks them touched;
  /// dismissing the sheet changes nothing. The page save stays the only
  /// write.
  Future<void> _openMeasureSheet(BodyZone zone) async {
    final l10n = AppLocalizations.of(context);
    final unitSystem = context.read<AppPreferencesCubit>().state.unitSystem;
    final config = _measureZone(zone);
    final unit = lengthUnitSymbol(unitSystem);
    final drafts = [for (final key in config.fieldKeys) _draftValue(key)];
    final seedCm = _measureSeedCm[zone]!;
    final seed =
        drafts.whereType<double>().firstOrNull ??
        (UnitConverters.lengthToDisplay(seedCm, unitSystem) / _measureStep)
                .round() *
            _measureStep;
    final stepText = '${_measureNumberPlain(_measureStep)} $unit';
    final label = _localizedZoneLabel(context, zone);
    setState(() => _selectedMeasure = zone);

    final result = await showExomSheet<Map<String, double>>(
      context: context,
      builder: (_) => _MeasureSheet(
        kicker: l10n.metricsMeasureSheetKicker,
        title: label,
        lastLine: _lastMeasureLine(l10n, zone, unitSystem),
        sides: [
          for (var i = 0; i < config.fieldKeys.length; i++)
            _MeasureSide(
              fieldKey: config.fieldKeys[i],
              label: !config.isBilateral
                  ? null
                  : i == 0
                  ? l10n.leftSideLabel
                  : l10n.rightSideLabel,
              initial: drafts[i] ?? seed,
              // A side without a value shows «—» until the client changes
              // it. Its ± starts from the other side when that one has a
              // value (owner decision) and from the zone seed otherwise.
              empty: drafts[i] == null,
            ),
        ],
        zoneLabel: label,
        unit: unit,
        step: _measureStep,
        max: UnitConverters.lengthToDisplay(_measureMaxCm, unitSystem),
        hint: l10n.setSheetWeightHint(stepText),
        decrementLabel: l10n.metricsWeightDecrease(stepText),
        incrementLabel: l10n.metricsWeightIncrease(stepText),
        doneLabel: l10n.metricsMeasureDone,
        noDataLabel: l10n.optionalRatingNoData,
        reviewMessage: l10n.measurementReviewTemplate(label.toLowerCase()),
      ),
    );
    if (!mounted || result == null || result.isEmpty) return;
    setState(() {
      for (final MapEntry(key: fieldKey, value: value) in result.entries) {
        _controllerForField(fieldKey).text = _draftText(value);
        _markMeasureTouched(fieldKey);
      }
    });
  }

  /// The step as text («0,5»).
  String _measureNumberPlain(double value) =>
      formatDisplayDecimal(value, decimalSeparator: _decimalSeparator());

  Widget _buildMeasureList(AppLocalizations l10n, UnitSystem unitSystem) {
    final palette = context.exomPalette;
    final unit = lengthUnitSymbol(unitSystem);
    final muted = TextStyle(color: palette.textSecondary);
    return ExomFlatRowGroup(
      children: [
        for (final config in _measureZones)
          _MeasureRow(
            key: Key('metrics-measure-row-${config.zone.name}'),
            zone: config.zone,
            label: _localizedZoneLabel(context, config.zone),
            valueSpans: _measureSpans(
              l10n,
              [for (final key in config.fieldKeys) _draftValue(key)],
              unit,
              muted,
            ),
            spokenValue: _measureSpoken(l10n, [
              for (final key in config.fieldKeys) _draftValue(key),
            ], unit),
            edited: _zoneEdited(config.zone),
            editedLabel: l10n.metricsMeasureEdited,
            onTap: () => _openMeasureSheet(config.zone),
          ),
      ],
    );
  }

  /// Spoken label of a plate: «Pecho, 96,5 cm» for a single zone; a plate of
  /// a pair names its side and reads that side only («Brazo, lado izquierdo,
  /// 33,0 cm», «Muslo, lado derecho, —»). Plate ids carry the anatomical side
  /// (`biceps_left`), the same one as the field keys (`arm_left_cm`).
  String _plateLabel(AppLocalizations l10n, String plateId, String unit) {
    final zone = _zoneForPlate(plateId)!;
    final config = _measureZone(zone);
    final name = _localizedZoneLabel(context, zone);
    if (!config.isBilateral) {
      final values = [for (final key in config.fieldKeys) _draftValue(key)];
      return '$name, ${_measureSpoken(l10n, values, unit)}';
    }
    final left = plateId.contains('_left');
    final value = _draftValue(config.fieldKeys[left ? 0 : 1]);
    final side = left
        ? l10n.metricsMeasureZoneLeft(name)
        : l10n.metricsMeasureZoneRight(name);
    return '$side, ${value == null ? '—' : '${_measureNumber(value)} $unit'}';
  }

  /// Height of the C5b selector in the body view: the 48 dp view toggle, its
  /// 12 dp gap and a 450 dp figure, as in the sketch.
  static const double _bodySelectorHeight = 510;

  Widget _buildMeasureBody(AppLocalizations l10n, UnitSystem unitSystem) {
    final palette = context.exomPalette;
    final unit = lengthUnitSymbol(unitSystem);
    final selected = _selectedMeasure;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExomSpacing.xl,
        ExomSpacing.lg,
        ExomSpacing.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RecapAnatomySelector(
            height: _bodySelectorHeight,
            selectedZoneIds: selected == null
                ? const <String>{}
                : _measurePlates[selected]!.toSet(),
            onZoneSelected: _onPlateSelected,
            zoneMarks: {
              for (final MapEntry(key: zone, value: plates)
                  in _measurePlates.entries)
                for (final plate in plates)
                  plate: _zoneHasDraft(zone)
                      ? RecapZoneMark.withData
                      : RecapZoneMark.withoutData,
            },
            zoneLabelOf: (plateId) => _plateLabel(l10n, plateId, unit),
          ),
          const SizedBox(height: ExomSpacing.lg),
          Text(
            l10n.metricsMeasureTapZone,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  BodyMetricEntity? _currentMetricSnapshot() {
    final state = context.read<MetricsBloc>().state;
    if (state is MetricsLoaded) {
      return state.current;
    }
    return null;
  }

  void _save() {
    final unitSystem = context.read<AppPreferencesCubit>().state.unitSystem;
    final currentMetric = _currentMetricSnapshot();
    final currentWeightKg = currentMetric?.weightKg;
    final currentSleepHours = currentMetric?.sleepHours;
    final currentMuscleMassKg = currentMetric?.muscleMassKg;
    final profileWeightKg = _cachedProfileNumber('current_weight');
    final data = <String, dynamic>{};
    final profileData = <String, dynamic>{};

    data['date'] = _apiDate(_selectedMetricDate);

    double? nextHeightCm = currentMetric?.heightCm;
    if (_heightTouched) {
      final rawHeight = _parseDouble(_heightController.text);
      if (rawHeight == null) {
        _showValidationMessage(
          AppLocalizations.of(context).validHeightRequired,
        );
        return;
      }

      nextHeightCm = UnitConverters.lengthFromDisplay(rawHeight, unitSystem);
    }
    if (nextHeightCm != null) {
      data['height_cm'] = nextHeightCm;
      profileData['height'] = nextHeightCm;
    }

    if (_weightTouched) {
      if (_weightInputInvalid) {
        _showValidationMessage(
          AppLocalizations.of(context).validWeightRequired,
        );
        return;
      }
      data['weight_kg'] = _weightKg;
    } else if (currentWeightKg != null) {
      data['weight_kg'] = currentWeightKg;
    } else if (currentMetric == null && profileWeightKg != null) {
      data['weight_kg'] = profileWeightKg;
    }

    if (_sleepTouched) {
      final sleepHours = _parseDouble(_sleepController.text);
      if (sleepHours == null) {
        _showValidationMessage(AppLocalizations.of(context).validSleepRequired);
        return;
      }
      data['sleep_hours'] = sleepHours;
    } else if (currentSleepHours != null) {
      data['sleep_hours'] = currentSleepHours;
    }

    if (_muscleMassTouched) {
      final rawMuscleMass = _muscleMassController.text.trim();
      if (rawMuscleMass.isNotEmpty) {
        final muscleMass = _parseDouble(rawMuscleMass);
        if (muscleMass == null) {
          _showValidationMessage(
            AppLocalizations.of(context).validMuscleMassRequired,
          );
          return;
        }
        data['muscle_mass_kg'] = UnitConverters.weightFromDisplay(
          muscleMass,
          unitSystem,
        );
      }
    } else if (currentMuscleMassKg != null) {
      data['muscle_mass_kg'] = currentMuscleMassKg;
    }

    final existingMeasures = <String, double?>{
      'neck_cm': currentMetric?.neckCm,
      'shoulders_cm': currentMetric?.shouldersCm,
      'chest_cm': currentMetric?.chestCm,
      'arm_left_cm': currentMetric?.armLeftCm,
      'arm_right_cm': currentMetric?.armRightCm,
      'forearm_left_cm': currentMetric?.forearmLeftCm,
      'forearm_right_cm': currentMetric?.forearmRightCm,
      'waist_cm': currentMetric?.waistCm,
      'hips_cm': currentMetric?.hipsCm,
      'thigh_left_cm': currentMetric?.thighLeftCm,
      'thigh_right_cm': currentMetric?.thighRightCm,
      'calf_left_cm': currentMetric?.calfLeftCm,
      'calf_right_cm': currentMetric?.calfRightCm,
    };

    for (final entry in _measureControllers.entries) {
      if (!_touchedMeasures.contains(entry.key)) {
        final existingValue = existingMeasures[entry.key];
        if (existingValue != null) {
          data[entry.key] = existingValue;
        }
        continue;
      }

      final rawValue = entry.value.text.trim();
      if (rawValue.isEmpty) {
        continue;
      }

      final parsedValue = _parseDouble(rawValue);
      if (parsedValue == null) {
        _showValidationMessage(
          AppLocalizations.of(context).measurementReviewTemplate(
            _localizedZoneLabel(
              context,
              _zoneForFieldKey(entry.key),
            ).toLowerCase(),
          ),
        );
        return;
      }

      data[entry.key] = UnitConverters.lengthFromDisplay(
        parsedValue,
        unitSystem,
      );
    }

    if (data.isEmpty) {
      _showValidationMessage(AppLocalizations.of(context).noChangesMessage);
      return;
    }

    context.read<MetricsBloc>().add(
      MetricsSaveRequested(
        data,
        profileData: profileData.isEmpty ? null : profileData,
      ),
    );
  }

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// Accepts «,» and «.» as the decimal separator in every locale.
  double? _parseDouble(String text) {
    return double.tryParse(text.trim().replaceAll(',', '.'));
  }

  String _lengthField(double? centimeters, UnitSystem unitSystem) =>
      _fieldNumber(formatLengthValue(centimeters, unitSystem));

  String _weightField(double? kilograms, UnitSystem unitSystem) =>
      _fieldNumber(formatWeightValue(kilograms, unitSystem));

  /// A fixed-decimals number as text for a field, with the decimal separator
  /// of the app locale («79,0» in Spanish, «79.0» in English).
  String _fieldNumber(String fixed) => fixed.replaceFirst(
    '.',
    decimalSeparatorFor(Localizations.localeOf(context).languageCode),
  );

  Map<String, dynamic>? _getCachedProfile() {
    return sl<LocalStorage>().getCachedMap('profile_me');
  }

  Future<void> _openSeenSource() async {
    final launched = await launchUrl(
      _seenSourceUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      await launchUrl(_seenSourceUri, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _openSeenEstimateCalculator(BuildContext context) async {
    final unitSystem = context.read<AppPreferencesCubit>().state.unitSystem;
    final profile = _getCachedProfile();
    final rawHeight = profile?['height'];
    final initialHeightCm = rawHeight is num
        ? rawHeight.toDouble()
        : double.tryParse(rawHeight?.toString() ?? '');
    final birthDate = profile?['birth_date'] is String
        ? DateTime.tryParse(profile!['birth_date'] as String)
        : null;

    final ageController = TextEditingController(
      text: birthDate != null ? calculateAgeYears(birthDate).toString() : '',
    );
    final heightController = TextEditingController(
      text: _heightController.text.isNotEmpty
          ? _heightController.text
          : initialHeightCm != null
          ? _lengthField(initialHeightCm, unitSystem)
          : '',
    );
    final calfController = TextEditingController(
      text: _preferredSeenCalfText(),
    );
    var selectedSex = parseSeenBiologicalSex(profile?['sex'] as String?);
    String? errorText;

    final estimate = await showDialog<SeenMuscleMassEstimate>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.exomPalette;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: palette.surface,
              title: Text(
                AppLocalizations.of(context).quickSeenEstimate,
                style: TextStyle(color: palette.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).seenFormulaDescription,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SeenSourceLink(
                      text: AppLocalizations.of(context).seenSourceLink,
                      onTap: _openSeenSource,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: palette.textPrimary),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).ageLabel,
                        suffixText: AppLocalizations.of(context).yearsLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: heightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(color: palette.textPrimary),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(
                          context,
                        ).heightSectionTitle,
                        suffixText: lengthUnitSymbol(unitSystem),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: calfController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(color: palette.textPrimary),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).calfLabel,
                        suffixText: lengthUnitSymbol(unitSystem),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SeenBiologicalSex>(
                      initialValue: selectedSex,
                      dropdownColor: palette.surfaceVariant,
                      style: TextStyle(color: palette.textPrimary),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).sexLabel,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: SeenBiologicalSex.male,
                          child: Text(AppLocalizations.of(context).maleOption),
                        ),
                        DropdownMenuItem(
                          value: SeenBiologicalSex.female,
                          child: Text(
                            AppLocalizations.of(context).femaleOption,
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedSex = value;
                          errorText = null;
                        });
                      },
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: TextStyle(color: palette.error, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(AppLocalizations.of(context).cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final age = int.tryParse(ageController.text.trim());
                    final heightValue = _parseDouble(heightController.text);
                    final calfValue = _parseDouble(calfController.text);

                    if (age == null || age <= 0) {
                      setDialogState(() {
                        errorText = AppLocalizations.of(
                          context,
                        ).invalidAgeError;
                      });
                      return;
                    }

                    if (heightValue == null || heightValue <= 0) {
                      setDialogState(() {
                        errorText = AppLocalizations.of(
                          context,
                        ).invalidHeightError;
                      });
                      return;
                    }

                    if (calfValue == null || calfValue <= 0) {
                      setDialogState(() {
                        errorText = AppLocalizations.of(
                          context,
                        ).invalidCalfError;
                      });
                      return;
                    }

                    final heightCm = UnitConverters.lengthFromDisplay(
                      heightValue,
                      unitSystem,
                    );
                    final calfCm = UnitConverters.lengthFromDisplay(
                      calfValue,
                      unitSystem,
                    );

                    final confirmedSex = selectedSex;
                    if (confirmedSex == null) {
                      setDialogState(() {
                        errorText = AppLocalizations.of(context).selectSexError;
                      });
                      return;
                    }

                    final result = estimateSeenMuscleMass(
                      calfCm: calfCm,
                      ageYears: age,
                      heightMeters: heightCm / 100,
                      sex: confirmedSex,
                    );

                    if (result == null) {
                      setDialogState(() {
                        errorText = AppLocalizations.of(
                          context,
                        ).estimationFailedError;
                      });
                      return;
                    }

                    _controllerForField('calf_left_cm').text = _lengthField(
                      calfCm,
                      unitSystem,
                    );
                    _controllerForField('calf_right_cm').text = _lengthField(
                      calfCm,
                      unitSystem,
                    );
                    _heightController.text = _lengthField(heightCm, unitSystem);
                    _heightTouched = true;
                    _muscleMassTouched = true;
                    _markMeasureTouched('calf_left_cm');
                    _markMeasureTouched('calf_right_cm');
                    Navigator.of(dialogContext).pop(result);
                  },
                  child: Text(
                    AppLocalizations.of(context).calculateAndUseButton,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    ageController.dispose();
    heightController.dispose();
    calfController.dispose();

    if (estimate == null || !context.mounted) {
      return;
    }

    setState(() {
      _muscleMassController.text = _weightField(
        estimate.estimatedAsmKg,
        unitSystem,
      );
    });

    final seenMsg = AppLocalizations.of(context).seenEstimateApplied(
      '${_weightField(estimate.estimatedAsmKg, unitSystem)} '
      '${weightUnitSymbol(unitSystem)}',
      _fieldNumber(estimate.estimatedAsmiKgPerM2.toStringAsFixed(2)),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(seenMsg), behavior: SnackBarBehavior.floating),
    );
  }

  void _populateFromMetric(BodyMetricEntity metric) {
    final unitSystem = context.read<AppPreferencesCubit>().state.unitSystem;
    final profile = _getCachedProfile();
    final rawProfileHeight = profile?['height'];
    final profileHeightCm = rawProfileHeight is num
        ? rawProfileHeight.toDouble()
        : double.tryParse(rawProfileHeight?.toString() ?? '');

    setState(() {
      final weightKg = metric.weightKg;
      if (weightKg != null) {
        _weightKg = weightKg;
      }
      _weightInputInvalid = false;
      _weightErrorShown = false;
      _weightFieldGeneration++;
      _heightTouched = false;
      _weightTouched = false;
      _muscleMassTouched = false;
      _sleepTouched = false;
      _touchedMeasures.clear();
    });
    _heightController.text = metric.heightCm != null
        ? _lengthField(metric.heightCm, unitSystem)
        : profileHeightCm != null
        ? _lengthField(profileHeightCm, unitSystem)
        : '';
    final sleepHours = metric.sleepHours;
    _sleepController.text = sleepHours != null
        ? _fieldNumber(sleepHours.toStringAsFixed(1))
        : '';
    if (metric.muscleMassKg != null) {
      _muscleMassController.text = _weightField(
        metric.muscleMassKg,
        unitSystem,
      );
    } else {
      _muscleMassController.clear();
    }
    final map = <String, double?>{
      'neck_cm': metric.neckCm,
      'shoulders_cm': metric.shouldersCm,
      'chest_cm': metric.chestCm,
      'arm_left_cm': metric.armLeftCm,
      'arm_right_cm': metric.armRightCm,
      'forearm_left_cm': metric.forearmLeftCm,
      'forearm_right_cm': metric.forearmRightCm,
      'waist_cm': metric.waistCm,
      'hips_cm': metric.hipsCm,
      'thigh_left_cm': metric.thighLeftCm,
      'thigh_right_cm': metric.thighRightCm,
      'calf_left_cm': metric.calfLeftCm,
      'calf_right_cm': metric.calfRightCm,
    };
    for (final entry in map.entries) {
      if (entry.value != null) {
        _controllerForField(entry.key).text = _lengthField(
          entry.value,
          unitSystem,
        );
      } else {
        _controllerForField(entry.key).clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
      (cubit) => cubit.state.unitSystem,
    );
    return BlocListener<MetricsBloc, MetricsState>(
      listener: (context, state) {
        if (state is MetricsLoaded) {
          final currentMetric = state.current;
          if (currentMetric != null) {
            _populateFromMetric(currentMetric);
          } else {
            _populateEmptyMetricState();
          }
        }
        if (state is MetricsSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(ExomIcons.done, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context).metricsSuccessMessage,
                    ),
                  ),
                ],
              ),
              backgroundColor: semantic.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
          Navigator.of(context).pop();
        }
        if (state is MetricsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizedErrorTextOf(
                  context,
                  state.message,
                  fallback: (l10n) => l10n.metricsSaveError,
                ),
              ),
              backgroundColor: palette.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }
      },
      child: ExomStaticBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: ExomAppBar(
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: Icon(ExomIcons.back, color: palette.textPrimary),
              onPressed: () => context.pop(),
            ),
          ),
          body: BlocBuilder<MetricsBloc, MetricsState>(
            builder: (context, state) {
              final isSaving = state is MetricsSaving;
              final bottomInset = MediaQuery.of(context).padding.bottom;
              final l10n = AppLocalizations.of(context);
              final secondary = TextStyle(
                color: palette.textSecondary,
                fontSize: 14,
                height: 1.45,
              );
              // Units next to a typed value: semibold so the two thin letters
              // keep their contrast in the light theme.
              final unitStyle = secondary.copyWith(fontWeight: FontWeight.w600);
              final fieldStyle = TextStyle(
                color: palette.textPrimary,
                fontSize: 18,
              );
              final weightUnit = weightUnitSymbol(unitSystem);
              double weightDisplay(double kg) =>
                  UnitConverters.weightToDisplay(kg, unitSystem);
              final weightStepText =
                  '${formatDisplayDecimal(weightDisplay(_weightStepKg), decimalSeparator: decimalSeparatorFor(Localizations.localeOf(context).languageCode))} $weightUnit';
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              HomeTitle(l10n.metricsPageTitle),
                              const SizedBox(height: ExomSpacing.sm),
                              Text(l10n.metricsFormSubtitle, style: secondary),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ExomNumberedSectionHeader(
                          n: 1,
                          title: l10n.recordDateTitle,
                        ),
                        _FormSection(
                          children: [
                            _DateField(
                              label: _selectedDateLabel(context),
                              onTap: _pickMetricDate,
                            ),
                            Text(l10n.recordDateDescription, style: secondary),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ExomNumberedSectionHeader(
                          n: 2,
                          title: l10n.weightSectionTitle,
                        ),
                        _FormSection(
                          children: [
                            KeyedSubtree(
                              key: ValueKey(_weightFieldGeneration),
                              child: ExomNumeralStepper(
                                key: const Key('metrics-weight-stepper'),
                                value: weightDisplay(_weightKg),
                                min: weightDisplay(_weightMinKg),
                                max: weightDisplay(_weightMaxKg),
                                step: weightDisplay(_weightStepKg),
                                unit: weightUnit,
                                label: l10n.weightSectionTitle,
                                decrementLabel: l10n.metricsWeightDecrease(
                                  weightStepText,
                                ),
                                incrementLabel: l10n.metricsWeightIncrease(
                                  weightStepText,
                                ),
                                // The manual mode took any typed value.
                                acceptsTypedOutOfRange: true,
                                onChanged: (value) =>
                                    _onWeightChanged(value, unitSystem),
                                onInvalidInput: _onWeightInvalidInput,
                                // A sign is invalid, not silently dropped.
                                rejectsSignedInput: true,
                                onSubmittedInvalid: _onWeightSubmittedInvalid,
                                errorText: _weightErrorShown
                                    ? l10n.validWeightRequired
                                    : null,
                              ),
                            ),
                            Text(l10n.metricsWeightTypeHint, style: secondary),
                            Text(l10n.weightUpdateNote, style: secondary),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ExomNumberedSectionHeader(
                          n: 3,
                          title: l10n.heightSectionTitle,
                        ),
                        _FormSection(
                          children: [
                            TextFormField(
                              controller: _heightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: fieldStyle,
                              decoration: InputDecoration(
                                hintText: _heightHint(l10n, unitSystem),
                                suffixText: lengthUnitSymbol(unitSystem),
                                suffixStyle: unitStyle,
                              ),
                              onChanged: (_) => _heightTouched = true,
                            ),
                            Text(l10n.heightDescription, style: secondary),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ExomNumberedSectionHeader(
                          n: 4,
                          title: l10n.muscleMassSectionTitle,
                        ),
                        _FormSection(
                          children: [
                            TextFormField(
                              controller: _muscleMassController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: fieldStyle,
                              decoration: InputDecoration(
                                hintText: localizedInputExample(
                                  l10n,
                                  unitSystem == UnitSystem.imperial
                                      ? 71.7
                                      : 32.5,
                                ),
                                suffixText: weightUnit,
                                suffixStyle: unitStyle,
                              ),
                              onChanged: (_) => _muscleMassTouched = true,
                            ),
                            Text(l10n.muscleMassDescription, style: secondary),
                            const SizedBox(height: ExomSpacing.sm),
                            Text(
                              l10n.seenCalculatorTitle,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              l10n.seenCalculatorDescription,
                              style: secondary,
                            ),
                            _SeenSourceLink(
                              text: l10n.seenSourceLink,
                              onTap: _openSeenSource,
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: ExomTextLink(
                                label: l10n.calculateEstimateButton,
                                onTap: () =>
                                    _openSeenEstimateCalculator(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ExomNumberedSectionHeader(
                          n: 5,
                          title: l10n.sleepHoursSectionTitle,
                        ),
                        _FormSection(
                          children: [
                            TextFormField(
                              controller: _sleepController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: fieldStyle,
                              decoration: InputDecoration(
                                hintText: localizedInputExample(l10n, 7.5),
                                suffixText: 'h',
                                suffixStyle: unitStyle,
                              ),
                              onChanged: (_) => _sleepTouched = true,
                            ),
                            Text(l10n.sleepHoursDescription, style: secondary),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [6.0, 7.0, 8.0, 9.0]
                                  .map((value) {
                                    return ActionChip(
                                      label: Text(
                                        '${value.toStringAsFixed(0)} h',
                                      ),
                                      onPressed: () => _setSleepValue(value),
                                    );
                                  })
                                  .toList(growable: false),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ExomNumberedSectionHeader(
                          n: 6,
                          title: l10n.bodyMeasurementsTitle,
                        ),
                        _FormSection(
                          children: [
                            ExomSegmentedControl<bool>(
                              options: const [true, false],
                              selected: _bodyMapMode,
                              labelOf: (bodyMap) => bodyMap
                                  ? l10n.bodyViewToggle
                                  : l10n.listViewToggle,
                              onChanged: (bodyMap) => setState(() {
                                _bodyMapMode = bodyMap;
                                _selectedMeasure = null;
                              }),
                            ),
                          ],
                        ),
                        if (_bodyMapMode)
                          _buildMeasureBody(l10n, unitSystem)
                        else ...[
                          const SizedBox(height: ExomSpacing.md),
                          _buildMeasureList(l10n, unitSystem),
                        ],
                      ],
                    ),
                  ),
                  ExomPinnedFooter(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
                    child: ExomPrimaryButton(
                      label: l10n.saveMetricsButton,
                      trailingIcon: ExomIcons.check,
                      busy: isSaving,
                      onPressed: _save,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MeasureZoneConfig {
  const _MeasureZoneConfig.single({required this.zone, required this.fieldKey})
    : leftFieldKey = null,
      rightFieldKey = null;

  const _MeasureZoneConfig.bilateral({
    required this.zone,
    required this.leftFieldKey,
    required this.rightFieldKey,
  }) : fieldKey = null;

  final BodyZone zone;
  final String? fieldKey;
  final String? leftFieldKey;
  final String? rightFieldKey;

  bool get isBilateral => leftFieldKey != null && rightFieldKey != null;

  List<String> get fieldKeys =>
      isBilateral ? [leftFieldKey!, rightFieldKey!] : [fieldKey!];
}

class _SeenSourceLink extends StatelessWidget {
  const _SeenSourceLink({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(ExomIcons.openExternal, size: 16),
      label: Text(text),
      style: TextButton.styleFrom(
        foregroundColor: palette.primary,
        padding: EdgeInsets.zero,
        minimumSize: const Size(kExomMinTapTarget, kExomMinTapTarget),
        tapTargetSize: MaterialTapTargetSize.padded,
        alignment: Alignment.centerLeft,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Body of a numbered section (`.pad.mt8.stack.g8` under an `.x-sh` of the
/// sketch «Formulario de métricas»): 20 dp sides, 8 dp from the header and
/// between its children.
class _FormSection extends StatelessWidget {
  const _FormSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExomSpacing.xl,
        ExomSpacing.sm,
        ExomSpacing.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: ExomSpacing.sm),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// The record date as a field that opens the date picker (`.input` with the
/// calendar icon): 56 high, 1.5 px muted border, radius 4. One button node
/// for assistive technology with the date as its label.
class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: ExomSpacing.md,
              vertical: ExomSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: palette.textSecondary, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(ExomIcons.calendar, color: palette.textPrimary, size: 20),
                const SizedBox(width: ExomSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 18,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Row of a measure in the list of «06 Medidas corporales» (sketch `.l6-r`):
/// the zone name (with the «Editada» marker when it was changed in this
/// session), the value at the end in tabular figures and a chevron, on the
/// shared flat-row surface. When the name and the value do not fit one line
/// (large text), the value moves under the name and stays at the end. The
/// row is one button for assistive technology.
class _MeasureRow extends StatelessWidget {
  const _MeasureRow({
    super.key,
    required this.zone,
    required this.label,
    required this.valueSpans,
    required this.spokenValue,
    required this.edited,
    required this.editedLabel,
    required this.onTap,
  });

  final BodyZone zone;
  final String label;
  final List<InlineSpan> valueSpans;
  final String spokenValue;
  final bool edited;
  final String editedLabel;
  final VoidCallback onTap;

  /// Gaps of the sketch: 12 between name and value, 10 before the marker.
  static const double _valueGap = 12;
  static const double _markerGap = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final labelStyle = theme.textTheme.bodyLarge!.copyWith(
      color: palette.textPrimary,
      height: 1.3,
    );
    final valueStyle = labelStyle.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final markerStyle = TextStyle(
      color: palette.textSecondary,
      fontSize: 13,
      height: 1.3,
    );
    final value = Text.rich(
      TextSpan(children: valueSpans),
      key: Key('metrics-measure-value-${zone.name}'),
      textAlign: TextAlign.end,
      style: valueStyle,
    );
    final marker = edited
        ? Row(
            key: Key('metrics-measure-edited-${zone.name}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: palette.textPrimary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(editedLabel, style: markerStyle),
            ],
          )
        : null;
    final name = Wrap(
      spacing: _markerGap,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(label, style: labelStyle),
        ?marker,
      ],
    );

    return MergeSemantics(
      child: Semantics(
        button: true,
        label: [label, spokenValue, if (edited) editedLabel].join(', '),
        excludeSemantics: true,
        child: ExomRowSurface(
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scaler = MediaQuery.textScalerOf(context);
                    final direction = Directionality.of(context);
                    double width(InlineSpan span) {
                      final painter = TextPainter(
                        text: span,
                        textDirection: direction,
                        textScaler: scaler,
                      );
                      try {
                        painter.layout();
                        return painter.width;
                      } finally {
                        painter.dispose();
                      }
                    }

                    var nameWidth = width(
                      TextSpan(text: label, style: labelStyle),
                    );
                    if (edited) {
                      nameWidth +=
                          _markerGap +
                          12 +
                          width(
                            TextSpan(text: editedLabel, style: markerStyle),
                          );
                    }
                    final valueWidth = width(
                      TextSpan(children: valueSpans, style: valueStyle),
                    );
                    if (nameWidth + _valueGap + valueWidth <=
                        constraints.maxWidth) {
                      return Row(
                        children: [
                          Expanded(child: name),
                          const SizedBox(width: _valueGap),
                          value,
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        name,
                        const SizedBox(height: 2),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: value,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Icon(ExomIcons.next, size: 22, color: palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// One stepper of the measure sheet: [fieldKey] of the draft, its side
/// label (null for a single zone) and the value it starts from, in the
/// display unit. An [empty] side shows «—» until it is changed; [initial] is
/// then only the base of its ±.
class _MeasureSide {
  const _MeasureSide({
    required this.fieldKey,
    required this.label,
    required this.initial,
    this.empty = false,
  });

  final String fieldKey;
  final String? label;
  final double initial;
  final bool empty;
}

/// Sheet of a measure (sketch «Hoja»): kicker «06 · Medidas», the zone name,
/// «Última…» when the loaded record has it, one numeral stepper per side
/// (stacked «Izquierda» and «Derecha» for a pair; step 0.5, typed with a
/// comma or a point) and «Hecho» pinned under them.
///
/// «Hecho» pops the sides the client changed, by field key; an invalid typed
/// value keeps the sheet open with the review message. Closing it any other
/// way pops null. Built like the set sheet: the fields scroll, the action
/// stays.
class _MeasureSheet extends StatefulWidget {
  const _MeasureSheet({
    required this.kicker,
    required this.title,
    required this.lastLine,
    required this.sides,
    required this.zoneLabel,
    required this.unit,
    required this.step,
    required this.max,
    required this.hint,
    required this.decrementLabel,
    required this.incrementLabel,
    required this.doneLabel,
    required this.noDataLabel,
    required this.reviewMessage,
  });

  final String kicker;
  final String title;
  final String? lastLine;
  final List<_MeasureSide> sides;
  final String zoneLabel;
  final String unit;
  final double step;
  final double max;
  final String hint;
  final String decrementLabel;
  final String incrementLabel;
  final String doneLabel;
  final String noDataLabel;
  final String reviewMessage;

  @override
  State<_MeasureSheet> createState() => _MeasureSheetState();
}

class _MeasureSheetState extends State<_MeasureSheet> {
  /// A value as the sheet shows it: at most two decimals, half up on the
  /// typed digits («33,256» becomes 33.26, «1,005» 1.01), so the draft and
  /// the save carry exactly the number shown.
  static double _measurePrecision(double value) => roundToHundredths(value);

  late final List<double> _values = [
    for (final side in widget.sides) side.initial,
  ];
  late final List<bool> _changed = [for (final _ in widget.sides) false];
  late final List<bool> _invalid = [for (final _ in widget.sides) false];
  bool _showErrors = false;

  void _done() {
    if (_invalid.any((invalid) => invalid)) {
      setState(() => _showErrors = true);
      return;
    }
    Navigator.of(context).pop(<String, double>{
      for (var i = 0; i < widget.sides.length; i++)
        if (_changed[i]) widget.sides[i].fieldKey: _values[i],
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final media = MediaQuery.of(context);
    // As in the set sheet: the frame caps its content at 90 % of the space
    // above the keyboard; the fields scroll and «Hecho» stays pinned.
    final bottomSafe = MediaQueryData.fromView(View.of(context)).padding.bottom;
    final maxHeight = math.max(
      0.0,
      (media.size.height - media.padding.top - media.viewInsets.bottom) * 0.9 -
          16 -
          bottomSafe -
          1,
    );
    final mutedStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 14,
      height: 1.4,
      color: palette.textSecondary,
    );
    final labelStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: palette.textPrimary,
    );

    final fields = Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ExomKicker(widget.kicker),
          ),
          const SizedBox(height: 4),
          Semantics(
            header: true,
            child: Text(
              widget.title.toUpperCase(),
              style: ExomType.headline2Section.copyWith(
                color: palette.textPrimary,
              ),
            ),
          ),
          if (widget.lastLine case final last?) ...[
            const SizedBox(height: 6),
            Text(
              last,
              key: const Key('metrics-measure-last'),
              style: mutedStyle,
            ),
          ],
          for (var i = 0; i < widget.sides.length; i++) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                if (widget.sides[i].label case final side?)
                  Text(side, style: labelStyle),
                if (i == 0) Text(widget.hint, style: mutedStyle),
              ],
            ),
            const SizedBox(height: 6),
            ExomNumeralStepper(
              key: Key('metrics-measure-stepper-${widget.sides[i].fieldKey}'),
              value: _values[i],
              min: 0,
              max: widget.max,
              step: widget.step,
              minFractionDigits: 1,
              empty: widget.sides[i].empty && !_changed[i],
              emptySemanticsValue: widget.noDataLabel,
              unit: widget.unit,
              label: widget.sides[i].label ?? widget.zoneLabel,
              decrementLabel: widget.decrementLabel,
              incrementLabel: widget.incrementLabel,
              // The old fields took any typed number.
              acceptsTypedOutOfRange: true,
              onChanged: (value) => setState(() {
                _values[i] = _measurePrecision(value);
                _changed[i] = true;
                _invalid[i] = false;
              }),
              onInvalidInput: (_) => setState(() => _invalid[i] = true),
              errorText: _showErrors && _invalid[i]
                  ? widget.reviewMessage
                  : null,
            ),
          ],
        ],
      ),
    );

    final actions = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.borderSoft)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: ExomPrimaryButton(
          key: const Key('metrics-measure-done'),
          label: widget.doneLabel,
          trailingIcon: ExomIcons.check,
          onPressed: _done,
        ),
      ),
    );

    return ConstrainedBox(
      key: const Key('metrics-measure-sheet'),
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(child: SingleChildScrollView(child: fields)),
          actions,
        ],
      ),
    );
  }
}
