import 'package:flutter/material.dart';

import 'package:exom_app/core/i18n/context_copy.dart';
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
    final trainingEffort = (formData['training_effort'] as num?)?.toInt() ?? 2;
    final trainingSessions =
        (formData['training_sessions'] as num?)?.toInt() ?? 2;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          RecapSectionCard(
            title: context.copy('Carga y sensaciones', 'Load and feelings'),
            subtitle: context.copy(
              'Cuéntanos cómo te has sentido entrenando esta semana.',
              'Tell us how you felt training this week.',
            ),
            icon: Icons.fitness_center,
            child: Column(
              children: [
                RecapEmojiRatingField(
                  label: context.copy('Esfuerzo general', 'Overall effort'),
                  helperText: context.copy(
                    '¿Cómo te has sentido con la carga de entrenos?',
                    'How did you feel with the training load?',
                  ),
                  value: trainingEffort.round().clamp(0, 4),
                  onChanged: (value) => onChanged('training_effort', value),
                ),
                const SizedBox(height: 20),
                RecapEmojiRatingField(
                  label: context.copy(
                    'Sesiones completadas',
                    'Completed sessions',
                  ),
                  helperText: context.copy(
                    '¿Cómo valoras el número de sesiones?',
                    'How do you rate the number of sessions?',
                  ),
                  value: trainingSessions.round().clamp(0, 4),
                  onChanged: (value) => onChanged('training_sessions', value),
                ),
              ],
            ),
          ),
          RecapSectionCard(
            title: context.copy('Progreso percibido', 'Perceived progress'),
            subtitle: context.copy(
              'Selecciona la evolución que mejor refleje tu semana.',
              'Choose the progress that best reflects your week.',
            ),
            icon: Icons.trending_up,
            child: RecapChoiceChipsField(
              label: context.copy(
                'Percepción de progreso',
                'Progress perception',
              ),
              helperText: context.copy(
                'Tu sensación general sobre la evolución del plan.',
                'Your overall feeling about the plan progress.',
              ),
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
            title: context.copy('Notas de entreno', 'Training notes'),
            subtitle: context.copy(
              'Añade contexto para que el coach revise mejor tu semana.',
              'Add context so your coach can review your week better.',
            ),
            icon: Icons.notes,
            child: RecapTextAreaField(
              label: context.copy('Observaciones', 'Notes'),
              hintText: context.copy(
                'Ej: me costó mantener el ritmo el jueves o noté mejor técnica en sentadilla.',
                'Eg: it was hard to keep the pace on Thursday or I noticed better squat technique.',
              ),
              initialValue: formData['training_notes'] as String? ?? '',
              onChanged: (value) => onChanged('training_notes', value),
            ),
          ),
        ],
      ),
    );
  }
}
