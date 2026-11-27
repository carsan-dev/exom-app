// Test double of the text scaler an Android 14+ device gives Flutter: the
// system font scale is nonlinear (FontScaleConverterFactory), so large sizes
// grow less than small ones and halving a font size does not halve its scaled
// size. TextScaler.linear in widget tests hides layout bugs that assume
// `scale(a * s) == a * scale(s)` (L5-A4 D1, seen on the Android 15 emulator).
// Not a test file: it has no `main` and is only imported.
import 'package:flutter/painting.dart';

/// Nonlinear [TextScaler] with the lookup tables of Android 14
/// (`FontScaleConverterFactory`): scales 1.15, 1.3, 1.5, 1.8 and 2.0 use their
/// table; a scale between two tables interpolates them, as Android does; a
/// scale at or below 1.0 is linear.
class AndroidNonlinearTextScaler extends TextScaler {
  const AndroidNonlinearTextScaler(this.textScaleFactor);

  @override
  final double textScaleFactor;

  static const List<double> _fromSp = [8, 10, 12, 14, 18, 20, 24, 30, 100];

  /// `(scale, toDp)` tables in ascending scale.
  static const List<(double, List<double>)> _tables = [
    (1.15, [9.2, 11.5, 13.8, 16.4, 19.8, 21.8, 25.2, 30, 100]),
    (1.3, [10.4, 13, 15.6, 18.8, 21.6, 23.6, 26.4, 30, 100]),
    (1.5, [12, 15, 18, 22, 24, 26, 28, 30, 100]),
    (1.8, [14.4, 18, 21.6, 24.4, 27.6, 30.8, 32.8, 34.8, 100]),
    (2.0, [16, 20, 24, 26, 30, 34, 36, 38, 100]),
  ];

  /// The `toDp` table for [textScaleFactor] (interpolated between tables).
  List<double> get _toDp {
    if (textScaleFactor >= _tables.last.$1) return _tables.last.$2;
    var lower = 1.0;
    var lowerTable = _fromSp;
    for (final (scale, table) in _tables) {
      if (textScaleFactor == scale) return table;
      if (textScaleFactor < scale) {
        final t = (textScaleFactor - lower) / (scale - lower);
        return [
          for (var i = 0; i < table.length; i++)
            lowerTable[i] + (table[i] - lowerTable[i]) * t,
        ];
      }
      lower = scale;
      lowerTable = table;
    }
    return lowerTable;
  }

  @override
  double scale(double fontSize) {
    if (textScaleFactor <= 1) return fontSize * textScaleFactor;
    final toDp = _toDp;
    if (fontSize >= _fromSp.last) return fontSize * toDp.last / _fromSp.last;
    var startSp = 0.0;
    var startDp = 0.0;
    for (var i = 0; i < _fromSp.length; i++) {
      if (fontSize <= _fromSp[i]) {
        final t = (fontSize - startSp) / (_fromSp[i] - startSp);
        return startDp + (toDp[i] - startDp) * t;
      }
      startSp = _fromSp[i];
      startDp = toDp[i];
    }
    return fontSize;
  }

  @override
  bool operator ==(Object other) =>
      other is AndroidNonlinearTextScaler &&
      other.textScaleFactor == textScaleFactor;

  @override
  int get hashCode => Object.hash(AndroidNonlinearTextScaler, textScaleFactor);

  @override
  String toString() => 'AndroidNonlinearTextScaler($textScaleFactor)';
}
