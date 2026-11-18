// Shared harness for the redesign L2 component tests: real theme (V4 tokens),
// bundled fonts, localizations, configurable width/text scale/theme and
// reduced motion.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../golden/redesign_scenes.dart' show loadRedesignFonts;

ThemeData themeFor(Brightness brightness) =>
    brightness == Brightness.dark ? AppTheme.dark : AppTheme.light;

/// Pumps [child] inside a localized MaterialApp/Scaffold on a [width] x
/// [height] surface at devicePixelRatio 1.
Future<void> pumpComponent(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  bool disableAnimations = false,
  Locale locale = const Locale('es'),
  EdgeInsets viewInsets = EdgeInsets.zero,
  bool wrapInScaffold = true,
}) async {
  await loadRedesignFonts();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => GlassDecoration.brightness = Brightness.dark);
  final theme = themeFor(brightness);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, app) {
        GlassDecoration.brightness = Theme.of(context).brightness;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
            viewInsets: viewInsets,
          ),
          child: app!,
        );
      },
      home: wrapInScaffold ? Scaffold(body: child) : child,
    ),
  );
  await tester.pump();
}

/// Evaluates the three tap-target guidelines of the plan (L2 criterion).
Future<void> expectTapTargetGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}

/// Fails if any frame produced a layout overflow or other exception.
void expectNoOverflow(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}
