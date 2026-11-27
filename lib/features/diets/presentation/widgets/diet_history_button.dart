import 'package:flutter/material.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/services/ingredient_unit_formatter.dart';
import 'package:exom_app/l10n/app_localizations.dart';

/// Opens the read-only diet history (entry «02» of the Nutrición index).
///
/// One read per opening ([load] runs once here); rebuilds of the dialog repeat
/// no request and no command.
Future<void> showDietHistory(
  BuildContext context, {
  required Future<DietHistory> Function() load,
}) {
  final l10n = AppLocalizations.of(context);
  final future = load();
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.dietHistoryTitle),
      content: SizedBox(
        width: 500,
        height: 440,
        child: FutureBuilder<DietHistory>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text(l10n.dietHistoryLoadError);
            final history = snapshot.data;
            if (history == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return _DietHistoryContent(history: history);
          },
        ),
      ),
    ),
  );
}

class _DietHistoryContent extends StatelessWidget {
  final DietHistory history;

  const _DietHistoryContent({required this.history});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatter = IngredientUnitFormatter(
      locale: Localizations.localeOf(context).toString(),
    );
    return ListView(
      children: [
        Text(l10n.dietHistoryReadOnly),
        if (history.entries.isEmpty) Text(l10n.dietHistoryEmpty),
        if (history.unresolvedMealIds.isNotEmpty) ...[
          Text(l10n.dietHistoryMissing),
          Text(
            history.unresolvedMealIds.join(', '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        for (final entry in history.entries)
          ExpansionTile(
            title: Text(entry.diet.name),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.legacyAvailable) Text(l10n.dietHistoryLegacy),
              Text(
                '${entry.diet.totalCalories ?? '—'} kcal · P ${entry.diet.totalProteinG ?? '—'} g · C ${entry.diet.totalCarbsG ?? '—'} g · G ${entry.diet.totalFatG ?? '—'} g',
              ),
              for (final meal in entry.diet.meals.expand(
                (meal) => [meal, ...meal.variants],
              )) ...[
                const SizedBox(height: 12),
                Text(meal.name, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '${meal.calories ?? '—'} kcal · P ${meal.proteinG ?? '—'} g · C ${meal.carbsG ?? '—'} g · G ${meal.fatG ?? '—'} g',
                ),
                for (final item in meal.ingredients)
                  Text(
                    '${item.name}: ${formatter.amount(quantityValue: item.quantity, unitCode: item.unit, gramsEquivalent: item.gramsEquivalent)}',
                  ),
              ],
            ],
          ),
      ],
    );
  }
}
