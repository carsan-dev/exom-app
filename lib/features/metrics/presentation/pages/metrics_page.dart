import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/formatters/unit_converters.dart';
import 'package:exom_app/core/formatters/unit_formatters.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/body_silhouette_painter.dart';
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
  bool _bodyFront = true;
  String? _selectedMeasure;

  final Map<String, TextEditingController> _measureControllers = {
    'Cuello': TextEditingController(),
    'Hombros': TextEditingController(),
    'Pecho': TextEditingController(),
    'Brazo': TextEditingController(),
    'Antebrazo': TextEditingController(),
    'Cintura': TextEditingController(),
    'Caderas': TextEditingController(),
    'Muslo': TextEditingController(),
    'Pantorrilla': TextEditingController(),
  };

  final Map<String, String> _measureKeys = {
    'Cuello': 'neck_cm',
    'Hombros': 'shoulders_cm',
    'Pecho': 'chest_cm',
    'Brazo': 'arm_cm',
    'Antebrazo': 'forearm_cm',
    'Cintura': 'waist_cm',
    'Caderas': 'hips_cm',
    'Muslo': 'thigh_cm',
    'Pantorrilla': 'calf_cm',
  };

  @override
  void initState() {
    super.initState();
    _populateHeightFromCachedProfile();
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

  // Front view zones (left column, right column)
  static const _frontLeftZones = ['Cuello', 'Pecho', 'Cintura'];
  static const _frontRightZones = ['Brazo', 'Antebrazo'];
  // Back view zones
  static const _backLeftZones = ['Hombros', 'Caderas'];
  static const _backRightZones = ['Muslo', 'Pantorrilla'];

  // Hotspot positions (relative to body silhouette)
  static const _frontHotspots = <String, Offset>{
    'Cuello': Offset(0.50, 0.10),
    'Pecho': Offset(0.50, 0.25),
    'Brazo': Offset(0.82, 0.30),
    'Antebrazo': Offset(0.85, 0.40),
    'Cintura': Offset(0.50, 0.40),
  };
  static const _backHotspots = <String, Offset>{
    'Hombros': Offset(0.50, 0.17),
    'Caderas': Offset(0.50, 0.45),
    'Muslo': Offset(0.62, 0.62),
    'Pantorrilla': Offset(0.62, 0.80),
  };

  // Flex values for label positioning on columns
  static const _frontLeftFlex = [2, 5, 9];
  static const _frontRightFlex = [6, 9];
  static const _backLeftFlex = [3, 9];
  static const _backRightFlex = [6, 9];

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
      return AppLocalizations.of(context)!.todayLabel;
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

  void _populateHeightFromCachedProfile() {
    final unitSystem = context.read<AppPreferencesCubit>().state.unitSystem;
    final profile = _getCachedProfile();
    final rawHeight = profile?['height'];
    final heightCm = rawHeight is num
        ? rawHeight.toDouble()
        : double.tryParse(rawHeight?.toString() ?? '');

    if (heightCm != null && _heightController.text.isEmpty) {
      _heightController.text = formatLengthValue(heightCm, unitSystem);
    }
  }

  void _populateEmptyMetricState() {
    _populateHeightFromCachedProfile();
    setState(() {
      _weight = 75.0;
      _sleepHours = 8.0;
      _heightTouched = false;
      _weightTouched = false;
      _muscleMassTouched = false;
      _sleepTouched = false;
      _touchedMeasures.clear();
    });
    _weightController.clear();
    _muscleMassController.clear();
    _sleepController.clear();
    for (final controller in _measureControllers.values) {
      controller.clear();
    }
  }

  Widget _buildBodyMapMeasurements() {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final unitSystem = context.read<AppPreferencesCubit>().state.unitSystem;
    final zones = _bodyFront ? _frontHotspots : _backHotspots;
    final leftZones = _bodyFront ? _frontLeftZones : _backLeftZones;
    final rightZones = _bodyFront ? _frontRightZones : _backRightZones;
    final leftFlex = _bodyFront ? _frontLeftFlex : _backLeftFlex;
    final rightFlex = _bodyFront ? _frontRightFlex : _backRightFlex;

    return Column(
      children: [
        // Toggle tabs
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _viewTab('Frontal', Icons.person_outline, _bodyFront, () {
              setState(() {
                _bodyFront = true;
                _selectedMeasure = null;
              });
            }),
            const SizedBox(width: 8),
            _viewTab('Posterior', Icons.person_outline, !_bodyFront, () {
              setState(() {
                _bodyFront = false;
                _selectedMeasure = null;
              });
            }),
          ],
        ),
        const SizedBox(height: 12),

        // Body map with labels
        SizedBox(
          height: 440,
          child: Row(
            children: [
              // Left labels
              Expanded(
                flex: 2,
                child: _buildZoneColumn(
                  leftZones,
                  leftFlex,
                  CrossAxisAlignment.end,
                  unitSystem,
                ),
              ),

              // Body silhouette with hotspots
              SizedBox(
                width: 130,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bodyW = constraints.maxWidth;
                    const bodyH = 440.0;
                    return SizedBox(
                      height: bodyH,
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: Size(bodyW, bodyH),
                            painter: BodySilhouettePainter(
                              isBack: !_bodyFront,
                              fillColor: palette.textSecondary.withValues(
                                alpha: 0.08,
                              ),
                              strokeColor: palette.textSecondary.withValues(
                                alpha: 0.22,
                              ),
                              detailColor: palette.textSecondary.withValues(
                                alpha: 0.16,
                              ),
                            ),
                          ),
                          ...zones.entries.map((e) {
                            final dx = e.value.dx * bodyW;
                            final dy = e.value.dy * bodyH;
                            return Positioned(
                              left: dx - 8,
                              top: dy - 8,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedMeasure = e.key),
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _selectedMeasure == e.key
                                        ? semantic.info
                                        : semantic.info.withValues(alpha: 0.3),
                                    border: Border.all(
                                      color: semantic.info,
                                      width: _selectedMeasure == e.key ? 2 : 1,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Right labels
              Expanded(
                flex: 2,
                child: _buildZoneColumn(
                  rightZones,
                  rightFlex,
                  CrossAxisAlignment.start,
                  unitSystem,
                ),
              ),
            ],
          ),
        ),

        // Input for selected zone
        if (_selectedMeasure != null) ...[
          const SizedBox(height: 16),
          _MeasureInput(
            label: _selectedMeasure!,
            controller: _measureControllers[_selectedMeasure]!,
            onChanged: (_) => _touchedMeasures.add(_selectedMeasure!),
          ),
        ],
      ],
    );
  }

  Widget _buildZoneColumn(
    List<String> zones,
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

  Widget _zoneLabel(String zone, UnitSystem unitSystem) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final val = _measureControllers[zone]?.text ?? '';
    final isSelected = _selectedMeasure == zone;

    return GestureDetector(
      onTap: () => setState(() => _selectedMeasure = zone),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? semantic.info.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: semantic.info.withValues(alpha: 0.4))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              zone,
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

  Widget _viewTab(
    String label,
    IconData icon,
    bool active,
    VoidCallback onTap,
  ) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? semantic.info.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? semantic.info : palette.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? semantic.info : palette.textDisabled,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? semantic.info : palette.textDisabled,
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
    final data = <String, dynamic>{};
    final profileData = <String, dynamic>{};

    data['date'] = _apiDate(_selectedMetricDate);

    double? nextHeightCm = currentMetric?.heightCm;
    if (_heightTouched) {
      final rawHeight = _parseDouble(_heightController.text);
      if (rawHeight == null) {
        _showValidationMessage(
          AppLocalizations.of(context)!.validHeightRequired,
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
            AppLocalizations.of(context)!.validWeightRequired,
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
    } else if (currentMetric?.weightKg != null) {
      data['weight_kg'] = currentMetric!.weightKg;
    }

    if (_sleepTouched) {
      final sleepHours = _parseDouble(_sleepController.text);
      if (sleepHours == null) {
        _showValidationMessage(
          AppLocalizations.of(context)!.validSleepRequired,
        );
        return;
      }
      data['sleep_hours'] = sleepHours;
    } else if (currentMetric?.sleepHours != null) {
      data['sleep_hours'] = currentMetric!.sleepHours;
    }

    if (_muscleMassTouched) {
      final rawMuscleMass = _muscleMassController.text.trim();
      if (rawMuscleMass.isNotEmpty) {
        final muscleMass = _parseDouble(rawMuscleMass);
        if (muscleMass == null) {
          _showValidationMessage(
            AppLocalizations.of(context)!.validMuscleMassRequired,
          );
          return;
        }
        data['muscle_mass_kg'] = UnitConverters.weightFromDisplay(
          muscleMass,
          unitSystem,
        );
      }
    } else if (currentMetric?.muscleMassKg != null) {
      data['muscle_mass_kg'] = currentMetric!.muscleMassKg;
    }

    final existingMeasures = <String, double?>{
      'Cuello': currentMetric?.neckCm,
      'Hombros': currentMetric?.shouldersCm,
      'Pecho': currentMetric?.chestCm,
      'Brazo': currentMetric?.armCm,
      'Antebrazo': currentMetric?.forearmCm,
      'Cintura': currentMetric?.waistCm,
      'Caderas': currentMetric?.hipsCm,
      'Muslo': currentMetric?.thighCm,
      'Pantorrilla': currentMetric?.calfCm,
    };

    for (final entry in _measureControllers.entries) {
      if (!_touchedMeasures.contains(entry.key)) {
        final existingValue = existingMeasures[entry.key];
        if (existingValue != null) {
          data[_measureKeys[entry.key]!] = existingValue;
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
          AppLocalizations.of(context)!.measurementReviewTemplate(entry.key.toLowerCase()),
        );
        return;
      }

      data[_measureKeys[entry.key]!] = UnitConverters.lengthFromDisplay(
        parsedValue,
        unitSystem,
      );
    }

    if (data.isEmpty) {
      _showValidationMessage(
        AppLocalizations.of(context)!.noChangesMessage,
      );
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
      text: _measureControllers['Pantorrilla']?.text ?? '',
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
                AppLocalizations.of(context)!.quickSeenEstimate,
                style: TextStyle(color: palette.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.seenFormulaDescription,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: palette.textPrimary),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.ageLabel,
                        suffixText: AppLocalizations.of(context)!.yearsLabel,
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
                        labelText: AppLocalizations.of(context)!.heightSectionTitle,
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
                        labelText: AppLocalizations.of(context)!.calfLabel,
                        suffixText: lengthUnitSymbol(unitSystem),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SeenBiologicalSex>(
                      initialValue: selectedSex,
                      dropdownColor: palette.surfaceVariant,
                      style: TextStyle(color: palette.textPrimary),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.sexLabel,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: SeenBiologicalSex.male,
                          child: Text(AppLocalizations.of(context)!.maleOption),
                        ),
                        DropdownMenuItem(
                          value: SeenBiologicalSex.female,
                          child: Text(AppLocalizations.of(context)!.femaleOption),
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
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final age = int.tryParse(ageController.text.trim());
                    final heightValue = _parseDouble(heightController.text);
                    final calfValue = _parseDouble(calfController.text);

                    if (age == null || age <= 0) {
                      setDialogState(() {
                        errorText = AppLocalizations.of(context)!.invalidAgeError;
                      });
                      return;
                    }

                    if (heightValue == null || heightValue <= 0) {
                      setDialogState(() {
                        errorText = AppLocalizations.of(context)!.invalidHeightError;
                      });
                      return;
                    }

                    if (calfValue == null || calfValue <= 0) {
                      setDialogState(() {
                        errorText = AppLocalizations.of(context)!.invalidCalfError;
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

                    if (selectedSex == null) {
                      setDialogState(() {
                        errorText = AppLocalizations.of(context)!.selectSexError;
                      });
                      return;
                    }

                    final result = estimateSeenMuscleMass(
                      calfCm: calfCm,
                      ageYears: age,
                      heightMeters: heightCm / 100,
                      sex: selectedSex!,
                    );

                    if (result == null) {
                      setDialogState(() {
                        errorText = AppLocalizations.of(context)!.estimationFailedError;
                      });
                      return;
                    }

                    _measureControllers['Pantorrilla']?.text =
                        formatLengthValue(calfCm, unitSystem);
                    _heightController.text = formatLengthValue(
                      heightCm,
                      unitSystem,
                    );
                    _heightTouched = true;
                    _muscleMassTouched = true;
                    _touchedMeasures.add('Pantorrilla');
                    Navigator.of(dialogContext).pop(result);
                  },
                  child: Text(
                    AppLocalizations.of(context)!.calculateAndUseButton,
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

    final seenMsg =
        'SEEN estimate applied: ${formatWeight(estimate.estimatedAsmKg, unitSystem)} (ASMI ${estimate.estimatedAsmiKgPerM2.toStringAsFixed(2)} kg/m²)';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(seenMsg),
        behavior: SnackBarBehavior.floating,
      ),
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
      if (metric.weightKg != null) {
        _weight = metric.weightKg!.clamp(40.0, 160.0);
      }
      if (metric.sleepHours != null) {
        _sleepHours = metric.sleepHours!.clamp(4.0, 12.0);
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
    _sleepController.text = metric.sleepHours != null
        ? metric.sleepHours!.toStringAsFixed(1)
        : '';
    if (metric.muscleMassKg != null) {
      _muscleMassController.text = formatWeightValue(
        metric.muscleMassKg,
        unitSystem,
      );
    } else {
      _muscleMassController.clear();
    }
    final map = {
      'Cuello': metric.neckCm,
      'Hombros': metric.shouldersCm,
      'Pecho': metric.chestCm,
      'Brazo': metric.armCm,
      'Antebrazo': metric.forearmCm,
      'Cintura': metric.waistCm,
      'Caderas': metric.hipsCm,
      'Muslo': metric.thighCm,
      'Pantorrilla': metric.calfCm,
    };
    for (final entry in map.entries) {
      if (entry.value != null) {
        _measureControllers[entry.key]?.text = formatLengthValue(
          entry.value,
          unitSystem,
        );
      } else {
        _measureControllers[entry.key]?.clear();
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
          if (state.current != null) {
            _populateFromMetric(state.current!);
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
                  Text(
                    AppLocalizations.of(context)!.metricsSuccessMessage,
                  ),
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
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.metricsPageTitle),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
        ),
        body: BlocBuilder<MetricsBloc, MetricsState>(
          builder: (context, state) {
            final isSaving = state is MetricsSaving;
            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    _SectionCard(
                      title: AppLocalizations.of(context)!.recordDateTitle,
                      icon: Icons.calendar_today_outlined,
                      color: palette.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.recordDateDescription,
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
                      title: AppLocalizations.of(context)!.heightSectionTitle,
                      icon: Icons.height,
                      color: semantic.info,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.heightDescription,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(
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
                      title: AppLocalizations.of(context)!.weightSectionTitle,
                      icon: Icons.monitor_weight_outlined,
                      color: palette.primary,
                      child: Column(
                        children: [
                          // Toggle manual/slider
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.manualEntryToggle,
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
                            AppLocalizations.of(context)!.weightUpdateNote,
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      title: AppLocalizations.of(context)!.muscleMassSectionTitle,
                      icon: Icons.fitness_center,
                      color: semantic.calorie,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.muscleMassDescription,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _muscleMassController,
                            keyboardType: const TextInputType.numberWithOptions(
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
                            decoration: BoxDecoration(
                              color: palette.surfaceVariant,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: palette.borderSoft),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.seenCalculatorTitle,
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  AppLocalizations.of(context)!.seenCalculatorDescription,
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _openSeenEstimateCalculator(context),
                                    icon: const Icon(Icons.calculate_outlined),
                                    label: Text(
                                      AppLocalizations.of(context)!.calculateEstimateButton,
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
                      title: AppLocalizations.of(context)!.sleepHoursSectionTitle,
                      icon: Icons.bedtime_outlined,
                      color: semantic.sleep,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.sleepHoursDescription,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _sleepController,
                            keyboardType: const TextInputType.numberWithOptions(
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
                      title: AppLocalizations.of(context)!.bodyMeasurementsTitle,
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
                                  ? AppLocalizations.of(context)!.listViewToggle
                                  : AppLocalizations.of(context)!.bodyViewToggle,
                              style: TextStyle(
                                color: semantic.info,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      child: _bodyMapMode
                          ? _buildBodyMapMeasurements()
                          : Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 2.0,
                                    ),
                                itemCount: _measureControllers.length,
                                itemBuilder: (context, index) {
                                  final key = _measureControllers.keys
                                      .elementAt(index);
                                  return _MeasureInput(
                                    label: key,
                                    controller: _measureControllers[key]!,
                                    onChanged: (_) => _touchedMeasures.add(key),
                                  );
                                },
                              ),
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      border: Border(top: BorderSide(color: palette.divider)),
                    ),
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
                              AppLocalizations.of(context)!.saveMetricsButton,
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
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

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
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

class _SleepEmoji extends StatelessWidget {
  final double hours;

  const _SleepEmoji(this.hours);

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final String emoji;
    final String label;
    if (hours < 6) {
      emoji = '😴';
      label = 'Muy poco sueño';
    } else if (hours < 7) {
      emoji = '😕';
      label = 'Sueño insuficiente';
    } else if (hours <= 9) {
      emoji = '😊';
      label = 'Sueño óptimo';
    } else {
      emoji = '😪';
      label = 'Demasiado sueño';
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
