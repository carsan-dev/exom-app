// Shared harness of the L5-D1 access screens (login, forgot password and
// locked account): a fake AuthBloc, a fake repository behind `sl` and a
// router-based pump with the real theme, fonts and localizations.
import 'dart:async';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;

/// AuthBloc double: records the events and lets the test emit states.
class FakeAuthBloc extends Fake implements AuthBloc {
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();
  AuthState _state = const AuthInitial();
  final List<AuthEvent> events = [];

  void emitState(AuthState state) {
    _state = state;
    _controller.add(state);
  }

  /// Emits [state] and lets the stream delivery and the rebuild it causes
  /// finish (the listener runs in a microtask, after the frame in flight).
  Future<void> pushState(WidgetTester tester, AuthState state) async {
    emitState(state);
    await tester.pump();
    await tester.pump();
  }

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  void add(AuthEvent event) => events.add(event);

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

/// AuthRepository double for the forgot-password page; everything but
/// `forgotPassword` is unused by it.
class FakeForgotRepository extends Fake implements AuthRepository {
  FakeForgotRepository({this.fails = false});

  bool fails;
  final List<String> sentTo = [];

  @override
  Future<void> forgotPassword(String email) async {
    sentTo.add(email);
    if (fails) throw StateError('forgot failed');
  }
}

Future<void> registerForgotRepository(FakeForgotRepository repository) async {
  await sl.reset();
  sl.registerSingleton<AuthRepository>(repository);
  addTearDown(sl.reset);
}

/// Pumps [page] at `/` of a router with `/other`; `/forgot` is [forgotPage]
/// when given (to push it over `/`).
Future<GoRouter> pumpAuthPage(
  WidgetTester tester,
  Widget page, {
  FakeAuthBloc? bloc,
  Widget? forgotPage,
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  Locale locale = const Locale('es'),
  bool disableAnimations = false,
  bool settle = true,
}) async {
  await loadRedesignFonts();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => GlassDecoration.brightness = Brightness.dark);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => page),
      GoRoute(
        path: '/other',
        builder: (context, state) => const Scaffold(body: Text('Otra')),
      ),
      if (forgotPage != null)
        GoRoute(path: '/forgot', builder: (context, state) => forgotPage),
    ],
  );
  addTearDown(router.dispose);
  final authBloc = bloc;
  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        GlassDecoration.brightness = Theme.of(context).brightness;
        final scaled = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        );
        return authBloc == null
            ? scaled
            : BlocProvider<AuthBloc>.value(value: authBloc, child: scaled);
      },
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return router;
}
