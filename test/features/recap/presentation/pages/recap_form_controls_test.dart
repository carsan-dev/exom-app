// L5-C5a · Recap, formulario por pasos: the value each rating control sends.
//
// D14-4 changes the control (faces, stars and optional chips become
// `ExomScaleChips`), not what is sent. Each test drives the control on the
// real form, saves the draft through the real bloc and reads the map that
// reaches the repository, so the same scenarios fix the contract with the
// previous controls and with the chips: same key, `int` type and number, the
// same value shown when it is left untouched, and `null` for «sin dato».
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_scale_chips.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'recap_list_redesign_test.dart'
    show RecapListTestRepository, pumpRecapList, recapListOpen;

/// Repository that keeps a copy of every map the bloc writes.
class _CapturingRepository extends RecapListTestRepository {
  _CapturingRepository() : super(recapListOpen());

  final captured = <Map<String, dynamic>>[];

  @override
  Future<RecapEntity> createRecap(Map<String, dynamic> data) {
    captured.add(Map<String, dynamic>.of(data));
    return super.createRecap(data);
  }

  @override
  Future<RecapEntity> updateRecap(String id, Map<String, dynamic> data) {
    captured.add(Map<String, dynamic>.of(data));
    return super.updateRecap(id, data);
  }
}

enum _Kind { faces, stars, optional }

class _Control {
  const _Control(
    this.key,
    this.step,
    this.kind,
    this.label, {
    required this.min,
    required this.max,
    this.initial,
  });

  final String key;
  final int step;
  final _Kind kind;
  final String Function(AppLocalizations l10n) label;

  /// Range of the value that is sent.
  final int min;
  final int max;

  /// Value shown when the form has none (never written until it is touched).
  final int? initial;
}

final _controls = <_Control>[
  _Control(
    'training_effort',
    1,
    _Kind.faces,
    (l) => l.overallEffort,
    min: 0,
    max: 4,
    initial: 2,
  ),
  _Control(
    'training_sessions',
    1,
    _Kind.faces,
    (l) => l.completedSessions,
    min: 0,
    max: 4,
    initial: 2,
  ),
  _Control(
    'food_quality',
    2,
    _Kind.faces,
    (l) => l.mealQuality,
    min: 0,
    max: 4,
    initial: 2,
  ),
  _Control(
    'improvement_service_rating',
    5,
    _Kind.stars,
    (l) => l.rateTheService,
    min: 1,
    max: 5,
    initial: 4,
  ),
  _Control(
    'improvement_app_rating',
    5,
    _Kind.stars,
    (l) => l.rateTheApp,
    min: 1,
    max: 5,
    initial: 4,
  ),
  _Control(
    'hunger_level',
    4,
    _Kind.optional,
    (l) => l.weeklyHunger,
    min: 1,
    max: 10,
  ),
  _Control(
    'energy_level',
    4,
    _Kind.optional,
    (l) => l.weeklyEnergy,
    min: 1,
    max: 10,
  ),
  _Control(
    'digestion_level',
    4,
    _Kind.optional,
    (l) => l.weeklyDigestion,
    min: 1,
    max: 10,
  ),
  _Control(
    'stress_level',
    4,
    _Kind.optional,
    (l) => l.perceivedStress,
    min: 0,
    max: 5,
  ),
];

const _faces = ['😫', '😞', '😐', '🙂', '😁'];

RecapBloc _bloc(WidgetTester tester) =>
    BlocProvider.of<RecapBloc>(tester.element(find.byType(Scaffold).first));

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

/// The question the control belongs to: the nearest column holding its label.
Finder _scope(WidgetTester tester, _Control control) {
  final label = control.label(_l10n(tester));
  return find.ancestor(of: find.text(label), matching: find.byType(Column));
}

bool _usesChips(WidgetTester tester, _Control control) => find
    .descendant(
      of: _scope(tester, control).first,
      matching: find.byType(ExomScaleChips),
    )
    .evaluate()
    .isNotEmpty;

Future<void> _pick(WidgetTester tester, _Control control, int value) async {
  final scope = _scope(tester, control).first;
  final Finder target;
  if (_usesChips(tester, control)) {
    // Faces are written by index (0-4) and shown as 1-5.
    final shown = control.kind == _Kind.faces ? value + 1 : value;
    target = find.descendant(of: scope, matching: find.text('$shown'));
  } else {
    target = switch (control.kind) {
      _Kind.faces => find.descendant(
        of: scope,
        matching: find.text(_faces[value]),
      ),
      _Kind.stars => find
          .descendant(of: scope, matching: find.byIcon(ExomIcons.star))
          .at(value - 1),
      _Kind.optional => find.descendant(
        of: scope,
        matching: find.text('$value'),
      ),
    };
  }
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pickNoData(WidgetTester tester, _Control control) async {
  final target = find.descendant(
    of: _scope(tester, control).first,
    matching: find.text(_l10n(tester).optionalRatingNoData),
  );
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 300));
}

/// The value the control shows as chosen, in the encoding that is sent.
int? _shown(WidgetTester tester, _Control control) {
  final scope = _scope(tester, control).first;
  if (_usesChips(tester, control)) {
    final chips = tester.widget<ExomScaleChips>(
      find.descendant(of: scope, matching: find.byType(ExomScaleChips)),
    );
    final selected = chips.selected;
    if (selected == null) return null;
    return control.kind == _Kind.faces ? selected - 1 : selected;
  }
  switch (control.kind) {
    case _Kind.faces:
      final boxes = tester.widgetList<AnimatedContainer>(
        find.descendant(of: scope, matching: find.byType(AnimatedContainer)),
      );
      final marked = <int>[
        for (final (i, box) in boxes.indexed)
          if (((box.decoration! as BoxDecoration).border! as Border)
                  .top
                  .width ==
              2)
            i,
      ];
      expect(marked.length, lessThanOrEqualTo(1));
      return marked.isEmpty ? null : marked.single;
    case _Kind.stars:
      final warning = Theme.of(tester.element(scope)).extension<ExomSemanticPalette>()!;
      final filled = tester
          .widgetList<Icon>(
            find.descendant(of: scope, matching: find.byIcon(ExomIcons.star)),
          )
          .where((icon) => icon.color == warning.warning)
          .length;
      return filled == 0 ? null : filled;
    case _Kind.optional:
      final selected = tester
          .widgetList<ChoiceChip>(
            find.descendant(of: scope, matching: find.byType(ChoiceChip)),
          )
          .where((chip) => chip.selected)
          .map((chip) => (chip.label as Text).data)
          .toList();
      expect(selected, hasLength(1));
      return int.tryParse(selected.single ?? '');
  }
}

Future<_CapturingRepository> _openStep(
  WidgetTester tester,
  _Control control,
  Locale locale,
) async {
  final repository = _CapturingRepository();
  await pumpRecapList(tester, repository: repository, locale: locale);
  await tester.tap(find.byKey(const ValueKey('recap-new')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  _bloc(tester).add(RecapStepChanged(control.step));
  await tester.pump();
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  if (control.key == 'stress_level') {
    final toggle = find.text(_l10n(tester).rateStressLevel);
    await tester.ensureVisible(toggle);
    await tester.pump();
    await tester.tap(toggle);
    await tester.pump(const Duration(milliseconds: 300));
  }
  return repository;
}

/// Saves the draft and returns the map that reached the repository.
Future<Map<String, dynamic>> _sent(
  WidgetTester tester,
  _CapturingRepository repository,
) async {
  _bloc(tester).add(const RecapSaveRequested());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(repository.captured, hasLength(1));
  return repository.captured.single;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });
  tearDown(() async => sl.reset());

  for (final locale in const [Locale('es'), Locale('en')]) {
    group('payload of the rating controls (${locale.languageCode})', () {
      for (final control in _controls) {
        final range = [control.min, control.max];

        testWidgets('${control.key}: untouched shows ${control.initial} and '
            'sends nothing for it', (tester) async {
          final repository = await _openStep(tester, control, locale);
          expect(_shown(tester, control), control.initial);
          final data = await _sent(tester, repository);
          expect(data.containsKey(control.key), isFalse);
        });

        for (final value in range) {
          testWidgets('${control.key}: choosing $value sends the int $value', (
            tester,
          ) async {
            final repository = await _openStep(tester, control, locale);
            await _pick(tester, control, value);
            expect(_shown(tester, control), value);
            final data = await _sent(tester, repository);
            expect(data[control.key], isA<int>());
            expect(data[control.key], value);
          });
        }

        if (control.initial != null) {
          testWidgets('${control.key}: tapping the value shown writes it', (
            tester,
          ) async {
            final repository = await _openStep(tester, control, locale);
            await _pick(tester, control, control.initial!);
            final data = await _sent(tester, repository);
            expect(data[control.key], control.initial);
          });
        } else {
          testWidgets('${control.key}: «sin dato» sends null', (tester) async {
            final repository = await _openStep(tester, control, locale);
            await _pick(tester, control, control.min + 1);
            await _pickNoData(tester, control);
            expect(_shown(tester, control), isNull);
            final data = await _sent(tester, repository);
            expect(data.containsKey(control.key), isTrue);
            expect(data[control.key], isNull);
          });

          testWidgets('${control.key}: «sin dato» with no previous value '
              'writes null', (tester) async {
            final repository = await _openStep(tester, control, locale);
            await _pickNoData(tester, control);
            final data = await _sent(tester, repository);
            expect(data.containsKey(control.key), isTrue);
            expect(data[control.key], isNull);
          });

          testWidgets('${control.key}: choosing the same value again clears '
              'it to null', (tester) async {
            final repository = await _openStep(tester, control, locale);
            await _pick(tester, control, control.max);
            await _pick(tester, control, control.max);
            expect(_shown(tester, control), isNull);
            final data = await _sent(tester, repository);
            expect(data.containsKey(control.key), isTrue);
            expect(data[control.key], isNull);
          });
        }
      }
    });
  }
}
