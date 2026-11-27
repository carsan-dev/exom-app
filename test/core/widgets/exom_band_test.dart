import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exom_component_harness.dart';
import 'exom_text_component_matrix.dart';

const _bandText = 'Peso, grasa corporal y perímetros de la última revisión';

// Callers style their content; the theme's bodyLarge is the text colour.
Widget _styled(String text) => Builder(
  builder: (context) =>
      Text(text, style: Theme.of(context).textTheme.bodyLarge),
);

Widget _band() => ExomBand(
  kicker: 'Datos corporales',
  child: Padding(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
    child: _styled(_bandText),
  ),
);

Widget _feature() => ExomFeatureBlock(
  child: Padding(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
    child: _styled('Jueves 19 · 1 de 4 entrenos esta semana'),
  ),
);

ExomThemePalette _palette(Brightness b) =>
    themeFor(b).extension<ExomThemePalette>()!;

BoxDecoration _decorationIn(WidgetTester tester, Type type) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(of: find.byType(type), matching: find.byType(DecoratedBox))
        .first,
  );
  return box.decoration as BoxDecoration;
}

void main() {
  registerTextComponentMatrix('ExomBand', _band);
  registerTextComponentMatrix('ExomFeatureBlock', _feature);

  group('ExomBand', () {
    testWidgets('is an ExomPanel with 20 px vertical padding and rules', (
      tester,
    ) async {
      await pumpComponent(tester, _band());
      final panel = tester.widget<ExomPanel>(find.byType(ExomPanel));
      expect(panel.padding, const EdgeInsets.symmetric(vertical: 20));
      expect(panel.topRule, isTrue);
      expect(panel.bottomRule, isTrue);
      expect(panel.raised, isFalse);
    });

    testWidgets('paints the kicker above the content, padded 20', (
      tester,
    ) async {
      await pumpComponent(tester, _band());
      expect(find.byType(ExomKicker), findsOneWidget);
      expect(find.text('DATOS CORPORALES'), findsOneWidget);
      final kicker = tester.getRect(find.byType(ExomKicker));
      final body = tester.getRect(find.text(_bandText));
      expect(kicker.left, 20);
      expect(kicker.bottom, lessThan(body.top));
    });

    testWidgets('joinsPrevious drops the top rule (.x-band + .x-band)', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        const SingleChildScrollView(
          child: Column(
            children: [
              ExomBand(child: SizedBox(height: 20)),
              ExomBand(joinsPrevious: true, child: SizedBox(height: 20)),
            ],
          ),
        ),
      );
      final bands = find.byType(ExomPanel);
      final first = tester.widget<ExomPanel>(bands.at(0));
      final second = tester.widget<ExomPanel>(bands.at(1));
      expect(first.topRule, isTrue);
      expect(first.bottomRule, isTrue);
      expect(second.topRule, isFalse);
      expect(second.bottomRule, isTrue);
    });

    testWidgets('without kicker only the child is painted', (tester) async {
      await pumpComponent(tester, const ExomBand(child: Text('Solo')));
      expect(find.byType(ExomKicker), findsNothing);
      expect(find.text('Solo'), findsOneWidget);
    });
  });

  group('ExomFeatureBlock', () {
    for (final brightness in Brightness.values) {
      testWidgets('4 px top bar in the data colour on the panel '
          '(${brightness.name})', (tester) async {
        final palette = _palette(brightness);
        await pumpComponent(tester, _feature(), brightness: brightness);
        final decoration = _decorationIn(tester, ExomFeatureBlock);
        expect(decoration.color, palette.surface);
        final border = decoration.border! as Border;
        expect(border.top.width, ExomRule.bar);
        expect(border.top.color, palette.data);
        expect(border.bottom, BorderSide.none);
      });
    }

    testWidgets('a row group inside it can drop its bottom rule '
        '(.x-feat .rows)', (tester) async {
      await pumpComponent(
        tester,
        const ExomFeatureBlock(
          child: ExomFlatRowGroup(
            bottomRule: false,
            children: [ExomValueRow(label: 'Versión', value: '1.3.0')],
          ),
        ),
      );
      final group = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(ExomFlatRowGroup),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final border = (group.decoration as BoxDecoration).border! as Border;
      expect(border.bottom, BorderSide.none);
    });

    testWidgets('pads 16 above and 20 below the content', (tester) async {
      await pumpComponent(
        tester,
        const Align(
          alignment: Alignment.topCenter,
          child: ExomFeatureBlock(child: SizedBox(height: 10)),
        ),
      );
      expect(
        tester.getSize(find.byType(ExomFeatureBlock)).height,
        ExomRule.bar + 16 + 10 + 20,
      );
    });
  });
}
