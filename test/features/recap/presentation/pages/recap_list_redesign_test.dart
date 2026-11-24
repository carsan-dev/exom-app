// L5-C4 · Recap, lista: visible structure and behaviour of sketch «C3 · Recap
// semanal, lista» (pinned footer instead of the floating button, one row per
// week with three values, featured row with a new trainer comment, empty and
// error states in the L5 vocabulary, blocked reason in line) in both themes and
// under large text.
import 'dart:async';

import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_step_transition.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/home/presentation/widgets/home_clock.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';
import 'package:exom_app/features/recap/presentation/pages/recap_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../core/theme/wcag_contrast.dart';
import '../../../../core/widgets/expect_no_lime_ink.dart';
import '../bloc/recap_bloc_test.dart'
    show RecapTestRepository, recapTestBloc, recapFixture;

/// Fixed clock of the fixture: Thursday 19 Nov 2026, week 16-22 Nov.
final DateTime recapListNow = DateTime(2026, 11, 19, 12);

/// Repository whose list is set by the test.
class RecapListTestRepository extends RecapTestRepository {
  RecapListTestRepository(this.recaps, {this.error, this.updateError});

  final List<RecapEntity> recaps;

  /// Failure of the load; it can be set after the first load succeeds.
  Object? error;

  /// Failure of the draft update (a save from the form).
  final Object? updateError;

  @override
  Future<RecapEntity> updateRecap(String id, Map<String, dynamic> data) async {
    final failure = updateError;
    if (failure != null) throw failure;
    return super.updateRecap(id, data);
  }

  @override
  Future<List<RecapEntity>> getMyRecaps() async {
    final failure = error;
    if (failure != null) throw failure;
    return recaps;
  }
}

RecapEntity _week(
  String id,
  String start,
  String end,
  String status, {
  Map<String, Object?> extra = const {},
}) => recapFixture(
  id: id,
  extra: {
    'week_start_date': start,
    'week_end_date': end,
    'created_at': start,
    'status': status,
    'published_coach_summary': null,
    'draft_coach_summary': null,
    'admin_comments': null,
    ...extra,
  },
);

/// Draft of this week, a reviewed week with a new trainer comment, a sent one
/// and a reviewed one without rating of nutrition and mood.
List<RecapEntity> recapListWithDraft() => [
  _week(
    'D',
    '2026-11-16',
    '2026-11-22',
    'DRAFT',
    extra: {'training_progress': 'MEJORANDO'},
  ),
  _week(
    'R',
    '2026-11-09',
    '2026-11-15',
    'REVIEWED',
    extra: {
      'training_progress': 'ESTABLE',
      'nutrition_quality': 'ALTA',
      'mood': 'BIEN',
      'client_feedback_text': 'Gran semana.',
      'client_feedback_sent_at': '2026-11-16T10:00:00Z',
    },
  ),
  _week(
    'S',
    '2026-11-02',
    '2026-11-08',
    'SUBMITTED',
    extra: {
      'training_progress': 'MEJORANDO',
      'nutrition_quality': 'MUY_ALTA',
      'mood': 'MUY_BIEN',
    },
  ),
  _week(
    'O',
    '2026-10-26',
    '2026-11-01',
    'REVIEWED',
    extra: {
      'training_progress': 'ESTABLE',
      'nutrition_quality': 'MODERADA',
      'mood': 'REGULAR',
    },
  ),
];

/// This week's recap already sent: the new-recap action is blocked.
List<RecapEntity> recapListBlocked() => [
  _week(
    'T',
    '2026-11-16',
    '2026-11-22',
    'SUBMITTED',
    extra: {
      'training_progress': 'MEJORANDO',
      'nutrition_quality': 'ALTA',
      'mood': 'BIEN',
    },
  ),
  ...recapListWithDraft().skip(1),
];

/// Last week only: this week is free, so the action is a new recap.
List<RecapEntity> recapListOpen() => recapListWithDraft().skip(1).toList();

/// A scene with long labels and no spaces, for large text.
List<RecapEntity> recapListRich() => [
  _week(
    'D',
    '2026-11-16',
    '2026-11-22',
    'DRAFT',
    extra: {'training_progress': 'MUY_MEJORANDO_PALABRALARGA'},
  ),
  ...recapListWithDraft().skip(1),
];

Future<GoRouter> pumpRecapList(
  WidgetTester tester, {
  List<RecapEntity> recaps = const [],
  Object? error,
  bool dark = false,
  double width = 390,
  double height = 844,
  Locale locale = const Locale('es'),
  TextScaler textScaler = TextScaler.noScaling,
  bool settle = true,
  RecapListTestRepository? repository,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  sl.registerSingleton<LocalStorage>(LocalStorage());
  final repo = repository ?? RecapListTestRepository(recaps, error: error);
  final bloc = recapTestBloc(repo);
  sl.registerFactory<RecapBloc>(() => bloc);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/recap',
        builder: (_, _) => const RecapPage(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                Scaffold(body: Text('detail-${state.pathParameters['id']}')),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.dark : AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      routerConfig: router,
      builder: (context, child) => HomeClock(
        now: () => recapListNow,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  unawaited(router.push('/recap'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  if (settle) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
  return router;
}

RecapBloc _blocOf(WidgetTester tester) =>
    BlocProvider.of<RecapBloc>(tester.element(find.byType(Scaffold).first));

/// Icon and colour of the state mark inside the row of [id].
({IconData icon, Color colour, Color labelColour}) _statusOf(
  WidgetTester tester,
  String id,
  String label,
) {
  final row = find.byKey(ValueKey('recap-row-$id'));
  final icons = <Icon>[
    for (final icon in const [
      ExomIcons.check,
      ExomIcons.time,
      ExomIcons.upload,
    ])
      ...tester.widgetList<Icon>(
        find.descendant(of: row, matching: find.byIcon(icon)),
      ),
  ];
  expect(icons, hasLength(1), reason: 'one state mark in row $id');
  final text = tester.widget<Text>(
    find.descendant(of: row, matching: find.text(label)),
  );
  return (
    icon: icons.single.icon!,
    colour: icons.single.color!,
    labelColour: text.style!.color!,
  );
}

Color? _fillOf(WidgetTester tester, Finder button) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: button, matching: find.byType(DecoratedBox)).first,
  );
  return (box.decoration as BoxDecoration).color;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
  });
  tearDown(() async => sl.reset());

  final newRecap = find.byKey(const ValueKey('recap-new'));

  group('pinned action', () {
    testWidgets('there is no floating button; the footer carries newRecap', (
      tester,
    ) async {
      await pumpRecapList(tester, recaps: recapListOpen());
      expect(find.byType(FloatingActionButton), findsNothing);
      final footer = find.byType(ExomPinnedFooter);
      expect(footer, findsOneWidget);
      expect(find.descendant(of: footer, matching: newRecap), findsOneWidget);
      final l10n = AppLocalizations.of(tester.element(footer));
      expect(
        find.descendant(
          of: newRecap,
          matching: find.text(l10n.newRecap.toUpperCase()),
        ),
        findsOneWidget,
      );
    });

    testWidgets('it opens the new recap form, as the floating button did', (
      tester,
    ) async {
      await pumpRecapList(tester, recaps: recapListOpen());
      await tester.tap(newRecap);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ExomStepTransition), findsOneWidget);
      // A new form: no recap id and nothing but this week's dates.
      final form = _blocOf(tester).state as RecapFormActive;
      expect(form.recapId, isNull);
      expect(form.step, 0);
      expect(form.formData.keys, {'week_start_date', 'week_end_date'});
    });

    testWidgets('a draft of this week turns it into «Continuar borrador»', (
      tester,
    ) async {
      await pumpRecapList(tester, recaps: recapListWithDraft());
      expect(
        find.descendant(
          of: newRecap,
          matching: find.text('CONTINUAR BORRADOR'),
        ),
        findsOneWidget,
      );
      await tester.tap(newRecap);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ExomStepTransition), findsOneWidget);
      // It loads that draft: its id, its week and its values.
      final form = _blocOf(tester).state as RecapFormActive;
      expect(form.recapId, 'D');
      expect(form.formData['week_start_date'], '2026-11-16');
      expect(form.formData['week_end_date'], '2026-11-22');
      expect(form.formData['training_progress'], 'MEJORANDO');
    });

    testWidgets('blocked: the reason is in line, there is no SnackBar and the '
        'button is not lime', (tester) async {
      await pumpRecapList(tester, recaps: recapListBlocked());
      final footer = find.byType(ExomPinnedFooter);
      expect(
        find.descendant(
          of: footer,
          matching: find.text('Ya tienes un recap subido esta semana'),
        ),
        findsOneWidget,
      );
      final button = tester.widget<ExomPrimaryButton>(newRecap);
      expect(button.onPressed, isNull);
      expect(_fillOf(tester, newRecap), isNot(AppColors.primary));
      await tester.tap(newRecap, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(ExomStepTransition), findsNothing);
    });

    testWidgets('not blocked: the button is lime and there is no reason', (
      tester,
    ) async {
      await pumpRecapList(tester, recaps: recapListOpen());
      expect(_fillOf(tester, newRecap), AppColors.primary);
      expect(find.text('Ya tienes un recap subido esta semana'), findsNothing);
    });
  });

  group('list', () {
    testWidgets('title, week of the fixture clock and two-line headline', (
      tester,
    ) async {
      await pumpRecapList(tester, recaps: recapListWithDraft());
      expect(find.text('RECAP SEMANAL'), findsOneWidget);
      expect(
        find.text('Semana del 16 de noviembre al 22 de noviembre'),
        findsOneWidget,
      );
      expect(find.text('TU SEMANA.'), findsOneWidget);
      expect(find.text('TAMBIÉN CUENTA.'), findsOneWidget);
    });

    testWidgets('the unread comment count is the protagonist', (tester) async {
      await pumpRecapList(tester, recaps: recapListWithDraft());
      expect(find.byType(ExomNumeral), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('comentario nuevo de tu entrenador'), findsOneWidget);
      // The featured row repeats where it is, as in the sketch.
      expect(find.text('Nuevo comentario de tu entrenador'), findsOneWidget);
    });

    testWidgets('no unread comment: no numeral, the headline stays', (
      tester,
    ) async {
      await pumpRecapList(tester, recaps: recapListBlocked().skip(2).toList());
      expect(find.byType(ExomNumeral), findsNothing);
      expect(find.text('TU SEMANA.'), findsOneWidget);
      expect(find.text('Nuevo comentario de tu entrenador'), findsNothing);
    });

    testWidgets('one row per week, with its three values and its state', (
      tester,
    ) async {
      await pumpRecapList(tester, recaps: recapListWithDraft());
      for (final range in const [
        '16 nov - 22 nov',
        '09 nov - 15 nov',
        '02 nov - 08 nov',
        '26 oct - 01 nov',
      ]) {
        expect(find.text(range), findsOneWidget, reason: range);
      }
      expect(find.text('Borrador'), findsOneWidget);
      expect(find.text('Enviado'), findsOneWidget);
      expect(find.text('Revisado'), findsNWidgets(2));
      // Three labels per row.
      expect(find.text('Entreno'), findsNWidgets(4));
      expect(find.text('Nutrición'), findsNWidgets(4));
      expect(find.text('Ánimo'), findsNWidgets(4));
      // The draft has no nutrition and no mood: both are «Sin valorar».
      expect(find.text('Sin valorar'), findsNWidgets(2));
      expect(find.text('MEJORANDO'), findsNWidgets(2));
      expect(find.text('MUY BIEN'), findsOneWidget);
    });

    testWidgets('no card, no chip and no old history card', (tester) async {
      await pumpRecapList(tester, recaps: recapListWithDraft());
      expect(find.text('Tu histórico semanal'), findsNothing);
      expect(find.text('Ver resumen'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    for (final (id, range, kind) in const [
      ('R', '09 nov - 15 nov', 'reviewed'),
      ('S', '02 nov - 08 nov', 'sent'),
    ]) {
      testWidgets('a $kind row opens its detail', (tester) async {
        await pumpRecapList(tester, recaps: recapListWithDraft(), height: 1400);
        await tester.tap(find.text(range));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('detail-$id'), findsOneWidget);
      });
    }

    testWidgets('a draft row opens the form with its week', (tester) async {
      await pumpRecapList(tester, recaps: recapListWithDraft());
      await tester.tap(find.text('16 nov - 22 nov'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ExomStepTransition), findsOneWidget);
      final form = _blocOf(tester).state as RecapFormActive;
      expect(form.recapId, 'D');
      expect(form.formData['week_start_date'], '2026-11-16');
      expect(form.formData['training_progress'], 'MEJORANDO');
    });

    group('state of the row (D19)', () {
      for (final dark in [true, false]) {
        testWidgets('draft pending, sent and reviewed confirmed (dark=$dark)', (
          tester,
        ) async {
          await pumpRecapList(
            tester,
            recaps: recapListWithDraft(),
            dark: dark,
            height: 1400,
          );
          final context = tester.element(
            find.byKey(const ValueKey('recap-row-D')),
          );
          final palette = context.exomPalette;
          final warning = context.exomSemantic.warning;

          // DRAFT: pending, amber with a clock.
          final draft = _statusOf(tester, 'D', 'Borrador');
          expect(draft.icon, ExomIcons.time);
          expect(draft.colour, warning);
          expect(draft.labelColour, warning);

          // SUBMITTED: the list comes from the server, so it is confirmed:
          // text colour with a check, never the «sending» cloud.
          final sent = _statusOf(tester, 'S', 'Enviado');
          expect(sent.icon, ExomIcons.check);
          expect(sent.colour, palette.textPrimary);
          expect(sent.labelColour, palette.textPrimary);

          // REVIEWED: confirmed too.
          final reviewed = _statusOf(tester, 'R', 'Revisado');
          expect(reviewed.icon, ExomIcons.check);
          expect(reviewed.colour, palette.textPrimary);
          expect(reviewed.labelColour, palette.textPrimary);

          // No row shows the upload cloud or the lime.
          expect(find.byIcon(ExomIcons.upload), findsNothing);
          if (!dark) expectNoLimeInk(tester);
        });
      }

      testWidgets('the sent label in English is «Submitted»', (tester) async {
        await pumpRecapList(
          tester,
          recaps: recapListWithDraft(),
          locale: const Locale('en'),
          height: 1400,
        );
        expect(_statusOf(tester, 'S', 'Submitted').icon, ExomIcons.check);
      });
    });

    testWidgets('the retry action in the bar reloads the list', (tester) async {
      final repository = RecapListTestRepository(recapListOpen());
      await pumpRecapList(tester, repository: repository);
      await tester.tap(find.byTooltip('Reintentar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('RECAP SEMANAL'), findsOneWidget);
    });
  });

  group('empty and error', () {
    testWidgets('empty: headline, trainer voice and first-recap action', (
      tester,
    ) async {
      await pumpRecapList(tester);
      final headline = tester.widget<ExomTwoLineHeadline>(
        find.byType(ExomTwoLineHeadline).last,
      );
      expect(headline.first, 'Sin recaps.');
      expect(headline.second, 'Todavía.');
      expect(find.text('Todavía no has enviado ningún recap'), findsOneWidget);
      expect(find.byType(ExomCoachBlock), findsOneWidget);
      // D16: no trainer name in the model, so the signature is «tu entrenador»
      // as the contract writes it (sketch: «Moi · tu entrenador»).
      expect(find.text('tu entrenador'), findsOneWidget);
      expect(find.text('Tu entrenador'), findsNothing);
      expect(find.text('Moi'), findsNothing);
      expect(
        find.descendant(
          of: newRecap,
          matching: find.text('CREAR MI PRIMER RECAP'),
        ),
        findsOneWidget,
      );
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('empty: the action opens the form', (tester) async {
      await pumpRecapList(tester);
      await tester.tap(newRecap);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ExomStepTransition), findsOneWidget);
    });

    testWidgets('error: headline with the second line in the error colour', (
      tester,
    ) async {
      await pumpRecapList(tester, error: Exception('boom'));
      final headline = tester.widget<ExomTwoLineHeadline>(
        find.byType(ExomTwoLineHeadline).last,
      );
      // The state does not say the cause was the network (5xx, save, parse):
      // the headline does not claim it and the real cause stays below.
      expect(headline.first, 'Algo ha fallado');
      expect(headline.second, 'con el recap.');
      expect(headline.isError, isTrue);
      expect(find.text('Sin conexión'), findsNothing);
      expect(find.text('No se pudo cargar el recap'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(ExomPinnedFooter), findsNothing);
    });

    testWidgets('error in English: neutral headline too', (tester) async {
      await pumpRecapList(
        tester,
        error: Exception('boom'),
        locale: const Locale('en'),
      );
      final headline = tester.widget<ExomTwoLineHeadline>(
        find.byType(ExomTwoLineHeadline).last,
      );
      expect(headline.first, 'Something went wrong');
      expect(headline.second, 'with the recap.');
      expect(find.text('No connection'), findsNothing);
    });

    testWidgets('a failed load shows the line only, with no SnackBar', (
      tester,
    ) async {
      await pumpRecapList(tester, error: Exception('boom'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('No se pudo cargar el recap'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.textContaining('No se pudo guardar el resumen semanal'),
        findsNothing,
      );
    });

    testWidgets('a failed retry of the load shows no SnackBar either', (
      tester,
    ) async {
      await pumpRecapList(tester, error: Exception('boom'));
      await tester.tap(find.byKey(const ValueKey('recap-retry')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('cancelling the form and failing to reload shows the line '
        'only, with no SnackBar', (tester) async {
      final repository = RecapListTestRepository(recapListWithDraft());
      await pumpRecapList(tester, repository: repository);
      await tester.tap(find.text('16 nov - 22 nov'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_blocOf(tester).state, isA<RecapFormActive>());
      repository.error = Exception('boom');
      await tester.tap(find.byIcon(ExomIcons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_blocOf(tester).state, isA<RecapError>());
      expect(find.text('No se pudo cargar el recap'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failed save from the form keeps its SnackBar', (
      tester,
    ) async {
      await pumpRecapList(
        tester,
        repository: RecapListTestRepository(
          recapListWithDraft(),
          updateError: Exception('boom'),
        ),
      );
      await tester.tap(find.text('16 nov - 22 nov'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_blocOf(tester).state, isA<RecapFormActive>());
      _blocOf(tester).add(const RecapSaveRequested());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('No se pudo guardar el resumen semanal. Inténtalo de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('error: «Reintentar» loads again', (tester) async {
      await pumpRecapList(tester, error: Exception('boom'));
      await tester.tap(find.byKey(const ValueKey('recap-retry')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('recap-retry')), findsOneWidget);
    });
  });

  group('long values in the figures (D1)', () {
    List<RecapEntity> longValues() => [
      _week(
        'L',
        '2026-11-16',
        '2026-11-22',
        'SUBMITTED',
        extra: {
          'training_progress': 'EXCELENTE',
          'nutrition_quality': 'MUY_BUENA',
          'mood': 'MUY_BIEN',
        },
      ),
      _week(
        'M',
        '2026-11-09',
        '2026-11-15',
        'REVIEWED',
        extra: {
          'training_progress': 'MEJORANDO',
          'nutrition_quality': 'MUY_BUENA',
          'mood': 'MUY_MAL',
        },
      ),
    ];

    /// Every painted line of [finder] starts and ends on a word boundary.
    void expectWholeWords(WidgetTester tester, Finder finder) {
      for (final element in finder.evaluate()) {
        final text = (element.widget as Text).data!;
        final paragraph = element.renderObject! as RenderParagraph;
        final starts = <int>[0];
        double? previousTop;
        for (var i = 0; i < text.length; i++) {
          if (text[i] == ' ') continue;
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: i + 1),
          );
          final top = boxes.first.top;
          if (previousTop != null && top > previousTop + 1) starts.add(i);
          previousTop = top;
        }
        expect(starts, isNotEmpty);
        for (final start in starts) {
          expect(
            start == 0 || text[start - 1] == ' ',
            isTrue,
            reason: '«$text» breaks a line inside a word at $start',
          );
        }
      }
    }

    final cases = <(String, double, double, Locale, List<String>)>[
      ('es', 360, 1.0, const Locale('es'),
          ['EXCELENTE', 'MEJORANDO', 'MUY BUENA', 'MUY BIEN', 'MUY MAL']),
      ('es', 411, 1.3, const Locale('es'),
          ['EXCELENTE', 'MEJORANDO', 'MUY BUENA', 'MUY BIEN', 'MUY MAL']),
      ('es', 320, 1.0, const Locale('es'),
          ['EXCELENTE', 'MEJORANDO', 'MUY BUENA', 'MUY BIEN', 'MUY MAL']),
      ('en', 360, 1.0, const Locale('en'),
          ['EXCELLENT', 'IMPROVING', 'VERY GOOD', 'VERY BAD']),
      ('en', 411, 1.3, const Locale('en'),
          ['EXCELLENT', 'IMPROVING', 'VERY GOOD', 'VERY BAD']),
      ('en', 320, 1.0, const Locale('en'),
          ['EXCELLENT', 'IMPROVING', 'VERY GOOD', 'VERY BAD']),
    ];
    /// Left edges of the trio cells of the row [id]: one per column.
    Set<double> columnsOf(WidgetTester tester, String id) {
      final row = find.byKey(ValueKey('recap-row-$id'));
      return {
        for (final label in const ['Entreno', 'Nutrición', 'Ánimo'])
          tester
              .getTopLeft(
                find.descendant(of: row, matching: find.text(label)),
              )
              .dx,
      };
    }

    testWidgets('360dp 1.0x: short and long rows share their columns', (
      tester,
    ) async {
      await pumpRecapList(
        tester,
        recaps: [
          _week(
            'A',
            '2026-11-16',
            '2026-11-22',
            'SUBMITTED',
            extra: {
              'training_progress': 'ALTA',
              'nutrition_quality': 'ALTA',
              'mood': 'BIEN',
            },
          ),
          _week(
            'B',
            '2026-11-09',
            '2026-11-15',
            'SUBMITTED',
            extra: {
              'training_progress': 'EXCELENTE',
              'nutrition_quality': 'ALTA',
              'mood': 'BIEN',
            },
          ),
        ],
        width: 360,
      );
      expect(columnsOf(tester, 'A').length, columnsOf(tester, 'B').length);
      expect(columnsOf(tester, 'A'), columnsOf(tester, 'B'));
    });

    testWidgets('1.6x: whole words and the same columns in every row', (
      tester,
    ) async {
      await pumpRecapList(
        tester,
        recaps: longValues(),
        width: 360,
        textScaler: AndroidNonlinearTextScaler(1.6),
      );
      expect(columnsOf(tester, 'L'), columnsOf(tester, 'M'));
      for (final value in const ['EXCELENTE', 'MEJORANDO', 'MUY BUENA']) {
        expectWholeWords(tester, find.text(value));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x with «Sin valorar»: whole words, shared columns', (
      tester,
    ) async {
      await pumpRecapList(
        tester,
        recaps: [
          ...longValues(),
          _week('N', '2026-11-02', '2026-11-08', 'DRAFT'),
        ],
        width: 360,
        textScaler: AndroidNonlinearTextScaler(1.6),
      );
      expectWholeWords(tester, find.text('Sin valorar'));
      expect(columnsOf(tester, 'N'), columnsOf(tester, 'L'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a no-break space does not split a word', (tester) async {
      // «MUY\u00A0BUENA» is one word: with a regular space it would fit in the
      // columns of «BUENA»; as one word it needs as many columns as it takes.
      List<RecapEntity> rows(String value) => [
        _week(
          'A',
          '2026-11-16',
          '2026-11-22',
          'SUBMITTED',
          extra: {
            'training_progress': 'ALTA',
            'nutrition_quality': value,
            'mood': 'BIEN',
          },
        ),
      ];
      await pumpRecapList(tester, recaps: rows('MUY_BUENA'), width: 360);
      final spaced = columnsOf(tester, 'A').length;
      tester.view.resetPhysicalSize();
      await tester.pumpWidget(const SizedBox());
      await sl.reset();
      await pumpRecapList(tester, recaps: rows('MUY\u00A0BUENA'), width: 360);
      expect(
        columnsOf(tester, 'A').length,
        lessThan(spaced),
        reason: 'NBSP value is one word, so its cell is wider',
      );
      expect(tester.takeException(), isNull);
    });

    for (final (name, width, scale, locale, values) in cases) {
      testWidgets('$name ${width.toInt()}dp ${scale}x: no word is split', (
        tester,
      ) async {
        await pumpRecapList(
          tester,
          recaps: longValues(),
          width: width,
          locale: locale,
          textScaler: AndroidNonlinearTextScaler(scale),
        );
        for (final value in values) {
          final finder = find.text(value);
          expect(finder, findsWidgets, reason: value);
          expectWholeWords(tester, finder);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('featured row bar (H2)', () {
    for (final scale in const [1.0, 1.6]) {
      testWidgets('360dp ${scale}x: the bar belongs to its row', (
        tester,
      ) async {
        await pumpRecapList(
          tester,
          recaps: recapListWithDraft(),
          width: 360,
          textScaler: AndroidNonlinearTextScaler(scale),
        );
        final block = tester.getRect(find.byType(ExomFeatureBlock));
        final featured = find.byKey(const ValueKey('recap-row-R'));
        final previous = find.byKey(const ValueKey('recap-row-D'));
        double lowestText(Finder row) => find
            .descendant(of: row, matching: find.byType(Text))
            .evaluate()
            .map((e) => tester.getRect(find.byWidget(e.widget)).bottom)
            .reduce((a, b) => a > b ? a : b);
        final above = block.top - lowestText(previous);
        final below =
            tester.getRect(find.text('09 nov - 15 nov')).top -
            (block.top + ExomRule.bar);
        expect(below, lessThan(above));
        expect(above, greaterThanOrEqualTo(24));
        expect(below, lessThanOrEqualTo(12));
        expect(featured, findsOneWidget);
      });
    }
  });

  group('unread hero (H1)', () {
    testWidgets('headline first, then the numeral with its label under it', (
      tester,
    ) async {
      await pumpRecapList(tester, recaps: recapListWithDraft());
      final headline = tester.getTopLeft(find.byType(ExomTwoLineHeadline).first);
      final numeral = find.byKey(ExomNumeral.valueKey);
      final label = find.text('comentario nuevo de tu entrenador');
      expect(numeral, findsOneWidget);
      expect(label, findsOneWidget);
      expect(headline.dy, lessThan(tester.getTopLeft(numeral).dy));
      final gap = tester.getTopLeft(label).dy - tester.getBottomLeft(numeral).dy;
      expect(gap, inInclusiveRange(0, 16));
      expect(tester.getTopLeft(label).dx, tester.getTopLeft(numeral).dx);
      // Nothing sits between the numeral and its label.
      final hero = find.byKey(const ValueKey('recap-unread-hero'));
      expect(
        find.descendant(of: hero, matching: find.byType(ExomTwoLineHeadline)),
        findsNothing,
      );
    });

    for (final (locale, text) in const [
      (Locale('es'), '2 comentarios nuevos de tu entrenador'),
      (Locale('en'), '2 new comments from your coach'),
    ]) {
      testWidgets('two unread comments: plural label (${locale.languageCode})', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpRecapList(
          tester,
          locale: locale,
          recaps: [
            ...recapListWithDraft(),
            _week(
              'U2',
              '2026-10-19',
              '2026-10-25',
              'REVIEWED',
              extra: {
                'client_feedback_text': 'Otra.',
                'client_feedback_sent_at': '2026-10-26T10:00:00Z',
              },
            ),
          ],
        );
        expect(
          (tester.widget<Text>(find.byKey(ExomNumeral.valueKey)).textSpan!)
              .toPlainText(),
          contains('2'),
        );
        expect(
          tester
              .getSemantics(find.byKey(const ValueKey('recap-unread-hero')))
              .label,
          text,
        );
        handle.dispose();
      });
    }

    testWidgets('the numeral and its label read as one node', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRecapList(tester, recaps: recapListWithDraft());
      final semantics = tester.getSemantics(
        find.byKey(const ValueKey('recap-unread-hero')),
      );
      expect(semantics.label, '1 comentario nuevo de tu entrenador');
      handle.dispose();
    });

    testWidgets('without unread comments only the headline shows', (
      tester,
    ) async {
      await pumpRecapList(
        tester,
        recaps: [_week('N', '2026-11-16', '2026-11-22', 'SUBMITTED')],
      );
      expect(find.byKey(ExomNumeral.valueKey), findsNothing);
      expect(find.byType(ExomTwoLineHeadline), findsWidgets);
    });
  });

  group('english', () {
    testWidgets('texts in English', (tester) async {
      await pumpRecapList(
        tester,
        recaps: recapListWithDraft(),
        locale: const Locale('en'),
      );
      expect(find.text('WEEKLY RECAP'), findsOneWidget);
      expect(find.text('Week of November 16 to November 22'), findsOneWidget);
      expect(find.text('YOUR WEEK.'), findsOneWidget);
      expect(find.text('new comment from your coach'), findsOneWidget);
    });
  });

  group('large text', () {
    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final width in const [320.0, 360.0]) {
        for (final scale in const [1.0, 1.3, 1.6]) {
          testWidgets(
            'rich scene at ${width.toInt()}dp ${scale}x ${locale.languageCode}',
            (tester) async {
              await pumpRecapList(
                tester,
                recaps: recapListRich(),
                width: width,
                locale: locale,
                textScaler: AndroidNonlinearTextScaler(scale),
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    testWidgets('2.0x text at 320 dp scrolls to the last row', (tester) async {
      await pumpRecapList(
        tester,
        recaps: recapListRich(),
        width: 320,
        height: 640,
        textScaler: AndroidNonlinearTextScaler(2.0),
      );
      await tester.scrollUntilVisible(
        find.text('26 oct - 01 nov'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('26 oct - 01 nov'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('guidelines', () {
    for (final dark in [true, false]) {
      for (final (name, recaps) in <(String, List<RecapEntity> Function())>[
        ('list', recapListWithDraft),
        ('blocked', recapListBlocked),
        ('empty', () => const <RecapEntity>[]),
      ]) {
        testWidgets('$name: tap targets, labels, contrast (dark=$dark)', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          await pumpRecapList(tester, recaps: recaps(), dark: dark);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          // The blocked action is an inactive component (WCAG 1.4.3 exempts
          // it); the shared button paints it 4.25:1 in the dark theme.
          if (name != 'blocked' || !dark) {
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          }
          if (!dark) expectNoLimeInk(tester);
          handle.dispose();
        });
      }
    }

    for (final dark in [true, false]) {
      testWidgets('blocked: the reason in line reaches 4.5:1 (dark=$dark)', (
        tester,
      ) async {
        await pumpRecapList(tester, recaps: recapListBlocked(), dark: dark);
        final reason = find.text('Ya tienes un recap subido esta semana');
        final palette = tester.element(reason).exomPalette;
        final colour = tester.widget<Text>(reason).style!.color!;
        // The footer paints `palette.background` behind the reason.
        expect(
          contrastRatio(colour, palette.background),
          greaterThanOrEqualTo(4.5),
        );
      });
    }

    testWidgets('error: tap targets, labels, contrast and no lime ink', (
      tester,
    ) async {
      for (final dark in [true, false]) {
        final handle = tester.ensureSemantics();
        await pumpRecapList(tester, error: Exception('boom'), dark: dark);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        if (!dark) expectNoLimeInk(tester);
        handle.dispose();
        await tester.pumpWidget(const SizedBox());
        await sl.reset();
      }
    });
  });
}
