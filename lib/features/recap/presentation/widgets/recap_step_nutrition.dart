import 'package:flutter/material.dart';

import 'package:exom_app/core/i18n/context_copy.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';

class RecapStepNutrition extends StatelessWidget {
  final Map<String, dynamic> formData;
  final void Function(String field, dynamic value) onChanged;

  const RecapStepNutrition({
    super.key,
    required this.formData,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final foodQuality = (formData['food_quality'] as num?)?.toInt() ?? 2;
    final hydrationEnabled = formData['hydration_enabled'] as bool? ?? false;
    final palette = context.exomPalette;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          RecapSectionCard(
            title: context.copy('Calidad de la semana', 'Week quality'),
            subtitle: context.copy(
              'Valora cómo ha ido tu alimentación estos días.',
              'Rate how your nutrition went these days.',
            ),
            icon: Icons.restaurant_menu,
            child: Column(
              children: [
                RecapChoiceChipsField(
                  label: context.copy(
                    'Calidad nutricional',
                    'Nutrition quality',
                  ),
                  helperText: context.copy(
                    'Tu percepción general sobre la alimentación semanal.',
                    'Your overall perception of this week\'s nutrition.',
                  ),
                  value: formData['nutrition_quality'] as String?,
                  options: const ['BAJA', 'MODERADA', 'ALTA', 'MUY_ALTA'],
                  onSelected: (value) => onChanged('nutrition_quality', value),
                ),
                const SizedBox(height: 20),
                RecapEmojiRatingField(
                  label: context.copy('Calidad de comidas', 'Meal quality'),
                  helperText: context.copy(
                    '¿Cómo valoras tu alimentación esta semana?',
                    'How do you rate your nutrition this week?',
                  ),
                  value: foodQuality.clamp(0, 4),
                  onChanged: (value) => onChanged('food_quality', value),
                ),
              ],
            ),
          ),
          RecapSectionCard(
            title: context.copy('Hidratación', 'Hydration'),
            subtitle: context.copy(
              'Indica si has prestado atención a este aspecto.',
              'Tell us if you paid attention to this area.',
            ),
            icon: Icons.water_drop_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  value: hydrationEnabled,
                  onChanged: (value) {
                    onChanged('hydration_enabled', value);
                    if (!value) {
                      onChanged('hydration_level', null);
                    }
                  },
                  activeThumbColor: palette.primary,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    context.copy(
                      'Quiero valorar mi hidratación',
                      'I want to rate my hydration',
                    ),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    context.copy(
                      'Actívalo si quieres reportar cómo fue durante la semana.',
                      'Enable it if you want to report how it went during the week.',
                    ),
                    style: TextStyle(color: palette.textDisabled),
                  ),
                ),
                if (hydrationEnabled) ...[
                  const SizedBox(height: 8),
                  RecapChoiceChipsField(
                    label: context.copy(
                      'Nivel de hidratación',
                      'Hydration level',
                    ),
                    helperText: context.copy(
                      'Selecciona la opción que mejor encaje contigo.',
                      'Choose the option that fits you best.',
                    ),
                    value: formData['hydration_level'] as String?,
                    options: const ['MALA', 'REGULAR', 'BUENA', 'MUY_BUENA'],
                    onSelected: (value) => onChanged('hydration_level', value),
                  ),
                ],
              ],
            ),
          ),
          RecapSectionCard(
            title: context.copy('Notas de alimentación', 'Nutrition notes'),
            subtitle: context.copy(
              'Deja contexto para incidencias, antojos o dificultades.',
              'Add context for issues, cravings, or difficulties.',
            ),
            icon: Icons.edit_note,
            child: RecapTextAreaField(
              label: context.copy('Observaciones', 'Notes'),
              hintText: context.copy(
                'Ej: me costó organizar desayunos o he mantenido mejor la estructura los fines de semana.',
                'Eg: it was hard to organize breakfasts or I kept a better structure on weekends.',
              ),
              initialValue: formData['nutrition_notes'] as String? ?? '',
              onChanged: (value) => onChanged('nutrition_notes', value),
            ),
          ),
        ],
      ),
    );
  }
}
