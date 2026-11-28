// Account switch A→B: the app-wide «No se pudo subir el feedback.» notice of
// A (a persistent SnackBar, it has an action) does not survive the logout,
// is not shown over the login nor to B, and its «Reintentar» cannot run A's
// retry under B's session. Mirrors the wiring of `_ExomAppViewState` in
// lib/main.dart: AuthBloc states go to [FeedbackNoticeSession.handle], a
// notice is shown only if [FeedbackNoticeSession.acceptsNotices] and its
// action calls the retry returned by [FeedbackNoticeSession.guardRetry].
import 'dart:async';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/get_me_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/social_login_usecase.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/feedback/presentation/feedback_notice_session.dart';
import 'package:exom_app/features/feedback/presentation/feedback_notice_snack_bars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/onboarding_harness.dart';

const _sessionA = LocalAuthSession(
  uid: 'uid-a',
  email: 'a@x.test',
  generation: 1,
);
const _sessionB = LocalAuthSession(
  uid: 'uid-b',
  email: 'b@x.test',
  generation: 3,
);
const _failed = 'No se pudo subir el feedback.';

String? _keyOf(LocalAuthSession? session) =>
    session == null ? null : '${session.uid}:${session.generation}';

class _Harness {
  _Harness(this.firebase, this.auth, this.notices, this.messengerKey);

  final SessionFirebaseAuthService firebase;
  final AuthBloc auth;
  final FeedbackNoticeSession notices;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final retried = <({String id, String? session})>[];

  Future<void> retry(String id) async =>
      retried.add((id: id, session: _keyOf(firebase.currentSession)));

  /// What `_showFeedbackNotice` does with a failed notice for [id].
  Future<void> Function(String)? showFailed(String id) {
    if (!notices.acceptsNotices) return null;
    final guarded = notices.guardRetry(retry);
    FeedbackNoticeSnackBars.show(
      messengerKey.currentState!,
      message: _failed,
      action: SnackBarAction(
        label: 'Reintentar',
        onPressed: () => unawaited(guarded(id)),
      ),
    );
    return guarded;
  }

  Future<void> signIn(WidgetTester tester, LocalAuthSession session) async {
    firebase.session = session;
    auth.add(const AuthCheckStatusRequested());
    await tester.pump();
    await tester.pump();
    expect(auth.state, isA<AuthAuthenticated>());
  }

  Future<void> logout(WidgetTester tester) async {
    auth.add(const AuthLogoutRequested());
    await tester.pump();
    firebase.session = null;
    await tester.pump();
    expect(auth.state, isA<AuthUnauthenticated>());
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<_Harness> _mount(WidgetTester tester) async {
  final firebase = SessionFirebaseAuthService(null);
  final repository = ScriptedAuthRepository(
    userFromServer(profile: doneProfile),
  );
  final auth = AuthBloc(
    loginUseCase: LoginUseCase(repository),
    socialLoginUseCase: SocialLoginUseCase(repository),
    logoutUseCase: LogoutUseCase(repository),
    getMeUseCase: GetMeUseCase(repository),
    deleteAccountUseCase: DeleteAccountUseCase(repository),
    firebaseAuthService: firebase,
  );
  addTearDown(auth.close);
  final notices = FeedbackNoticeSession(
    sessionKey: () => _keyOf(firebase.currentSession),
  );
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: auth,
      child: BlocListener<AuthBloc, AuthState>(
        listener: (_, state) => notices.handle(state),
        child: MaterialApp(
          scaffoldMessengerKey: messengerKey,
          home: BlocBuilder<AuthBloc, AuthState>(
            builder: (_, state) => Scaffold(
              body: Text(state is AuthAuthenticated ? 'inicio' : 'login'),
            ),
          ),
        ),
      ),
    ),
  );
  return _Harness(firebase, auth, notices, messengerKey);
}

void main() {
  testWidgets('the failed-feedback notice of A is closed by the logout and '
      'is neither over the login nor shown to B', (tester) async {
    final h = await _mount(tester);
    await h.signIn(tester, _sessionA);
    h.showFailed('upload-a');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.text(_failed), findsOneWidget);

    await h.logout(tester);
    expect(find.text('login'), findsOneWidget);
    expect(find.text(_failed), findsNothing);

    await h.signIn(tester, _sessionB);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('inicio'), findsOneWidget);
    expect(find.text(_failed), findsNothing);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('«Reintentar» of A does nothing once B is signed in', (
    tester,
  ) async {
    final h = await _mount(tester);
    await h.signIn(tester, _sessionA);
    final retryOfA = h.showFailed('upload-a')!;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    await h.logout(tester);
    await h.signIn(tester, _sessionB);
    // The button is gone; a tap still in flight lands on the same callback.
    expect(find.text('Reintentar'), findsNothing);
    await retryOfA('upload-a');
    expect(h.retried, isEmpty);
  });

  testWidgets('«Reintentar» of A does nothing after the logout', (
    tester,
  ) async {
    final h = await _mount(tester);
    await h.signIn(tester, _sessionA);
    final retryOfA = h.showFailed('upload-a')!;
    await tester.pump();

    await h.logout(tester);
    await retryOfA('upload-a');
    expect(h.retried, isEmpty);
  });

  testWidgets('«Reintentar» works for the account that saw the notice', (
    tester,
  ) async {
    final h = await _mount(tester);
    await h.signIn(tester, _sessionA);
    h.showFailed('upload-a');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(h.retried, [(id: 'upload-a', session: 'uid-a:1')]);
  });

  testWidgets('a notice of A that arrives after the logout or under B is '
      'not shown', (tester) async {
    final h = await _mount(tester);
    await h.signIn(tester, _sessionA);
    await h.logout(tester);

    // Late notice while signed out (over the login).
    expect(h.showFailed('upload-a'), isNull);
    await tester.pump();
    expect(find.text(_failed), findsNothing);

    // Firebase already holds B but AuthBloc has not validated it yet.
    h.firebase.session = _sessionB;
    expect(h.showFailed('upload-a'), isNull);
    await tester.pump();
    expect(find.text(_failed), findsNothing);
  });
}
