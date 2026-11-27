// L6 E-D1: in the set-logging sheet, after a weight validation error, tapping
// the weight field again opens the keyboard and the field must still be
// scrolled above the pinned footer (Guardar). The keyboard is simulated with
// the view's insets, as the engine reports it, so the focused field reacts to
// the metrics change like on a device.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;

final _weight = find.byKey(const Key('set-sheet-weight-field'));
final _save = find.byKey(const Key('set-sheet-save'));

/// The pinned footer: the box with the top border that holds Guardar.
Finder get _footer => find.ancestor(
  of: _save,
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is DecoratedBox &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).border is Border &&
        ((widget.decoration as BoxDecoration).border! as Border).top.width > 0,
  ),
);

// Samsung S25: 1080 x 2340 px; the Samsung keyboard starts at y = 1330 px.
const double _dpr = 2.625;
const Size _physical = Size(1080, 2340);
const double _keyboardPx = 2340 - 1330;

Future<void> _openSheet(WidgetTester tester, Locale locale) async {
  await loadRedesignFonts();
  tester.view.physicalSize = _physical;
  tester.view.devicePixelRatio = _dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () => showSetPerformanceSheet(
                context,
                AppLocalizations.of(context),
                setNumber: 2,
                prescribedReps: '8 reps · RIR 2',
                repsRequired: false,
                timeUnit: null,
                previousPerformance: const SetPerformance(
                  setNumber: 2,
                  reps: 8,
                  weightKg: 60,
                  rir: 2,
                ),
                targetCount: 8,
                targetRir: 2,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

/// Raises the keyboard over several frames, as the engine reports it.
Future<void> _raiseKeyboard(WidgetTester tester) async {
  const steps = 8;
  for (var i = 1; i <= steps; i++) {
    tester.view.viewInsets = FakeViewPadding(bottom: _keyboardPx * i / steps);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}

Future<void> _hideKeyboard(WidgetTester tester) async {
  tester.view.viewInsets = FakeViewPadding.zero;
  await tester.pumpAndSettle();
}

void _expectWeightAboveFooter(WidgetTester tester) {
  final weightRect = tester.getRect(_weight);
  final footerTop = tester.getRect(_footer.first).top;
  final keyboardTop = (_physical.height - _keyboardPx) / _dpr;
  expect(footerTop, lessThanOrEqualTo(keyboardTop));
  expect(weightRect.top, greaterThanOrEqualTo(0));
  expect(
    weightRect.bottom,
    lessThanOrEqualTo(footerTop),
    reason: 'the focused weight field must be scrolled above the footer',
  );
}

/// The weight error message (it quotes what was typed).
Finder get _weightError => find.byWidgetPredicate(
  (widget) => widget is Text && (widget.data?.contains('62.5,5') ?? false),
);

/// INT-D1: the whole error message under the focused weight field, not only
/// the field and its caret, must be scrolled above the footer.
void _expectWeightErrorAboveFooter(WidgetTester tester) {
  _expectWeightAboveFooter(tester);
  final errorRect = tester.getRect(_weightError);
  final footerTop = tester.getRect(_footer.first).top;
  expect(
    errorRect.bottom,
    lessThanOrEqualTo(footerTop),
    reason:
        'the weight error under the focused field must be fully visible '
        'above the footer',
  );
}

void main() {
  for (final locale in const [Locale('es'), Locale('en')]) {
    testWidgets('E-D1 ($locale): after a weight error, tapping the field '
        'again scrolls it above the footer and the keyboard', (tester) async {
      await _openSheet(tester, locale);
      await tester.enterText(_weight, '62.5,5');
      await tester.pump();
      await tester.tap(_save);
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text && (widget.data?.contains('62.5,5') ?? false),
        ),
        findsOneWidget,
        reason: 'the weight error is shown',
      );
      expect(tester.widget<TextField>(_weight).focusNode!.hasFocus, isTrue);

      // The keyboard was dismissed; the user taps the weight field again.
      await _hideKeyboard(tester);
      await tester.tap(_weight);
      await _raiseKeyboard(tester);

      _expectWeightAboveFooter(tester);
    });
  }

  testWidgets('INT-D1 (es): after a weight error, tapping the field again '
      'scrolls the field and its whole two-line error above the footer', (
    tester,
  ) async {
    await _openSheet(tester, const Locale('es'));
    await tester.enterText(_weight, '62.5,5');
    await tester.pump();
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(_weightError, findsOneWidget);

    await _hideKeyboard(tester);
    await tester.tap(_weight);
    await _raiseKeyboard(tester);

    _expectWeightErrorAboveFooter(tester);
  });

  testWidgets('INT-D1 (es): when the weight error appears with the field '
      'focused and the keyboard up, the whole error is above the footer', (
    tester,
  ) async {
    await _openSheet(tester, const Locale('es'));
    await tester.tap(_weight);
    await _raiseKeyboard(tester);
    await tester.enterText(_weight, '62.5,5');
    await tester.pump();
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(_weightError, findsOneWidget);

    _expectWeightErrorAboveFooter(tester);
  });

  testWidgets('E-D1 control: without an error, focusing the weight field '
      'with the keyboard scrolls it above the footer', (tester) async {
    await _openSheet(tester, const Locale('es'));
    await tester.tap(_weight);
    await _raiseKeyboard(tester);

    _expectWeightAboveFooter(tester);
  });
}
