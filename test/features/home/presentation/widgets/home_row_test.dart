// L5 T0.3a: HomeRow / HomeRowGroup are thin wrappers over the core
// ExomFlatRow / ExomFlatRowGroup, with the same public API.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/features/home/presentation/widgets/home_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/exom_component_harness.dart';

void main() {
  testWidgets('HomeRow delegates to ExomFlatRow with its icon as leading', (
    tester,
  ) async {
    final palette = AppTheme.dark.extension<ExomThemePalette>()!;
    var taps = 0;
    await pumpComponent(
      tester,
      HomeRowGroup(
        children: [
          HomeRow(
            icon: ExomIcons.diet,
            title: 'Definición',
            subtitles: const ['1 de 4 comidas hechas'],
            onTap: () => taps++,
          ),
        ],
      ),
    );
    expect(find.byType(ExomFlatRowGroup), findsOneWidget);
    final row = tester.widget<ExomFlatRow>(find.byType(ExomFlatRow));
    expect(row.title, 'Definición');
    expect(row.subtitles, ['1 de 4 comidas hechas']);
    final icon = tester.widget<Icon>(find.byIcon(ExomIcons.diet));
    expect(icon.size, 22);
    expect(icon.color, palette.textPrimary);
    await tester.tap(find.byType(HomeRow));
    expect(taps, 1);
  });
}
