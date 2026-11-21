// «Borrar caché» in Settings must warn before it destroys an unfinished
// circuit (L3b P4). Real LocalStorage over temporary Hive boxes: what the
// page considers "in progress" is exactly what `clearCache` would delete.
import 'dart:io';
import 'dart:typed_data';

import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/services/app_update_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:exom_app/features/settings/presentation/pages/settings_page.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _Update extends Fake implements AppUpdateService {
  @override
  String get currentVersionLabel => '1.0.0 (1)';
}

class _Auth extends Fake implements AuthBloc {
  @override
  AuthState get state => AuthInitial();

  @override
  Stream<AuthState> get stream => const Stream<AuthState>.empty();

  @override
  Future<void> close() async {}
}

const _circuitKey = 'active_circuit:uid-a:2026-11-18:training:block';

void main() {
  late LocalAuthSession? session;
  late LocalStorage storage;

  setUp(() async {
    // In-memory boxes: file IO never completes under the widget test clock.
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
    await sl.reset();
    sl.registerSingleton<LocalStorage>(storage);
    sl.registerSingleton<AppUpdateService>(_Update());
  });

  tearDown(() async {
    await sl.reset();
    await Hive.close();
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _Auth()),
          BlocProvider<AppPreferencesCubit>(
            create: (_) => AppPreferencesCubit(storage),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapClearCache(WidgetTester tester) async {
    // L5-B3: the row paints its title upper case; it is found by key.
    final tile = find.byKey(const Key('settings-clear-cache'));
    await tester.scrollUntilVisible(tile, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    // Hive's write queue completes on real microtask/timer turns.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  // L5-B3 (L5-D29, D17-1): the confirmation is a straight sheet, shown every
  // time; the amber notice only appears with an unfinished circuit.
  final sheet = find.byKey(const Key('exom-sheet-panel'));
  final circuitWarning = find.byKey(
    const Key('settings-clear-cache-circuit-warning'),
  );
  final confirmButton = find.byKey(const Key('settings-clear-cache-confirm'));
  final cancelButton = find.byKey(const Key('settings-clear-cache-cancel'));

  testWidgets('warns before clearing while a circuit is in progress and '
      'keeps everything when cancelled', (tester) async {
    await storage.cacheData(_circuitKey, {'status': 'executing'});
    await storage.cacheData('home_profile', {'name': 'x'});
    await pumpSettings(tester);

    await tapClearCache(tester);

    expect(sheet, findsOneWidget);
    expect(circuitWarning, findsOneWidget);
    expect(storage.getCachedMap(_circuitKey), isNotNull);
    expect(storage.getCachedMap('home_profile'), isNotNull);

    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    expect(sheet, findsNothing);
    expect(storage.getCachedMap(_circuitKey), isNotNull);
    expect(storage.getCachedMap('home_profile'), isNotNull);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('clears as before once the user confirms', (tester) async {
    await storage.cacheData(_circuitKey, {'status': 'executing'});
    await storage.cacheData('home_profile', {'name': 'x'});
    await pumpSettings(tester);

    await tapClearCache(tester);
    expect(sheet, findsOneWidget);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(storage.getCachedMap(_circuitKey), isNull);
    expect(storage.getCachedMap('home_profile'), isNull);
    expect(find.text('Caché sin conexión borrada correctamente'),
        findsOneWidget);
  });

  testWidgets('without work in progress it still asks first and clears only '
      'after confirming (L5-D29)', (tester) async {
    await storage.cacheData('home_profile', {'name': 'x'});
    await pumpSettings(tester);

    await tapClearCache(tester);

    expect(sheet, findsOneWidget);
    expect(circuitWarning, findsNothing);
    expect(storage.getCachedMap('home_profile'), isNotNull);

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(storage.getCachedMap('home_profile'), isNull);
    expect(find.text('Caché sin conexión borrada correctamente'),
        findsOneWidget);
  });

  testWidgets('another account\'s circuit does not trigger the warning',
      (tester) async {
    session = const LocalAuthSession(uid: 'uid-b', generation: 1);
    await storage.cacheData(_circuitKey, {'status': 'executing'});
    session = const LocalAuthSession(uid: 'uid-a', generation: 1);
    await storage.cacheData('home_profile', {'name': 'x'});
    await pumpSettings(tester);

    await tapClearCache(tester);

    expect(sheet, findsOneWidget);
    expect(circuitWarning, findsNothing);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    expect(storage.getCachedMap('home_profile'), isNull);
  });
}
