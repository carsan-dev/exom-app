import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/injection_container.dart';
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
  final _weightController = TextEditingController();
  double _sleepHours = 8.0;

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
    for (final c in _measureControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final double finalWeight = _useManualWeight
        ? double.tryParse(_weightController.text) ?? _weight
        : _weight;

    final data = <String, dynamic>{
      'weight_kg': finalWeight,
      'sleep_hours': _sleepHours,
    };

    for (final entry in _measureControllers.entries) {
      final val = double.tryParse(entry.value.text);
      if (val != null) {
        data[_measureKeys[entry.key]!] = val;
      }
    }

    context.read<MetricsBloc>().add(MetricsSaveRequested(data));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MetricsBloc, MetricsState>(
      listener: (context, state) {
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                              Switch(
                                value: _useManualWeight,
                                onChanged: (val) => setState(() => _useManualWeight = val),
                                activeColor: AppColors.primary,
                              ),
                            ],
                          ),
                          if (_useManualWeight)
                            TextFormField(
                              controller: _weightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: const InputDecoration(
                                hintText: 'Ej: 75.5',
                                suffixText: 'kg',
                                suffixStyle: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          else ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('60 kg', style: TextStyle(color: AppColors.textDisabled, fontSize: 11)),
                                Text(
                                  '${_weight.toStringAsFixed(1)} kg',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Text('150 kg', style: TextStyle(color: AppColors.textDisabled, fontSize: 11)),
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
                              const Text('4h', style: TextStyle(color: AppColors.textDisabled, fontSize: 11)),
                              Text(
                                '${_sleepHours.toStringAsFixed(1)}h',
                                style: const TextStyle(
                                  color: AppColors.sleepAccent,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text('12h', style: TextStyle(color: AppColors.textDisabled, fontSize: 11)),
                            ],
                          ),
                          Slider(
                            value: _sleepHours,
                            min: 4.0,
                            max: 12.0,
                            divisions: 16,
                            activeColor: AppColors.sleepAccent,
                            inactiveColor: AppColors.surfaceVariant,
                            onChanged: (val) => setState(() => _sleepHours = val),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _SleepEmoji(_sleepHours),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Body measurements
                    _SectionCard(
                      title: 'Medidas corporales',
                      icon: Icons.straighten,
                      color: AppColors.secondary,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 2.0,
                          ),
                          itemCount: _measureControllers.length,
                          itemBuilder: (context, index) {
                            final key = _measureControllers.keys.elementAt(index);
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
                      border: const Border(top: BorderSide(color: AppColors.divider)),
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

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
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
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
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
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}
