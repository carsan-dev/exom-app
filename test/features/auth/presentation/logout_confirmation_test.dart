// «Cerrar sesión» asks first when the current account has an unfinished
// local workout (L5-D67), from the drawer and from Settings. Real
// LocalStorage over in-memory Hive boxes, so «unfinished» is exactly what the
// storage reports.
import 'dart:io';
import 'dart:typed_data';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/services/app_update_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/settings/presentation/pages/settings_page.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _Update extends Fake implements AppUpdateService {
  @override
  String get currentVersionLabel => '1.0.0 (1)';
}

class _Auth extends Fake implements AuthBloc {
  final events = <AuthEvent>[];

  @override
  AuthState get state => AuthInitial();

  @override
  Stream<AuthState> get stream => const Stream<AuthState>.empty();

  @override
  void add(AuthEvent event) => events.add(event);

  @override
  Future<void> close() async {}
}

class _ThrowingStorage extends LocalStorage {
  _ThrowingStorage({required super.currentSession});

  @override
  List<Map<String, dynamic>> getPendingTrainingExecutions() =>
      throw StateError('storage unavailable');
}

ActiveWorkoutHiveModel _draft({String? sessionId, String? exerciseId}) =>
    ActiveWorkoutHiveModel(
      trainingId: 'training-1',
      sessionId: sessionId,
      exerciseId: exerciseId ?? 'exercise-1:2026-11-27:exec-1',
      currentSet: 1,
      completedSets: 0,
    );

Map<String, Object> _execution(String status) => {
  'id': 'exec-1',
  'training_id': 'training-1',
  'assignment_date': '2026-11-27',
  'status': status,
};

void main() {
  late LocalAuthSession? session;
  late LocalStorage storage;
  late _Auth auth;

  setUp(() async {
    Hive.init(Directory.systemTemp.path);
    if (!Hive.isAdapterRegistered(ActiveWorkoutHiveModel.typeId)) {
      Hive.registerAdapter(ActiveWorkoutHiveModelAdapter());
    }
    await Hive.openBox('auth_box', bytes: Uint8List(0));
    await Hive.openBox('cache_box', bytes: Uint8List(0));
    await Hive.openBox('settings_box', bytes: Uint8List(0));
    await Hive.openBox<ActiveWorkoutHiveModel>(
      'active_workout_box',
      bytes: Uint8List(0),
    );
    session = const LocalAuthSession(uid: 'uid-a', generation: 1);
    storage = LocalStorage(currentSession: () => session);
    auth = _Auth();
    await sl.reset();
    sl.registerSingleton<LocalStorage>(storage);
    sl.registerSingleton<AppUpdateService>(_Update());
  });

  tearDown(() async {
    await sl.reset();
    await Hive.close();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider<AppPreferencesCubit>(
            create: (_) => AppPreferencesCubit(storage),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final sheet = find.byKey(const Key('exom-sheet-panel'));
  final confirm = find.byKey(const Key('logout-unfinished-confirm'));
  final cancel = find.byKey(const Key('logout-unfinished-cancel'));
  const title = 'Tienes un entrenamiento sin terminar';

  // ── Settings ──────────────────────────────────────────────────────────────
  Future<void> tapSettingsLogout(WidgetTester tester) async {
    await pumpApp(tester, const SettingsPage());
    final button = find.byKey(const Key('settings-logout'));
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await settle(tester);
  }

  group('Settings', () {
    testWidgets('nothing unfinished: logs out with no sheet', (tester) async {
      await tapSettingsLogout(tester);
      expect(sheet, findsNothing);
      expect(auth.events.single, isA<AuthLogoutRequested>());
    });

    testWidgets('finished work pending sync only: no sheet', (tester) async {
      await storage.cacheData('training_executions', [
        _execution('pending-sync'),
      ]);
      await tapSettingsLogout(tester);
      expect(sheet, findsNothing);
      expect(auth.events.single, isA<AuthLogoutRequested>());
    });

    testWidgets('unfinished execution: Cancel keeps the session', (
      tester,
    ) async {
      await storage.cacheData('training_executions', [_execution('pending')]);
      await tapSettingsLogout(tester);
      expect(sheet, findsOneWidget);
      expect(find.text(title.toUpperCase()), findsOneWidget);
      expect(auth.events, isEmpty);

      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(auth.events, isEmpty);
    });

    testWidgets('unfinished execution: Confirm logs out', (tester) async {
      await storage.cacheData('training_executions', [
        _execution('pending-finalize'),
      ]);
      await tapSettingsLogout(tester);
      expect(sheet, findsOneWidget);

      await tester.tap(confirm);
      await settle(tester);
      expect(auth.events.single, isA<AuthLogoutRequested>());
    });

    const circuitKey = 'active_circuit:uid-a:2026-11-27:training-1:block-1:exec-1';
    Map<String, Object> circuitState() => {
      'training_session_id': 'exec-1',
      'status': 'executing',
    };

    for (final status in ['pending', 'pending-finalize']) {
      testWidgets('circuit of a $status execution: sheet', (tester) async {
        await storage.cacheData('training_executions', [_execution(status)]);
        await storage.cacheData(circuitKey, circuitState());
        await tapSettingsLogout(tester);
        expect(sheet, findsOneWidget);
      });
    }

    for (final status in ['pending-sync', 'confirmed']) {
      testWidgets('leftover circuit of a $status execution: no sheet', (
        tester,
      ) async {
        await storage.cacheData('training_executions', [_execution(status)]);
        await storage.cacheData(circuitKey, circuitState());
        await tapSettingsLogout(tester);
        expect(sheet, findsNothing);
        expect(auth.events.single, isA<AuthLogoutRequested>());
      });
    }

    testWidgets('circuit with no session id is not unfinished work', (
      tester,
    ) async {
      await storage.cacheData(
        'active_circuit:uid-a:2026-11-27:training-1:block-1',
        {'training_session_id': null, 'status': 'executing'},
      );
      await tapSettingsLogout(tester);
      expect(sheet, findsNothing);
    });

    testWidgets('session changed while the sheet is open: does nothing', (
      tester,
    ) async {
      await storage.cacheData('training_executions', [_execution('pending')]);
      await tapSettingsLogout(tester);
      expect(sheet, findsOneWidget);

      session = const LocalAuthSession(uid: 'uid-a', generation: 2);
      await tester.tap(confirm);
      await settle(tester);
      expect(auth.events, isEmpty);
    });

    for (final status in ['pending-sync', 'confirmed']) {
      testWidgets('leftover draft of a $status execution: no sheet', (
        tester,
      ) async {
        await storage.cacheData('training_executions', [_execution(status)]);
        await storage.saveActiveWorkout(_draft(sessionId: 'exec-1'));
        await tapSettingsLogout(tester);
        expect(sheet, findsNothing);
        expect(auth.events.single, isA<AuthLogoutRequested>());
      });
    }

    testWidgets('draft of an unfinished execution on its own: sheet', (
      tester,
    ) async {
      await storage.saveActiveWorkout(_draft(sessionId: 'exec-1'));
      await tapSettingsLogout(tester);
      expect(sheet, findsOneWidget);
      expect(auth.events, isEmpty);
    });

    testWidgets('draft of a pending execution: sheet', (tester) async {
      await storage.cacheData('training_executions', [_execution('pending')]);
      await storage.saveActiveWorkout(_draft(sessionId: 'exec-1'));
      await tapSettingsLogout(tester);
      expect(sheet, findsOneWidget);
    });

    testWidgets('draft with no session id is not unfinished work', (
      tester,
    ) async {
      await storage.saveActiveWorkout(_draft());
      await tapSettingsLogout(tester);
      expect(sheet, findsNothing);
      expect(auth.events.single, isA<AuthLogoutRequested>());
    });

    testWidgets('barrier tap closes the sheet without logging out', (
      tester,
    ) async {
      await storage.cacheData('training_executions', [_execution('pending')]);
      await tapSettingsLogout(tester);
      expect(sheet, findsOneWidget);
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(auth.events, isEmpty);
    });

    testWidgets('system back closes the sheet without logging out', (
      tester,
    ) async {
      await storage.cacheData('training_executions', [_execution('pending')]);
      await tapSettingsLogout(tester);
      expect(sheet, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(auth.events, isEmpty);
    });

    testWidgets('the storage check throws: logs out as before', (tester) async {
      final throwing = _ThrowingStorage(currentSession: () => session);
      await sl.reset();
      sl.registerSingleton<LocalStorage>(throwing);
      sl.registerSingleton<AppUpdateService>(_Update());
      await tapSettingsLogout(tester);
      expect(sheet, findsNothing);
      expect(auth.events.single, isA<AuthLogoutRequested>());
    });

    testWidgets('another account unfinished work does not ask', (tester) async {
      session = const LocalAuthSession(uid: 'uid-b', generation: 1);
      await storage.cacheData('training_executions', [_execution('pending')]);
      session = const LocalAuthSession(uid: 'uid-a', generation: 1);
      await tapSettingsLogout(tester);
      expect(sheet, findsNothing);
      expect(auth.events.single, isA<AuthLogoutRequested>());
    });
  });

  // ── Drawer ────────────────────────────────────────────────────────────────
  Future<void> tapDrawerLogout(WidgetTester tester) async {
    final keys = List.generate(7, (_) => GlobalKey());
    await pumpApp(
      tester,
      Scaffold(
        endDrawer: AppDrawer(drawerItemKeys: keys, displayName: 'Ana'),
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(keys[6]));
    await settle(tester);
  }

  group('Drawer', () {
    testWidgets('nothing unfinished: closes and logs out with no sheet', (
      tester,
    ) async {
      await tapDrawerLogout(tester);
      expect(sheet, findsNothing);
      expect(find.byType(Drawer), findsNothing);
      expect(auth.events.single, isA<AuthLogoutRequested>());
    });

    testWidgets('finished work pending sync only: no sheet', (tester) async {
      await storage.cacheData('training_executions', [
        _execution('pending-sync'),
      ]);
      await tapDrawerLogout(tester);
      expect(sheet, findsNothing);
      expect(auth.events.single, isA<AuthLogoutRequested>());
    });

    testWidgets('unfinished: Cancel keeps the session', (tester) async {
      await storage.cacheData('training_executions', [_execution('pending')]);
      await tapDrawerLogout(tester);
      expect(sheet, findsOneWidget);
      expect(find.text(title.toUpperCase()), findsOneWidget);
      expect(auth.events, isEmpty);

      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(auth.events, isEmpty);
    });

    testWidgets('unfinished: Confirm closes the drawer and logs out', (
      tester,
    ) async {
      await storage.cacheData('training_executions', [_execution('pending')]);
      await tapDrawerLogout(tester);
      expect(sheet, findsOneWidget);

      await tester.tap(confirm);
      await settle(tester);
      expect(auth.events.single, isA<AuthLogoutRequested>());
      expect(find.byType(Drawer), findsNothing);
    });

    testWidgets('Cancel leaves the drawer open', (tester) async {
      await storage.cacheData('training_executions', [_execution('pending')]);
      await tapDrawerLogout(tester);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(find.byType(Drawer), findsOneWidget);
      expect(auth.events, isEmpty);
    });

    testWidgets('session changed while the sheet is open: no logout', (
      tester,
    ) async {
      await storage.cacheData('training_executions', [_execution('pending')]);
      await tapDrawerLogout(tester);
      expect(sheet, findsOneWidget);
      session = const LocalAuthSession(uid: 'uid-a', generation: 2);
      await tester.tap(confirm);
      await settle(tester);
      expect(auth.events, isEmpty);
    });

    testWidgets('leftover draft of a pending-sync execution: no sheet', (
      tester,
    ) async {
      await storage.cacheData('training_executions', [
        _execution('pending-sync'),
      ]);
      await storage.saveActiveWorkout(_draft(sessionId: 'exec-1'));
      await tapDrawerLogout(tester);
      expect(sheet, findsNothing);
      expect(auth.events.single, isA<AuthLogoutRequested>());
    });
  });

  // The sheet's two stacked actions share one alignment: each label is
  // centred in a button of the same width and left edge.
  group('Sheet actions alignment', () {
    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      testWidgets('text scale $scale: both labels centred in same-width '
          'buttons', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await storage.cacheData('training_executions', [_execution('pending')]);
        await tapSettingsLogout(tester);
        expect(sheet, findsOneWidget);

        // Worst distance of a painted line (not of the Text box, which can
        // span the whole button) from the button's centre.
        double labelOffset(Finder button) {
          final text = find.descendant(
            of: button,
            matching: find.byType(RichText),
          );
          final paragraph = tester.renderObject<RenderParagraph>(text.first);
          final origin = paragraph.localToGlobal(Offset.zero);
          final centre = tester.getCenter(button).dx;
          // Words (no trailing blanks) grouped into their painted lines.
          final label = paragraph.text.toPlainText();
          final lines = <double, Rect>{};
          for (final word in RegExp(r'\S+').allMatches(label)) {
            for (final box in paragraph.getBoxesForSelection(
              TextSelection(baseOffset: word.start, extentOffset: word.end),
            )) {
              final rect = box.toRect();
              lines.update(
                rect.top.roundToDouble(),
                (line) => line.expandToInclude(rect),
                ifAbsent: () => rect,
              );
            }
          }
          var worst = 0.0;
          for (final rect in lines.values) {
            final delta = origin.dx + rect.center.dx - centre;
            if (delta.abs() > worst.abs()) worst = delta;
          }
          return worst;
        }

        expect(labelOffset(confirm), closeTo(0, 0.5));
        expect(labelOffset(cancel), closeTo(0, 0.5));
        expect(
          tester.getTopLeft(confirm).dx,
          closeTo(tester.getTopLeft(cancel).dx, 0.5),
        );
        expect(
          tester.getSize(confirm).width,
          closeTo(tester.getSize(cancel).width, 0.5),
        );
      });
    }
  });
}
