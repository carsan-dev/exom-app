// L5-C5b · Recap, «Enviado»: the screen shown after the server confirmed the
// send. Owner decision 2026-11-25 (sketch c5b-enviado-cabecera, option C «Sin
// cabecera» + the check of option B): no band and no «5»; the kicker «Recap
// semanal», the two-line headline with a large check to its right, the full
// segment rule, the week, the confirmed state, the trainer's note and «Volver
// a recaps» in the pinned footer. Failed sends keep their SnackBar and never
// show it.
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';
import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;
import '../../../../core/widgets/exom_component_harness.dart'
    show expectNoOverflow;
import 'recap_list_redesign_test.dart'
    show RecapListTestRepository, pumpRecapList, recapListWithDraft;

class _EventSpy extends BlocObserver {
  final events = <RecapEvent>[];

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    if (event is RecapEvent) events.add(event);
  }
}

class _QuietObserver extends BlocObserver {}

class _FailingSubmitRepository extends RecapListTestRepository {
  _FailingSubmitRepository(super.recaps);

  @override
  Future<void> submitRecap(String id) async {
    throw Exception('submit failed');
  }
}

const _sent = ValueKey('recap-sent');
const _back = ValueKey('recap-sent-back');
const _close = ValueKey('recap-sent-close');
const _check = ValueKey('recap-sent-check');
const _headlineRow = ValueKey('recap-sent-headline-row');

Finder _inSent(Finder matching) =>
    find.descendant(of: find.byKey(_sent), matching: matching);

/// The check stands next to (or, when there is no room, under) the headline,
/// never on top of it, and inside the screen.
void _expectCheckBesideHeadline(WidgetTester tester) {
  final headline = tester.getRect(_inSent(find.byType(ExomTwoLineHeadline)));
  final check = tester.getRect(find.byKey(_check));
  final screen =
      Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(check.overlaps(headline), isFalse, reason: '$check vs $headline');
  expect(check.right, lessThanOrEqualTo(screen.right - 20 + 0.01));
  expect(check.left, greaterThanOrEqualTo(20 - 0.01));
  expect(check.width, greaterThan(0));
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Opens the form from the list, goes to the last step and sends.
Future<GoRouter> sendRecapFromForm(
  WidgetTester tester, {
  RecapListTestRepository? repository,
  Locale locale = const Locale('es'),
  bool dark = false,
  double width = 390,
  double height = 844,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final router = await pumpRecapList(
    tester,
    repository: repository ?? RecapListTestRepository(recapListWithDraft()),
    locale: locale,
    dark: dark,
    width: width,
    height: height,
    textScaler: textScaler,
  );
  await tester.tap(find.byKey(const ValueKey('recap-new')));
  await _settle(tester);
  BlocProvider.of<RecapBloc>(
    tester.element(find.byType(Scaffold).first),
  ).add(const RecapStepChanged(5));
  await _settle(tester);
  final action = find.byKey(const ValueKey('recap-step-action'));
  await tester.ensureVisible(action);
  await tester.tap(action, warnIfMissed: false);
  await _settle(tester);
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

/// Week of the draft the form opens on (fixed in the fixture, so the test does
/// not depend on the clock: the bloc's own «new recap» uses `DateTime.now()`).
String _sentWeekLine(WidgetTester tester, String languageCode) {
  final format = DateFormat.MMMMd(languageCode);
  return _l10n(tester).recapListWeekSubtitle(
    format.format(DateTime(2026, 11, 16)),
    format.format(DateTime(2026, 11, 22)),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('en');
    // The bundled fonts, so the headline has its real width and the check
    // finds its real room next to it (Ahem squares are far wider).
    await loadRedesignFonts();
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

  group('a confirmed send shows «Enviado»', () {
    testWidgets('the view replaces the list, without SnackBar or footer', (
      tester,
    ) async {
      await sendRecapFromForm(tester);
      final l10n = _l10n(tester);
      expect(find.byKey(_sent), findsOneWidget);
      expect(find.text(l10n.weeklyRecapTitle.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.recapSentKicker.toUpperCase()), findsNothing);
      expect(find.text('RECAP'), findsOneWidget);
      expect(find.text('ENVIADO.'), findsOneWidget);
      expect(find.text(l10n.recapSentStatus), findsOneWidget);
      expect(find.text(l10n.recapSentCoach), findsOneWidget);
      expect(find.text(l10n.recapBackToRecaps), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(l10n.recapSentSuccessfully), findsNothing);
      expect(find.byKey(const ValueKey('recap-new')), findsNothing);
      expect(find.byKey(const ValueKey('recap-list')), findsNothing);
    });

    testWidgets('the button is secondary, never the primary action', (
      tester,
    ) async {
      await sendRecapFromForm(tester);
      expect(
        tester.widget<Widget>(find.byKey(_back)),
        isA<ExomSecondaryButton>(),
      );
      expect(find.byType(ExomPrimaryButton), findsNothing);
    });

    testWidgets('the week line is the week that was sent (es)', (tester) async {
      await sendRecapFromForm(tester);
      // The list header shows the same week, so look inside the sent view.
      expect(
        find.descendant(
          of: find.byKey(_sent),
          matching: find.text(_sentWeekLine(tester, 'es')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('en locale copy', (tester) async {
      await sendRecapFromForm(tester, locale: const Locale('en'));
      expect(find.byKey(_sent), findsOneWidget);
      expect(find.text('WEEKLY RECAP'), findsOneWidget);
      expect(find.text('FIVE STEPS COMPLETED'), findsNothing);
      expect(find.text('SENT.'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      expect(
        find.text(
          "Thanks for telling me. I'll review it and leave my comment on "
          'your recap.',
        ),
        findsOneWidget,
      );
      expect(find.text('Back to recaps'), findsOneWidget);
      expect(find.text(_sentWeekLine(tester, 'en')), findsOneWidget);
      expect(_sentWeekLine(tester, 'en'), startsWith('Week of '));
    });

    for (final locale in const [Locale('es'), Locale('en')]) {
      testWidgets('no «Ver resumen» (${locale.languageCode})', (tester) async {
        await sendRecapFromForm(tester, locale: locale);
        expect(find.byKey(_sent), findsOneWidget);
        expect(find.textContaining('Ver resumen'), findsNothing);
        expect(find.textContaining('View summary'), findsNothing);
      });
    }
  });

  group('header: option C (no band, no «5») with the check', () {
    testWidgets('no band, no numeral, no «Cinco pasos completados»', (
      tester,
    ) async {
      await sendRecapFromForm(tester);
      expect(_inSent(find.byType(ExomBand)), findsNothing);
      expect(_inSent(find.byType(ExomNumeral)), findsNothing);
      expect(_inSent(find.text('5')), findsNothing);
      expect(find.text('CINCO PASOS COMPLETADOS'), findsNothing);
    });

    testWidgets('kicker, then the headline with the check to its right', (
      tester,
    ) async {
      await sendRecapFromForm(tester);
      final kicker = tester.getRect(find.text('RECAP SEMANAL'));
      final headline = tester.getRect(
        _inSent(find.byType(ExomTwoLineHeadline)),
      );
      final check = tester.getRect(find.byKey(_check));
      expect(kicker.bottom, lessThanOrEqualTo(headline.top));
      expect(check.left, greaterThanOrEqualTo(headline.right));
      expect(check.center.dy, closeTo(headline.center.dy, 1));
      expect(check.width, closeTo(56, 0.01));
      expect(check.height, closeTo(56, 0.01));
      expect(
        find.descendant(
          of: find.byKey(_headlineRow),
          matching: find.byKey(_check),
        ),
        findsOneWidget,
      );
      _expectCheckBesideHeadline(tester);
    });

    testWidgets('the check is decorative: no semantics node of its own', (
      tester,
    ) async {
      await sendRecapFromForm(tester);
      expect(
        find.descendant(
          of: find.byKey(_check),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_check),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });
  });

  group('a failed send does not show «Enviado»', () {
    testWidgets('the error SnackBar stays', (tester) async {
      await sendRecapFromForm(
        tester,
        repository: _FailingSubmitRepository(recapListWithDraft()),
      );
      expect(find.byKey(_sent), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(_l10n(tester).recapSentSuccessfully), findsNothing);
    });
  });

  group('leaving «Enviado» goes back to the list', () {
    testWidgets('«Volver a recaps» shows the list; a double tap is one', (
      tester,
    ) async {
      final router = await sendRecapFromForm(tester);
      final before = spy.events.length;
      final back = find.byKey(_back);
      await tester.tap(back);
      await tester.tap(back, warnIfMissed: false);
      await _settle(tester);
      expect(find.byKey(_sent), findsNothing);
      expect(find.byKey(const ValueKey('recap-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('recap-new')), findsOneWidget);
      expect(spy.events.length, before, reason: 'no event is dispatched');
      expect(_location(router), '/recap');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a second tap after the rebuild does not open a new form', (
      tester,
    ) async {
      await sendRecapFromForm(tester);
      final before = spy.events.length;
      final spot = tester.getCenter(find.byKey(_back));
      await tester.tap(find.byKey(_back));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(spot);
      await _settle(tester);
      expect(spy.events.length, before, reason: 'no RecapFormStarted');
      expect(find.byKey(const ValueKey('recap-step-action')), findsNothing);
      expect(find.byKey(const ValueKey('recap-list')), findsOneWidget);
      // Once the transition is over the footer works as usual.
      await tester.tap(find.byKey(const ValueKey('recap-new')));
      await _settle(tester);
      expect(spy.events.whereType<RecapFormStarted>(), hasLength(2));
    });

    testWidgets('close X, then an immediate tap on the footer, opens nothing', (
      tester,
    ) async {
      await sendRecapFromForm(tester);
      final before = spy.events.length;
      await tester.tap(find.byKey(_close));
      await tester.pump(const Duration(milliseconds: 50));
      final footer = find.byKey(const ValueKey('recap-new'));
      await tester.tapAt(tester.getCenter(footer));
      await _settle(tester);
      expect(spy.events.length, before);
      expect(find.byKey(const ValueKey('recap-list')), findsOneWidget);
    });

    testWidgets('the close X shows the list without navigating', (
      tester,
    ) async {
      final router = await sendRecapFromForm(tester);
      final before = spy.events.length;
      await tester.tap(find.byKey(_close));
      await _settle(tester);
      expect(find.byKey(_sent), findsNothing);
      expect(find.byKey(const ValueKey('recap-list')), findsOneWidget);
      expect(spy.events.length, before);
      expect(_location(router), '/recap');
    });

    testWidgets('system back shows the list without leaving the route', (
      tester,
    ) async {
      final router = await sendRecapFromForm(tester);
      final before = spy.events.length;
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.byKey(_sent), findsNothing);
      expect(find.byKey(const ValueKey('recap-list')), findsOneWidget);
      expect(spy.events.length, before);
      expect(_location(router), '/recap');
    });

    testWidgets('the app bar of «Enviado» has only the close X', (
      tester,
    ) async {
      await sendRecapFromForm(tester);
      expect(find.byKey(_close), findsOneWidget);
      expect(find.byTooltip(_l10n(tester).retry), findsNothing);
    });
  });

  group('large text and small screens', () {
    for (final dark in [false, true]) {
      testWidgets('360x800, text scale 2.0, ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await sendRecapFromForm(
          tester,
          dark: dark,
          width: 360,
          height: 800,
          textScaler: const AndroidNonlinearTextScaler(2.0),
        );
        expect(find.byKey(_sent), findsOneWidget);
        expectNoOverflow(tester);
        _expectCheckBesideHeadline(tester);
        final back = find.byKey(_back);
        expect(back, findsOneWidget);
        expect(
          tester.getRect(back).bottom,
          lessThanOrEqualTo(tester.view.physicalSize.height),
        );
        await tester.tap(back);
        await _settle(tester);
        expect(find.byKey(const ValueKey('recap-list')), findsOneWidget);
      });

      testWidgets('320x480, text scale 2.0, ${dark ? 'dark' : 'light'}: '
          'the check fits beside or under the headline', (tester) async {
        await sendRecapFromForm(
          tester,
          dark: dark,
          width: 320,
          height: 480,
          textScaler: const AndroidNonlinearTextScaler(2.0),
        );
        expect(find.byKey(_sent), findsOneWidget);
        expect(find.byKey(_check), findsOneWidget);
        expectNoOverflow(tester);
        _expectCheckBesideHeadline(tester);
      });
    }
  });
}
