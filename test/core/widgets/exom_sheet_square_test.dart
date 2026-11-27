// L5 T0.1, decision D12 (docs/plans/rediseno-app-l5-contrato-v2.md): every
// sheet has square corners, both the EXOM sheet and the theme default.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kExomSheetRadius is 0', () {
    expect(kExomSheetRadius, 0);
  });

  test('bottomSheetTheme has square corners in dark and light', () {
    for (final theme in [AppTheme.dark, AppTheme.light]) {
      final shape = theme.bottomSheetTheme.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.zero);
    }
  });
}
