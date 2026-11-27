import 'dart:io';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/anatomy_selector.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The flutter_test default font (Ahem) is far wider than the app font, so
  // the width assertions need the real body face.
  setUpAll(() async {
    final loader = FontLoader(AppTheme.bodyFontFamily);
    for (final file in Directory('assets/fonts').listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (name.startsWith('dm-sans-') && name.endsWith('.ttf')) {
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
    }
    await loader.load();
  });

  testWidgets('Frontal/Posterior tabs are at least 48 dp tall', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(child: AnatomySelector(onZoneSelected: (_) {})),
        ),
      ),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    for (final label in [l10n.frontViewLabel, l10n.backViewLabel]) {
      // The tap target is the tab (GestureDetector) that wraps the label.
      final tab = find.ancestor(
        of: find.text(label),
        matching: find.byType(GestureDetector),
      );
      expect(tab, findsOneWidget);
      final size = tester.getSize(tab);
      expect(size.height, greaterThanOrEqualTo(48), reason: '$label: $size');
    }
  });

  group('tab labels stay on one complete line', () {
    // Width at which metrics_page mounts the selector (height 440).
    final selectorWidth = AnatomySelector.bodyHeightFor(440) * (320 / 760);

    for (final locale in const ['es', 'en']) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final screenWidth in const [390.0, 320.0]) {
          testWidgets('$locale scale $scale screen $screenWidth', (
            tester,
          ) async {
            tester.view.physicalSize = Size(screenWidth, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.dark,
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Center(child: AnatomySelector(onZoneSelected: (_) {})),
                ),
              ),
            );
            final l10n = AppLocalizations.of(
              tester.element(find.byType(Scaffold)),
            );
            expect(
              tester.getSize(find.byType(AnatomySelector)).width,
              closeTo(selectorWidth, 0.01),
            );
            // Both selection states: the active tab is bold, hence wider.
            for (final backActive in [false, true]) {
              if (backActive) {
                await tester.tap(find.text(l10n.backViewLabel));
                await tester.pump();
              }
              for (final label in [l10n.frontViewLabel, l10n.backViewLabel]) {
                final textFinder = find.text(label);
                final paragraph = tester.renderObject<RenderParagraph>(
                  textFinder,
                );
                expect(paragraph.text.toPlainText(), label);
                expect(paragraph.didExceedMaxLines, isFalse, reason: label);
                // A single line: no wrapping at the paragraph level.
                expect(
                  paragraph.getFullHeightForCaret(
                    const TextPosition(offset: 0),
                  ),
                  greaterThan(0),
                );
                expect(
                  paragraph.size.height,
                  lessThan(14 * scale * 1.6),
                  reason: '$label wraps: ${paragraph.size}',
                );
                final tab = find.ancestor(
                  of: textFinder,
                  matching: find.byType(GestureDetector),
                );
                final tabRect = tester.getRect(tab);
                final textRect = tester.getRect(textFinder);
                expect(
                  textRect.left,
                  greaterThanOrEqualTo(tabRect.left - 0.01),
                  reason: '$label clipped left',
                );
                expect(
                  textRect.right,
                  lessThanOrEqualTo(tabRect.right + 0.01),
                  reason: '$label clipped right: $textRect vs $tabRect',
                );
                if (scale == 1.0) {
                  // Never below the 14 px design size at the default scale.
                  expect(
                    textRect.height / paragraph.size.height,
                    greaterThanOrEqualTo(0.99),
                    reason: '$label shrunk at scale 1.0',
                  );
                }
              }
            }
          });
        }
      }
    }
  });
}
