// L5-D1 (docs/plans/rediseno-app-l5-contrato-v2.md, D17-1, CC 11): «Vincular
// acceso» is confirmed in a straight EXOM sheet, not in an AlertDialog; the
// router location change closes it without submitting anything.
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/auth/presentation/pages/login_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_pages_test_support.dart';

final _es = lookupAppLocalizations(const Locale('es'));

const _sheet = Key('exom-sheet-panel');

Finder _sheetAction(String label) => find.descendant(
  of: find.byKey(const Key('exom-sheet-actions')),
  matching: find.textContaining(RegExp('^$label\$', caseSensitive: false)),
);

Future<FakeAuthBloc> _openSheet(
  WidgetTester tester, {
  String typedPassword = '',
}) async {
  final bloc = FakeAuthBloc();
  addTearDown(bloc.close);
  await pumpAuthPage(tester, const LoginPage(), bloc: bloc);
  if (typedPassword.isNotEmpty) {
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('login-password')),
        matching: find.byType(TextField),
      ),
      typedPassword,
    );
  }
  bloc.emitState(
    const AuthLinkPasswordRequired(
      email: 'lucia@ejemplo.es',
      provider: 'google',
    ),
  );
  await tester.pumpAndSettle();
  return bloc;
}

void main() {
  testWidgets(
    'opens as an EXOM sheet with the full sentence, not as a dialog',
    (tester) async {
      await _openSheet(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(_sheet), findsOneWidget);
      expect(find.text(_es.linkSocialTitle.toUpperCase()), findsOneWidget);
      expect(
        find.text(_es.linkSocialDescription('lucia@ejemplo.es', 'google')),
        findsOneWidget,
      );
      expect(
        _es.linkSocialDescription('lucia@ejemplo.es', 'google'),
        endsWith('para vincular este acceso.'),
      );
      expect(_sheetAction(_es.linkSocialConfirmButton), findsOneWidget);
      expect(_sheetAction(_es.cancel), findsOneWidget);
    },
  );

  testWidgets('confirming with a valid password submits it and keeps the '
      'email on the form', (tester) async {
    final bloc = await _openSheet(tester);
    await tester.enterText(
      find.byKey(const Key('link-password')),
      'secreto123',
    );
    await tester.tap(_sheetAction(_es.linkSocialConfirmButton));
    await tester.pumpAndSettle();

    expect(find.byKey(_sheet), findsNothing);
    final submitted = bloc.events.whereType<AuthLinkPasswordSubmitted>();
    expect(submitted, hasLength(1));
    expect(submitted.single.password, 'secreto123');
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('login-email')),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      'lucia@ejemplo.es',
    );
  });

  testWidgets('validation is unchanged: empty and short passwords do not '
      'submit', (tester) async {
    final bloc = await _openSheet(tester);
    await tester.tap(_sheetAction(_es.linkSocialConfirmButton));
    await tester.pump();
    expect(find.text(_es.passwordValidationEmpty), findsOneWidget);
    expect(bloc.events, isEmpty);

    await tester.enterText(find.byKey(const Key('link-password')), 'corta');
    await tester.tap(_sheetAction(_es.linkSocialConfirmButton));
    await tester.pump();
    expect(find.text(_es.passwordValidationLength), findsOneWidget);
    expect(bloc.events, isEmpty);
    expect(find.byKey(_sheet), findsOneWidget);
  });

  testWidgets('the password typed on the form prefills the sheet', (
    tester,
  ) async {
    await _openSheet(tester, typedPassword: 'secreto123');
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('link-password')),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      'secreto123',
    );
  });

  testWidgets('Cancelar closes the sheet and cancels the link', (tester) async {
    final bloc = await _openSheet(tester);
    await tester.tap(_sheetAction(_es.cancel));
    await tester.pumpAndSettle();

    expect(find.byKey(_sheet), findsNothing);
    expect(bloc.events.whereType<AuthLinkCancelled>(), hasLength(1));
    expect(bloc.events.whereType<AuthLinkPasswordSubmitted>(), isEmpty);
  });

  testWidgets('a tap outside does not dismiss it (as the dialog did not)', (
    tester,
  ) async {
    final bloc = await _openSheet(tester);
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
    expect(find.byKey(_sheet), findsOneWidget);
    expect(bloc.events, isEmpty);
  });

  testWidgets('the system back closes it and cancels the link once, as the '
      'dialog did', (tester) async {
    final bloc = await _openSheet(tester);
    expect(find.byKey(_sheet), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(_sheet), findsNothing);
    expect(bloc.events.whereType<AuthLinkCancelled>(), hasLength(1));
    expect(bloc.events.whereType<AuthLinkPasswordSubmitted>(), isEmpty);
    expect(bloc.events, hasLength(1));
  });

  testWidgets('a double tap on Vincular submits the password only once', (
    tester,
  ) async {
    final bloc = await _openSheet(tester);
    await tester.enterText(
      find.byKey(const Key('link-password')),
      'secreto123',
    );
    final confirm = _sheetAction(_es.linkSocialConfirmButton);
    await tester.tap(confirm);
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byKey(_sheet), findsNothing);
    expect(bloc.events.whereType<AuthLinkPasswordSubmitted>(), hasLength(1));
    expect(bloc.events.whereType<AuthLinkCancelled>(), isEmpty);
  });

  testWidgets('a router location change closes it without submitting (CC 11)', (
    tester,
  ) async {
    final bloc = FakeAuthBloc();
    addTearDown(bloc.close);
    final router = await pumpAuthPage(tester, const LoginPage(), bloc: bloc);
    bloc.emitState(
      const AuthLinkPasswordRequired(
        email: 'lucia@ejemplo.es',
        provider: 'google',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_sheet), findsOneWidget);

    router.go('/other');
    await tester.pumpAndSettle();

    expect(find.byKey(_sheet), findsNothing);
    expect(find.text('Otra'), findsOneWidget);
    expect(bloc.events.whereType<AuthLinkPasswordSubmitted>(), isEmpty);
  });
}
