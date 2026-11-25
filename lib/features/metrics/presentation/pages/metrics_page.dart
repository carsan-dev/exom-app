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
    show decimalSeparatorFor, formatDisplayDecimal;
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/models/body_zone.dart';
import 'package:exom_app/core/widgets/anatomy_selector.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_numeral_stepper.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_segmented_control.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/core/widgets/glass_app_bar.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/utils/seen_muscle_mass_estimator.dart';
import 'package:exom_app/features/metrics/presentation/bloc/metrics_bloc.dart';
import 'package:exom_app/features/home/presentation/widgets/home_headline.dart';

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

  static const _measureZones = <_MeasureZoneConfig>[
    _MeasureZoneConfig.single(zone: BodyZone.neck, fieldKey: 'neck_cm'),
    _MeasureZoneConfig.single(
      zone: BodyZone.shoulders,
      fieldKey: 'shoulders_cm',
    ),
    _MeasureZoneConfig.single(zone: BodyZone.chest, fieldKey: 'chest_cm'),
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
    _MeasureZoneConfig.single(zone: BodyZone.waist, fieldKey: 'waist_cm'),
    _MeasureZoneConfig.single(zone: BodyZone.hips, fieldKey: 'hips_cm'),
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

  static const _bodyMapLeftZones = [
    BodyZone.neck,
    BodyZone.shoulders,
    BodyZone.chest,
    BodyZone.waist,
    BodyZone.hips,
  ];
  static const _bodyMapRightZones = [
    BodyZone.upperArm,
    BodyZone.forearm,
    BodyZone.thigh,
    BodyZone.calf,
  ];
  static const _bodyMapLeftFlex = [1, 2, 4, 6, 8];
  static const _bodyMapRightFlex = [3, 4, 7, 9];

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

  String _zoneValuePreview(BodyZone zone) {
    final config = _measureZone(zone);
    if (!config.isBilateral) {
      return _controllerForField(config.fieldKey!).text.trim();
    }

    final left = _controllerForField(config.leftFieldKey!).text.trim();
    final right = _controllerForField(config.rightFieldKey!).text.trim();
    if (left.isEmpty && right.isEmpty) {
      return '';
    }

    return '${left.isEmpty ? '-' : left} / ${right.isEmpty ? '-' : right}';
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

  Widget _buildMeasureEditor(BuildContext context, BodyZone zone) {
    final config = _measureZone(zone);
    if (!config.isBilateral) {
      return _MeasureInput(
        label: _localizedZoneLabel(context, zone),
        controller: _controllerForField(config.fieldKey!),
        onChanged: (_) => _markMeasureTouched(config.fieldKey!),
      );
    }

    final l10n = AppLocalizations.of(context);
    return _BilateralMeasureInput(
      label: _localizedZoneLabel(context, zone),
      leftLabel: l10n.leftSideShortLabel,
      rightLabel: l10n.rightSideShortLabel,
      leftController: _controllerForField(config.leftFieldKey!),
      rightController: _controllerForField(config.rightFieldKey!),
      onLeftChanged: (_) => _markMeasureTouched(config.leftFieldKey!),
      onRightChanged: (_) => _markMeasureTouched(config.rightFieldKey!),
    );
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

  /// Horizontal and vertical room a zone control takes besides its text:
  /// 8 dp of padding and the 1.5 dp border on each side.
  static const double _zoneControlChromeWidth = 19;
  static const double _zoneControlChromeHeight = 11;
  static const double _bodyMapSelectorHeight = 440;

  /// Whether the zone names and values fit the side columns of the body map
  /// without splitting a word or outgrowing the body height. It depends only
  /// on the available width, the text scale and the locale, never on what the
  /// user typed, so the layout (and the editor under it) does not change while
  /// typing.
  bool _bodyMapFitsSideBySide(
    BuildContext context,
    double maxWidth,
    UnitSystem unitSystem,
  ) {
    // The context below the page's Material, where the zone texts inherit
    // their default style from.
    final scaler = MediaQuery.textScalerOf(context);
    final base = DefaultTextStyle.of(context).style;
    final labelStyle = base.merge(
      const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    );
    final valueStyle = base.merge(const TextStyle(fontSize: 13));
    final contentWidth =
        (maxWidth - AnatomySelector.widthFor(_bodyMapSelectorHeight)) / 2 -
        _zoneControlChromeWidth;
    if (contentWidth <= 0) {
      return false;
    }
    final unit = lengthUnitSymbol(unitSystem);
    // Measures and releases the painter right away.
    Size measure(String text, TextStyle style, double maxWidth) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      );
      try {
        painter.layout(maxWidth: maxWidth);
        return painter.size;
      } finally {
        painter.dispose();
      }
    }

    final bodyHeight = AnatomySelector.bodyHeightFor(_bodyMapSelectorHeight);
    for (final column in [_bodyMapLeftZones, _bodyMapRightZones]) {
      var columnHeight = 0.0;
      for (final zone in column) {
        final label = measure(
          _localizedZoneLabel(context, zone),
          labelStyle,
          double.infinity,
        );
        if (label.width > contentWidth) {
          return false;
        }
        // Widest value the zone can show: two sides of three digits and a
        // decimal for the bilateral zones.
        final value = _measureZone(zone).isBilateral
            ? '000.0 / 000.0 $unit'
            : '000.0 $unit';
        if (measure('000.0', valueStyle, double.infinity).width >
            contentWidth) {
          return false;
        }
        final valueHeight = measure(value, valueStyle, contentWidth).height;
        columnHeight += math.max(
          kExomMinTapTarget,
          _zoneControlChromeHeight + label.height + valueHeight,
        );
      }
      if (columnHeight > bodyHeight) {
        return false;
      }
    }
    return true;
  }

  static const _bodyMapStackedZones = [
    BodyZone.neck,
    BodyZone.shoulders,
    BodyZone.chest,
    BodyZone.upperArm,
    BodyZone.forearm,
    BodyZone.waist,
    BodyZone.hips,
    BodyZone.thigh,
    BodyZone.calf,
  ];

  Widget _buildBodyMapMeasurements() {
    final unitSystem = context.read<AppPreferencesCubit>().state.unitSystem;
    return LayoutBuilder(
      builder: (context, constraints) =>
          _bodyMapFitsSideBySide(context, constraints.maxWidth, unitSystem)
          ? _buildSideBySideBodyMap(unitSystem)
          : _buildStackedBodyMap(unitSystem),
    );
  }

  Widget _buildStackedBodyMap(UnitSystem unitSystem) {
    const selectorHeight = _bodyMapSelectorHeight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: AnatomySelector(
            height: selectorHeight,
            selectedZone: _selectedMeasure,
            onZoneSelected: (zone) {
              setState(() => _selectedMeasure = zone);
            },
          ),
        ),
        const SizedBox(height: 8),
        for (final zone in _bodyMapStackedZones)
          _zoneLabel(zone, unitSystem, stacked: true),
        if (_selectedMeasure != null) ...[
          const SizedBox(height: 16),
          _buildMeasureEditor(context, _selectedMeasure!),
        ],
      ],
    );
  }

  Widget _buildSideBySideBodyMap(UnitSystem unitSystem) {
    const selectorHeight = _bodyMapSelectorHeight;
    final selectorBodyHeight = AnatomySelector.bodyHeightFor(selectorHeight);

    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: selectorHeight,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.topRight,
                  child: SizedBox(
                    height: selectorBodyHeight,
                    child: _buildZoneColumn(
                      _bodyMapLeftZones,
                      _bodyMapLeftFlex,
                      CrossAxisAlignment.end,
                      unitSystem,
                    ),
                  ),
                ),
              ),
              AnatomySelector(
                height: selectorHeight,
                selectedZone: _selectedMeasure,
                onZoneSelected: (zone) {
                  setState(() => _selectedMeasure = zone);
                },
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    height: selectorBodyHeight,
                    child: _buildZoneColumn(
                      _bodyMapRightZones,
                      _bodyMapRightFlex,
                      CrossAxisAlignment.start,
                      unitSystem,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_selectedMeasure != null) ...[
          const SizedBox(height: 16),
          _buildMeasureEditor(context, _selectedMeasure!),
        ],
      ],
    );
  }

  Widget _buildZoneColumn(
    List<BodyZone> zones,
    List<int> flex,
    CrossAxisAlignment align,
    UnitSystem unitSystem,
  ) {
    final children = <Widget>[];
    for (var i = 0; i < zones.length; i++) {
      if (i == 0 && flex[i] > 1) {
        children.add(Spacer(flex: flex[i]));
      } else if (i > 0) {
        children.add(Spacer(flex: flex[i] - flex[i - 1]));
      }
      children.add(_zoneLabel(zones[i], unitSystem));
    }
    children.add(Spacer(flex: 10 - flex.last));

    return Column(crossAxisAlignment: align, children: children);
  }

  Widget _zoneLabel(
    BodyZone zone,
    UnitSystem unitSystem, {
    bool stacked = false,
  }) {
    final palette = context.exomPalette;
    final val = _zoneValuePreview(zone);
    final isSelected = _selectedMeasure == zone;
    // Stacked (large text): one line per text, scaled down as a last resort
    // so a word is never split.
    Widget fit(Widget text) =>
        stacked ? FittedBox(fit: BoxFit.scaleDown, child: text) : text;

    return GestureDetector(
      onTap: () => setState(() => _selectedMeasure = zone),
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: kExomMinTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? palette.textPrimary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            fit(
              Text(
                _localizedZoneLabel(context, zone),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? palette.textPrimary
                      : palette.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (val.isNotEmpty)
              fit(
                Text(
                  '$val ${lengthUnitSymbol(unitSystem)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? palette.textPrimary
                        : palette.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
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
          appBar: GlassAppBar(
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
                            if (_bodyMapMode)
                              _buildBodyMapMeasurements()
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 8,
                                      mainAxisExtent:
                                          112 *
                                          math.max(
                                            1.0,
                                            MediaQuery.textScalerOf(
                                                  context,
                                                ).scale(14) /
                                                14,
                                          ),
                                    ),
                                itemCount: _measureZones.length,
                                itemBuilder: (context, index) {
                                  final zone = _measureZones[index].zone;
                                  return _buildMeasureEditor(context, zone);
                                },
                              ),
                          ],
                        ),
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

/// Placeholder of a measure field: «0» in metric, «0.0» in imperial with the
/// decimal separator of the app locale (the one the field values use).
String _measureHint(BuildContext context, UnitSystem unitSystem) =>
    unitSystem == UnitSystem.imperial
    ? '0.0'.replaceFirst(
        '.',
        decimalSeparatorFor(Localizations.localeOf(context).languageCode),
      )
    : '0';

class _MeasureInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const _MeasureInput({
    required this.label,
    required this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
      (cubit) => cubit.state.unitSystem,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: palette.textPrimary, fontSize: 16),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: _measureHint(context, unitSystem),
            suffixText: lengthUnitSymbol(unitSystem),
            suffixStyle: TextStyle(
              color: palette.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }
}

class _BilateralMeasureInput extends StatelessWidget {
  final String label;
  final String leftLabel;
  final String rightLabel;
  final TextEditingController leftController;
  final TextEditingController rightController;
  final ValueChanged<String>? onLeftChanged;
  final ValueChanged<String>? onRightChanged;

  const _BilateralMeasureInput({
    required this.label,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftController,
    required this.rightController,
    this.onLeftChanged,
    this.onRightChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
      (cubit) => cubit.state.unitSystem,
    );

    InputDecoration decoration() {
      return InputDecoration(
        hintText: _measureHint(context, unitSystem),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      );
    }

    Widget buildSideField({
      required String sideLabel,
      required TextEditingController controller,
      required ValueChanged<String>? onChanged,
    }) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                sideLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: palette.textPrimary, fontSize: 16),
              onChanged: onChanged,
              decoration: decoration(),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            buildSideField(
              sideLabel: leftLabel,
              controller: leftController,
              onChanged: onLeftChanged,
            ),
            const SizedBox(width: 8),
            buildSideField(
              sideLabel: rightLabel,
              controller: rightController,
              onChanged: onRightChanged,
            ),
          ],
        ),
      ],
    );
  }
}
