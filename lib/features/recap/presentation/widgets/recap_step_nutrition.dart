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
    final foodQuality = (formData['food_quality'] as num?)?.toDouble() ?? 3;
    final hydrationEnabled = formData['hydration_enabled'] as bool? ?? false;

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
                RecapSliderField(
                  label: 'Calidad de comidas',
                  helperText: 'Del 0 al 5, puntúa adherencia y sensación.',
                  value: foodQuality,
                  min: 0,
                  max: 5,
                  divisions: 5,
                  valueLabelBuilder: _qualityLabel,
                  onChanged: (value) =>
                      onChanged('food_quality', value.round()),
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
                  activeThumbColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Quiero valorar mi hidratación',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Actívalo si quieres reportar cómo fue durante la semana.',
                    style: TextStyle(color: AppColors.textDisabled),
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

  String _qualityLabel(double value) {
    switch (value.round()) {
      case 0:
        return 'Muy baja';
      case 1:
        return 'Baja';
      case 2:
        return 'Irregular';
      case 3:
        return 'Correcta';
      case 4:
        return 'Buena';
      case 5:
        return 'Excelente';
      default:
        return value.round().toString();
    }
  }
}
