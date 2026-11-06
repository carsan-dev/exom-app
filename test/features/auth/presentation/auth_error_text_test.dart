import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/auth/presentation/pages/login_page.dart';
import 'package:exom_app/features/trainings/presentation/bloc/active_exercise_bloc.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final es = lookupAppLocalizations(const Locale('es'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('missing email instruction is localized with the provider', () {
    final message = AuthErrorMessages.missingEmail('Google');
    expect(AuthErrorMessages.missingEmailProvider(message), 'Google');
    expect(authErrorText(es, message), es.authMissingEmailForLink('Google'));
    expect(authErrorText(es, message), contains('Google'));
    expect(authErrorText(en, message), contains('Sign in with your current method'));
    expect(authErrorText(es, message), isNot(es.authOperationError));
  });

  test('expired link request is localized', () {
    expect(authErrorText(es, AuthErrorMessages.linkRequestExpired), es.authLinkRequestExpired);
    expect(authErrorText(en, AuthErrorMessages.linkRequestExpired), en.authLinkRequestExpired);
  });

  test('unknown messages still fall back to generic', () {
    expect(authErrorText(es, 'raw boom'), es.authOperationError);
  });

  test('active exercise execution collision has a dedicated message', () {
    expect(ActiveExerciseState.otherExecutionMessage,
        'Existing workout belongs to another execution');
    expect(es.activeExerciseOtherExecution, isNot(es.activeExerciseSaveError));
    expect(en.activeExerciseOtherExecution, isNot(en.activeExerciseSaveError));
  });
}
