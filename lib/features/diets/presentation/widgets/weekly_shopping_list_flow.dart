import 'dart:typed_data';

import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/domain/usecases/get_weekly_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/utils/diet_export_period_utils.dart';
import 'package:exom_app/features/diets/presentation/pages/shopping_list_pages.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

/// Shopping-list steps shared by the calendar export and the Diets screen
/// (L5-E8): the choice of alternatives and the list are pushed screens
/// ([ShoppingListSetupPage], [ShoppingListPage]); the list builds the PDF and
/// opens the print/share sheet from «Compartir lista».

enum PdfAction { print, share }

/// Opens the shopping list of [period]: the choice of alternatives when some
/// meal of [period] has them, otherwise the list straight away (I7). Returns
/// when the user leaves the first screen. [mealTypes] maps the upper-case
/// meal type to its label.
Future<void> openShoppingList(
  BuildContext context, {
  required DietPeriodEntity period,
  required bool calendarMonth,
  required Map<String, String> mealTypes,
}) {
  final hasVariants = period.days.any(
    (day) => (day.diet?.meals ?? const <MealEntity>[]).any(
      (meal) => meal.variants.isNotEmpty,
    ),
  );
  return pushShoppingListRoute<void>(
    context,
    (_) => hasVariants
        ? ShoppingListSetupPage(
            period: period,
            calendarMonth: calendarMonth,
            mealTypes: mealTypes,
          )
        : ShoppingListPage(
            period: period,
            calendarMonth: calendarMonth,
            selections: const [],
          ),
  );
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

/// The weekly shopping list of the Diets row, for the week that contains
/// [date]: same use case, same screens and same messages as the calendar
/// export of that week.
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
    await openShoppingList(
      context,
      period: period,
      calendarMonth: false,
      mealTypes: {
        'BREAKFAST': l10n.mealTypeBreakfast,
        'LUNCH': l10n.mealTypeLunch,
        'SNACK': l10n.mealTypeSnack,
        'DINNER': l10n.mealTypeDinner,
      },
    );
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.weeklyDietExportError)));
  }
}
