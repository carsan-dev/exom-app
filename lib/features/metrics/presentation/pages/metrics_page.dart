import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/body_silhouette_painter.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/presentation/bloc/metrics_bloc.dart';

class MetricsPage extends StatelessWidget {
  const MetricsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MetricsBloc>()..add(const MetricsLoadRequested()),
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
  final _weightController = TextEditingController();
  final _muscleMassController = TextEditingController();
  double _sleepHours = 8.0;

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
  void dispose() {
    _weightController.dispose();
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

  Widget _buildBodyMapMeasurements() {
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
                            painter: BodySilhouettePainter(isBack: !_bodyFront),
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
                                        ? AppColors.secondary
                                        : AppColors.secondary.withValues(
                                            alpha: 0.3,
                                          ),
                                    border: Border.all(
                                      color: AppColors.secondary,
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
          ),
        ],
      ],
    );
  }

  Widget _buildZoneColumn(
    List<String> zones,
    List<int> flex,
    CrossAxisAlignment align,
  ) {
    final children = <Widget>[];
    for (var i = 0; i < zones.length; i++) {
      if (i == 0 && flex[i] > 1) {
        children.add(Spacer(flex: flex[i]));
      } else if (i > 0) {
        children.add(Spacer(flex: flex[i] - flex[i - 1]));
      }
      children.add(_zoneLabel(zones[i]));
    }
    children.add(Spacer(flex: 10 - flex.last));

    return Column(crossAxisAlignment: align, children: children);
  }

  Widget _zoneLabel(String zone) {
    final val = _measureControllers[zone]?.text ?? '';
    final isSelected = _selectedMeasure == zone;

    return GestureDetector(
      onTap: () => setState(() => _selectedMeasure = zone),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppColors.secondary.withValues(alpha: 0.4))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              zone,
              style: TextStyle(
                color: isSelected
                    ? AppColors.secondary
                    : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (val.isNotEmpty)
              Text(
                '$val cm',
                style: TextStyle(
                  color: isSelected
                      ? AppColors.secondary
                      : AppColors.textDisabled,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.secondary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.secondary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? AppColors.secondary : AppColors.textDisabled,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.secondary : AppColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final double finalWeight = _useManualWeight
        ? double.tryParse(_weightController.text) ?? _weight
        : _weight;

    final data = <String, dynamic>{
      'weight_kg': finalWeight,
      'sleep_hours': _sleepHours,
    };

    final muscleMass = double.tryParse(_muscleMassController.text);
    if (muscleMass != null) {
      data['muscle_mass_kg'] = muscleMass;
    }

    for (final entry in _measureControllers.entries) {
      final val = double.tryParse(entry.value.text);
      if (val != null) {
        data[_measureKeys[entry.key]!] = val;
      }
    }

    context.read<MetricsBloc>().add(MetricsSaveRequested(data));
  }

  void _populateFromMetric(BodyMetricEntity metric) {
    setState(() {
      if (metric.weightKg != null) {
        _weight = metric.weightKg!.clamp(40.0, 160.0);
      }
      if (metric.sleepHours != null) {
        _sleepHours = metric.sleepHours!.clamp(4.0, 12.0);
      }
    });
    if (metric.muscleMassKg != null) {
      _muscleMassController.text = metric.muscleMassKg!.toStringAsFixed(1);
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
        _measureControllers[entry.key]?.text = entry.value!.toStringAsFixed(1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MetricsBloc, MetricsState>(
      listener: (context, state) {
        if (state is MetricsLoaded && state.current != null) {
          _populateFromMetric(state.current!);
        }
        if (state is MetricsSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Métricas guardadas correctamente'),
                ],
              ),
              backgroundColor: AppColors.success,
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
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Actualizar Métricas'),
          backgroundColor: AppColors.background,
        ),
        body: BlocBuilder<MetricsBloc, MetricsState>(
          builder: (context, state) {
            final isSaving = state is MetricsSaving;
            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    // Weight section
                    _SectionCard(
                      title: 'Peso',
                      icon: Icons.monitor_weight_outlined,
                      color: AppColors.primary,
                      child: Column(
                        children: [
                          // Toggle manual/slider
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Entrada manual',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              Switch(
                                value: _useManualWeight,
                                onChanged: (val) =>
                                    setState(() => _useManualWeight = val),
                                activeColor: AppColors.primary,
                              ),
                            ],
                          ),
                          if (_useManualWeight)
                            TextFormField(
                              controller: _weightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Ej: 75.5',
                                suffixText: 'kg',
                                suffixStyle: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          else ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '60 kg',
                                  style: TextStyle(
                                    color: AppColors.textDisabled,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  '${_weight.toStringAsFixed(1)} kg',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Text(
                                  '150 kg',
                                  style: TextStyle(
                                    color: AppColors.textDisabled,
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
                              activeColor: AppColors.primary,
                              inactiveColor: AppColors.surfaceVariant,
                              onChanged: (val) => setState(() => _weight = val),
                            ),
                          ],
                        ],
                      ),
                    ),

                    _SectionCard(
                      title: 'Masa muscular',
                      icon: Icons.fitness_center,
                      color: AppColors.calorieAccent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          const Text(
                            'Registra tu estimación actual para comparar tu evolución con el objetivo del perfil.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
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
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Ej: 32.5',
                              suffixText: 'kg',
                              suffixStyle: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sleep section
                    _SectionCard(
                      title: 'Horas de sueño',
                      icon: Icons.bedtime_outlined,
                      color: AppColors.sleepAccent,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '4h',
                                style: TextStyle(
                                  color: AppColors.textDisabled,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '${_sleepHours.toStringAsFixed(1)}h',
                                style: const TextStyle(
                                  color: AppColors.sleepAccent,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                '12h',
                                style: TextStyle(
                                  color: AppColors.textDisabled,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _sleepHours,
                            min: 4.0,
                            max: 12.0,
                            divisions: 16,
                            activeColor: AppColors.sleepAccent,
                            inactiveColor: AppColors.surfaceVariant,
                            onChanged: (val) =>
                                setState(() => _sleepHours = val),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [_SleepEmoji(_sleepHours)],
                          ),
                        ],
                      ),
                    ),

                    // Body measurements
                    _SectionCard(
                      title: 'Medidas corporales',
                      icon: Icons.straighten,
                      color: AppColors.secondary,
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
                              color: AppColors.secondary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _bodyMapMode ? 'Lista' : 'Cuerpo',
                              style: const TextStyle(
                                color: AppColors.secondary,
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
                      color: AppColors.surface,
                      border: const Border(
                        top: BorderSide(color: AppColors.divider),
                      ),
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
                          : const Text('Guardar métricas'),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
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

  const _MeasureInput({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: const InputDecoration(
            hintText: '0',
            suffixText: 'cm',
            suffixStyle: TextStyle(color: AppColors.textDisabled, fontSize: 12),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
