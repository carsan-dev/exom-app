// L5-D64 (OBS-7): «Descartar progreso anterior» keeps «Cancelar» and the
// primary action on one row at text scale 1,0 on a phone, and stacks them only
// when they do not fit (large text). Measured with the bundled fonts, since the
// test font would not tell whether the real labels fit.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/trainings/presentation/widgets/discard_foreign_progress_dialog.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;

Future<Future<bool>> _open(
  WidgetTester tester, {
  required TextScaler textScaler,
  Size size = const Size(390, 844),
}) async {
  await loadRedesignFonts();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  late BuildContext pageContext;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Builder(
        builder: (context) {
          pageContext = context;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );
  final result = confirmDiscardForeignProgress(pageContext);
  await tester.pumpAndSettle();
  return result;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(AlertDialog)));

void main() {
  for (final size in const [Size(390, 844), Size(411, 914)]) {
    testWidgets('1.0 on ${size.width.toInt()} dp: actions on one row', (
      tester,
    ) async {
      await _open(tester, textScaler: TextScaler.noScaling, size: size);
      final l10n = _l10n(tester);
      final cancel = tester.getRect(find.text(l10n.cancel));
      final discard = tester.getRect(
        find.text(l10n.activeExerciseDiscardAction),
      );
      expect(cancel.center.dy, moreOrLessEquals(discard.center.dy, epsilon: 1));
      expect(cancel.right, lessThan(discard.left));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('1.6: the actions stack instead of overflowing', (tester) async {
    await _open(tester, textScaler: const AndroidNonlinearTextScaler(1.6));
    final l10n = _l10n(tester);
    final cancel = tester.getRect(find.text(l10n.cancel));
    final discard = tester.getRect(find.text(l10n.activeExerciseDiscardAction));
    expect((cancel.center.dy - discard.center.dy).abs(), greaterThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('answers: confirm is true, cancel and dismiss are false', (
    tester,
  ) async {
    var result = await _open(tester, textScaler: TextScaler.noScaling);
    await tester.tap(find.text(_l10n(tester).activeExerciseDiscardAction));
    await tester.pumpAndSettle();
    expect(await result, isTrue);

    result = await _open(tester, textScaler: TextScaler.noScaling);
    await tester.tap(find.text(_l10n(tester).cancel));
    await tester.pumpAndSettle();
    expect(await result, isFalse);

    result = await _open(tester, textScaler: TextScaler.noScaling);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });
}
