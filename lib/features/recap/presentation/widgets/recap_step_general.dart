import 'package:flutter/material.dart';

import 'package:exom_app/core/i18n/context_copy.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';

class RecapStepGeneral extends StatelessWidget {
  final Map<String, dynamic> formData;
  final void Function(String field, dynamic value) onChanged;

  const RecapStepGeneral({
    super.key,
    required this.formData,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final stressEnabled = formData['stress_enabled'] as bool? ?? false;
    final stressLevel = (formData['stress_level'] as num?)?.toInt() ?? 2;
    final appRating =
        (formData['improvement_app_rating'] as num?)?.toInt() ?? 4;
    final serviceRating =
        (formData['improvement_service_rating'] as num?)?.toInt() ?? 4;
    final improvementAreas =
        (formData['improvement_areas'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];
    final palette = context.exomPalette;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          RecapSectionCard(
            title: context.copy('Estado general', 'General state'),
            subtitle: context.copy(
              'Tu contexto mental y emocional también cuenta.',
              'Your mental and emotional context also matters.',
            ),
            icon: Icons.mood,
            child: Column(
              children: [
                RecapChoiceChipsField(
                  label: context.copy('Ánimo predominante', 'Main mood'),
                  helperText: context.copy(
                    'Cómo te has sentido la mayor parte de la semana.',
                    'How you felt most of the week.',
                  ),
                  value: formData['mood'] as String?,
                  options: const [
                    'MAL',
                    'REGULAR',
                    'NORMAL',
                    'BIEN',
                    'MUY_BIEN',
                  ],
                  onSelected: (value) => onChanged('mood', value),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  value: stressEnabled,
                  onChanged: (value) {
                    onChanged('stress_enabled', value);
                    if (!value) {
                      onChanged('stress_level', null);
                    }
                  },
                  activeThumbColor: palette.primary,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    context.copy(
                      'Valorar nivel de estrés',
                      'Rate stress level',
                    ),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    context.copy(
                      'Actívalo si quieres reportar la presión o carga de la semana.',
                      'Enable it if you want to report the pressure or load of the week.',
                    ),
                    style: TextStyle(color: palette.textDisabled),
                  ),
                ),
                if (stressEnabled) ...[
                  const SizedBox(height: 8),
                  RecapEmojiRatingField(
                    label: context.copy('Estrés percibido', 'Perceived stress'),
                    helperText: context.copy(
                      '¿Cuánto estrés has sentido esta semana?',
                      'How much stress did you feel this week?',
                    ),
                    value: stressLevel.clamp(0, 4),
                    onChanged: (value) => onChanged('stress_level', value),
                  ),
                ],
              ],
            ),
          ),
          RecapSectionCard(
            title: context.copy(
              'Feedback sobre el servicio',
              'Service feedback',
            ),
            subtitle: context.copy(
              'Ayuda a mejorar la experiencia y el acompañamiento.',
              'Help improve the experience and support.',
            ),
            icon: Icons.rate_review_outlined,
            child: Column(
              children: [
                RecapStarRatingField(
                  label: context.copy('Valora la app', 'Rate the app'),
                  helperText: context.copy(
                    'Tu experiencia general con la aplicación.',
                    'Your overall experience with the app.',
                  ),
                  value: appRating.round().clamp(1, 5),
                  onChanged: (value) =>
                      onChanged('improvement_app_rating', value),
                ),
                const SizedBox(height: 20),
                RecapStarRatingField(
                  label: context.copy('Valora el servicio', 'Rate the service'),
                  helperText: context.copy(
                    'Cómo percibes el soporte recibido esta semana.',
                    'How you rate the support received this week.',
                  ),
                  value: serviceRating.round().clamp(1, 5),
                  onChanged: (value) =>
                      onChanged('improvement_service_rating', value),
                ),
                const SizedBox(height: 20),
                RecapMultiSelectField(
                  label: context.copy('Áreas a mejorar', 'Areas to improve'),
                  helperText: context.copy(
                    'Selecciona los puntos donde quieres más apoyo.',
                    'Select the points where you want more support.',
                  ),
                  values: improvementAreas,
                  options: const [
                    'ENTRENAMIENTO',
                    'NUTRICION',
                    'ADHERENCIA',
                    'RECUPERACION',
                    'MOTIVACION',
                    'APP',
                  ],
                  onChanged: (value) => onChanged('improvement_areas', value),
                ),
              ],
            ),
          ),
          RecapSectionCard(
            title: context.copy('Comentarios finales', 'Final comments'),
            subtitle: context.copy(
              'Cierra la semana con lo más relevante para tu coach.',
              'Close the week with what matters most for your coach.',
            ),
            icon: Icons.chat_bubble_outline,
            child: Column(
              children: [
                RecapTextAreaField(
                  label: context.copy('Notas generales', 'General notes'),
                  hintText: context.copy(
                    'Comparte cualquier detalle relevante de tu semana.',
                    'Share any relevant detail from your week.',
                  ),
                  initialValue: formData['general_notes'] as String? ?? '',
                  onChanged: (value) => onChanged('general_notes', value),
                ),
                const SizedBox(height: 18),
                RecapTextAreaField(
                  label: context.copy(
                    'Sugerencias o mejoras',
                    'Suggestions or improvements',
                  ),
                  hintText: context.copy(
                    'Ej: me gustaría más contexto en las sesiones o una mejor guía para el fin de semana.',
                    'Eg: I would like more context in the sessions or better guidance for the weekend.',
                  ),
                  initialValue:
                      formData['improvement_feedback_text'] as String? ?? '',
                  onChanged: (value) =>
                      onChanged('improvement_feedback_text', value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
