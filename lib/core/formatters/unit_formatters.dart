import 'package:exom_app/core/formatters/unit_converters.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';

String weightUnitSymbol(UnitSystem unitSystem) {
  return unitSystem == UnitSystem.imperial ? 'lb' : 'kg';
}

String lengthUnitSymbol(UnitSystem unitSystem) {
  return unitSystem == UnitSystem.imperial ? 'in' : 'cm';
}

String formatWeightValue(
  double? kilograms,
  UnitSystem unitSystem, {
  int decimals = 1,
  String empty = '--',
}) {
  if (kilograms == null) {
    return empty;
  }

  return UnitConverters.weightToDisplay(
    kilograms,
    unitSystem,
  ).toStringAsFixed(decimals);
}

String formatWeight(
  double? kilograms,
  UnitSystem unitSystem, {
  int decimals = 1,
  String empty = '--',
}) {
  if (kilograms == null) {
    return empty;
  }

  return '${formatWeightValue(kilograms, unitSystem, decimals: decimals, empty: empty)} ${weightUnitSymbol(unitSystem)}';
}

String formatLengthValue(
  double? centimeters,
  UnitSystem unitSystem, {
  int decimals = 1,
  String empty = '--',
}) {
  if (centimeters == null) {
    return empty;
  }

  return UnitConverters.lengthToDisplay(
    centimeters,
    unitSystem,
  ).toStringAsFixed(decimals);
}

String formatLength(
  double? centimeters,
  UnitSystem unitSystem, {
  int decimals = 1,
  String empty = '--',
}) {
  if (centimeters == null) {
    return empty;
  }

  return '${formatLengthValue(centimeters, unitSystem, decimals: decimals, empty: empty)} ${lengthUnitSymbol(unitSystem)}';
}
