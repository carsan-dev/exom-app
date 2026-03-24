import 'package:flutter/material.dart';

import 'package:exom_app/core/i18n/context_copy.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';

class RecapStepRecovery extends StatelessWidget {
  final Map<String, dynamic> formData;
  final void Function(String field, dynamic value) onChanged;

  const RecapStepRecovery({
    super.key,
    required this.formData,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final musclePainZones =
        (formData['muscle_pain_zones'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          RecapSectionCard(
            title: context.copy('Descanso y recuperación', 'Rest and recovery'),
            subtitle: context.copy(
              'Evalúa cómo ha respondido tu cuerpo esta semana.',
              'Rate how your body responded this week.',
            ),
            icon: Icons.hotel_outlined,
            child: Column(
              children: [
                RecapChoiceChipsField(
                  label: context.copy('Horas de sueño', 'Sleep hours'),
                  helperText: context.copy(
                    'Selecciona el rango que más se repitió.',
                    'Select the range that repeated the most.',
                  ),
                  value: formData['sleep_hours_range'] as String?,
                  options: const ['MENOS_5', 'ENTRE_5_6', 'ENTRE_6_7', 'MAS_8'],
                  onSelected: (value) => onChanged('sleep_hours_range', value),
                ),
                const SizedBox(height: 20),
                RecapChoiceChipsField(
                  label: context.copy('Nivel de fatiga', 'Fatigue level'),
                  helperText: context.copy(
                    'Cómo te sentiste en energía general.',
                    'How your overall energy felt.',
                  ),
                  value: formData['fatigue_level'] as String?,
                  options: const ['CANSADO', 'NORMAL', 'BIEN', 'FUERTE'],
                  onSelected: (value) => onChanged('fatigue_level', value),
                ),
              ],
            ),
          ),
          RecapSectionCard(
            title: context.copy(
              'Molestias o cargas',
              'Discomfort or tightness',
            ),
            subtitle: context.copy(
              'Toca las zonas que has sentido más cargadas.',
              'Tap the areas that felt the most loaded.',
            ),
            icon: Icons.accessibility_new,
            child: Column(
              children: [
                RecapBodyMapField(
                  label: context.copy(
                    'Zonas con dolor o tensión',
                    'Areas with pain or tension',
                  ),
                  helperText: context.copy(
                    'Pulsa sobre las zonas del cuerpo afectadas.',
                    'Tap the affected body areas.',
                  ),
                  values: musclePainZones,
                  onChanged: (value) => onChanged('muscle_pain_zones', value),
                ),
                if (musclePainZones.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  RecapChoiceChipsField(
                    label: context.copy(
                      'Intensidad del dolor',
                      'Pain intensity',
                    ),
                    helperText: context.copy(
                      'Nivel general de las molestias percibidas.',
                      'Overall level of discomfort felt.',
                    ),
                    value: formData['pain_intensity'] as String?,
                    options: const ['LEVE', 'MODERADO', 'ALTO', 'MUY_ALTO'],
                    onSelected: (value) => onChanged('pain_intensity', value),
                  ),
                ],
              ],
            ),
          ),
          RecapSectionCard(
            title: context.copy('Notas de recuperación', 'Recovery notes'),
            subtitle: context.copy(
              'Añade lo que creas importante para ajustar el plan.',
              'Add anything important to adjust the plan.',
            ),
            icon: Icons.self_improvement,
            child: RecapTextAreaField(
              label: context.copy('Observaciones', 'Notes'),
              hintText: context.copy(
                'Ej: arrastro tensión lumbar o he dormido mejor desde que bajó el volumen de carga.',
                'Eg: I still have lower-back tightness or I have slept better since the training volume dropped.',
              ),
              initialValue: formData['recovery_notes'] as String? ?? '',
              onChanged: (value) => onChanged('recovery_notes', value),
            ),
          ),
        ],
      ),
    );
  }
}
