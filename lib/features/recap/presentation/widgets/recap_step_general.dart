import 'package:flutter/material.dart';

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
    final stressLevel = (formData['stress_level'] as num?)?.toDouble() ?? 2;
    final appRating =
        (formData['improvement_app_rating'] as num?)?.toDouble() ?? 4;
    final serviceRating =
        (formData['improvement_service_rating'] as num?)?.toDouble() ?? 4;
    final improvementAreas =
        (formData['improvement_areas'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          RecapSectionCard(
            title: 'Estado general',
            subtitle: 'Tu contexto mental y emocional también cuenta.',
            icon: Icons.mood,
            child: Column(
              children: [
                RecapChoiceChipsField(
                  label: 'Ánimo predominante',
                  helperText:
                      'Cómo te has sentido la mayor parte de la semana.',
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
                  activeThumbColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Valorar nivel de estrés',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Actívalo si quieres reportar la presión o carga de la semana.',
                    style: TextStyle(color: AppColors.textDisabled),
                  ),
                ),
                if (stressEnabled) ...[
                  const SizedBox(height: 8),
                  RecapSliderField(
                    label: 'Estrés percibido',
                    helperText: '0 es muy bajo y 5 muy alto.',
                    value: stressLevel,
                    min: 0,
                    max: 5,
                    divisions: 5,
                    valueLabelBuilder: _stressLabel,
                    onChanged: (value) =>
                        onChanged('stress_level', value.round()),
                  ),
                ],
              ],
            ),
          ),
          RecapSectionCard(
            title: 'Feedback sobre el servicio',
            subtitle: 'Ayuda a mejorar la experiencia y el acompañamiento.',
            icon: Icons.rate_review_outlined,
            child: Column(
              children: [
                RecapSliderField(
                  label: 'Valoración de la app',
                  helperText: '1 es baja y 5 excelente.',
                  value: appRating,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  valueLabelBuilder: (value) => '${value.round()}/5',
                  onChanged: (value) =>
                      onChanged('improvement_app_rating', value.round()),
                ),
                const SizedBox(height: 20),
                RecapSliderField(
                  label: 'Valoración del servicio',
                  helperText: 'Cómo percibes el soporte recibido esta semana.',
                  value: serviceRating,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  valueLabelBuilder: (value) => '${value.round()}/5',
                  onChanged: (value) =>
                      onChanged('improvement_service_rating', value.round()),
                ),
                const SizedBox(height: 20),
                RecapMultiSelectField(
                  label: 'Áreas a mejorar',
                  helperText: 'Selecciona los puntos donde quieres más apoyo.',
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
            title: 'Comentarios finales',
            subtitle: 'Cierra la semana con lo más relevante para tu coach.',
            icon: Icons.chat_bubble_outline,
            child: Column(
              children: [
                RecapTextAreaField(
                  label: 'Notas generales',
                  hintText:
                      'Comparte cualquier detalle relevante de tu semana.',
                  initialValue: formData['general_notes'] as String? ?? '',
                  onChanged: (value) => onChanged('general_notes', value),
                ),
                const SizedBox(height: 18),
                RecapTextAreaField(
                  label: 'Sugerencias o mejoras',
                  hintText:
                      'Ej: me gustaría más contexto en las sesiones o una mejor guía para el fin de semana.',
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

  String _stressLabel(double value) {
    switch (value.round()) {
      case 0:
        return 'Muy bajo';
      case 1:
        return 'Bajo';
      case 2:
        return 'Controlado';
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
