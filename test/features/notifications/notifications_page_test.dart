// L5-A1 «Avisos» (docs/plans/rediseno-app-l5-contrato-v2.md, L5-A1): smoke of
// NotificationsPage, the delete-read confirmation as an EXOM sheet (D17-1,
// CC 11), the silent revert of "mark as read" (L5-D26) and the layout rules
// (CC 3, CC 4).
import 'dart:async';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_arrival.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_notice_row.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:exom_app/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:exom_app/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/widgets/exom_component_harness.dart'
    show expectNoOverflow, expectTapTargetGuidelines;
import '../../core/theme/wcag_contrast.dart';
import '../../core/widgets/expect_no_lime_ink.dart';
import 'notifications_test_support.dart';

const _deleteLink = 'Eliminar leídas';
const _markAllLink = 'Marcar todas';
const _sheetTitle = '¿Eliminar notificaciones leídas?';

ExomNoticeRow _row(WidgetTester tester, String title) =>
    tester.widget<ExomNoticeRow>(
      find.byWidgetPredicate((w) => w is ExomNoticeRow && w.title == title),
    );

// Bloc state, so the guard holds before and after the repaint.
NotificationsLoaded _loaded(WidgetTester tester) {
  final state = tester
      .element(find.byType(Scaffold).first)
      .read<NotificationsBloc>()
      .state;
  expect(state, isA<NotificationsLoaded>());
  return state as NotificationsLoaded;
}

bool _isUnread(WidgetTester tester, String id) =>
    _loaded(tester).items.firstWhere((item) => item.id == id).isUnread;

/// Lets the confirmation sheet finish closing and the bloc emit its
/// "deleting" state, stopping right at the first frame of the fold.
Future<void> _afterSheetCloses(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 16));
}

/// Taps the sheet's «Eliminar» action, whatever its painted case.
Future<void> _confirmDelete(WidgetTester tester) => tester.tap(
  find.descendant(
    of: find.byKey(const Key('exom-sheet-actions')),
    matching: find.textContaining(RegExp(r'^eliminar$', caseSensitive: false)),
  ),
);

void main() {
  testWidgets('smoke: title, rows, unread marks and the two links', (
    tester,
  ) async {
    final repo = FakeNotificationsRepository(mainSceneItems());
    await pumpNotificationsPage(tester, repo);

    // The title is the body headline (painted upper case); the app bar only
    // carries the back button, as in the sketch.
    expect(find.text('AVISOS'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byType(Text)),
      findsNothing,
    );
    expect(find.byType(ExomNoticeRow), findsNWidgets(5));
    expect(_row(tester, 'Nuevo plan de dieta').unread, isTrue);
    expect(_row(tester, 'Reto completado').unread, isFalse);
    expect(find.byType(ExomTextLink), findsNWidgets(2));
    expect(find.text(_markAllLink), findsOneWidget);
    expect(find.text(_deleteLink), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expectNoOverflow(tester);
  });

  testWidgets('relative time is localized and compact', (tester) async {
    final repo = FakeNotificationsRepository([
      notice('a', 'Ahora', 'x', unread: true, age: Duration.zero),
      notice('b', 'Minutos', 'x', unread: true),
      notice(
        'c',
        'Horas',
        'x',
        unread: false,
        age: const Duration(hours: 3, minutes: 2),
      ),
      notice('d', 'Dias', 'x', unread: false, age: const Duration(days: 2)),
    ]);
    await pumpNotificationsPage(tester, repo);
    expect(find.text('ahora'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('3 h'), findsOneWidget);
    expect(find.text('2 d'), findsOneWidget);
  });

  testWidgets('loading shows row skeletons, not a spinner', (tester) async {
    final repo = FakeNotificationsRepository(mainSceneItems())
      ..loadDelay = const Duration(seconds: 1);
    await pumpNotificationsPage(
      tester,
      repo,
      disableAnimations: true,
      settle: false,
    );
    expect(find.byType(ExomSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(ExomSkeleton), findsNothing);
    expect(find.byType(ExomNoticeRow), findsNWidgets(5));
  });

  testWidgets('empty: flat empty state, no icon', (tester) async {
    final repo = FakeNotificationsRepository(const []);
    await pumpNotificationsPage(tester, repo);
    expect(find.byType(ExomEmptyState), findsOneWidget);
    expect(find.text('No tienes notificaciones'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_off_outlined), findsNothing);
    expect(find.byType(ExomTextLink), findsNothing);
  });

  testWidgets('load error: inline message with retry, no filled button', (
    tester,
  ) async {
    final repo = FakeNotificationsRepository(mainSceneItems())..failLoad = true;
    await pumpNotificationsPage(tester, repo);
    final message = tester.widget<ExomInlineMessage>(
      find.byType(ExomInlineMessage),
    );
    expect(message.kind, ExomMessageKind.error);
    expect(find.byType(FilledButton), findsNothing);
    repo.failLoad = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byType(ExomInlineMessage), findsNothing);
    expect(find.byType(ExomNoticeRow), findsNWidgets(5));
  });

  group('confirm delete read (D17-1, CC 11)', () {
    testWidgets('opens as an EXOM sheet, not an AlertDialog', (tester) async {
      final repo = FakeNotificationsRepository(mainSceneItems());
      await pumpNotificationsPage(tester, repo);
      await tester.tap(find.text(_deleteLink));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const Key('exom-sheet-actions')), findsOneWidget);
      expect(find.text(_sheetTitle.toUpperCase()), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('exom-sheet-actions')),
          matching: find.text('Cancelar'),
        ),
        findsOneWidget,
      );
      expect(repo.deleteReadCalls, 0);
    });

    testWidgets('the action deletes; cancel does not', (tester) async {
      final repo = FakeNotificationsRepository(mainSceneItems());
      await pumpNotificationsPage(tester, repo);

      await tester.tap(find.text(_deleteLink));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(repo.deleteReadCalls, 0);
      expect(find.byType(ExomNoticeRow), findsNWidgets(5));

      await tester.tap(find.text(_deleteLink));
      await tester.pumpAndSettle();
      await _confirmDelete(tester);
      await tester.pumpAndSettle();
      expect(repo.deleteReadCalls, 1);
      expect(find.byType(ExomNoticeRow), findsNWidgets(2));
      expect(find.text(_deleteLink), findsNothing);
    });

    testWidgets('a router location change closes it without deleting', (
      tester,
    ) async {
      final repo = FakeNotificationsRepository(mainSceneItems());
      final router = await pumpNotificationsPage(tester, repo);
      await tester.tap(find.text(_deleteLink));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exom-sheet-actions')), findsOneWidget);

      router.go('/other');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exom-sheet-actions')), findsNothing);
      expect(find.text('Otra'), findsOneWidget);
      expect(repo.deleteReadCalls, 0);
    });
  });

  group('fold on delete (M7)', () {
    testWidgets('read rows fold away while deleting, unread stay', (
      tester,
    ) async {
      final repo = FakeNotificationsRepository(mainSceneItems())
        ..deleteGate = Completer<void>();
      await pumpNotificationsPage(tester, repo);
      await tester.tap(find.text(_deleteLink));
      await tester.pumpAndSettle();
      await _confirmDelete(tester);
      final full = tester.getSize(find.byType(NotificationTile).at(2)).height;
      await _afterSheetCloses(tester);
      await tester.pump(const Duration(milliseconds: 80));
      // Folding: still mounted, its height partly gone.
      expect(find.text('Reto completado'), findsOneWidget);
      final fold = find.ancestor(
        of: find.text('Reto completado'),
        matching: find.byType(SizeTransition),
      );
      expect(tester.getSize(fold.first).height, inExclusiveRange(0, full));
      await tester.pumpAndSettle();
      expect(find.text('Reto completado'), findsNothing);
      expect(find.text('Tu resumen semanal está listo'), findsNothing);
      expect(find.text('Nuevo plan de dieta'), findsOneWidget);
      // A day group left with only read rows folds with them.
      expect(find.text('ESTA SEMANA'), findsNothing);
      expect(find.text('HOY'), findsOneWidget);

      // A failed delete brings them back (the bloc restores its state).
      repo
        ..failDelete = true
        ..deleteGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Reto completado'), findsOneWidget);
    });

    testWidgets('reduced motion: fade only, rows still go away', (
      tester,
    ) async {
      final repo = FakeNotificationsRepository(mainSceneItems())
        ..deleteGate = Completer<void>();
      await pumpNotificationsPage(tester, repo, disableAnimations: true);
      await tester.tap(find.text(_deleteLink));
      await tester.pumpAndSettle();
      await _confirmDelete(tester);
      await _afterSheetCloses(tester);
      await tester.pump(const Duration(milliseconds: 40));
      final heightMid = tester.getSize(find.text('Reto completado')).height;
      expect(heightMid, greaterThan(0));
      // The innermost fade (the row's own) is already going down.
      final opacities = tester
          .widgetList<FadeTransition>(
            find.ancestor(
              of: find.text('Reto completado'),
              matching: find.byType(FadeTransition),
            ),
          )
          .map((fade) => fade.opacity.value);
      expect(opacities.reduce((a, b) => a < b ? a : b), lessThan(1));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('Reto completado'), findsNothing);
      repo.deleteGate!.complete();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('I2: after deleting the read rows the unread row keeps its own '
      'state: visible at full size, no unfold', (tester) async {
    final repo = FakeNotificationsRepository([
      notice('r1', 'Leído uno', 'Primero', unread: false),
      notice('u1', 'Sin leer', 'Segundo', unread: true),
      notice('r2', 'Leído dos', 'Tercero', unread: false),
    ])..deleteGate = Completer<void>();
    await pumpNotificationsPage(tester, repo);
    Finder unreadRow() => find.ancestor(
      of: find.text('Sin leer'),
      matching: find.byType(ExomArrivalItem),
    );
    final full = tester.getSize(unreadRow()).height;

    await tester.tap(find.text(_deleteLink));
    await tester.pumpAndSettle();
    await _confirmDelete(tester);
    await tester.pumpAndSettle();
    expect(find.text('Leído uno'), findsNothing);
    expect(find.text('Sin leer'), findsOneWidget);

    repo.deleteGate!.complete();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_loaded(tester).deletingRead, isFalse);
    expect(_loaded(tester).items.map((n) => n.id), ['u1']);
    // First frames after the reload: the unread row is there at full height
    // (it did not inherit the folded state of the read row that used to sit
    // at its index) and nothing is animating its size.
    expect(find.text('Sin leer'), findsOneWidget);
    expect(tester.getSize(unreadRow()).height, full);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(unreadRow()).height, full);
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('sketch elements from existing data (L5-D36)', () {
    testWidgets('unread count as the 96 hero, data colour, no total', (
      tester,
    ) async {
      final repo = FakeNotificationsRepository(mainSceneItems());
      await pumpNotificationsPage(tester, repo);
      final hero = tester.widget<ExomNumeral>(find.byType(ExomNumeral));
      expect(hero.value, '2');
      expect(hero.size, ExomNumeralSize.hero96);
      expect(hero.isData, isTrue);
      expect(find.text('SIN LEER'), findsOneWidget);
      // «de N avisos» needs the total, which the state does not carry.
      expect(find.textContaining('avisos'), findsNothing);
    });

    testWidgets('day groups numbered 01, 02, 03 from createdAt (es)', (
      tester,
    ) async {
      final repo = FakeNotificationsRepository([
        ...mainSceneItems(),
        notice(
          'old',
          'Antiguo',
          'Hace dos semanas.',
          unread: false,
          age: const Duration(days: 14),
        ),
      ]);
      // Tall enough for the lazy list to build every header at once.
      await pumpNotificationsPage(tester, repo, height: 1800);
      final headers = tester
          .widgetList<ExomNumberedSectionHeader>(
            find.byType(ExomNumberedSectionHeader),
          )
          .map((h) => (h.n, h.title))
          .toList();
      expect(headers, [(1, 'Hoy'), (2, 'Esta semana'), (3, 'Anteriores')]);
      // Rows sit under their header, in order.
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('HOY'), lessThan(top('Nuevo plan de dieta')));
      expect(top('Reto completado'), lessThan(top('ESTA SEMANA')));
      expect(
        top('ESTA SEMANA'),
        lessThan(top('Tu resumen semanal está listo')),
      );
      expect(top('ANTERIORES'), lessThan(top('Antiguo')));
      // Two weeks old: the previous dd/MM/yy date, unchanged.
      expect(find.text('06/11/26'), findsOneWidget);
    });

    // L5-D37: the week always starts on Monday, in every language.
    for (final locale in const [Locale('en'), Locale('es')]) {
      final title = locale.languageCode == 'en'
          ? (week: 'THIS WEEK', earlier: 'EARLIER')
          : (week: 'ESTA SEMANA', earlier: 'ANTERIORES');

      testWidgets(
        'Sunday: previous Monday is this week (${locale.languageCode})',
        (tester) async {
          final sunday = DateTime(2026, 11, 22, 12);
          final repo = FakeNotificationsRepository([
            NotificationEntity(
              id: 'mon',
              title: 'Lunes',
              body: 'x',
              status: 'SENT',
              createdAt: DateTime(2026, 11, 22 - 6, 9),
              readAt: DateTime(2026, 11, 22 - 6, 10),
            ),
          ]);
          await pumpNotificationsPage(
            tester,
            repo,
            locale: locale,
            now: sunday,
          );
          expect(find.text(title.week), findsOneWidget);
          expect(find.text(title.earlier), findsNothing);
        },
      );

      testWidgets(
        'Monday: previous Sunday is earlier (${locale.languageCode})',
        (tester) async {
          final monday = DateTime(2026, 11, 23, 12);
          final repo = FakeNotificationsRepository([
            NotificationEntity(
              id: 'sun',
              title: 'Domingo',
              body: 'x',
              status: 'SENT',
              createdAt: DateTime(2026, 11, 23 - 1, 9),
              readAt: DateTime(2026, 11, 23 - 1, 10),
            ),
          ]);
          await pumpNotificationsPage(
            tester,
            repo,
            locale: locale,
            now: monday,
          );
          expect(find.text(title.earlier), findsOneWidget);
          expect(find.text(title.week), findsNothing);
        },
      );
    }

    testWidgets('day groups in English', (tester) async {
      final repo = FakeNotificationsRepository(mainSceneItems());
      await pumpNotificationsPage(tester, repo, locale: const Locale('en'));
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('UNREAD'), findsOneWidget);
    });

    testWidgets('icon by notification type in a 56 thumbnail', (tester) async {
      final repo = FakeNotificationsRepository([
        notice('d', 'Dieta', 'x', unread: true, data: {'type': 'diet'}),
        notice(
          'c',
          'Reto',
          'x',
          unread: false,
          data: {'type': 'challenge_update'},
        ),
        notice('t', 'Tipo raro', 'x', unread: false, data: {'type': 42}),
        notice('n', 'Sin tipo', 'x', unread: false),
      ]);
      await pumpNotificationsPage(tester, repo);
      Finder iconIn(String title, IconData icon) => find.descendant(
        of: find.ancestor(
          of: find.text(title),
          matching: find.byType(ExomNoticeRow),
        ),
        matching: find.byIcon(icon),
      );
      expect(iconIn('Dieta', Icons.restaurant), findsOneWidget);
      expect(iconIn('Reto', Icons.emoji_events), findsOneWidget);
      expect(iconIn('Tipo raro', Icons.notifications_outlined), findsOneWidget);
      expect(iconIn('Sin tipo', Icons.notifications_outlined), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('notice-thumb-d'))),
        const Size(56, 56),
      );
    });

    testWidgets('empty: hero 0 in the text colour and «Todo al día»', (
      tester,
    ) async {
      final repo = FakeNotificationsRepository(const []);
      await pumpNotificationsPage(tester, repo);
      final hero = tester.widget<ExomNumeral>(find.byType(ExomNumeral));
      expect(hero.value, '0');
      expect(hero.isData, isFalse);
      expect(find.text('Todo al día'), findsOneWidget);
      expect(find.text('AVISOS'), findsOneWidget);
    });

    testWidgets('loading: title, numeral skeleton and five row skeletons', (
      tester,
    ) async {
      final repo = FakeNotificationsRepository(mainSceneItems())
        ..loadDelay = const Duration(seconds: 1);
      await pumpNotificationsPage(
        tester,
        repo,
        disableAnimations: true,
        settle: false,
      );
      expect(find.text('AVISOS'), findsOneWidget);
      expect(find.byType(ExomSkeleton), findsNWidgets(6));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('error: title above the inline message', (tester) async {
      final repo = FakeNotificationsRepository(mainSceneItems())
        ..failLoad = true;
      await pumpNotificationsPage(tester, repo);
      expect(find.text('AVISOS'), findsOneWidget);
      expect(find.byType(ExomNumeral), findsNothing);
      expect(find.byType(ExomInlineMessage), findsOneWidget);
    });

    testWidgets('«Marcar todas» marks every row and hides itself; the lone '
        '«Eliminar leídas» sits at the end', (tester) async {
      final repo = FakeNotificationsRepository(mainSceneItems());
      await pumpNotificationsPage(tester, repo);
      await tester.tap(find.text(_markAllLink));
      await tester.pumpAndSettle();
      expect(repo.markAllReadCalls, 1);
      expect(_loaded(tester).unreadCount, 0);
      expect(_loaded(tester).items.every((n) => !n.isUnread), isTrue);
      expect(find.text(_markAllLink), findsNothing);
      expect(find.text(_deleteLink), findsOneWidget);
      expect(
        tester.getTopRight(find.byType(ExomTextLink)).dx,
        moreOrLessEquals(390 - 20),
      );
      expect(
        tester.widget<ExomNumeral>(find.byType(ExomNumeral)).isData,
        isFalse,
      );
    });
  });

  group('delete sheet styling (I1)', () {
    for (final brightness in Brightness.values) {
      testWidgets('red 3 px bar, outlined error action, no lime '
          '(${brightness.name})', (tester) async {
        final repo = FakeNotificationsRepository(mainSceneItems());
        await pumpNotificationsPage(tester, repo, brightness: brightness);
        await tester.tap(find.text(_deleteLink));
        await tester.pumpAndSettle();
        final palette = Theme.of(
          tester.element(find.byKey(const Key('exom-sheet-actions'))),
        ).extension<ExomThemePalette>()!;

        final bar = find.byKey(const Key('notices-delete-bar'));
        expect(tester.getSize(bar).height, 3);
        expect(
          tester.getSize(bar).width,
          tester.getSize(find.byKey(const Key('exom-sheet-panel'))).width,
        );
        expect(tester.widget<ColoredBox>(bar).color, palette.error);

        final actions = find.byKey(const Key('exom-sheet-actions'));
        expect(
          find.descendant(
            of: actions,
            matching: find.byType(ExomPrimaryButton),
          ),
          findsNothing,
        );
        final label = tester.widget<Text>(
          find.descendant(of: actions, matching: find.text('Eliminar')),
        );
        expect(label.style?.color, palette.error);
        final box = tester.widget<DecoratedBox>(
          find.byKey(const Key('notices-delete-confirm')),
        );
        final border = (box.decoration as BoxDecoration).border! as Border;
        expect(border.top.color, palette.error);
        expect(border.top.width, ExomRule.outline);
        expect(
          find.descendant(of: actions, matching: find.byType(ExomQuietButton)),
          findsOneWidget,
        );
        if (brightness == Brightness.light) expectNoLimeInk(tester);
        await expectTapTargetGuidelines(tester);
        // Same rule as exom_sheet_confirm_test.dart: on 14 px DM Sans the
        // pixel sampler can measure an antialiasing shade of the sheet body
        // (3.23 in light, seen in the L0 baseline). A report may only name
        // that body, and the real colour pairs must reach AA.
        final evaluation = await textContrastGuideline.evaluate(tester);
        if (!evaluation.passed) {
          final reason = evaluation.reason ?? '';
          expect(
            RegExp('SemanticsNode#').allMatches(reason).length,
            1,
            reason: reason,
          );
          expect(reason, contains('Se eliminarán'), reason: reason);
        }
        for (final ink in [
          palette.textSecondary,
          palette.textPrimary,
          palette.error,
        ]) {
          expect(
            contrastRatio(ink, palette.surface),
            greaterThanOrEqualTo(4.5),
          );
        }
      });
    }
  });

  group('mark as read revert is silent (L5-D26)', () {
    testWidgets('after a failed mark-as-read the row is unread again, with no '
        'inline message and no SnackBar', (tester) async {
      final repo = FakeNotificationsRepository(mainSceneItems())
        ..failMarkRead = true;
      await pumpNotificationsPage(tester, repo);
      expect(_isUnread(tester, 'n1'), isTrue);

      await tester.tap(find.text('Nuevo plan de dieta'));
      await tester.pumpAndSettle();

      expect(repo.markReadCalls, 1);
      expect(_isUnread(tester, 'n1'), isTrue);
      expect(_loaded(tester).unreadCount, 2);
      expect(find.byType(ExomInlineMessage), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a successful mark-as-read keeps the row read', (tester) async {
      final repo = FakeNotificationsRepository(mainSceneItems());
      await pumpNotificationsPage(tester, repo);
      await tester.tap(find.text('Nuevo plan de dieta'));
      await tester.pumpAndSettle();
      expect(_isUnread(tester, 'n1'), isFalse);
      expect(_loaded(tester).unreadCount, 1);
    });
  });

  group('layout (CC 3, CC 4)', () {
    const sizes = <(double, double)>[(320, 1.3), (320, 1.6), (360, 1.6)];
    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final (width, scale) in sizes) {
        testWidgets('no overflow ${locale.languageCode} ${width}dp x$scale '
            '(list and empty)', (tester) async {
          final repo = FakeNotificationsRepository(mainSceneItems());
          await pumpNotificationsPage(
            tester,
            repo,
            width: width,
            textScale: scale,
            locale: locale,
          );
          expectNoOverflow(tester);
          repo.items = const [];
          // Re-pump with the empty scene.
          await pumpNotificationsPage(
            tester,
            repo,
            width: width,
            textScale: scale,
            locale: locale,
          );
          expectNoOverflow(tester);
        });
      }

      for (final scale in const [1.3, 1.6]) {
        testWidgets('no overflow ${locale.languageCode} 320dp x$scale '
            '(sheet, error and loading)', (tester) async {
          final repo = FakeNotificationsRepository(mainSceneItems());
          await pumpNotificationsPage(
            tester,
            repo,
            width: 320,
            textScale: scale,
            locale: locale,
          );
          await tester.tap(find.byType(ExomTextLink).last);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('notices-delete-bar')), findsOneWidget);
          expectNoOverflow(tester);

          repo.failLoad = true;
          await pumpNotificationsPage(
            tester,
            repo,
            width: 320,
            textScale: scale,
            locale: locale,
          );
          expect(find.byType(ExomInlineMessage), findsOneWidget);
          expectNoOverflow(tester);

          repo
            ..failLoad = false
            ..loadDelay = const Duration(seconds: 1);
          await pumpNotificationsPage(
            tester,
            repo,
            width: 320,
            textScale: scale,
            locale: locale,
            disableAnimations: true,
            settle: false,
          );
          expect(find.byType(ExomSkeleton), findsWidgets);
          expectNoOverflow(tester);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        });
      }

      testWidgets('x2.0 at 320dp: all content reachable by scrolling '
          '(${locale.languageCode})', (tester) async {
        final repo = FakeNotificationsRepository(mainSceneItems());
        await pumpNotificationsPage(
          tester,
          repo,
          width: 320,
          textScale: 2.0,
          locale: locale,
        );
        await tester.scrollUntilVisible(
          find.text('Cambio en tu calendario'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Cambio en tu calendario'), findsOneWidget);
        expectNoOverflow(tester);
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets(
        'no lime ink, contrast and tap targets (${brightness.name})',
        (tester) async {
          final repo = FakeNotificationsRepository(mainSceneItems());
          await pumpNotificationsPage(tester, repo, brightness: brightness);
          if (brightness == Brightness.light) expectNoLimeInk(tester);
          await expectTapTargetGuidelines(tester);
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        },
      );
    }
  });
}
