import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/formatters/unit_converters.dart';
import 'package:exom_app/core/formatters/unit_formatters.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/models/body_zone.dart';
import 'package:exom_app/core/widgets/anatomy_selector.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/glass_app_bar.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/utils/seen_muscle_mass_estimator.dart';
import 'package:exom_app/features/metrics/presentation/bloc/metrics_bloc.dart';

class MetricsPage extends StatelessWidget {
  const MetricsPage({super.key});

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

  double _weight = 75.0;
  bool _useManualWeight = false;
  final _sleepController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _muscleMassController = TextEditingController();
  DateTime _selectedMetricDate = DateUtils.dateOnly(DateTime.now());
  double _sleepHours = 8.0;
  bool _heightTouched = false;
  bool _weightTouched = false;
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
    _populateFallbackValuesFromCachedProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMetricForSelectedDate();
      }
    });
  }

  @override
  void dispose() {
    _sleepController.dispose();
    _weightController.dispose();
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

  String _weightHint(UnitSystem unitSystem) {
    return unitSystem == UnitSystem.imperial ? 'Eg: 166.4' : 'Eg: 75.5';
  }

  String _heightHint(UnitSystem unitSystem) {
    return unitSystem == UnitSystem.imperial ? 'Eg: 70.9' : 'Eg: 180';
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

  void _setSleepValue(double value) {
    setState(() {
      _sleepHours = value;
      _sleepController.text = value.toStringAsFixed(1);
      _sleepTouched = true;
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
      _heightController.text = formatLengthValue(heightCm, unitSystem);
    }

    if (weightKg != null && _weightController.text.isEmpty) {
      _weight = weightKg.clamp(40.0, 160.0);
      _weightController.text = formatWeightValue(weightKg, unitSystem);
      _useManualWeight = weightKg < 40.0 || weightKg > 160.0;
    }
  }

  void _populateEmptyMetricState() {
    final unitSystem = context.read<AppPreferencesCubit>().state.unitSystem;
    final profileHeightCm = _cachedProfileNumber('height');
    final profileWeightKg = _cachedProfileNumber('current_weight');

    setState(() {
      _weight = (profileWeightKg ?? 75.0).clamp(40.0, 160.0);
      _sleepHours = 8.0;
      _heightTouched = false;
      _weightTouched = false;
      _muscleMassTouched = false;
      _sleepTouched = false;
      _touchedMeasures.clear();
      _useManualWeight =
          profileWeightKg != null &&
          (profileWeightKg < 40.0 || profileWeightKg > 160.0);
    });
    _heightController.text = profileHeightCm != null
        ? formatLengthValue(profileHeightCm, unitSystem)
        : '';
    _weightController.text = profileWeightKg != null
        ? formatWeightValue(profileWeightKg, unitSystem)
        : '';
    _muscleMassController.clear();
    _sleepController.clear();
    for (final controller in _measureControllers.values) {
      controller.clear();
    }
  }

  Widget _buildBodyMapMeasurements() {
    final unitSystem = context.read<AppPreferencesCubit>().state.unitSystem;
    const selectorHeight = 440.0;
    const selectorBodyHeight = 388.0;

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

  Widget _zoneLabel(BodyZone zone, UnitSystem unitSystem) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final val = _zoneValuePreview(zone);
    final isSelected = _selectedMeasure == zone;

    return GestureDetector(
      onTap: () => setState(() => _selectedMeasure = zone),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: isSelected
            ? GlassDecoration.accentCard(semantic.info, borderRadius: 10)
            : const BoxDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _localizedZoneLabel(context, zone),
              style: TextStyle(
                color: isSelected ? semantic.info : palette.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (val.isNotEmpty)
              Text(
                '$val ${lengthUnitSymbol(unitSystem)}',
                style: TextStyle(
                  color: isSelected ? semantic.info : palette.textDisabled,
                  fontSize: 10,
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
      if (_useManualWeight) {
        final manualWeight = _parseDouble(_weightController.text);
        if (manualWeight == null) {
          _showValidationMessage(
            AppLocalizations.of(context).validWeightRequired,
          );
          return;
        }
        data['weight_kg'] = UnitConverters.weightFromDisplay(
          manualWeight,
          unitSystem,
        );
      } else {
        data['weight_kg'] = _weight;
      }
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

  double? _parseDouble(String text) {
    return double.tryParse(text.trim().replaceAll(',', '.'));
  }

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
          ? formatLengthValue(initialHeightCm, unitSystem)
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
                        fontSize: 12,
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
                        style: TextStyle(color: palette.error, fontSize: 12),
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

                    _controllerForField('calf_left_cm').text =
                        formatLengthValue(calfCm, unitSystem);
                    _controllerForField('calf_right_cm').text =
                        formatLengthValue(calfCm, unitSystem);
                    _heightController.text = formatLengthValue(
                      heightCm,
                      unitSystem,
                    );
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
      _muscleMassController.text = formatWeightValue(
        estimate.estimatedAsmKg,
        unitSystem,
      );
    });

    final seenMsg = AppLocalizations.of(context).seenEstimateApplied(
      formatWeight(estimate.estimatedAsmKg, unitSystem),
      estimate.estimatedAsmiKgPerM2.toStringAsFixed(2),
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
        _weight = weightKg.clamp(40.0, 160.0);
      }
      final sleepHours = metric.sleepHours;
      if (sleepHours != null) {
        _sleepHours = sleepHours.clamp(4.0, 12.0);
      }
      _heightTouched = false;
      _weightTouched = false;
      _muscleMassTouched = false;
      _sleepTouched = false;
      _touchedMeasures.clear();
    });
    _heightController.text = metric.heightCm != null
        ? formatLengthValue(metric.heightCm, unitSystem)
        : profileHeightCm != null
        ? formatLengthValue(profileHeightCm, unitSystem)
        : '';
    _weightController.text = metric.weightKg != null
        ? formatWeightValue(metric.weightKg, unitSystem)
        : '';
    final sleepHours = metric.sleepHours;
    _sleepController.text = sleepHours != null
        ? sleepHours.toStringAsFixed(1)
        : '';
    if (metric.muscleMassKg != null) {
      _muscleMassController.text = formatWeightValue(
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
        _controllerForField(entry.key).text = formatLengthValue(
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
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(AppLocalizations.of(context).metricsSuccessMessage),
                ],
              ),
              backgroundColor: semantic.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          Navigator.of(context).pop();
        }
        if (state is MetricsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: palette.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
              icon: Icon(Icons.arrow_back, color: palette.textPrimary),
              onPressed: () => context.pop(),
            ),
            title: Text(
              AppLocalizations.of(context).metricsPageTitle,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.374,
              ),
            ),
          ),
          body: BlocBuilder<MetricsBloc, MetricsState>(
            builder: (context, state) {
              final isSaving = state is MetricsSaving;
              final bottomInset = MediaQuery.of(context).padding.bottom;
              return Stack(
                children: [
                  ListView(
                    padding: EdgeInsets.only(bottom: 124 + bottomInset),
                    children: [
                      _SectionCard(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        title: AppLocalizations.of(context).recordDateTitle,
                        icon: Icons.calendar_today_outlined,
                        color: palette.primary,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(
                                context,
                              ).recordDateDescription,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _pickMetricDate,
                              icon: const Icon(Icons.event_outlined, size: 16),
                              label: Text(_selectedDateLabel(context)),
                            ),
                          ],
                        ),
                      ),

                      _SectionCard(
                        title: AppLocalizations.of(context).heightSectionTitle,
                        icon: Icons.height,
                        color: semantic.info,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context).heightDescription,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _heightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: TextStyle(color: palette.textPrimary),
                              decoration: InputDecoration(
                                hintText: _heightHint(unitSystem),
                                suffixText: lengthUnitSymbol(unitSystem),
                                suffixStyle: TextStyle(
                                  color: palette.textSecondary,
                                ),
                              ),
                              onChanged: (_) => _heightTouched = true,
                            ),
                          ],
                        ),
                      ),

                      // Weight section
                      _SectionCard(
                        title: AppLocalizations.of(context).weightSectionTitle,
                        icon: Icons.monitor_weight_outlined,
                        color: palette.primary,
                        child: Column(
                          children: [
                            // Toggle manual/slider
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  ).manualEntryToggle,
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                Switch(
                                  value: _useManualWeight,
                                  onChanged: (val) =>
                                      setState(() => _useManualWeight = val),
                                  activeThumbColor: palette.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppLocalizations.of(context).weightUpdateNote,
                              style: TextStyle(
                                color: palette.textDisabled,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                            if (_useManualWeight)
                              TextFormField(
                                controller: _weightController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: TextStyle(color: palette.textPrimary),
                                decoration: InputDecoration(
                                  hintText: _weightHint(unitSystem),
                                  suffixText: weightUnitSymbol(unitSystem),
                                  suffixStyle: TextStyle(
                                    color: palette.textSecondary,
                                  ),
                                ),
                                onChanged: (_) => _weightTouched = true,
                              )
                            else ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    formatWeight(40, unitSystem, decimals: 0),
                                    style: TextStyle(
                                      color: palette.textDisabled,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    formatWeight(_weight, unitSystem),
                                    style: TextStyle(
                                      color: palette.primary,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    formatWeight(160, unitSystem, decimals: 0),
                                    style: TextStyle(
                                      color: palette.textDisabled,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: _weight,
                                min: 40.0,
                                max: 160.0,
                                divisions: 240,
                                activeColor: palette.primary,
                                inactiveColor: palette.surfaceVariant,
                                onChanged: (val) => setState(() {
                                  _weight = val;
                                  _weightTouched = true;
                                }),
                              ),
                            ],
                          ],
                        ),
                      ),

                      _SectionCard(
                        title: AppLocalizations.of(
                          context,
                        ).muscleMassSectionTitle,
                        icon: Icons.fitness_center,
                        color: semantic.calorie,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(
                                context,
                              ).muscleMassDescription,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _muscleMassController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: TextStyle(color: palette.textPrimary),
                              decoration: InputDecoration(
                                hintText: unitSystem == UnitSystem.imperial
                                    ? 'Eg: 71.7'
                                    : 'Eg: 32.5',
                                suffixText: weightUnitSymbol(unitSystem),
                                suffixStyle: TextStyle(
                                  color: palette.textSecondary,
                                ),
                              ),
                              onChanged: (_) => _muscleMassTouched = true,
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: GlassDecoration.card(
                                borderRadius: 18,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    ).seenCalculatorTitle,
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    ).seenCalculatorDescription,
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _SeenSourceLink(
                                    text: AppLocalizations.of(
                                      context,
                                    ).seenSourceLink,
                                    onTap: _openSeenSource,
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _openSeenEstimateCalculator(context),
                                      icon: const Icon(
                                        Icons.calculate_outlined,
                                      ),
                                      label: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).calculateEstimateButton,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Sleep section
                      _SectionCard(
                        title: AppLocalizations.of(
                          context,
                        ).sleepHoursSectionTitle,
                        icon: Icons.bedtime_outlined,
                        color: semantic.sleep,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(
                                context,
                              ).sleepHoursDescription,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _sleepController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: TextStyle(color: palette.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Eg: 7.5',
                                suffixText: 'h',
                                suffixStyle: TextStyle(
                                  color: palette.textSecondary,
                                ),
                              ),
                              onChanged: (value) {
                                _sleepTouched = true;
                                final parsed = _parseDouble(value);
                                if (parsed != null) {
                                  _sleepHours = parsed.clamp(0.0, 24.0);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
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
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.center,
                              child: _SleepEmoji(_sleepHours),
                            ),
                          ],
                        ),
                      ),

                      // Body measurements
                      _SectionCard(
                        title: AppLocalizations.of(
                          context,
                        ).bodyMeasurementsTitle,
                        icon: Icons.straighten,
                        color: semantic.info,
                        trailing: GestureDetector(
                          onTap: () => setState(() {
                            _bodyMapMode = !_bodyMapMode;
                            _selectedMeasure = null;
                          }),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _bodyMapMode
                                    ? Icons.grid_view
                                    : Icons.accessibility_new,
                                color: semantic.info,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _bodyMapMode
                                    ? AppLocalizations.of(
                                        context,
                                      ).listViewToggle
                                    : AppLocalizations.of(
                                        context,
                                      ).bodyViewToggle,
                                style: TextStyle(
                                  color: semantic.info,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bodyMapMode
                                ? _buildBodyMapMeasurements()
                                : Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 8,
                                            mainAxisExtent: 104,
                                          ),
                                      itemCount: _measureZones.length,
                                      itemBuilder: (context, index) {
                                        final zone = _measureZones[index].zone;
                                        return _buildMeasureEditor(
                                          context,
                                          zone,
                                        );
                                      },
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Save button
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        12,
                        12,
                        bottomInset > 0 ? bottomInset : 12,
                      ),
                      decoration: _metricsStickyBarDecoration(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: GlassDecoration.elevated(borderRadius: 24),
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _save,
                          child: isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  AppLocalizations.of(
                                    context,
                                  ).saveMetricsButton,
                                ),
                        ),
                      ),
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

BoxDecoration _metricsStickyBarDecoration(BuildContext context) {
  final palette = context.exomPalette;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return BoxDecoration(
    color: isDark ? AppColors.navBarGlass : AppColors.navBarGlassLightTheme,
    border: Border(
      top: BorderSide(
        color: palette.glassBorder.withValues(alpha: isDark ? 0.18 : 0.10),
        width: 0.6,
      ),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
        blurRadius: 24,
        offset: const Offset(0, -6),
        spreadRadius: -14,
      ),
    ],
  );
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
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(text),
      style: TextButton.styleFrom(
        foregroundColor: palette.primary,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.centerLeft,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.trailing,
    this.margin = const EdgeInsets.fromLTRB(16, 16, 16, 0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(20),
      decoration: GlassDecoration.card(borderRadius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (trailing != null) ...[const Spacer(), trailing!],
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

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
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: palette.textPrimary, fontSize: 14),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: unitSystem == UnitSystem.imperial ? '0.0' : '0',
            suffixText: lengthUnitSymbol(unitSystem),
            suffixStyle: TextStyle(color: palette.textDisabled, fontSize: 12),
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
        hintText: unitSystem == UnitSystem.imperial ? '0.0' : '0',
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
                  color: palette.textDisabled,
                  fontSize: 10,
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
              style: TextStyle(color: palette.textPrimary, fontSize: 14),
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
            fontSize: 11,
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

class _SleepEmoji extends StatelessWidget {
  final double hours;

  const _SleepEmoji(this.hours);

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final String emoji;
    final String label;
    if (hours < 6) {
      emoji = '😴';
      label = l10n.sleepVeryLow;
    } else if (hours < 7) {
      emoji = '😕';
      label = l10n.sleepInsufficient;
    } else if (hours <= 9) {
      emoji = '😊';
      label = l10n.sleepOptimal;
    } else {
      emoji = '😪';
      label = l10n.sleepTooMuch;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: palette.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
