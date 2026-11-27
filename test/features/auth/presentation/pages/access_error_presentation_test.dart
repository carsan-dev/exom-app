// L5-D1 (docs/plans/rediseno-app-l5-contrato-v2.md, D14-8): access errors are
// an inline message with an icon above the button, not a SnackBar. They stay
// until the next attempt and the typed email is kept. The busy button keeps
// its label and the fields are disabled while it works.
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:exom_app/features/auth/presentation/pages/login_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_pages_test_support.dart';

final _es = lookupAppLocalizations(const Locale('es'));

const _emailKey = Key('login-email');
const _passwordKey = Key('login-password');
const _submitKey = Key('login-submit');

Finder _inner(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(TextField));

String _fieldText(WidgetTester tester, Key key) =>
    tester.widget<TextField>(_inner(key)).controller!.text;

void main() {
  group('login', () {
    testWidgets('a failed attempt shows an inline error above the button and '
        'no SnackBar', (tester) async {
      final bloc = FakeAuthBloc();
      addTearDown(bloc.close);
      await pumpAuthPage(tester, const LoginPage(), bloc: bloc);

      await bloc.pushState(tester, const AuthError(AuthErrorMessages.unknown));

      expect(find.byType(SnackBar), findsNothing);
      final message = find.byType(ExomInlineMessage);
      expect(message, findsOneWidget);
      expect(
        tester.widget<ExomInlineMessage>(message).kind,
        ExomMessageKind.error,
      );
      expect(find.text(_es.authOperationError), findsOneWidget);
      // Inside the pinned footer, right above the submit button.
      expect(
        find.descendant(
          of: find.byType(ExomPinnedFooter),
          matching: find.byType(ExomInlineMessage),
        ),
        findsOneWidget,
      );
      expect(
        tester.getBottomLeft(message).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byKey(_submitKey)).dy),
      );
    });

    testWidgets('the error stays until the next attempt and keeps the email', (
      tester,
    ) async {
      final bloc = FakeAuthBloc();
      addTearDown(bloc.close);
      await pumpAuthPage(tester, const LoginPage(), bloc: bloc);
      await tester.enterText(_inner(_emailKey), 'lucia@ejemplo.es');
      await tester.enterText(_inner(_passwordKey), 'secreto123');
      await bloc.pushState(tester, const AuthError(AuthErrorMessages.invalidCredential));
      await tester.pump(const Duration(seconds: 30));

      expect(find.text(_es.authInvalidCredential), findsOneWidget);
      expect(_fieldText(tester, _emailKey), 'lucia@ejemplo.es');

      // A new attempt clears it.
      await tester.tap(find.byKey(_submitKey));
      await tester.pump();
      expect(bloc.events.whereType<AuthLoginRequested>(), hasLength(1));
      expect(find.byType(ExomInlineMessage), findsNothing);
      expect(_fieldText(tester, _emailKey), 'lucia@ejemplo.es');
    });

    testWidgets('a social attempt clears the previous error', (tester) async {
      final bloc = FakeAuthBloc();
      addTearDown(bloc.close);
      await pumpAuthPage(tester, const LoginPage(), bloc: bloc);
      await bloc.pushState(tester, const AuthError(AuthErrorMessages.userDisabled));
      expect(find.text(_es.authUserDisabled), findsOneWidget);

      await bloc.pushState(tester, const AuthLoading());
      expect(find.byType(ExomInlineMessage), findsNothing);
    });

    testWidgets('the error text follows the locale', (tester) async {
      final bloc = FakeAuthBloc();
      addTearDown(bloc.close);
      await pumpAuthPage(
        tester,
        const LoginPage(),
        bloc: bloc,
        locale: const Locale('en'),
      );
      await bloc.pushState(tester, const AuthError(AuthErrorMessages.unknown));
      final en = lookupAppLocalizations(const Locale('en'));
      expect(find.text(en.authOperationError), findsOneWidget);
    });

    testWidgets('busy: the button keeps its label and the fields are '
        'disabled', (tester) async {
      final bloc = FakeAuthBloc();
      addTearDown(bloc.close);
      await pumpAuthPage(tester, const LoginPage(), bloc: bloc);
      await bloc.pushState(tester, const AuthLoading());

      expect(find.text(_es.loginButton.toUpperCase()), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      for (final key in [_emailKey, _passwordKey]) {
        expect(tester.widget<TextField>(_inner(key)).enabled, isFalse);
      }
      await tester.tap(find.byKey(_submitKey));
      await tester.pump();
      expect(bloc.events, isEmpty);
    });

    testWidgets('validation is unchanged: empty values do not dispatch and '
        'the message carries an icon', (tester) async {
      final bloc = FakeAuthBloc();
      addTearDown(bloc.close);
      await pumpAuthPage(tester, const LoginPage(), bloc: bloc);
      await tester.tap(find.byKey(_submitKey));
      await tester.pump();
      expect(bloc.events, isEmpty);
      expect(find.text(_es.emailValidationEmpty), findsOneWidget);
      expect(find.text(_es.passwordValidationEmpty), findsOneWidget);
      expect(find.byIcon(ExomIcons.error), findsNWidgets(2));

      await tester.enterText(_inner(_emailKey), 'lucia@ejemplo.es');
      await tester.enterText(_inner(_passwordKey), 'corta');
      await tester.tap(find.byKey(_submitKey));
      await tester.pump();
      expect(bloc.events, isEmpty);
      expect(find.text(_es.passwordValidationLength), findsOneWidget);
    });

    testWidgets('Apple is offered only on iOS', (tester) async {
      final bloc = FakeAuthBloc();
      addTearDown(bloc.close);
      await pumpAuthPage(tester, const LoginPage(), bloc: bloc);
      expect(find.text(_es.continueWithGoogle), findsOneWidget);
      expect(find.text(_es.continueWithApple), findsNothing);
    });
  });

  group('forgot password', () {
    testWidgets('a failed send shows an inline error, no SnackBar, and keeps '
        'the email', (tester) async {
      final repo = FakeForgotRepository(fails: true);
      await registerForgotRepository(repo);
      await pumpAuthPage(
        tester,
        const ForgotPasswordPage(initialEmail: 'lucia@ejemplo.es'),
      );
      await tester.tap(find.byKey(const Key('forgot-submit')));
      await tester.pump();
      await tester.pump();

      expect(repo.sentTo, ['lucia@ejemplo.es']);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(ExomInlineMessage), findsOneWidget);
      expect(find.text(_es.passwordResetEmailFailed), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ExomPinnedFooter),
          matching: find.byType(ExomInlineMessage),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 30));
      expect(find.text(_es.passwordResetEmailFailed), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'lucia@ejemplo.es',
      );

      // The next attempt clears it (and a success replaces the form).
      repo.fails = false;
      await tester.tap(find.byKey(const Key('forgot-submit')));
      await tester.pump();
      expect(find.text(_es.passwordResetEmailFailed), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text(_es.resetEmailSentLinkTitle), findsOneWidget);
    });
  });
}
