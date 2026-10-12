import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/repositories/home_repository.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/home/presentation/pages/home_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';

class _PreferencesStorage extends LocalStorage {
  @override
  ThemeMode getThemeModePreference() => ThemeMode.light;
  @override
  Locale? getLocalePreference() => const Locale('en');
  @override
  UnitSystem getUnitSystemPreference() => UnitSystem.metric;
}

class _Repository implements HomeRepository {
  int loads = 0;
  bool completed = false;

  @override
  Future<HomeSummaryEntity> getHomeSummary({DateTime? date}) async {
    loads++;
    return HomeSummaryEntity(
      trainingId: 'training',
      trainingName: 'Training',
      trainingTypes: const ['FUERZA'],
      trainingCompleted: completed,
      totalExercises: 1,
      exercisesCompleted: completed ? 1 : 0,
    );
  }
}

void main() {
  for (final initialRoute in ['/', '/calendar']) {
    testWidgets(
      'completion refresh reaches scoped HomeBloc from $initialRoute and repeats',
      (tester) async {
        await initializeDateFormatting('en');
        final repository = _Repository();
        final preferences = AppPreferencesCubit(_PreferencesStorage());
        final bloc = HomeBloc(
          getHomeSummaryUseCase: GetHomeSummaryUseCase(repository),
        )..add(const HomeLoadRequested());
        final router = GoRouter(
          initialLocation: initialRoute,
          routes: [
            ShellRoute(
              builder: (_, _, child) =>
                  BlocProvider<HomeBloc>.value(value: bloc, child: child),
              routes: [
                GoRoute(
                  path: '/',
                  pageBuilder: (_, state) => NoTransitionPage(
                    child: HomePage(
                      completionRefresh: switch (state.extra) {
                        HomeCompletionRefresh refresh => refresh,
                        _ => null,
                      },
                    ),
                  ),
                ),
                GoRoute(
                  path: '/calendar',
                  builder: (_, _) => const Scaffold(body: Text('Calendar')),
                ),
              ],
            ),
          ],
        );
        await tester.pumpWidget(
          BlocProvider<AppPreferencesCubit>.value(
            value: preferences,
            child: MaterialApp.router(
              routerConfig: router,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(repository.loads, 1);
        repository.completed = true;
        final firstRefresh = HomeCompletionRefresh();
        router.go('/', extra: firstRefresh);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(repository.loads, 2);
        expect((bloc.state as HomeLoaded).summary.trainingCompleted, isTrue);
        expect(find.byType(HomePage), findsOneWidget);
        // A route rebuild with the same intent must not reload the summary.
        router.go('/', extra: firstRefresh);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(repository.loads, 2);
        repository.completed = false;
        router.go('/', extra: HomeCompletionRefresh());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(repository.loads, 3);
        expect((bloc.state as HomeLoaded).summary.trainingCompleted, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        addTearDown(bloc.close);
        addTearDown(preferences.close);
      },
    );
  }
}
