import 'dart:typed_data';

import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_export.dart';
import 'package:exom_app/features/diets/domain/usecases/get_weekly_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/utils/diet_export_period_utils.dart';
import 'package:exom_app/features/diets/services/weekly_diet_pdf_service.dart';
import 'package:exom_app/features/diets/services/weekly_shopping_list_builder.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

/// Shopping-list export steps shared by the calendar export and the Diets
/// screen: variant selection, PDF build and the print/share sheet.

enum PdfAction { print, share }

/// Variant selection + shopping-list PDF for [period]. Returns null when the
/// user dismisses the selector. [mealTypes] maps the upper-case meal type to
/// its label. With [skipSelectorWithoutVariants] the selector is not shown
/// when no meal of [period] has alternatives to choose from.
Future<({Uint8List bytes, String filename})?> buildWeeklyShoppingListPdf(
  BuildContext context, {
  required DietPeriodEntity period,
  required bool calendarMonth,
  required Map<String, String> mealTypes,
  bool skipSelectorWithoutVariants = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();
  final hasVariants = period.days.any(
    (day) => (day.diet?.meals ?? const <MealEntity>[]).any(
      (meal) => meal.variants.isNotEmpty,
    ),
  );
  final selections = skipSelectorWithoutVariants && !hasVariants
      ? const <WeeklyMealSelection>[]
      : await showModalBottomSheet<List<WeeklyMealSelection>>(
          context: context,
          isScrollControlled: true,
          builder: (sheetContext) => WeeklyVariantSelector(
            week: period,
            locale: locale,
            title: l10n.weeklyVariantSelectorTitle,
            mainLabel: l10n.weeklyVariantMain,
            generateLabel: l10n.weeklyGenerateShoppingList,
            mealTypes: mealTypes,
          ),
        );
  if (selections == null || !context.mounted) return null;
  final items = const WeeklyShoppingListBuilder().build(
    week: period,
    selections: selections,
    locale: locale,
  );
  final bytes = await GetIt.I<WeeklyDietPdfService>().buildShoppingList(
    week: period,
    items: items,
    locale: locale,
    labels: WeeklyShoppingListPdfLabels(
      title: calendarMonth
          ? l10n.monthlyShoppingListPdfTitle
          : l10n.weeklyShoppingListPdfTitle,
      empty: calendarMonth
          ? l10n.monthlyShoppingListEmpty
          : l10n.weeklyShoppingListEmpty,
    ),
  );
  final filename = dietExportFilename(
    shoppingList: true,
    start: period.start,
    end: period.end,
    calendarMonth: calendarMonth,
  );
  return (bytes: bytes, filename: filename);
}

/// Print / share sheet for a generated PDF.
Future<void> printOrSharePdf(
  BuildContext context, {
  required Uint8List bytes,
  required String filename,
}) async {
  final l10n = AppLocalizations.of(context);
  final action = await showModalBottomSheet<PdfAction>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(ExomIcons.print),
            title: Text(l10n.weeklyDietPrint),
            onTap: () => Navigator.pop(sheetContext, PdfAction.print),
          ),
          ListTile(
            leading: const Icon(ExomIcons.share),
            title: Text(l10n.weeklyDietShare),
            onTap: () => Navigator.pop(sheetContext, PdfAction.share),
          ),
        ],
      ),
    ),
  );
  if (action == PdfAction.print) {
    await Printing.layoutPdf(name: filename, onLayout: (_) async => bytes);
  } else if (action == PdfAction.share) {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}

/// The weekly shopping-list flow of the calendar export, for the week that
/// contains [date]: same use case, same selector, same PDF, same messages.
Future<void> startWeeklyShoppingList(
  BuildContext context,
  DateTime date,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    final period = await GetIt.I<GetWeeklyDietUseCase>()(
      DateFormat('yyyy-MM-dd').format(mondayFor(date)),
    );
    if (!period.hasDiets) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.dietPeriodEmpty)));
      return;
    }
    if (!context.mounted) return;
    final result = await buildWeeklyShoppingListPdf(
      context,
      period: period,
      calendarMonth: false,
      skipSelectorWithoutVariants: true,
      mealTypes: {
        'BREAKFAST': l10n.mealTypeBreakfast,
        'LUNCH': l10n.mealTypeLunch,
        'SNACK': l10n.mealTypeSnack,
        'DINNER': l10n.mealTypeDinner,
      },
    );
    if (result == null || !context.mounted) return;
    await printOrSharePdf(
      context,
      bytes: result.bytes,
      filename: result.filename,
    );
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.weeklyDietExportError)));
  }
}

class WeeklyVariantSelector extends StatefulWidget {
  const WeeklyVariantSelector({
    super.key,
    required this.week,
    required this.locale,
    required this.title,
    required this.mainLabel,
    required this.generateLabel,
    required this.mealTypes,
  });

  final DietPeriodEntity week;
  final String locale;
  final String title;
  final String mainLabel;
  final String generateLabel;
  final Map<String, String> mealTypes;

  @override
  State<WeeklyVariantSelector> createState() => _WeeklyVariantSelectorState();
}

class _WeeklyVariantSelectorState extends State<WeeklyVariantSelector> {
  late final Map<String, String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = {};
    for (final day in widget.week.days) {
      for (final meal in day.diet?.meals ?? const <MealEntity>[]) {
        if (meal.variants.isNotEmpty) {
          _selectedIds[WeeklyMealSelection.selectionKey(day.date, meal.id)] =
              meal.id;
        }
      }
    }
  }

  List<WeeklyMealSelection> _result() => [
    for (final day in widget.week.days)
      for (final meal in day.diet?.meals ?? const <MealEntity>[])
        if (meal.variants.isNotEmpty)
          WeeklyMealSelection(
            date: day.date,
            parentMealId: meal.id,
            selectedMealId:
                _selectedIds[WeeklyMealSelection.selectionKey(
                  day.date,
                  meal.id,
                )] ??
                meal.id,
          ),
  ];

  // Open-menu entry: full name on several lines with 8 dp above and below.
  Widget _menuText(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ExomSpacing.sm),
    child: Text(text),
  );

  @override
  Widget build(BuildContext context) {
    final dayFormat = DateFormat.EEEE(widget.locale);
    // The sheet measures its content (title + list + button) up to 85 % of
    // the screen; only beyond that does the list scroll under a fixed button.
    // SafeArea would read MediaQuery.padding, which the main shell inflates
    // with the height of its bottom bar; the real system inset is viewPadding.
    final media = MediaQuery.of(context);
    final bottomInset = media.viewPadding.bottom > media.viewInsets.bottom
        ? media.viewPadding.bottom
        : media.viewInsets.bottom;
    return SafeArea(
      bottom: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(ExomIcons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  for (final day in widget.week.days)
                    if ((day.diet?.meals ?? const <MealEntity>[]).any(
                      (meal) => meal.variants.isNotEmpty,
                    )) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 6),
                        child: Text(
                          toBeginningOfSentenceCase(dayFormat.format(day.date)),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      for (final meal
                          in day.diet?.meals ?? const <MealEntity>[])
                        if (meal.variants.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue:
                                  _selectedIds[WeeklyMealSelection.selectionKey(
                                    day.date,
                                    meal.id,
                                  )],
                              decoration: InputDecoration(
                                labelText:
                                    widget.mealTypes[meal.type.toUpperCase()] ??
                                    meal.type,
                                border: const OutlineInputBorder(),
                              ),
                              itemHeight: null,
                              selectedItemBuilder: (context) => [
                                Text(
                                  '${widget.mainLabel}: ${meal.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                for (final variant in meal.variants)
                                  Text(
                                    variant.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                              items: [
                                DropdownMenuItem(
                                  value: meal.id,
                                  child: _menuText(
                                    '${widget.mainLabel}: ${meal.name}',
                                  ),
                                ),
                                ...meal.variants.map(
                                  (variant) => DropdownMenuItem(
                                    value: variant.id,
                                    child: _menuText(variant.name),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedIds[WeeklyMealSelection.selectionKey(
                                        day.date,
                                        meal.id,
                                      )] =
                                      value;
                                });
                              },
                            ),
                          ),
                    ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                ExomSpacing.lg,
                ExomSpacing.sm,
                ExomSpacing.lg,
                ExomSpacing.lg + bottomInset,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _result()),
                  icon: const Icon(ExomIcons.pdf),
                  label: Text(widget.generateLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
