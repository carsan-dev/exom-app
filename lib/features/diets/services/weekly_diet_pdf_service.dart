import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_export.dart';
import 'package:exom_app/features/diets/services/ingredient_unit_formatter.dart';

class WeeklyDietPdfLabels {
  final String title;
  final String noDiet;
  final String ingredients;
  final String alternatives;
  final Map<String, String> mealTypes;

  const WeeklyDietPdfLabels({
    required this.title,
    required this.noDiet,
    required this.ingredients,
    required this.alternatives,
    required this.mealTypes,
  });
}

class WeeklyShoppingListPdfLabels {
  final String title;
  final String empty;

  const WeeklyShoppingListPdfLabels({required this.title, required this.empty});
}

class WeeklyDietPdfService {
  const WeeklyDietPdfService();

  Future<Uint8List> build({
    required WeeklyDietEntity week,
    required String locale,
    required WeeklyDietPdfLabels labels,
  }) async {
    await initializeDateFormatting(locale);
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/CabinetGrotesk-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/CabinetGrotesk-Bold.ttf'),
    );
    final logo = await rootBundle.loadString('assets/images/logo.svg');
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final dateFormat = DateFormat.yMMMMd(locale);
    final dayFormat = DateFormat.EEEE(locale);
    final unitFormatter = IngredientUnitFormatter(locale: locale);
    final range =
        '${dateFormat.format(week.weekStart)} – '
        '${dateFormat.format(week.weekEnd)}';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 14),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.SvgImage(svg: logo, width: 72),
              pw.Text(
                labels.title,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 18,
                  color: PdfColor.fromHex('#713B22'),
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Text(range, style: pw.TextStyle(font: bold, fontSize: 13)),
          pw.SizedBox(height: 14),
          ...week.days.map(
            (day) => _buildDay(
              day: day,
              dateFormat: dateFormat,
              dayFormat: dayFormat,
              labels: labels,
              bold: bold,
              unitFormatter: unitFormatter,
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  Future<Uint8List> buildShoppingList({
    required WeeklyDietEntity week,
    required List<ShoppingListItem> items,
    required String locale,
    required WeeklyShoppingListPdfLabels labels,
  }) async {
    await initializeDateFormatting(locale);
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/CabinetGrotesk-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/CabinetGrotesk-Bold.ttf'),
    );
    final logo = await rootBundle.loadString('assets/images/logo.svg');
    final dateFormat = DateFormat.yMMMMd(locale);
    final formatter = IngredientUnitFormatter(locale: locale);
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final range =
        '${dateFormat.format(week.weekStart)} – ${dateFormat.format(week.weekEnd)}';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 14),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.SvgImage(svg: logo, width: 72),
              pw.Text(
                labels.title,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 18,
                  color: PdfColor.fromHex('#713B22'),
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Text(range, style: pw.TextStyle(font: bold, fontSize: 13)),
          pw.SizedBox(height: 16),
          if (items.isEmpty)
            pw.Text(labels.empty)
          else
            ...items.map(
              (item) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 7),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300),
                  ),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 12,
                      height: 12,
                      margin: const pw.EdgeInsets.only(right: 9, top: 1),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey700),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        item.name,
                        style: pw.TextStyle(font: bold, fontSize: 11),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Text(
                      formatter.shoppingAmount(
                        quantityValue: item.quantity,
                        unitCode: item.unit,
                        gramsEquivalent: item.gramsEquivalent,
                        toTaste: item.toTaste,
                      ),
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _buildDay({
    required WeeklyDietDayEntity day,
    required DateFormat dateFormat,
    required DateFormat dayFormat,
    required WeeklyDietPdfLabels labels,
    required pw.Font bold,
    required IngredientUnitFormatter unitFormatter,
  }) {
    final heading =
        '${_capitalize(dayFormat.format(day.date))} · '
        '${dateFormat.format(day.date)}';
    final diet = day.diet;

    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8F2EC'),
        border: pw.Border.all(color: PdfColor.fromHex('#E5D4C5')),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            heading,
            style: pw.TextStyle(
              font: bold,
              fontSize: 13,
              color: PdfColor.fromHex('#713B22'),
            ),
          ),
          pw.SizedBox(height: 5),
          if (diet == null)
            pw.Text(labels.noDiet, style: const pw.TextStyle(fontSize: 10))
          else ...[
            pw.Text(diet.name, style: pw.TextStyle(font: bold, fontSize: 11)),
            pw.SizedBox(height: 6),
            ...diet.meals.map(
              (meal) => _buildMeal(
                meal,
                labels: labels,
                bold: bold,
                unitFormatter: unitFormatter,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildMeal(
    MealEntity meal, {
    required WeeklyDietPdfLabels labels,
    required pw.Font bold,
    required IngredientUnitFormatter unitFormatter,
    bool alternative = false,
  }) {
    final type = labels.mealTypes[meal.type.toUpperCase()] ?? meal.type;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: alternative ? '${labels.alternatives}: ' : '$type: ',
                  style: pw.TextStyle(font: bold, fontSize: 10),
                ),
                pw.TextSpan(
                  text: meal.name,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
          if (meal.ingredients.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 10, top: 2),
              child: pw.Text(
                '${labels.ingredients}: ${meal.ingredients.map((item) => _ingredientText(item, unitFormatter)).join(', ')}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          ...meal.variants.map(
            (variant) => pw.Padding(
              padding: const pw.EdgeInsets.only(left: 10, top: 3),
              child: _buildMeal(
                variant,
                labels: labels,
                bold: bold,
                unitFormatter: unitFormatter,
                alternative: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ingredientText(
    MealIngredientEntity ingredient,
    IngredientUnitFormatter formatter,
  ) =>
      '${formatter.amount(quantityValue: ingredient.quantity, unitCode: ingredient.unit, gramsEquivalent: ingredient.gramsEquivalent)} ${ingredient.name}'
          .trim();

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
