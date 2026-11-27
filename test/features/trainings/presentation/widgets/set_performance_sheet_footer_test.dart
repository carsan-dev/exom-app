// L6 A-O1, variant B (sketch extension/l6-hoja-tercio-inferior.html, frames
// e, f and g): the Repeticiones and Peso «− valor +» rows are part of the
// pinned footer of the set sheet, above «Guardar serie», so their ± sit in
// the bottom third of the screen and never move when the upper zone (header,
// «Igual que la anterior», RIR) scrolls.
//
// Pinned here: the ± position at 1.0 (360 x 780 and 411 x 891), no overflow
// at 320 x 640 and 360 x 780 at 1.0, 1.3 and 2.0 (linear and Android
// nonlinear), with and without the keyboard, every control still reachable,
// the typing error inside the footer fully visible above the keyboard, and
// the reading order header → RIR → Reps → Peso → Guardar → Cancelar /
// Completar sin registrar.
//
// The keyboard is simulated with the view's insets, as the engine reports it,
// so the focused field reacts to the metrics change like on a device.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/presentation/pages/active_exercise_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;

final _open = find.byKey(const Key('open'));
final _weight = find.byKey(const Key('set-sheet-weight-field'));
final _save = find.byKey(const Key('set-sheet-save'));
final _cancel = find.byKey(const Key('set-sheet-cancel'));
final _skip = find.byKey(const Key('set-sheet-skip-tracking'));
final _footer = find.byKey(const Key('set-sheet-footer'));
final _fieldsScroll = find.byKey(const Key('set-sheet-fields-scroll'));

final AppLocalizations _es = lookupAppLocalizations(const Locale('es'));

const _nonlinear2 = AndroidNonlinearTextScaler(2);

/// The weight step as the sheet writes it (a no-break space before the unit).
const _step = '2,5 kg';

/// The `Semantics` widget labelled [label] (its box is the ± tap area).
Finder _labelled(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

/// The four ± of the sheet (es, metric: the weight step is «2,5 kg»).
List<Finder> get _plusMinus => [
  _labelled(_es.setSheetRepsDecrement),
  _labelled(_es.setSheetRepsIncrement),
  _labelled(_es.setSheetWeightDecrement(_step)),
  _labelled(_es.setSheetWeightIncrement(_step)),
];

/// The weight error message (it quotes what was typed).
Finder get _weightError => find.byWidgetPredicate(
  (widget) => widget is Text && (widget.data?.contains('62,5,5') ?? false),
);

Future<void> _openSheet(
  WidgetTester tester, {
  required Size size,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await loadRedesignFonts();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Only the text scale is overridden: the view insets (the keyboard)
      // come from the view, as on a device.
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: app!,
      ),
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
                previousWeight: 62.5,
                previousPerformance: const SetPerformance(
                  setNumber: 2,
                  reps: 8,
                  weightKg: 60,
                  rir: 2,
                ),
                targetCount: 8,
                targetRir: 2,
                exerciseName: 'Sentadilla búlgara',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(_open);
  await tester.pumpAndSettle();
}

/// Raises the keyboard ([height] dp) over several frames.
Future<void> _raiseKeyboard(WidgetTester tester, double height) async {
  const steps = 8;
  for (var i = 1; i <= steps; i++) {
    tester.view.viewInsets = FakeViewPadding(bottom: height * i / steps);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}

/// The visible part of the footer: its own box clipped by the footer's
/// scroll view when it scrolls internally.
Rect _footerViewport(WidgetTester tester) {
  final scroll = find.descendant(
    of: _footer,
    matching: find.byType(Scrollable),
  );
  return tester.getRect(scroll.first);
}

void _expectFullyVisible(
  WidgetTester tester,
  Finder target, {
  required double keyboardTop,
  required String what,
}) {
  final rect = tester.getRect(target);
  final viewport = _footerViewport(tester);
  expect(
    rect.top,
    greaterThanOrEqualTo(viewport.top - 0.5),
    reason: '$what must not be scrolled above the visible footer',
  );
  expect(
    rect.bottom,
    lessThanOrEqualTo(viewport.bottom + 0.5),
    reason: '$what must not be cut by the bottom of the footer',
  );
  expect(
    rect.bottom,
    lessThanOrEqualTo(keyboardTop + 0.5),
    reason: '$what must be above the keyboard',
  );
}

/// The [RenderEditable] that paints the text of the field [field].
RenderEditable _renderEditable(WidgetTester tester, Finder field) {
  RenderEditable? found;
  void visit(RenderObject node) {
    if (found != null) return;
    if (node is RenderEditable) {
      found = node;
      return;
    }
    node.visitChildren(visit);
  }

  visit(tester.renderObject(field));
  return found!;
}

/// Pre-order walk of the semantics tree in traversal (reading) order.
List<SemanticsNode> _readingOrder(WidgetTester tester) {
  final out = <SemanticsNode>[];
  void walk(SemanticsNode node) {
    out.add(node);
    for (final child in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      walk(child);
    }
  }

  var root = tester.getSemantics(_save);
  while (root.parent != null) {
    root = root.parent!;
  }
  walk(root);
  return out;
}

void main() {
  group('± in the bottom third', () {
    for (final size in const [Size(360, 780), Size(411, 891)]) {
      final name = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('$name at 1.0: both ± rows start at or below 2/3 of the '
          'screen and do not move when the upper zone scrolls', (tester) async {
        final semantics = tester.ensureSemantics();
        await _openSheet(tester, size: size);
        expect(tester.takeException(), isNull);

        final third = size.height * 2 / 3;
        final before = [for (final f in _plusMinus) tester.getRect(f)];
        for (final rect in before) {
          expect(rect.top, greaterThanOrEqualTo(third));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
        }
        // The ± and Guardar live in the pinned footer.
        for (final finder in [..._plusMinus, _save]) {
          expect(
            find.descendant(of: _footer, matching: finder),
            findsOneWidget,
          );
        }
        expect(
          find.descendant(of: _fieldsScroll, matching: find.text('5+')),
          findsOneWidget,
          reason: 'RIR stays in the upper, scrolling zone',
        );

        await tester.drag(_fieldsScroll, const Offset(0, -300));
        await tester.pumpAndSettle();
        final after = [for (final f in _plusMinus) tester.getRect(f)];
        expect(after, before);
        semantics.dispose();
      });
    }

    testWidgets('360x640 at 1.3: the upper zone scrolls, the ± stay put', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _openSheet(
        tester,
        size: const Size(360, 640),
        textScaler: const TextScaler.linear(1.3),
      );
      final before = [for (final f in _plusMinus) tester.getRect(f)];
      await tester.drag(_fieldsScroll, const Offset(0, -300));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(
            find.descendant(
              of: _fieldsScroll,
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      expect(position.pixels, greaterThan(0));
      expect([for (final f in _plusMinus) tester.getRect(f)], before);
      semantics.dispose();
    });
  });

  group('no overflow, everything reachable', () {
    final scalers = <String, TextScaler>{
      '1.0': TextScaler.noScaling,
      '1.3': const TextScaler.linear(1.3),
      '2.0 linear': const TextScaler.linear(2),
      '2.0 nonlinear': const AndroidNonlinearTextScaler(2),
    };
    for (final size in const [Size(320, 640), Size(360, 780)]) {
      for (final entry in scalers.entries) {
        for (final keyboard in const [false, true]) {
          final name =
              '${size.width.toInt()}x${size.height.toInt()} at ${entry.key}'
              '${keyboard ? ', keyboard up' : ''}';
          testWidgets(name, (tester) async {
            await _openSheet(tester, size: size, textScaler: entry.value);
            expect(tester.takeException(), isNull);
            final keyboardHeight = keyboard ? size.height * 0.4 : 0.0;
            final keyboardTop = size.height - keyboardHeight;
            if (keyboard) {
              await tester.ensureVisible(_weight);
              await tester.pumpAndSettle();
              await tester.tap(_weight);
              await _raiseKeyboard(tester, keyboardHeight);
              expect(tester.takeException(), isNull);
            }
            // With a focused field, its selection handle floats over the
            // sheet (an overlay, as on a device), so hit tests are only
            // checked once the field is unfocused.
            Future<void> expectReachable(
              List<Finder> targets,
              double bottom, {
              required bool hitTest,
            }) async {
              for (final target in targets) {
                await tester.ensureVisible(target);
                await tester.pumpAndSettle();
                final rect = tester.getRect(target);
                expect(rect.top, greaterThanOrEqualTo(0));
                expect(rect.bottom, lessThanOrEqualTo(bottom + 0.5));
                if (hitTest) expect(target.hitTestable(), findsOneWidget);
              }
            }

            // Guardar and the quiet actions are pinned: fully visible in the
            // footer without scrolling, keyboard or not.
            final footerTop = tester.getRect(_footer).top;
            for (final target in [_save, _cancel, _skip]) {
              final rect = tester.getRect(target);
              expect(rect.top, greaterThanOrEqualTo(footerTop));
              expect(rect.bottom, lessThanOrEqualTo(keyboardTop + 0.5));
              if (!keyboard) expect(target.hitTestable(), findsOneWidget);
            }
            final footerControls = [
              find.byKey(const Key('set-sheet-count-field')),
              _weight,
              _save,
              _cancel,
              _skip,
            ];
            await expectReachable(
              footerControls,
              keyboardTop,
              hitTest: !keyboard,
            );
            if (keyboard) {
              // While typing the footer may take the whole sheet; the upper
              // zone is back as soon as the keyboard closes.
              FocusManager.instance.primaryFocus?.unfocus();
              tester.view.viewInsets = FakeViewPadding.zero;
              await tester.pumpAndSettle();
            }
            await expectReachable(
              [find.text('SERIE 2'), find.text('5+'), ...footerControls],
              size.height,
              hitTest: true,
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  group('typing error inside the footer', () {
    // When the focused field and its error do not both fit in the visible
    // footer rows (2.0 linear on 360 x 780 with the keyboard), the field and
    // its caret take priority, as before A-O1 (`_RevealErrorBelow`).
    for (final (label, size, scaler, errorFits) in const [
      ('360x780 at 1.0', Size(360, 780), TextScaler.noScaling, true),
      ('320x640 at 1.3', Size(320, 640), TextScaler.linear(1.3), true),
      ('411x891 at 2.0 nonlinear', Size(411, 891), _nonlinear2, true),
      ('360x780 at 2.0 linear', Size(360, 780), TextScaler.linear(2), false),
    ]) {
      testWidgets('$label: the weight error is in the footer; with the '
          'field focused and the keyboard up, '
          '${errorFits ? 'field and whole error are' : 'the field is'} '
          'visible above the keyboard', (tester) async {
        await _openSheet(tester, size: size, textScaler: scaler);
        await tester.ensureVisible(_weight);
        await tester.pumpAndSettle();
        await tester.enterText(_weight, '62,5,5');
        await tester.pump();
        await tester.ensureVisible(_save);
        await tester.pumpAndSettle();
        await tester.tap(_save);
        await tester.pumpAndSettle();
        expect(_weightError, findsOneWidget);
        expect(find.descendant(of: _footer, matching: _weightError), findsOne);
        expect(tester.takeException(), isNull);

        // The keyboard was dismissed; the user taps the field again.
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        await tester.ensureVisible(_weight);
        await tester.pumpAndSettle();
        await tester.tap(_weight);
        final keyboardHeight = size.height * 0.4;
        await _raiseKeyboard(tester, keyboardHeight);
        expect(tester.takeException(), isNull);

        final keyboardTop = size.height - keyboardHeight;
        _expectFullyVisible(
          tester,
          _weight,
          keyboardTop: keyboardTop,
          what: 'the focused weight field',
        );
        if (errorFits) {
          _expectFullyVisible(
            tester,
            _weightError,
            keyboardTop: keyboardTop,
            what: 'the whole weight error',
          );
        }
        // Guardar stays pinned above the keyboard.
        expect(
          tester.getRect(_save).top,
          greaterThanOrEqualTo(tester.getRect(_footer).top),
        );
        expect(
          tester.getRect(_save).bottom,
          lessThanOrEqualTo(keyboardTop + 0.5),
        );
      });
    }
  });

  group('Reps and Peso rows share one stepper column', () {
    // Orchestrator decision (departs from the sketch's flex split): the − of
    // both rows at the same x, the + at the same x, and both rows laid out
    // the same way at a given scale (label beside or above the stepper).
    for (final (label, size, scaler) in const [
      ('360x780 at 1.0', Size(360, 780), TextScaler.noScaling),
      ('390x844 at 1.0', Size(390, 844), TextScaler.noScaling),
      ('411x891 at 1.0', Size(411, 891), TextScaler.noScaling),
      ('360x780 at 1.3', Size(360, 780), TextScaler.linear(1.3)),
      ('390x844 at 1.6', Size(390, 844), TextScaler.linear(1.6)),
      ('411x891 at 1.6', Size(411, 891), TextScaler.linear(1.6)),
      ('320x640 at 2.0', Size(320, 640), TextScaler.linear(2)),
    ]) {
      testWidgets('$label: − and + aligned, same disposition', (tester) async {
        final semantics = tester.ensureSemantics();
        await _openSheet(tester, size: size, textScaler: scaler);
        expect(tester.takeException(), isNull);
        final [repsMinus, repsPlus, weightMinus, weightPlus] = [
          for (final f in _plusMinus) tester.getRect(f),
        ];
        expect(repsMinus.left, moreOrLessEquals(weightMinus.left));
        expect(repsMinus.right, moreOrLessEquals(weightMinus.right));
        expect(repsPlus.left, moreOrLessEquals(weightPlus.left));
        expect(repsPlus.right, moreOrLessEquals(weightPlus.right));
        final countField = tester.getRect(
          find.byKey(const Key('set-sheet-count-field')),
        );
        final weightField = tester.getRect(_weight);
        expect(countField.left, moreOrLessEquals(weightField.left));
        expect(countField.right, moreOrLessEquals(weightField.right));

        bool stacked(String text, Rect minus) {
          final caption = find.descendant(
            of: _footer,
            matching: find.text(text),
          );
          return tester.getRect(caption).bottom <= minus.top + 0.5;
        }

        expect(
          stacked(_es.setSheetWeightLabel, weightMinus),
          stacked(_es.setSheetRepsLabel, repsMinus),
          reason: 'both rows stacked or both inline',
        );
        semantics.dispose();
      });
    }
  });

  group('a typed value with an error is never cut', () {
    for (final (label, size, scaler) in const [
      ('360x780 at 1.0', Size(360, 780), TextScaler.noScaling),
      ('390x844 at 1.6', Size(390, 844), TextScaler.linear(1.6)),
      ('411x891 at 1.6', Size(411, 891), TextScaler.linear(1.6)),
      ('320x640 at 1.6', Size(320, 640), TextScaler.linear(1.6)),
    ]) {
      testWidgets('$label: «62,5,5» fits in its field, focused or not', (
        tester,
      ) async {
        await _openSheet(tester, size: size, textScaler: scaler);
        await tester.ensureVisible(_weight);
        await tester.pumpAndSettle();
        await tester.enterText(_weight, '62,5,5');
        await tester.pump();
        await tester.ensureVisible(_save);
        await tester.pumpAndSettle();
        await tester.tap(_save);
        await tester.pumpAndSettle();
        expect(_weightError, findsOneWidget);

        void expectWhole(String state) {
          final editable = _renderEditable(tester, _weight);
          expect(
            editable.getMaxIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(editable.size.width + 0.5),
            reason: '$state: the whole text fits in the field',
          );
          expect(editable.offset.pixels, 0, reason: '$state: not scrolled');
        }

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expectWhole('unfocused');
        await tester.tap(_weight);
        await tester.pumpAndSettle();
        expectWhole('focused');
      });
    }
  });

  testWidgets('reading order: header, RIR, Reps, Peso, Guardar, Cancelar, '
      'Completar sin registrar', (tester) async {
    final semantics = tester.ensureSemantics();
    await _openSheet(tester, size: const Size(360, 780));
    final nodes = _readingOrder(tester);
    int indexOf(bool Function(SemanticsData data) test, String what) {
      final index = nodes.indexWhere((node) => test(node.getSemanticsData()));
      expect(index, isNot(-1), reason: '$what is in the semantics tree');
      return index;
    }

    bool labelIs(SemanticsData data, String label) => data.label == label;
    final order = [
      indexOf((d) => labelIs(d, 'SERIE 2'), 'title'),
      indexOf((d) => d.label.contains('RIR 1'), 'RIR chip'),
      indexOf((d) => labelIs(d, _es.setSheetRepsDecrement), 'reps −'),
      indexOf((d) => labelIs(d, _es.setSheetRepsIncrement), 'reps +'),
      indexOf(
        (d) => labelIs(d, _es.setSheetWeightDecrement(_step)),
        'weight −',
      ),
      indexOf(
        (d) => labelIs(d, _es.setSheetWeightIncrement(_step)),
        'weight +',
      ),
      indexOf(
        (d) => d.label.toLowerCase() == _es.setSheetSave.toLowerCase(),
        'Guardar',
      ),
      indexOf((d) => d.label.contains(_es.cancel), 'Cancelar'),
      indexOf(
        (d) => d.label.contains(_es.completeWithoutTracking),
        'Completar sin registrar',
      ),
    ];
    for (var i = 1; i < order.length; i++) {
      expect(
        order[i],
        greaterThan(order[i - 1]),
        reason: 'item $i is read after item ${i - 1}: $order',
      );
    }
    semantics.dispose();
  });
}
