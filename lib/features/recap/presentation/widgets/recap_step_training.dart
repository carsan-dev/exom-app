import 'package:flutter/material.dart';

import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';

class RecapStepTraining extends StatelessWidget {
  final Map<String, dynamic> formData;
  final void Function(String field, dynamic value) onChanged;

  const RecapStepTraining({
    super.key,
    required this.formData,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final trainingEffort =
        (formData['training_effort'] as num?)?.toDouble() ?? 3;
    final trainingSessions =
        (formData['training_sessions'] as num?)?.toDouble() ?? 3;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          RecapSectionCard(
            title: 'Carga y sensaciones',
            subtitle: 'Cuéntanos cómo te has sentido entrenando esta semana.',
            icon: Icons.fitness_center,
            child: Column(
              children: [
                RecapSliderField(
                  label: 'Esfuerzo general',
                  helperText: 'Del 0 al 5, valora cuánto te exigió el plan.',
                  value: trainingEffort,
                  min: 0,
                  max: 5,
                  divisions: 5,
                  valueLabelBuilder: _effortLabel,
                  onChanged: (value) =>
                      onChanged('training_effort', value.round()),
                ),
                const SizedBox(height: 20),
                RecapSliderField(
                  label: 'Sesiones completadas',
                  helperText: 'Indica cuántas sesiones útiles completaste.',
                  value: trainingSessions,
                  min: 0,
                  max: 5,
                  divisions: 5,
                  valueLabelBuilder: (value) => '${value.round()} sesiones',
                  onChanged: (value) =>
                      onChanged('training_sessions', value.round()),
                ),
              ],
            ),
          ),
          RecapSectionCard(
            title: 'Progreso percibido',
            subtitle: 'Selecciona la evolución que mejor refleje tu semana.',
            icon: Icons.trending_up,
            child: RecapChoiceChipsField(
              label: 'Percepción de progreso',
              helperText: 'Tu sensación general sobre la evolución del plan.',
              value: formData['training_progress'] as String?,
              options: const [
                'NADA',
                'POCO',
                'ESTABLE',
                'MEJORANDO',
                'EXCELENTE',
              ],
              onSelected: (value) => onChanged('training_progress', value),
            ),
          ),
          RecapSectionCard(
            title: 'Notas de entreno',
            subtitle:
                'Añade contexto para que el coach revise mejor tu semana.',
            icon: Icons.notes,
            child: RecapTextAreaField(
              label: 'Observaciones',
              hintText:
                  'Ej: me costó mantener el ritmo el jueves o noté mejor técnica en sentadilla.',
              initialValue: formData['training_notes'] as String? ?? '',
              onChanged: (value) => onChanged('training_notes', value),
            ),
          ),
        ],
      ),
    );
  }

  String _effortLabel(double value) {
    switch (value.round()) {
      case 0:
        return 'Muy suave';
      case 1:
        return 'Bajo';
      case 2:
        return 'Ligero';
      case 3:
        return 'Medio';
      case 4:
        return 'Alto';
      case 5:
        return 'Muy alto';
      default:
        return value.round().toString();
    }
  }
}
