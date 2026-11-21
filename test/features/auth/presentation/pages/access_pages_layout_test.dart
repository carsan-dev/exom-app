// L5-D1 (docs/plans/rediseno-app-l5-contrato-v2.md): the forgot-password
// flow (autofocus once the push settles, sent state), the locked-account
// screen, and the layout rules of CC 2-4 for the three screens.
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/auth/presentation/pages/account_locked_page.dart';
import 'package:exom_app/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:exom_app/features/auth/presentation/pages/login_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/exom_component_harness.dart'
    show expectNoOverflow, expectTapTargetGuidelines;
import '../../../../core/widgets/expect_no_lime_ink.dart';
import 'auth_pages_test_support.dart';

final _es = lookupAppLocalizations(const Locale('es'));

bool _emailFocused(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byType(ForgotPasswordPage),
        matching: find.byType(EditableText),
      ),
    )
    .focusNode
    .hasFocus;

Future<void> _pumpForgotPushed(WidgetTester tester, {String? email}) async {
  final repo = FakeForgotRepository();
  await registerForgotRepository(repo);
  final bloc = FakeAuthBloc();
  addTearDown(bloc.close);
  final router = await pumpAuthPage(
    tester,
    const LoginPage(),
    bloc: bloc,
    forgotPage: ForgotPasswordPage(initialEmail: email),
  );
  router.push('/forgot');
  await tester.pump();
}

void main() {
  group('forgot password', () {
    testWidgets('the email field takes focus only after the push transition '
        'settles (autofocus of T0.5)', (tester) async {
      await _pumpForgotPushed(tester);
      // Mid-transition: the page is mounted, the keyboard has not been asked
      // for yet.
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(ForgotPasswordPage), findsOneWidget);
      expect(_emailFocused(tester), isFalse);

      await tester.pumpAndSettle();
      expect(_emailFocused(tester), isTrue);
    });

    testWidgets('with reduced motion, pushed for real, the field is focused '
        'once the push finishes', (tester) async {
      final repo = FakeForgotRepository();
      await registerForgotRepository(repo);
      final bloc = FakeAuthBloc();
      addTearDown(bloc.close);
      final router = await pumpAuthPage(
        tester,
        const LoginPage(),
        bloc: bloc,
        forgotPage: const ForgotPasswordPage(),
        disableAnimations: true,
      );
      router.push('/forgot');
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordPage), findsOneWidget);
      expect(_emailFocused(tester), isTrue);
    });

    testWidgets('sent state: headline, check message and a single secondary '
        'action, no lime', (tester) async {
      final repo = FakeForgotRepository();
      await registerForgotRepository(repo);
      await pumpAuthPage(
        tester,
        const ForgotPasswordPage(initialEmail: 'lucia@ejemplo.es'),
      );
      await tester.tap(find.byKey(const Key('forgot-submit')));
      await tester.pumpAndSettle();

      expect(repo.sentTo, ['lucia@ejemplo.es']);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(_es.resetEmailSentFirst.toUpperCase()), findsOneWidget);
      expect(find.text(_es.resetEmailSentLinkTitle), findsOneWidget);
      expect(find.textContaining('lucia@ejemplo.es'), findsOneWidget);
      expect(find.textContaining('!'), findsNothing);
      expect(
        tester.widget<ExomInlineMessage>(find.byType(ExomInlineMessage)).kind,
        ExomMessageKind.ok,
      );
      expect(find.byType(ExomPrimaryButton), findsNothing);
      expect(find.byType(ExomSecondaryButton), findsOneWidget);
      expect(find.text(_es.backToLoginButton), findsOneWidget);
    });

    testWidgets('empty email is still rejected and nothing is sent', (
      tester,
    ) async {
      final repo = FakeForgotRepository();
      await registerForgotRepository(repo);
      await pumpAuthPage(tester, const ForgotPasswordPage());
      await tester.tap(find.byKey(const Key('forgot-submit')));
      await tester.pump();
      expect(repo.sentTo, isEmpty);
      expect(find.text(_es.emailValidationEmpty), findsOneWidget);
    });
  });

  group('account locked', () {
    testWidgets('error line with the real text, coach voice in first person, '
        'one way out that logs out', (tester) async {
      final bloc = FakeAuthBloc();
      addTearDown(bloc.close);
      await pumpAuthPage(tester, const AccountLockedPage(), bloc: bloc);

      expect(
        find.text(_es.accountLockedHeadlineFirst.toUpperCase()),
        findsOneWidget,
      );
      expect(
        tester.widget<ExomInlineMessage>(find.byType(ExomInlineMessage)).kind,
        ExomMessageKind.error,
      );
      expect(find.text(_es.accountLockedMessage), findsOneWidget);
      expect(find.byType(ExomReplyBlock), findsOneWidget);
      expect(find.text(_es.accountLockedCoachMessage), findsOneWidget);
      expect(
        find.text('Contacta conmigo para más información.'),
        findsOneWidget,
      );
      expect(find.byType(ExomPrimaryButton), findsNothing);

      await tester.tap(find.text(_es.backToLoginButton));
      await tester.pump();
      expect(bloc.events.whereType<AuthLogoutRequested>(), hasLength(1));
    });
  });

  group('layout (CC 3, CC 4)', () {
    const sizes = [
      (320.0, 640.0, 1.3),
      (320.0, 640.0, 1.6),
      (360.0, 740.0, 1.6),
    ];
    final scenes =
        <
          String,
          Future<void> Function(
            WidgetTester,
            Locale,
            double,
            double,
            double,
            Brightness,
          )
        >{
          'login': (tester, locale, w, h, scale, brightness) async {
            final bloc = FakeAuthBloc();
            addTearDown(bloc.close);
            await pumpAuthPage(
              tester,
              const LoginPage(),
              bloc: bloc,
              locale: locale,
              width: w,
              height: h,
              textScale: scale,
              brightness: brightness,
            );
            await bloc.pushState(
              tester,
              const AuthError(AuthErrorMessages.unknown),
            );
          },
          'forgot': (tester, locale, w, h, scale, brightness) async {
            await registerForgotRepository(FakeForgotRepository());
            await pumpAuthPage(
              tester,
              const ForgotPasswordPage(initialEmail: 'lucia@ejemplo.es'),
              locale: locale,
              width: w,
              height: h,
              textScale: scale,
              brightness: brightness,
            );
          },
          'locked': (tester, locale, w, h, scale, brightness) async {
            final bloc = FakeAuthBloc();
            addTearDown(bloc.close);
            await pumpAuthPage(
              tester,
              const AccountLockedPage(),
              bloc: bloc,
              locale: locale,
              width: w,
              height: h,
              textScale: scale,
              brightness: brightness,
            );
          },
        };

    for (final entry in scenes.entries) {
      for (final locale in const [Locale('es'), Locale('en')]) {
        for (final (w, h, scale) in sizes) {
          testWidgets('${entry.key} ${locale.languageCode} ${w.toInt()}dp '
              'x$scale: no overflow', (tester) async {
            await entry.value(tester, locale, w, h, scale, Brightness.dark);
            expectNoOverflow(tester);
          });
        }
      }

      testWidgets('${entry.key}: light theme has no lime ink and the tap '
          'targets pass', (tester) async {
        await entry.value(
          tester,
          const Locale('es'),
          390,
          844,
          1.0,
          Brightness.light,
        );
        expectNoOverflow(tester);
        expectNoLimeInk(tester);
        await expectTapTargetGuidelines(tester);
      });

      testWidgets('${entry.key}: at 2.0x everything is reachable by scroll', (
        tester,
      ) async {
        await entry.value(
          tester,
          const Locale('es'),
          320,
          640,
          2.0,
          Brightness.dark,
        );
        expectNoOverflow(tester);
        final footers = find.byType(ExomPinnedFooter);
        if (footers.evaluate().isNotEmpty) {
          // The footer is capped at 40 % of the height and scrolls itself.
          expect(
            tester.getSize(footers.first).height,
            lessThanOrEqualTo(640 * kExomPinnedFooterMaxHeightFraction + 1),
          );
        }
      });
    }
  });
}
