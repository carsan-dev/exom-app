// Alignment of «Recuperar contraseña» and «Cuenta bloqueada» (L5-D1, sketch
// `d-acceso`): like «Inicio de sesión», the content sits on `.pad` (20 from
// each edge) and the pinned button on `.foot` (12 20). Measured on the real
// layout.
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/auth/presentation/pages/account_locked_page.dart';
import 'package:exom_app/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_pages_test_support.dart';

const _start = 20.0;
const _end = 390.0 - 20;

List<String> _edges(
  WidgetTester tester,
  String screen,
  List<(String, Finder, bool)> blocks,
) {
  final failures = <String>[];
  for (final (label, finder, right) in blocks) {
    final rect = tester.getRect(finder.first);
    if (rect.left != _start) failures.add('$label.left = ${rect.left}');
    if (right && rect.right != _end) {
      failures.add('$label.right = ${rect.right}');
    }
  }
  return failures;
}

void main() {
  testWidgets('forgot password: headline, field and footer button on the '
      '20 / 370 margins', (tester) async {
    await registerForgotRepository(FakeForgotRepository());
    await pumpAuthPage(
      tester,
      const ForgotPasswordPage(),
      brightness: Brightness.light,
      disableAnimations: true,
    );
    final failures = _edges(tester, 'forgot', [
      ('headline', find.byType(ExomTwoLineHeadline), false),
      ('email', find.byKey(const Key('forgot-email')), true),
      ('submit', find.byKey(const Key('forgot-submit')), true),
    ]);
    expect(failures, isEmpty);
  });

  testWidgets('account locked: headline, error line, coach voice and footer '
      'button on the 20 / 370 margins', (tester) async {
    final bloc = FakeAuthBloc();
    addTearDown(bloc.close);
    await pumpAuthPage(
      tester,
      const AccountLockedPage(),
      bloc: bloc,
      brightness: Brightness.light,
      disableAnimations: true,
    );
    final l10n = lookupAppLocalizations(const Locale('es'));
    final failures = _edges(tester, 'locked', [
      (
        'headline',
        find.text(l10n.accountLockedHeadlineFirst.toUpperCase()),
        false,
      ),
      ('error', find.byType(ExomInlineMessage), true),
      ('coach', find.byType(ExomReplyBlock), true),
      ('back', find.byType(ExomSecondaryButton), true),
    ]);
    expect(failures, isEmpty);
  });
}
