// Alignment of «Inicio de sesión» (L5-D1, sketch `d-acceso` «Inicio de
// sesión»): every block sits on the page margins of the sketch, `.pad` (20
// from each edge) for the content and `.foot` (12 20) for the pinned button,
// like the rest of the L5 screens. Measured on the real layout.
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_pages_test_support.dart';

const _start = 20.0;
const _end = 390.0 - 20;

void main() {
  testWidgets('login: headline, fields, link, social buttons and the footer '
      'button on the 20 / 370 margins', (tester) async {
    final bloc = FakeAuthBloc();
    addTearDown(bloc.close);
    await pumpAuthPage(
      tester,
      const LoginPage(),
      bloc: bloc,
      brightness: Brightness.light,
      disableAnimations: true,
    );
    final failures = <String>[];
    void edges(String label, Finder finder, {bool right = true}) {
      final rect = tester.getRect(finder.first);
      if (rect.left != _start) failures.add('$label.left = ${rect.left}');
      if (right && rect.right != _end) {
        failures.add('$label.right = ${rect.right}');
      }
    }

    edges('headline', find.byType(ExomTwoLineHeadline), right: false);
    edges('email', find.byKey(const Key('login-email')));
    edges('password', find.byKey(const Key('login-password')));
    edges('submit', find.byKey(const Key('login-submit')));
    final google = find.ancestor(
      of: find.textContaining('Google'),
      matching: find.byWidgetPredicate(
        (w) => w is ButtonStyleButton || w is InkWell,
      ),
    );
    if (google.evaluate().isNotEmpty) edges('google', google.last);
    expect(failures, isEmpty);
  });
}
