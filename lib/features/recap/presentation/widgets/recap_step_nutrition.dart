import 'package:flutter/material.dart';

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
            title: 'Calidad de la semana',
            subtitle: 'Valora cómo ha ido tu alimentación estos días.',
            icon: Icons.restaurant_menu,
            child: Column(
              children: [
                RecapChoiceChipsField(
                  label: 'Calidad nutricional',
                  helperText:
                      'Tu percepción general sobre la alimentación semanal.',
                  value: formData['nutrition_quality'] as String?,
                  options: const ['BAJA', 'MODERADA', 'ALTA', 'MUY_ALTA'],
                  onSelected: (value) => onChanged('nutrition_quality', value),
                ),
                const SizedBox(height: 20),
                RecapEmojiRatingField(
                  label: 'Calidad de comidas',
                  helperText: '¿Cómo valoras tu alimentación esta semana?',
                  value: foodQuality.clamp(0, 4),
                  onChanged: (value) => onChanged('food_quality', value),
                ),
              ],
            ),
          ),
          RecapSectionCard(
            title: 'Hidratación',
            subtitle: 'Indica si has prestado atención a este aspecto.',
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
                    'Quiero valorar mi hidratación',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Actívalo si quieres reportar cómo fue durante la semana.',
                    style: TextStyle(color: palette.textDisabled),
                  ),
                ),
                if (hydrationEnabled) ...[
                  const SizedBox(height: 8),
                  RecapChoiceChipsField(
                    label: 'Nivel de hidratación',
                    helperText:
                        'Selecciona la opción que mejor encaje contigo.',
                    value: formData['hydration_level'] as String?,
                    options: const ['MALA', 'REGULAR', 'BUENA', 'MUY_BUENA'],
                    onSelected: (value) => onChanged('hydration_level', value),
                  ),
                ],
              ],
            ),
          ),
          RecapSectionCard(
            title: 'Notas de alimentación',
            subtitle: 'Deja contexto para incidencias, antojos o dificultades.',
            icon: Icons.edit_note,
            child: RecapTextAreaField(
              label: 'Observaciones',
              hintText:
                  'Ej: me costó organizar desayunos o he mantenido mejor la estructura los fines de semana.',
              initialValue: formData['nutrition_notes'] as String? ?? '',
              onChanged: (value) => onChanged('nutrition_notes', value),
            ),
          ),
        ],
      ),
    );
  }
}
