// L5-B1 «Ayuda» (docs/plans/rediseno-app-l5-contrato-v2.md, L5-B1 and §3.0):
// smoke of the page (it had no test), the D14-3 inline error when a link does
// not open (no SnackBar), the numbered accordion 01-06 (M7), the rows that say
// whether they open the browser or the mail app, the measure of the answers
// and the common criteria CC 3 and CC 4. Links are opened through a mocked
// url_launcher channel: nothing leaves the test.
import 'dart:async';

import 'package:exom_app/core/config/external_links.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_accordion.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/help/presentation/pages/help_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/exom_component_harness.dart';
import '../../../../core/widgets/exom_text_component_matrix.dart';
import '../../../../core/widgets/expect_no_lime_ink.dart';
import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;

const _channel = MethodChannel('plugins.flutter.io/url_launcher');
const _errorKey = Key('help-link-error');

/// What the mocked channel answers to `launch`; every launched URL is logged.
class _Launcher {
  _Launcher(this.answer);

  Object? Function(String url) answer;
  final urls = <String>[];

  void install(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      if (call.method != 'launch') return null;
      final url = (call.arguments as Map<Object?, Object?>)['url']! as String;
      urls.add(url);
      final result = answer(url);
      if (result is PlatformException) throw result;
      return result;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      ),
    );
  }
}

final _routes = <String>[];

Future<void> _pumpHelp(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  Locale locale = const Locale('es'),
  bool disableAnimations = true,
}) async {
  await loadRedesignFonts();
  _routes.clear();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
        routes: [
          GoRoute(path: 'help', builder: (_, _) => const HelpPage()),
        ],
      ),
      GoRoute(
        path: '/feedback',
        builder: (_, _) {
          _routes.add('/feedback');
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) {
          _routes.add('/settings');
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: themeFor(brightness),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: app!,
      ),
    ),
  );
  router.push('/home/help');
  await tester.pumpAndSettle();
}

Finder _linkRow(String title) => find.ancestor(
  of: find.text(title.toUpperCase()),
  matching: find.byKey(const Key('help-link-row')),
);

/// The page is a lazy list: scroll until [finder] is built and on screen.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byType(Scrollable).first,
    const Offset(0, -200),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapLink(WidgetTester tester, String title) async {
  final row = _linkRow(title);
  await _reveal(tester, row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  group('smoke', () {
    testWidgets('shows the two-line headline, the intro and the kicker', (
      tester,
    ) async {
      await _pumpHelp(tester);
      expect(find.byType(ExomKicker), findsWidgets);
      expect(find.text('AYUDA'), findsWidgets);
      expect(find.byType(ExomTwoLineHeadline), findsOneWidget);
      expect(find.text('TUS DUDAS.'), findsOneWidget);
      expect(find.text('CON TU ENTRENADOR.'), findsOneWidget);
      expect(
        find.textContaining('Todo lo importante para usar EXOM'),
        findsOneWidget,
      );
    });

    testWidgets('the two quick actions go to feedback and settings', (
      tester,
    ) async {
      await _pumpHelp(tester);
      expect(find.text('Si no encuentras la respuesta, escríbeme.'), findsOne);
      await tester.tap(find.text('ENVIAR DUDA O INCIDENCIA'));
      await tester.pumpAndSettle();
      expect(_routes, ['/feedback']);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('NOTIFICACIONES Y CACHÉ'));
      await tester.pumpAndSettle();
      expect(_routes, ['/feedback', '/settings']);
    });
  });

  group('numbered accordion (M7)', () {
    testWidgets('six accordions numbered 01-06; only 04 starts open', (
      tester,
    ) async {
      await _pumpHelp(tester);
      final accordions = tester
          .widgetList<ExomAccordion>(find.byType(ExomAccordion))
          .toList();
      expect(accordions.map((a) => a.number), [1, 2, 3, 4, 5, 6]);
      expect(accordions.map((a) => a.initiallyOpen), [
        false,
        false,
        false,
        true,
        false,
        false,
      ]);
      expect(find.textContaining('La app conserva en caché'), findsOneWidget);
      expect(find.textContaining('El ReCap te permite'), findsNothing);
    });

    testWidgets('a tap opens that answer', (
      tester,
    ) async {
      await _pumpHelp(tester);
      await _reveal(tester, find.text('¿Para qué sirve el ReCap semanal?'));
      await tester.tap(find.text('¿Para qué sirve el ReCap semanal?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('El ReCap te permite'), findsOneWidget);
    });

    testWidgets('answers keep a reading measure of about 68 characters', (
      tester,
    ) async {
      await _pumpHelp(tester, width: 900, height: 1200);
      final answer = find.textContaining('La app conserva en caché');
      expect(tester.getSize(answer).width, lessThanOrEqualTo(68 * 9.0));
      expect(tester.getSize(answer).width, greaterThan(300));
    });
  });

  group('links say where they open', () {
    testWidgets('browser and mail rows name their destination', (
      tester,
    ) async {
      await _pumpHelp(tester);
      for (final title in const [
        'Centro de soporte',
        'Política de privacidad',
        'Dudas del servicio',
        'Dudas técnicas',
      ]) {
        await _reveal(tester, _linkRow(title));
      }
      expect(find.text('Se abre en el navegador'), findsNWidgets(2));
      expect(find.text('Se abre en tu aplicación de correo'), findsNWidgets(2));
    });
  });

  group('D14-3: a link that does not open shows an inline error', () {
    final cases = <(String, String, Uri)>[
      (
        'Centro de soporte',
        'No se pudo abrir la página de soporte.',
        ExternalLinks.supportPage,
      ),
      (
        'Política de privacidad',
        'No se pudo abrir la política de privacidad.',
        ExternalLinks.privacyPolicy,
      ),
      (
        'Dudas del servicio',
        'No se pudo abrir la aplicación de correo.',
        ExternalLinks.serviceSupportEmail,
      ),
      (
        'Dudas técnicas',
        'No se pudo abrir la aplicación de correo.',
        ExternalLinks.technicalSupportEmail,
      ),
    ];
    for (final (title, message, uri) in cases) {
      testWidgets('$title: inline message, no SnackBar', (tester) async {
        final launcher = _Launcher((_) => false)..install(tester);
        await _pumpHelp(tester);
        await _tapLink(tester, title);
        expect(launcher.urls, [uri.toString()]);
        expect(find.byType(SnackBar), findsNothing);
        final inline = find.byKey(_errorKey);
        expect(inline, findsOneWidget);
        expect(
          tester.widget<ExomInlineMessage>(inline).kind,
          ExomMessageKind.error,
        );
        expect(
          find.descendant(of: inline, matching: find.text(message)),
          findsOneWidget,
        );
      });
    }

    testWidgets('the developer link in the credits shows its own error', (
      tester,
    ) async {
      final launcher = _Launcher((_) => false)..install(tester);
      await _pumpHelp(tester);
      final link = find.text('Desarrollador');
      await _reveal(tester, link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(launcher.urls.single, contains('github.com/carsan-dev'));
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('No se pudo abrir el perfil de GitHub.'), findsOne);
    });

    testWidgets('a platform exception also ends in the inline message', (
      tester,
    ) async {
      _Launcher((_) => PlatformException(code: 'ACTIVITY_NOT_FOUND'))
          .install(tester);
      await _pumpHelp(tester);
      await _tapLink(tester, 'Dudas del servicio');
      expect(tester.takeException(), isNull);
      expect(find.byKey(_errorKey), findsOneWidget);
    });

    testWidgets('«Reintentar» launches again and clears the message on success', (
      tester,
    ) async {
      var ok = false;
      final launcher = _Launcher((_) => ok)..install(tester);
      await _pumpHelp(tester);
      await _tapLink(tester, 'Centro de soporte');
      expect(find.byKey(_errorKey), findsOneWidget);
      ok = true;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(launcher.urls, hasLength(2));
      expect(find.byKey(_errorKey), findsNothing);
    });

    testWidgets('a link that opens shows no message', (tester) async {
      final launcher = _Launcher((_) => true)..install(tester);
      await _pumpHelp(tester);
      await _tapLink(tester, 'Política de privacidad');
      expect(launcher.urls.single, 'https://exommethod.com/privacy');
      expect(find.byKey(_errorKey), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('leaving the page while the link opens does not throw', (
      tester,
    ) async {
      final gate = Completer<bool>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        (call) => gate.future,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _channel,
          null,
        ),
      );
      await _pumpHelp(tester);
      final row = _linkRow('Centro de soporte');
      await _reveal(tester, row);
      await tester.tap(row);
      await tester.pump();
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      gate.complete(false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('CC 3 and CC 4', () {
    for (final locale in const [Locale('es'), Locale('en')]) {
      for (final width in const [320.0, 360.0]) {
        for (final scale in const [1.0, 1.3, 1.6]) {
          if (width == 360 && scale == 1.3) continue;
          testWidgets(
            '${locale.languageCode} ${width.toInt()} dp at $scale x: '
            'no overflow, nothing cut',
            (tester) async {
              _Launcher((_) => false).install(tester);
              // Tall surface: the lazy list builds the whole page.
              await _pumpHelp(
                tester,
                width: width,
                height: 9000,
                textScale: scale,
                locale: locale,
              );
              expectNoOverflow(tester);
              expectNoEllipsis(tester);
              // Everything open and the longest inline error showing.
              for (final header in find
                  .byKey(const Key('exom-accordion-header'))
                  .evaluate()
                  .toList()) {
                await tester.tap(find.byElementPredicate((e) => e == header));
                await tester.pumpAndSettle();
              }
              await tester.tap(find.byKey(const Key('help-link-row')).first);
              await tester.pumpAndSettle();
              expect(find.byKey(_errorKey), findsOneWidget);
              expectNoOverflow(tester);
              expectNoEllipsis(tester);
              // The contact titles never split a word.
              final l10n = lookupAppLocalizations(locale);
              final spec = <(Key, String)>[
                (const Key('help-feedback-row'), l10n.sendQuestionOrIssue),
                (const Key('help-settings-row'), l10n.notificationsAndCache),
              ];
              for (final (key, title) in spec) {
                final paragraph = tester.renderObject<RenderParagraph>(
                  find.descendant(
                    of: find.byKey(key),
                    matching: find.text(title.toUpperCase()),
                  ),
                );
                var longest = 0.0;
                for (final word in title.toUpperCase().split(' ')) {
                  final painter = TextPainter(
                    text: TextSpan(text: word, style: ExomType.section),
                    textDirection: TextDirection.ltr,
                    textScaler: TextScaler.linear(scale),
                  )..layout();
                  if (painter.width > longest) longest = painter.width;
                  painter.dispose();
                }
                expect(
                  paragraph.size.width,
                  greaterThanOrEqualTo(longest - 0.5),
                  reason: '"$title" split a word at ${width.toInt()} dp, $scale x',
                );
              }
            },
          );
        }
      }
    }

    for (final scale in const [1.0, 1.3, 1.6]) {
      testWidgets('chevrons of the rows sit on the right edge, like the '
          'accordion one, at $scale x (OBS-10)', (tester) async {
        await _pumpHelp(tester, textScale: scale);
        final rights = <String, double>{};
        for (final key in const ['help-feedback-row', 'help-settings-row']) {
          final chevron = find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byIcon(ExomIcons.next),
          );
          await _reveal(tester, chevron);
          final rect = tester.getRect(chevron);
          expect(rect.width, greaterThanOrEqualTo(22));
          rights[key] = rect.right;
        }
        final accordion = find.descendant(
          of: find.byType(ExomAccordion).first,
          matching: find.byIcon(ExomIcons.expand),
        );
        await tester.dragUntilVisible(
          find.text('01'),
          find.byType(Scrollable).first,
          const Offset(0, -200),
        );
        final edge = tester.getRect(accordion).right;
        rights.forEach((key, right) {
          expect(right, closeTo(edge, 1), reason: '$key at $scale x');
        });
      });
    }

    testWidgets('at 2.0 x the whole content is reachable by scrolling', (
      tester,
    ) async {
      await _pumpHelp(tester, width: 320, textScale: 2.0);
      expectNoOverflow(tester);
      final developer = find.text('Desarrollador');
      await tester.dragUntilVisible(
        developer,
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      expect(developer, findsOneWidget);
      expectNoOverflow(tester);
    });

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: guidelines and no lime ink in light', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await _pumpHelp(tester, brightness: brightness);
        await expectTapTargetGuidelines(tester);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        expectNoLimeInk(tester, brightness: brightness);
        handle.dispose();
      });
    }

    testWidgets('the headline is read once, in its original case', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpHelp(tester);
      // The page's semantic container merges the kicker, the headline and the
      // intro into one node: the headline is read once, in its original case.
      final data = tester
          .getSemantics(find.byType(ExomTwoLineHeadline))
          .getSemanticsData();
      expect(data.label, contains('Tus dudas. Con tu entrenador.'));
      expect(data.label, isNot(contains('TUS DUDAS')));
      handle.dispose();
    });

    testWidgets('the legacy glass card and snack bar are gone', (tester) async {
      await _pumpHelp(tester);
      expect(find.text('Centro de ayuda'), findsNothing);
      expect(find.byType(Card), findsNothing);
    });
  });

  testWidgets('English copy', (tester) async {
    await _pumpHelp(tester, locale: const Locale('en'));
    expect(find.text('YOUR QUESTIONS.'), findsOneWidget);
    expect(find.text('WITH YOUR COACH.'), findsOneWidget);
  });
}
