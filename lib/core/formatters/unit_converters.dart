import 'package:exom_app/core/preferences/app_preferences.dart';

class UnitConverters {
  UnitConverters._();

  static const _poundsPerKilogram = 2.2046226218;
  static const _centimetersPerInch = 2.54;

  static double kgToLb(double kilograms) => kilograms * _poundsPerKilogram;

  static double lbToKg(double pounds) => pounds / _poundsPerKilogram;

  static double cmToIn(double centimeters) => centimeters / _centimetersPerInch;

  static double inToCm(double inches) => inches * _centimetersPerInch;

  static double weightToDisplay(double kilograms, UnitSystem unitSystem) {
    return unitSystem == UnitSystem.imperial ? kgToLb(kilograms) : kilograms;
  }

  static double weightFromDisplay(double value, UnitSystem unitSystem) {
    return unitSystem == UnitSystem.imperial ? lbToKg(value) : value;
  }

  static double lengthToDisplay(double centimeters, UnitSystem unitSystem) {
    return unitSystem == UnitSystem.imperial
        ? cmToIn(centimeters)
        : centimeters;
  }

  static double lengthFromDisplay(double value, UnitSystem unitSystem) {
    return unitSystem == UnitSystem.imperial ? inToCm(value) : value;
  }
}
