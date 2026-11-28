// L6-UX8 (M-11, M-13): the metrics form is inert while the day loads and
// while it saves, so nothing typed is lost to the repopulation that follows
// and a second save or a date change cannot start mid-save.
import 'dart:async';

import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:exom_app/features/metrics/domain/usecases/save_metric_usecase.dart';
import 'package:exom_app/features/metrics/presentation/bloc/metrics_bloc.dart';
import 'package:exom_app/features/metrics/presentation/pages/metrics_page.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 11, 18);

final _metric = BodyMetricEntity(
  id: 'metric-1',
  date: _today,
  weightKg: 68.4,
  heightCm: 168,
  muscleMassKg: 31.2,
  sleepHours: 7.5,
);

class _Repository extends Fake implements MetricsRepository {
  Completer<BodyMetricEntity?>? loadGate;
  Completer<void>? saveGate;
  var loads = 0;
  final saved = <Map<String, dynamic>>[];

  @override
  Future<BodyMetricEntity?> getLatestMetric({String? date}) async {
    loads++;
    final gate = loadGate;
    return gate == null ? _metric : gate.future;
  }

  @override
  Future<BodyMetricEntity> saveMetric(Map<String, dynamic> data) async {
    saved.add({...data});
    await saveGate?.future;
    return _metric;
  }
}

class _Profile extends Fake implements ProfileEntity {}

class _ProfileRepository extends Fake implements ProfileRepository {
  @override
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data) async =>
      _Profile();
}

class _Storage extends LocalStorage {
  @override
  ThemeMode getThemeModePreference() => ThemeMode.dark;
  @override
  Locale? getLocalePreference() => null;
  @override
  UnitSystem getUnitSystemPreference() => UnitSystem.metric;
  @override
  Map<String, dynamic>? getCachedMap(String key) => null;
}

Future<_Repository> _mount(
  WidgetTester tester, {
  Completer<BodyMetricEntity?>? loadGate,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await sl.reset();
  addTearDown(sl.reset);
  final repository = _Repository()..loadGate = loadGate;
  final storage = _Storage();
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerFactory<MetricsBloc>(
    () => MetricsBloc(
      saveMetricUseCase: SaveMetricUseCase(repository),
      metricsRepository: repository,
      updateProfileUseCase: UpdateProfileUseCase(_ProfileRepository()),
    ),
  );
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    BlocProvider<AppPreferencesCubit>(
      create: (_) => AppPreferencesCubit(storage),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.dark,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => MetricsFormPage(clock: () => _today),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return repository;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(MetricsFormPage)));

/// The height and sleep fields, found by their unit suffix.
Finder _height() => find.widgetWithText(TextFormField, 'cm');
Finder _sleep() => find.widgetWithText(TextFormField, 'h');

String _text(WidgetTester tester, Finder field) =>
    tester.widget<TextFormField>(field).controller!.text;

/// The list builds lazily: scrolls so that the height field is built.
Future<void> _reveal(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('while the day loads (M-11)', () {
    testWidgets('typing in height does not change the field and the loaded '
        'value is what shows', (tester) async {
      final gate = Completer<BodyMetricEntity?>();
      await _mount(tester, loadGate: gate);
      await _reveal(tester);
      await tester.enterText(_height(), '170');
      await tester.pump();
      expect(_text(tester, _height()), isNot('170'));
      gate.complete(_metric);
      await _settle(tester);
      expect(_text(tester, _height()), '168,0');
    });

    testWidgets('typing in sleep does not change the field', (tester) async {
      final gate = Completer<BodyMetricEntity?>();
      await _mount(tester, loadGate: gate);
      await tester.scrollUntilVisible(
        find.text(_l10n(tester).sleepHoursDescription),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(_sleep(), '9');
      await tester.pump();
      expect(_text(tester, _sleep()), isNot('9'));
      gate.complete(_metric);
      await _settle(tester);
      expect(_text(tester, _sleep()), '7,5');
    });

    testWidgets('shows the loading indicator with its live-region semantics '
        'and hides it when loaded', (tester) async {
      final handle = tester.ensureSemantics();
      final gate = Completer<BodyMetricEntity?>();
      await _mount(tester, loadGate: gate);
      final label = _l10n(tester).metricsDayLoading;
      expect(find.byKey(const Key('metrics-day-loading')), findsOneWidget);
      final node = tester.getSemantics(find.byKey(const Key('metrics-day-loading')));
      expect(node.label, contains(label));
      expect(node.flagsCollection.isLiveRegion, isTrue);
      gate.complete(_metric);
      await _settle(tester);
      expect(find.byKey(const Key('metrics-day-loading')), findsNothing);
      handle.dispose();
    });

    testWidgets('after loading the fields are editable again', (tester) async {
      final gate = Completer<BodyMetricEntity?>();
      await _mount(tester, loadGate: gate);
      gate.complete(_metric);
      await _settle(tester);
      await _reveal(tester);
      await tester.enterText(_height(), '170');
      await tester.pump();
      expect(_text(tester, _height()), '170');
    });
  });

  group('while the form saves (M-13)', () {
    testWidgets('the date field does nothing and the inputs are inert', (
      tester,
    ) async {
      final repository = await _mount(tester);
      await _reveal(tester);
      await tester.enterText(_height(), '170');
      await tester.pump();
      repository.saveGate = Completer<void>();
      await tester.tap(find.byType(ExomPrimaryButton));
      await tester.pump();
      expect(repository.saved, hasLength(1));
      final loadsBefore = repository.loads;
      final dateField = find.text(_l10n(tester).todayLabel);
      await tester.scrollUntilVisible(
        dateField,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(dateField, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(repository.loads, loadsBefore);
      await _reveal(tester);
      await tester.enterText(_height(), '171');
      await tester.pump();
      expect(_text(tester, _height()), '170');
    });
  });
}
