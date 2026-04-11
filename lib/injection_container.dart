import 'package:get_it/get_it.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/config/flavor_config.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/services/local_notification_service.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';

// Auth
import 'package:exom_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:exom_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:exom_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:exom_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/social_login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/get_me_usecase.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_bloc.dart';

// Home
import 'package:exom_app/features/home/data/datasources/home_remote_datasource.dart';
import 'package:exom_app/features/home/data/repositories/home_repository_impl.dart';
import 'package:exom_app/features/home/domain/repositories/home_repository.dart';
import 'package:exom_app/features/home/domain/usecases/get_home_summary_usecase.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';

// Trainings
import 'package:exom_app/features/trainings/data/datasources/training_remote_datasource.dart';
import 'package:exom_app/features/trainings/data/repositories/training_repository_impl.dart';
import 'package:exom_app/features/trainings/domain/repositories/training_repository.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_today_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_trainings_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/complete_training_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/mark_exercise_completed_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/get_completed_exercises_usecase.dart';
import 'package:exom_app/features/trainings/domain/usecases/unmark_exercise_completed_usecase.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';

// Diets
import 'package:exom_app/features/diets/data/datasources/diet_remote_datasource.dart';
import 'package:exom_app/features/diets/data/repositories/diet_repository_impl.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';
import 'package:exom_app/features/diets/domain/usecases/get_today_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_meal_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/mark_meal_completed_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_completed_meals_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/unmark_meal_completed_usecase.dart';
import 'package:exom_app/features/diets/presentation/bloc/diet_bloc.dart';

// Profile
import 'package:exom_app/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:exom_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:exom_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/upload_avatar_usecase.dart';
import 'package:exom_app/features/profile/presentation/bloc/profile_bloc.dart';

// Calendar
import 'package:exom_app/features/calendar/data/datasources/calendar_remote_datasource.dart';
import 'package:exom_app/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:exom_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_month_calendar_usecase.dart';
import 'package:exom_app/features/calendar/domain/usecases/get_week_summary_usecase.dart';
import 'package:exom_app/features/calendar/presentation/bloc/calendar_bloc.dart';

// Challenges
import 'package:exom_app/features/challenges/data/datasources/challenges_remote_datasource.dart';
import 'package:exom_app/features/challenges/data/repositories/challenges_repository_impl.dart';
import 'package:exom_app/features/challenges/domain/repositories/challenges_repository.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_achievement_catalog_usecase.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_my_challenges_usecase.dart';
import 'package:exom_app/features/challenges/domain/usecases/update_challenge_progress_usecase.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_my_achievements_usecase.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_my_streak_usecase.dart';
import 'package:exom_app/features/challenges/presentation/bloc/challenges_bloc.dart';

// Recap
import 'package:exom_app/features/recap/data/datasources/recap_remote_datasource.dart';
import 'package:exom_app/features/recap/data/repositories/recap_repository_impl.dart';
import 'package:exom_app/features/recap/domain/repositories/recap_repository.dart';
import 'package:exom_app/features/recap/domain/usecases/create_recap_usecase.dart';
import 'package:exom_app/features/recap/domain/usecases/get_my_recaps_usecase.dart';
import 'package:exom_app/features/recap/domain/usecases/get_recap_detail_usecase.dart';
import 'package:exom_app/features/recap/domain/usecases/mark_recap_feedback_read_usecase.dart';
import 'package:exom_app/features/recap/domain/usecases/submit_recap_usecase.dart';
import 'package:exom_app/features/recap/domain/usecases/update_recap_usecase.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';

// Feedback
import 'package:exom_app/features/feedback/data/datasources/feedback_remote_datasource.dart';
import 'package:exom_app/features/feedback/data/repositories/feedback_repository_impl.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:exom_app/features/feedback/domain/usecases/get_my_feedback_usecase.dart';
import 'package:exom_app/features/feedback/domain/usecases/create_feedback_usecase.dart';
import 'package:exom_app/features/feedback/domain/usecases/upload_feedback_media_usecase.dart';
import 'package:exom_app/features/feedback/presentation/bloc/feedback_bloc.dart';

// Services
import 'package:exom_app/core/services/fcm_service.dart';

// Metrics
import 'package:exom_app/features/metrics/data/datasources/metrics_remote_datasource.dart';
import 'package:exom_app/features/metrics/data/repositories/metrics_repository_impl.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:exom_app/features/metrics/domain/usecases/save_metric_usecase.dart';
import 'package:exom_app/features/metrics/presentation/bloc/metrics_bloc.dart';

// Onboarding
import 'package:exom_app/features/onboarding/presentation/bloc/onboarding_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ── Core ──────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<LocalStorage>(() => LocalStorage());
  sl.registerLazySingleton<AppPreferencesCubit>(
    () => AppPreferencesCubit(sl<LocalStorage>()),
  );

  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(baseUrl: FlavorConfig.instance.apiBaseUrl),
  );

  sl.registerLazySingleton<FirebaseAuthService>(() => FirebaseAuthService());

  sl.registerLazySingleton<FcmService>(
    () => FcmService(
      sl<ApiClient>(),
      sl<LocalStorage>(),
      sl<LocalNotificationService>(),
    ),
  );

  sl.registerLazySingleton<LocalNotificationService>(
    () => LocalNotificationService(),
  );

  sl.registerLazySingleton<OfflineSyncService>(
    () => OfflineSyncService(sl<ApiClient>(), sl<LocalStorage>()),
  );

  // ── Auth ──────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl<AuthRemoteDataSource>(),
      firebaseAuthService: sl<FirebaseAuthService>(),
    ),
  );

  sl.registerLazySingleton(() => LoginUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => SocialLoginUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => LogoutUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => GetMeUseCase(sl<AuthRepository>()));

  sl.registerFactory(
    () => AuthBloc(
      loginUseCase: sl<LoginUseCase>(),
      socialLoginUseCase: sl<SocialLoginUseCase>(),
      logoutUseCase: sl<LogoutUseCase>(),
      getMeUseCase: sl<GetMeUseCase>(),
      firebaseAuthService: sl<FirebaseAuthService>(),
    ),
  );

  // ── Home ──────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<HomeRemoteDataSource>(
    () => HomeRemoteDataSourceImpl(sl<ApiClient>(), sl<LocalStorage>()),
  );

  sl.registerLazySingleton<HomeRepository>(
    () => HomeRepositoryImpl(sl<HomeRemoteDataSource>()),
  );

  sl.registerLazySingleton(() => GetHomeSummaryUseCase(sl<HomeRepository>()));

  sl.registerFactory(
    () => HomeBloc(getHomeSummaryUseCase: sl<GetHomeSummaryUseCase>()),
  );

  // ── Trainings ─────────────────────────────────────────────────────────────
  sl.registerLazySingleton<TrainingRemoteDataSource>(
    () => TrainingRemoteDataSourceImpl(
      sl<ApiClient>(),
      sl<LocalStorage>(),
      sl<OfflineSyncService>(),
    ),
  );

  sl.registerLazySingleton<TrainingRepository>(
    () => TrainingRepositoryImpl(sl<TrainingRemoteDataSource>()),
  );

  sl.registerLazySingleton(
    () => GetTodayTrainingUseCase(sl<TrainingRepository>()),
  );
  sl.registerLazySingleton(() => GetTrainingsUseCase(sl<TrainingRepository>()));
  sl.registerLazySingleton(() => GetTrainingUseCase(sl<TrainingRepository>()));
  sl.registerLazySingleton(
    () => MarkExerciseCompletedUseCase(sl<TrainingRepository>()),
  );
  sl.registerLazySingleton(
    () => UnmarkExerciseCompletedUseCase(sl<TrainingRepository>()),
  );
  sl.registerLazySingleton(
    () => CompleteTrainingUseCase(sl<TrainingRepository>()),
  );
  sl.registerLazySingleton(
    () => GetCompletedExercisesUseCase(sl<TrainingRepository>()),
  );

  sl.registerFactory(
    () => TrainingBloc(
      getTodayTrainingUseCase: sl<GetTodayTrainingUseCase>(),
      getTrainingsUseCase: sl<GetTrainingsUseCase>(),
      getTrainingUseCase: sl<GetTrainingUseCase>(),
      markExerciseCompletedUseCase: sl<MarkExerciseCompletedUseCase>(),
      unmarkExerciseCompletedUseCase: sl<UnmarkExerciseCompletedUseCase>(),
      completeTrainingUseCase: sl<CompleteTrainingUseCase>(),
      getCompletedExercisesUseCase: sl<GetCompletedExercisesUseCase>(),
    ),
  );

  // ── Diets ─────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<DietRemoteDataSource>(
    () => DietRemoteDataSourceImpl(
      sl<ApiClient>(),
      sl<LocalStorage>(),
      sl<OfflineSyncService>(),
    ),
  );

  sl.registerLazySingleton<DietRepository>(
    () => DietRepositoryImpl(sl<DietRemoteDataSource>()),
  );

  sl.registerLazySingleton(() => GetTodayDietUseCase(sl<DietRepository>()));
  sl.registerLazySingleton(() => GetMealUseCase(sl<DietRepository>()));
  sl.registerLazySingleton(
    () => MarkMealCompletedUseCase(sl<DietRepository>()),
  );
  sl.registerLazySingleton(
    () => UnmarkMealCompletedUseCase(sl<DietRepository>()),
  );
  sl.registerLazySingleton(
    () => GetCompletedMealsUseCase(sl<DietRepository>()),
  );

  sl.registerFactory(
    () => DietBloc(
      getTodayDietUseCase: sl<GetTodayDietUseCase>(),
      getMealUseCase: sl<GetMealUseCase>(),
      markMealCompletedUseCase: sl<MarkMealCompletedUseCase>(),
      unmarkMealCompletedUseCase: sl<UnmarkMealCompletedUseCase>(),
      getCompletedMealsUseCase: sl<GetCompletedMealsUseCase>(),
    ),
  );

  // ── Calendar ─────────────────────────────────────────────────────────────
  sl.registerLazySingleton<CalendarRemoteDataSource>(
    () => CalendarRemoteDataSourceImpl(sl<ApiClient>(), sl<LocalStorage>()),
  );

  sl.registerLazySingleton<CalendarRepository>(
    () => CalendarRepositoryImpl(sl<CalendarRemoteDataSource>()),
  );

  sl.registerLazySingleton(
    () => GetMonthCalendarUseCase(sl<CalendarRepository>()),
  );
  sl.registerLazySingleton(
    () => GetWeekSummaryUseCase(sl<CalendarRepository>()),
  );

  sl.registerFactory(
    () => CalendarBloc(
      getMonthCalendarUseCase: sl<GetMonthCalendarUseCase>(),
      getWeekSummaryUseCase: sl<GetWeekSummaryUseCase>(),
      getMyChallengesUseCase: sl<GetMyChallengesUseCase>(),
    ),
  );

  // ── Challenges ───────────────────────────────────────────────────────────
  sl.registerLazySingleton<ChallengesRemoteDataSource>(
    () => ChallengesRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<ChallengesRepository>(
    () => ChallengesRepositoryImpl(sl<ChallengesRemoteDataSource>()),
  );

  sl.registerLazySingleton(
    () => GetMyChallengesUseCase(sl<ChallengesRepository>()),
  );
  sl.registerLazySingleton(
    () => UpdateChallengeProgressUseCase(sl<ChallengesRepository>()),
  );
  sl.registerLazySingleton(
    () => GetAchievementCatalogUseCase(sl<ChallengesRepository>()),
  );
  sl.registerLazySingleton(
    () => GetMyAchievementsUseCase(sl<ChallengesRepository>()),
  );
  sl.registerLazySingleton(
    () => GetMyStreakUseCase(sl<ChallengesRepository>()),
  );

  sl.registerFactory(
    () => ChallengesBloc(
      getMyChallengesUseCase: sl<GetMyChallengesUseCase>(),
      updateChallengeProgressUseCase: sl<UpdateChallengeProgressUseCase>(),
      getAchievementCatalogUseCase: sl<GetAchievementCatalogUseCase>(),
      getMyAchievementsUseCase: sl<GetMyAchievementsUseCase>(),
      getMyStreakUseCase: sl<GetMyStreakUseCase>(),
    ),
  );

  // ── Recap ─────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<RecapRemoteDataSource>(
    () => RecapRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<RecapRepository>(
    () => RecapRepositoryImpl(sl<RecapRemoteDataSource>()),
  );

  sl.registerLazySingleton(() => CreateRecapUseCase(sl<RecapRepository>()));
  sl.registerLazySingleton(() => GetMyRecapsUseCase(sl<RecapRepository>()));
  sl.registerLazySingleton(() => UpdateRecapUseCase(sl<RecapRepository>()));
  sl.registerLazySingleton(() => SubmitRecapUseCase(sl<RecapRepository>()));
  sl.registerLazySingleton(() => GetRecapDetailUseCase(sl<RecapRepository>()));
  sl.registerLazySingleton(
    () => MarkRecapFeedbackReadUseCase(sl<RecapRepository>()),
  );

  sl.registerFactory(
    () => RecapBloc(
      getMyRecapsUseCase: sl<GetMyRecapsUseCase>(),
      createRecapUseCase: sl<CreateRecapUseCase>(),
      updateRecapUseCase: sl<UpdateRecapUseCase>(),
      submitRecapUseCase: sl<SubmitRecapUseCase>(),
      getRecapDetailUseCase: sl<GetRecapDetailUseCase>(),
      markRecapFeedbackReadUseCase: sl<MarkRecapFeedbackReadUseCase>(),
    ),
  );

  // ── Feedback ─────────────────────────────────────────────────────────────
  sl.registerLazySingleton<FeedbackRemoteDataSource>(
    () => FeedbackRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<FeedbackRepository>(
    () => FeedbackRepositoryImpl(sl<FeedbackRemoteDataSource>()),
  );

  sl.registerLazySingleton(
    () => GetMyFeedbackUseCase(sl<FeedbackRepository>()),
  );
  sl.registerLazySingleton(
    () => CreateFeedbackUseCase(sl<FeedbackRepository>()),
  );
  sl.registerLazySingleton(
    () => UploadFeedbackMediaUseCase(sl<FeedbackRepository>()),
  );

  sl.registerFactory(
    () => FeedbackBloc(
      getMyFeedbackUseCase: sl<GetMyFeedbackUseCase>(),
      createFeedbackUseCase: sl<CreateFeedbackUseCase>(),
      uploadFeedbackMediaUseCase: sl<UploadFeedbackMediaUseCase>(),
    ),
  );

  // ── Profile ───────────────────────────────────────────────────────────────
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(sl<ApiClient>(), sl<LocalStorage>()),
  );

  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl<ProfileRemoteDataSource>()),
  );

  sl.registerLazySingleton(() => GetProfileUseCase(sl<ProfileRepository>()));
  sl.registerLazySingleton(() => UpdateProfileUseCase(sl<ProfileRepository>()));
  sl.registerLazySingleton(() => UploadAvatarUseCase(sl<ProfileRepository>()));

  sl.registerFactory(
    () => ProfileBloc(
      getProfileUseCase: sl<GetProfileUseCase>(),
      updateProfileUseCase: sl<UpdateProfileUseCase>(),
      uploadAvatarUseCase: sl<UploadAvatarUseCase>(),
      metricsRepository: sl<MetricsRepository>(),
    ),
  );

  // ── Metrics ───────────────────────────────────────────────────────────────
  sl.registerLazySingleton<MetricsRemoteDataSource>(
    () => MetricsRemoteDataSourceImpl(sl<ApiClient>(), sl<LocalStorage>()),
  );

  sl.registerLazySingleton<MetricsRepository>(
    () => MetricsRepositoryImpl(sl<MetricsRemoteDataSource>()),
  );

  sl.registerLazySingleton(() => SaveMetricUseCase(sl<MetricsRepository>()));

  sl.registerFactory(
    () => MetricsBloc(
      saveMetricUseCase: sl<SaveMetricUseCase>(),
      metricsRepository: sl<MetricsRepository>(),
      updateProfileUseCase: sl<UpdateProfileUseCase>(),
    ),
  );

  // ── Onboarding ────────────────────────────────────────────────────────────
  sl.registerFactory(
    () => OnboardingBloc(
      getProfile: sl<GetProfileUseCase>(),
      updateProfile: sl<UpdateProfileUseCase>(),
      uploadAvatar: sl<UploadAvatarUseCase>(),
      localStorage: sl<LocalStorage>(),
    ),
  );
}
