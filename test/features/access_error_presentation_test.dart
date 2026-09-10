import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';
import 'package:exom_app/features/diets/domain/usecases/get_today_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_meal_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_completed_meals_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/mark_meal_completed_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/unmark_meal_completed_usecase.dart';
import 'package:exom_app/features/diets/presentation/bloc/diet_bloc.dart';
import 'package:exom_app/features/diets/presentation/pages/diets_page.dart';
import 'package:exom_app/features/diets/presentation/widgets/meal_detail_sheet.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';
import 'package:exom_app/features/trainings/domain/usecases/complete_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_completed_exercises_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_previous_exercise_performances_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_today_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_trainings_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/mark_exercise_completed_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/unmark_exercise_completed_usecase.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/features/trainings/presentation/pages/trainings_page.dart';
import 'package:exom_app/features/trainings/presentation/pages/training_detail_page.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';

const date = '2026-09-03';

Object failure(int status) {
  if (status == -1) return StateError('internal fixture diagnostic');
  final request = RequestOptions(path: '/fixture-only');
  return DioException(
    requestOptions: request,
    type: status == 0
        ? DioExceptionType.connectionTimeout
        : DioExceptionType.badResponse,
    response: status == 0
        ? null
        : Response(requestOptions: request, statusCode: status),
    message: 'This exception was thrown because the response has a status code',
  );
}

class _DietRepository extends Fake implements DietRepository {
  _DietRepository(this.error);
  final Object error;
  final dates = <String?>[];
  @override
  Future<DietEntity?> getTodayDiet({String? date}) async {
    dates.add(date);
    throw error;
  }

  @override
  Future<Set<String>> getCompletedMealIds({String? date}) async => throw error;
}

class _TrainingRepository extends Fake implements TrainingRepository {
  _TrainingRepository(this.error);
  final Object error;
  final dates = <String?>[];
  @override
  Future<List<TrainingEntity>> getDayTrainings({String? date}) async {
    dates.add(date);
    throw error;
  }

  @override
  Future<List<TrainingHistoryEntity>> getTrainings({String? date}) async =>
      throw error;
  @override
  Future<TrainingEntity> getTraining(String id, {String? date}) async =>
      throw error;
}

void main() {
  setUp(() async => sl.reset());
  tearDown(() async => sl.reset());
  for (final pageName in ['diets', 'meal', 'trainings', 'training']) {
    for (final status in [403, 401, 404, 423, 500, 0, -1]) {
      testWidgets('$pageName renders a safe localized error for $status', (
        tester,
      ) async {
        final diet = _DietRepository(failure(status));
        final training = _TrainingRepository(failure(status));
        sl.registerFactory<DietBloc>(
          () => DietBloc(
            getTodayDietUseCase: GetTodayDietUseCase(diet),
            getMealUseCase: GetMealUseCase(diet),
            getCompletedMealsUseCase: GetCompletedMealsUseCase(diet),
            markMealCompletedUseCase: MarkMealCompletedUseCase(diet),
            unmarkMealCompletedUseCase: UnmarkMealCompletedUseCase(diet),
          ),
        );
        sl.registerFactory<TrainingBloc>(
          () => TrainingBloc(
            getTodayTrainingUseCase: GetTodayTrainingUseCase(training),
            getTrainingsUseCase: GetTrainingsUseCase(training),
            getTrainingUseCase: GetTrainingUseCase(training),
            getCompletedExercisesUseCase: GetCompletedExercisesUseCase(
              training,
            ),
            getPreviousExercisePerformancesUseCase:
                GetPreviousExercisePerformancesUseCase(training),
            markExerciseCompletedUseCase: MarkExerciseCompletedUseCase(
              training,
            ),
            unmarkExerciseCompletedUseCase: UnmarkExerciseCompletedUseCase(
              training,
            ),
            completeTrainingUseCase: CompleteTrainingUseCase(training),
          ),
        );
        final scroll = ScrollController();
        final page = switch (pageName) {
          'diets' => const DietsPage(selectedDate: date),
          'meal' => MealDetailSheet(
            mealId: 'fixture-meal',
            selectedDate: date,
            scrollController: scroll,
          ),
          'trainings' => const TrainingsPage(selectedDate: date),
          _ => const TrainingDetailPage(
            trainingId: 'fixture-training',
            selectedDate: date,
          ),
        };
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: page),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(page.runtimeType)),
        );
        final expected = switch (status) {
          403 => l10n.errorForbidden,
          401 => l10n.errorSessionExpired,
          404 => l10n.errorNotFound,
          423 => l10n.errorAccountLocked,
          0 => l10n.errorNetwork,
          _ => l10n.errorServer,
        };
        expect(find.text(expected), findsOneWidget);
        expect(find.textContaining('DioException'), findsNothing);
        expect(
          find.textContaining('internal fixture diagnostic'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        if (status == 403 && ['diets', 'trainings'].contains(pageName)) {
          tester.widget<ErrorWidget2>(find.byType(ErrorWidget2)).onRetry!();
          await tester.pumpAndSettle();
          expect(pageName == 'diets' ? diet.dates : training.dates, [
            date,
            date,
          ]);
          expect(find.text(expected), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        scroll.dispose();
      });
    }
  }
}
