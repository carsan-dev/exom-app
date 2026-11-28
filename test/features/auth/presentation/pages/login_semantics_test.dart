// Accessibility of «Inicio de sesión»: email and password fields expose their
// label to the screen reader (es and en).
import 'package:exom_app/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_pages_test_support.dart';

void main() {
  const cases = <(Locale, String, String)>[
    (Locale('es'), 'Correo electrónico', 'Contraseña'),
    (Locale('en'), 'Email', 'Password'),
  ];
  for (final (locale, email, password) in cases) {
    testWidgets('login ${locale.languageCode}: fields expose their label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final bloc = FakeAuthBloc();
      addTearDown(bloc.close);
      await pumpAuthPage(tester, const LoginPage(), bloc: bloc, locale: locale);
      final emailNode = tester.getSemantics(
        find.byKey(const Key('login-email')),
      );
      final passwordNode = tester.getSemantics(
        find.byKey(const Key('login-password')),
      );
      // ignore: avoid_print
      print(
        '${locale.languageCode} email="${emailNode.label}" '
        'password="${passwordNode.label}"',
      );
      expect(emailNode.label, contains(email));
      expect(passwordNode.label, contains(password));
      handle.dispose();
    });
  }
}
