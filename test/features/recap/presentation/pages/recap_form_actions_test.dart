// L5-C5a (r2) · Recap, formulario por pasos: the real buttons of the pinned
// footer, the week the recap belongs to, the step numeral and a draft that
// comes back with extreme saved values.
//
// These tests press what the user presses (Siguiente, Anterior, Guardar
// borrador, ENVIAR RECAP, Comenzar) and read the event the real bloc received,
// the step that is shown and whether the button is enabled (`onPressed`).
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_scale_chips.dart';
import 'package:exom_app/core/widgets/exom_step_header.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart'
    show RecapWeekLabel;
import 'package:exom_app/features/recap/presentation/widgets/recap_start_view.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../bloc/recap_bloc_test.dart' show recapFixture;
import 'recap_list_redesign_test.dart'
    show
        RecapListTestRepository,
        pumpRecapList,
        recapListOpen,
        recapListWithDraft;

/// Records every event the bloc receives.
class _EventSpy extends BlocObserver {
  final events = <RecapEvent>[];

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    if (event is RecapEvent) events.add(event);
  }

  List<int> get stepChanges =>
      events.whereType<RecapStepChanged>().map((e) => e.step).toList();
}

class _QuietObserver extends BlocObserver {}

/// Repository that keeps a copy of what the bloc writes.
class _WritingRepository extends RecapListTestRepository {
  _WritingRepository(super.recaps);

  final updates = <Map<String, dynamic>>[];

  @override
  Future<RecapEntity> updateRecap(String id, Map<String, dynamic> data) {
    updates.add(Map<String, dynamic>.of(data));
    return super.updateRecap(id, data);
  }
}

RecapBloc _bloc(WidgetTester tester) =>
    BlocProvider.of<RecapBloc>(tester.element(find.byType(Scaffold).first));

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Opens the form from the list with the real «new / continue» button.
Future<void> _openForm(
  WidgetTester tester, {
  required RecapListTestRepository repository,
  Locale locale = const Locale('es'),
}) async {
  await pumpRecapList(tester, repository: repository, locale: locale);
  await tester.tap(find.byKey(const ValueKey('recap-new')));
  await _settle(tester);
}

ExomPrimaryButton _action(WidgetTester tester) => tester
    .widget<ExomPrimaryButton>(find.byKey(const ValueKey('recap-step-action')));

Finder _quiet(String label) => find.byWidgetPredicate(
  (widget) => widget is ExomQuietButton && widget.label == label,
);

ExomQuietButton _quietButton(WidgetTester tester, String label) =>
    tester.widget<ExomQuietButton>(_quiet(label));

Future<void> _press(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder, warnIfMissed: false);
  await _settle(tester);
}

/// The step that is on screen: 0 for the start view.
int _shownStep(WidgetTester tester) {
  if (find.byType(RecapStartView).evaluate().isNotEmpty) return 0;
  return tester.widget<ExomStepHeader>(find.byType(ExomStepHeader)).step;
}

String _weekText(Locale locale) {
  final format = DateFormat('dd MMM', locale.languageCode);
  return '${format.format(DateTime(2026, 11, 16))} - '
      '${format.format(DateTime(2026, 11, 22))}';
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });
  late _EventSpy spy;
  setUp(() {
    spy = _EventSpy();
    Bloc.observer = spy;
  });
  tearDown(() async {
    Bloc.observer = _QuietObserver();
    await sl.reset();
  });

  group('the week of the recap is shown in the form (I1)', () {
    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets(
        'step 0 and steps 1-5 name the week (${locale.languageCode})',
        (tester) async {
          await _openForm(
            tester,
            repository: RecapListTestRepository(recapListWithDraft()),
            locale: locale,
          );
          final week = find.text(_weekText(locale));
          expect(_shownStep(tester), 0);
          expect(week, findsOneWidget, reason: 'start view');
          await _press(tester, find.byKey(const ValueKey('recap-start')));
          for (var step = 1; step <= 5; step++) {
            expect(_shownStep(tester), step);
            expect(week, findsOneWidget, reason: 'step $step');
            if (step < 5) {
              await _press(
                tester,
                find.byKey(const ValueKey('recap-step-action')),
              );
            }
          }
        },
      );
    }
  });

  group('step numeral of the sketch (01 /05)', () {
    testWidgets('steps 1-5 carry it, the start view does not', (tester) async {
      await _openForm(
        tester,
        repository: RecapListTestRepository(recapListOpen()),
      );
      expect(find.byType(ExomNumeral), findsNothing);
      await _press(tester, find.byKey(const ValueKey('recap-start')));
      for (var step = 1; step <= 5; step++) {
        final numeral = tester.widget<ExomNumeral>(find.byType(ExomNumeral));
        expect(numeral.value, '0$step');
        expect(numeral.unit, '/05');
        if (step < 5) {
          await _press(tester, find.byKey(const ValueKey('recap-step-action')));
        }
      }
    });
  });

  group('step numeral semantics and colour (r3)', () {
    testWidgets('the week is read in steps 1-5 and the decorative numeral is '
        'not', (tester) async {
      final handle = tester.ensureSemantics();
      await _openForm(
        tester,
        repository: RecapListTestRepository(recapListWithDraft()),
      );
      await _press(tester, find.byKey(const ValueKey('recap-start')));
      for (var step = 1; step <= 5; step++) {
        final week = tester.getSemantics(find.byKey(RecapWeekLabel.labelKey));
        expect(week.label, _weekText(const Locale('es')), reason: 'step $step');
        expect(find.bySemanticsLabel(RegExp('0$step ?/05')), findsNothing);
        if (step < 5) {
          await _press(tester, find.byKey(const ValueKey('recap-step-action')));
        }
      }
      handle.dispose();
    });

    testWidgets('the «/05» is muted, not data colour', (tester) async {
      await _openForm(
        tester,
        repository: RecapListTestRepository(recapListOpen()),
      );
      await _press(tester, find.byKey(const ValueKey('recap-start')));
      final palette = tester.element(find.byType(ExomNumeral)).exomPalette;
      final text = tester.widget<Text>(find.byKey(ExomNumeral.valueKey));
      final spans = <TextSpan>[];
      text.textSpan!.visitChildren((span) {
        if (span is TextSpan) spans.add(span);
        return true;
      });
      final unit = spans.firstWhere((span) => span.text == '/05');
      expect(unit.style?.color, palette.textMuted);
      expect(palette.textMuted, isNot(palette.data));
    });
  });

  group('the real buttons of the footer (I2)', () {
    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets('Comenzar, Siguiente and Anterior walk 0 to 5 and back '
          '(${locale.languageCode})', (tester) async {
        await _openForm(
          tester,
          repository: RecapListTestRepository(recapListOpen()),
          locale: locale,
        );
        final l10n = _l10n(tester);
        expect(_shownStep(tester), 0);
        expect(find.byKey(const ValueKey('recap-step-action')), findsNothing);

        await _press(tester, find.byKey(const ValueKey('recap-start')));
        expect(spy.stepChanges, [1]);
        expect(_shownStep(tester), 1);

        for (var step = 1; step < 5; step++) {
          expect(_action(tester).label, l10n.recapNextStep);
          await _press(tester, find.byKey(const ValueKey('recap-step-action')));
          expect(spy.stepChanges.last, step + 1);
          expect(_shownStep(tester), step + 1);
        }
        expect(spy.stepChanges, [1, 2, 3, 4, 5]);
        expect(_action(tester).label, l10n.sendRecap);

        for (var step = 5; step >= 1; step--) {
          await _press(tester, _quiet(l10n.previous));
          expect(spy.stepChanges.last, step - 1);
          expect(_shownStep(tester), step - 1);
        }
        expect(spy.stepChanges, [1, 2, 3, 4, 5, 4, 3, 2, 1, 0]);
        expect(find.byType(RecapStartView), findsOneWidget);
      });
    }

    testWidgets('two quick taps on Siguiente move one step, not two', (
      tester,
    ) async {
      await _openForm(
        tester,
        repository: RecapListTestRepository(recapListOpen()),
      );
      await _press(tester, find.byKey(const ValueKey('recap-start')));
      final action = find.byKey(const ValueKey('recap-step-action'));
      await tester.tap(action);
      await tester.tap(action);
      await _settle(tester);
      expect((_bloc(tester).state as RecapFormActive).step, 2);
      expect(_shownStep(tester), 2);
      expect(spy.stepChanges.where((step) => step > 2), isEmpty);
    });

    testWidgets('Guardar borrador sends RecapSaveRequested once and the '
        'draft reaches the repository', (tester) async {
      final repository = RecapListTestRepository(recapListOpen());
      await _openForm(tester, repository: repository);
      await _press(tester, find.byKey(const ValueKey('recap-start')));
      await _press(tester, find.byKey(const ValueKey('recap-step-action')));
      final save = _l10n(tester).recapSaveDraft;
      expect(_quietButton(tester, save).onPressed, isNotNull);
      await _press(tester, _quiet(save));
      expect(spy.events.whereType<RecapSaveRequested>(), hasLength(1));
      expect(spy.events.whereType<RecapSubmitRequested>(), isEmpty);
      expect(repository.writes, ['create']);
      expect(_bloc(tester).state, isA<RecapListLoaded>());
    });

    testWidgets('ENVIAR RECAP sends RecapSubmitRequested once and submits', (
      tester,
    ) async {
      final repository = RecapListTestRepository(recapListOpen());
      await _openForm(tester, repository: repository);
      _bloc(tester).add(const RecapStepChanged(5));
      await _settle(tester);
      expect(_action(tester).label, _l10n(tester).sendRecap);
      expect(_action(tester).onPressed, isNotNull);
      await _press(tester, find.byKey(const ValueKey('recap-step-action')));
      final submits = spy.events.whereType<RecapSubmitRequested>().toList();
      expect(submits, hasLength(1));
      expect(spy.events.whereType<RecapSaveRequested>(), isEmpty);
      expect(repository.writes, ['create', 'submit:A']);
    });
  });

  group('validation blocks saving and sending (I3)', () {
    testWidgets('with an invalid number of steps Guardar borrador and ENVIAR '
        'RECAP are disabled and pressing them sends nothing', (tester) async {
      final repository = RecapListTestRepository(recapListOpen());
      await _openForm(tester, repository: repository);
      final l10n = _l10n(tester);
      await _press(tester, find.byKey(const ValueKey('recap-start')));

      expect(_quietButton(tester, l10n.recapSaveDraft).onPressed, isNotNull);
      final steps = find.byType(TextField).first;
      await tester.ensureVisible(steps);
      await tester.enterText(steps, '250000');
      await _settle(tester);

      expect(_quietButton(tester, l10n.recapSaveDraft).onPressed, isNull);
      // Moving between steps is not blocked.
      expect(_action(tester).onPressed, isNotNull);
      await _press(tester, _quiet(l10n.recapSaveDraft));
      expect(spy.events.whereType<RecapSaveRequested>(), isEmpty);

      for (var step = 1; step < 5; step++) {
        await _press(tester, find.byKey(const ValueKey('recap-step-action')));
      }
      expect(_shownStep(tester), 5);
      expect(_action(tester).label, l10n.sendRecap);
      expect(_action(tester).onPressed, isNull);
      expect(_quietButton(tester, l10n.recapSaveDraft).onPressed, isNull);
      await _press(tester, find.byKey(const ValueKey('recap-step-action')));
      await _press(tester, _quiet(l10n.recapSaveDraft));
      expect(spy.events.whereType<RecapSubmitRequested>(), isEmpty);
      expect(spy.events.whereType<RecapSaveRequested>(), isEmpty);
      expect(repository.writes, isEmpty);
      expect(_bloc(tester).state, isA<RecapFormActive>());

      // Fixing the value enables them again.
      for (var step = 5; step > 1; step--) {
        await _press(tester, _quiet(l10n.previous));
      }
      final field = find.byType(TextField).first;
      await tester.ensureVisible(field);
      await tester.enterText(field, '8500');
      await _settle(tester);
      expect(_quietButton(tester, l10n.recapSaveDraft).onPressed, isNotNull);
    });
  });

  group('a draft with extreme saved values (I4)', () {
    RecapEntity draft() => recapFixture(
      id: 'D',
      extra: {
        'week_start_date': '2026-11-16',
        'week_end_date': '2026-11-22',
        'created_at': '2026-11-16',
        'status': 'DRAFT',
        'published_coach_summary': null,
        'draft_coach_summary': null,
        'admin_comments': null,
        'training_effort': 0,
        'improvement_app_rating': 1,
        'stress_enabled': true,
        'stress_level': 0,
        'hunger_level': null,
      },
    );

    Finder scope(WidgetTester tester, String label) => find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first;

    int? chipsSelected(WidgetTester tester, String label) => tester
        .widget<ExomScaleChips>(
          find.descendant(
            of: scope(tester, label),
            matching: find.byType(ExomScaleChips),
          ),
        )
        .selected;

    bool? noDataSelected(WidgetTester tester, String label) =>
        tester
            .widget<ExomChoiceChips<bool>>(
              find.descendant(
                of: scope(tester, label),
                matching: find.byType(ExomChoiceChips<bool>),
              ),
            )
            .selected ??
        false;

    testWidgets('reopens with face 1, 1 star, stress 0 and «Sin dato» chosen, '
        'and sending without touching sends the same', (tester) async {
      final repository = _WritingRepository([draft()]);
      await _openForm(tester, repository: repository);
      final l10n = _l10n(tester);
      await _press(tester, find.byKey(const ValueKey('recap-start')));

      // Face 0 of 0-4 is the chip 1.
      expect(chipsSelected(tester, l10n.overallEffort), 1);

      await _press(tester, find.byKey(const ValueKey('recap-step-action')));
      await _press(tester, find.byKey(const ValueKey('recap-step-action')));
      await _press(tester, find.byKey(const ValueKey('recap-step-action')));
      expect(_shownStep(tester), 4);
      expect(chipsSelected(tester, l10n.perceivedStress), 0);
      expect(noDataSelected(tester, l10n.perceivedStress), isFalse);
      expect(chipsSelected(tester, l10n.weeklyHunger), isNull);
      expect(noDataSelected(tester, l10n.weeklyHunger), isTrue);

      await _press(tester, find.byKey(const ValueKey('recap-step-action')));
      expect(_shownStep(tester), 5);
      expect(chipsSelected(tester, l10n.rateTheApp), 1);

      await _press(tester, find.byKey(const ValueKey('recap-step-action')));
      expect(spy.events.whereType<RecapSubmitRequested>(), hasLength(1));
      expect(repository.updates, hasLength(1));
      final sent = repository.updates.single;
      expect(sent['training_effort'], 0);
      expect(sent['improvement_app_rating'], 1);
      expect(sent['stress_level'], 0);
      // A «Sin dato» that was never written stays absent: not a stored null.
      expect(sent.containsKey('hunger_level'), isFalse);
      expect(sent['hunger_level'], isNull);
      expect(repository.writes, ['update:D', 'submit:D']);
    });
  });
}
