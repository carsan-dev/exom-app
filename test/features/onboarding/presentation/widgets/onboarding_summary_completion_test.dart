// L5-D2 · Onboarding, round 4: the summary's completion block. The label
// depends on the percentage (tiers), the accessible label keeps the number,
// and the block has the thin neutral rule of the summary sections instead of
// the thick data-coloured bar of ExomFeatureBlock.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_summary_step.dart';
import 'package:exom_app/l10n/app_localizations_en.dart';
import 'package:exom_app/l10n/app_localizations_es.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../onboarding_test_support.dart';

/// 9 counted fields (8 of the profile + the photo): n filled = n / 9.
const _all = <String, dynamic>{
  'first_name': 'Lucía',
  'last_name': 'Martín',
  'birth_date': '1994-03-14',
  'height': 168.5,
  'current_weight': 68.4,
  'level': 'INTERMEDIO',
  'main_goal': 'Ganar músculo',
  'target_calories': 2100,
};

Map<String, dynamic> _filled(int count) =>
    Map.fromEntries(_all.entries.take(count));

Future<void> _pump(
  WidgetTester tester,
  Map<String, dynamic> data, {
  String? avatarUrl,
  Locale locale = const Locale('es'),
}) {
  return pumpOnboardingStep(
    tester,
    OnboardingSummaryStep(
      accumulatedData: data,
      avatarUrl: avatarUrl,
      onConfirm: () {},
      onEditBasics: () {},
      onEditBody: () {},
      onEditGoals: () {},
    ),
    locale: locale,
  );
}

void main() {
  group('tiers of the label (thresholds)', () {
    final es = AppLocalizationsEs();
    final en = AppLocalizationsEn();
    const cases = <(int, String, String)>[
      (0, 'Perfil incompleto', 'Profile incomplete'),
      (39, 'Perfil incompleto', 'Profile incomplete'),
      (40, 'Perfil a medias', 'Profile half done'),
      (69, 'Perfil a medias', 'Profile half done'),
      (70, 'Perfil casi completo', 'Profile almost complete'),
      (99, 'Perfil casi completo', 'Profile almost complete'),
      (100, 'Perfil completo', 'Profile complete'),
    ];
    for (final (percent, spanish, english) in cases) {
      test('$percent % -> $spanish / $english', () {
        expect(onboardingCompletionLabel(es, percent), spanish);
        expect(onboardingCompletionLabel(en, percent), english);
      });
    }
  });

  group('the block shows the tier and the number', () {
    const cases = <(int, int, String, String)>[
      (0, 0, 'Perfil incompleto', 'Profile incomplete'),
      (4, 44, 'Perfil a medias', 'Profile half done'),
      (8, 89, 'Perfil casi completo', 'Profile almost complete'),
    ];
    for (final (count, percent, spanish, english) in cases) {
      for (final locale in const [Locale('es'), Locale('en')]) {
        final isEs = locale.languageCode == 'es';
        testWidgets('${locale.languageCode} $percent %', (tester) async {
          await _pump(tester, _filled(count), locale: locale);
          final label = isEs ? spanish : english;
          expect(find.text(label), findsOneWidget);
          expect(findFigure('$percent'), findsWidgets);
          // The accessible label keeps the percentage.
          final handle = tester.ensureSemantics();
          expect(
            find.bySemanticsLabel(
              isEs ? '$label, $percent %' : '$label, $percent%',
            ),
            findsOneWidget,
          );
          handle.dispose();
        });
      }
    }

    testWidgets('100 % (with the photo): complete profile', (tester) async {
      await _pump(tester, _all, avatarUrl: 'https://example.invalid/a.png');
      expect(find.text('Perfil completo'), findsOneWidget);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Perfil completo, 100 %'), findsOneWidget);
      handle.dispose();
    });
  });

  group('the block rule', () {
    testWidgets('no thick data bar: ExomFeatureBlock is not used and no '
        'decoration of the summary has a top border of the data colour', (
      tester,
    ) async {
      await _pump(tester, _all);
      expect(find.byType(ExomFeatureBlock), findsNothing);
      final data = tester.element(find.byType(Scaffold)).exomPalette.data;
      for (final box in tester.widgetList<Container>(
        find.descendant(
          of: find.byType(OnboardingSummaryStep),
          matching: find.byType(Container),
        ),
      )) {
        final decoration = box.decoration;
        if (decoration is! BoxDecoration) continue;
        final border = decoration.border;
        if (border is! Border) continue;
        expect(
          border.top.color == data && border.top.width > 0,
          isFalse,
          reason: 'a thick data rule is left in the summary',
        );
      }
    });

    testWidgets('the block has the thin neutral rule on top, and the '
        'neutral separator of the first section below', (tester) async {
      await _pump(tester, _filled(8));
      final palette = tester.element(find.byType(Scaffold)).exomPalette;
      final block = find
          .ancestor(
            of: find.text('Perfil casi completo'),
            matching: find.byType(Container),
          )
          .first;
      final decoration = tester.widget<Container>(block).decoration!;
      final box = decoration as BoxDecoration;
      final top = (box.border! as Border).top;
      expect(top.width, ExomRule.hairline);
      expect(top.color, palette.borderSoft);
      expect(box.color, palette.surface);
      // Below: the header of section 01 carries the same hairline.
      final header = find
          .descendant(
            of: find.byType(ExomNumberedSectionHeader).first,
            matching: find.byType(DecoratedBox),
          )
          .first;
      final headerBox =
          tester.widget<DecoratedBox>(header).decoration as BoxDecoration;
      final headerTop = (headerBox.border! as Border).top;
      expect(headerTop.width, top.width);
      expect(headerTop.color, top.color);
      expect(
        tester.getTopLeft(header).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(block).dy),
      );
    });
  });
}
