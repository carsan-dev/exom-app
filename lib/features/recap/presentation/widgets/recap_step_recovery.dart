import 'package:flutter/material.dart';

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
            title: 'Descanso y recuperación',
            subtitle: 'Evalúa cómo ha respondido tu cuerpo esta semana.',
            icon: Icons.hotel_outlined,
            child: Column(
              children: [
                RecapChoiceChipsField(
                  label: 'Horas de sueño',
                  helperText: 'Selecciona el rango que más se repitió.',
                  value: formData['sleep_hours_range'] as String?,
                  options: const ['MENOS_5', 'ENTRE_5_6', 'ENTRE_6_7', 'MAS_8'],
                  onSelected: (value) => onChanged('sleep_hours_range', value),
                ),
                const SizedBox(height: 20),
                RecapChoiceChipsField(
                  label: 'Nivel de fatiga',
                  helperText: 'Cómo te sentiste en energía general.',
                  value: formData['fatigue_level'] as String?,
                  options: const ['CANSADO', 'NORMAL', 'BIEN', 'FUERTE'],
                  onSelected: (value) => onChanged('fatigue_level', value),
                ),
              ],
            ),
          ),
          RecapSectionCard(
            title: 'Molestias o cargas',
            subtitle: 'Toca las zonas que has sentido más cargadas.',
            icon: Icons.accessibility_new,
            child: Column(
              children: [
                RecapBodyMapField(
                  label: 'Zonas con dolor o tensión',
                  helperText: 'Pulsa sobre las zonas del cuerpo afectadas.',
                  values: musclePainZones,
                  onChanged: (value) => onChanged('muscle_pain_zones', value),
                ),
                if (musclePainZones.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  RecapChoiceChipsField(
                    label: 'Intensidad del dolor',
                    helperText: 'Nivel general de las molestias percibidas.',
                    value: formData['pain_intensity'] as String?,
                    options: const ['LEVE', 'MODERADO', 'ALTO', 'MUY_ALTO'],
                    onSelected: (value) =>
                        onChanged('pain_intensity', value),
                  ),
                ],
              ],
            ),
          ),
          RecapSectionCard(
            title: 'Notas de recuperación',
            subtitle: 'Añade lo que creas importante para ajustar el plan.',
            icon: Icons.self_improvement,
            child: RecapTextAreaField(
              label: 'Observaciones',
              hintText:
                  'Ej: arrastro tensión lumbar o he dormido mejor desde que bajó el volumen de carga.',
              initialValue: formData['recovery_notes'] as String? ?? '',
              onChanged: (value) => onChanged('recovery_notes', value),
            ),
          ),
        ],
      ),
    );
  }
}
