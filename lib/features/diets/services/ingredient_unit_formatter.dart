import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/l10n/app_localizations.dart';

class IngredientUnitFormatter {
  final String locale;
  final AppLocalizations _l10n;

  IngredientUnitFormatter({required this.locale})
    : _l10n = lookupAppLocalizations(_localeFrom(locale));

  static Locale _localeFrom(String value) {
    final parts = value.replaceAll('-', '_').split('_');
    return Locale(parts.first, parts.length > 1 ? parts[1] : null);
  }

  String quantity(double value) => NumberFormat('0.##', locale).format(value);

  String unit(String code, double count) {
    switch (code) {
      case 'g':
        return _l10n.ingredientUnitG;
      case 'ml':
        return _l10n.ingredientUnitMl;
      case 'piece':
        return _l10n.ingredientUnitPiece(count);
      case 'tablespoon':
        return _l10n.ingredientUnitTablespoon(count);
      case 'teaspoon':
        return _l10n.ingredientUnitTeaspoon(count);
      case 'handful':
        return _l10n.ingredientUnitHandful(count);
      case 'slice':
        return _l10n.ingredientUnitSlice(count);
      case 'palm':
        return _l10n.ingredientUnitPalm(count);
      case 'fist':
        return _l10n.ingredientUnitFist(count);
      case 'ladle':
        return _l10n.ingredientUnitLadle(count);
      case 'cold_cut_slice':
        return _l10n.ingredientUnitColdCutSlice(count);
      case 'glass':
        return _l10n.ingredientUnitGlass(count);
      case 'cup':
        return _l10n.ingredientUnitCup(count);
      case 'bowl':
        return _l10n.ingredientUnitBowl(count);
      case 'finger':
        return _l10n.ingredientUnitFinger(count);
      case 'pinch':
        return _l10n.ingredientUnitPinch(count);
      case 'serving':
        return _l10n.ingredientUnitServing(count);
      case 'to_taste':
        return _l10n.ingredientToTaste;
      default:
        return code;
    }
  }

  String amount({
    required double quantityValue,
    required String unitCode,
    double? gramsEquivalent,
  }) {
    if (unitCode == 'to_taste') return _l10n.ingredientToTaste;
    final base = '${quantity(quantityValue)} ${unit(unitCode, quantityValue)}';
    if (unitCode == 'g' || gramsEquivalent == null || gramsEquivalent <= 0) {
      return base;
    }
    return '$base (${quantity(gramsEquivalent)} ${_l10n.ingredientUnitG})';
  }

  String shoppingAmount({
    required double? quantityValue,
    required String? unitCode,
    required double? gramsEquivalent,
    required bool toTaste,
  }) {
    if (quantityValue == null || unitCode == null) {
      return _l10n.ingredientToTaste;
    }
    final base = amount(
      quantityValue: quantityValue,
      unitCode: unitCode,
      gramsEquivalent: gramsEquivalent,
    );
    return toTaste ? '$base + ${_l10n.ingredientToTaste}' : base;
  }
}
