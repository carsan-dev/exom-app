import 'package:get_it/get_it.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/config/flavor_config.dart';
import 'package:exom_app/core/storage/local_storage.dart';

// Auth
import 'package:exom_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:exom_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:exom_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:exom_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/social_login_usecase.dart';
import 'package:exom_app/features/auth/domain/usecases/logout_usecase.dart';
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
import 'package:exom_app/features/trainings/domain/usecases/mark_exercise_completed_usecase.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';

// Diets
import 'package:exom_app/features/diets/data/datasources/diet_remote_datasource.dart';
import 'package:exom_app/features/diets/data/repositories/diet_repository_impl.dart';
import 'package:exom_app/features/diets/domain/repositories/diet_repository.dart';
import 'package:exom_app/features/diets/domain/usecases/get_today_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_meal_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/mark_meal_completed_usecase.dart';
import 'package:exom_app/features/diets/presentation/bloc/diet_bloc.dart';

// Profile
import 'package:exom_app/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:exom_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:exom_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/upload_avatar_usecase.dart';
import 'package:exom_app/features/profile/presentation/bloc/profile_bloc.dart';

// Services
import 'package:exom_app/core/services/fcm_service.dart';

// Metrics
import 'package:exom_app/features/metrics/data/datasources/metrics_remote_datasource.dart';
import 'package:exom_app/features/metrics/data/repositories/metrics_repository_impl.dart';
import 'package:exom_app/features/metrics/domain/repositories/metrics_repository.dart';
import 'package:exom_app/features/metrics/domain/usecases/save_metric_usecase.dart';
import 'package:exom_app/features/metrics/presentation/bloc/metrics_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ── Core ──────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<LocalStorage>(() => LocalStorage());

  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(baseUrl: FlavorConfig.instance.apiBaseUrl),
  );

  sl.registerLazySingleton<FirebaseAuthService>(() => FirebaseAuthService());

  sl.registerLazySingleton<FcmService>(() => FcmService(sl<ApiClient>()));

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

  sl.registerFactory(
    () => AuthBloc(
      loginUseCase: sl<LoginUseCase>(),
      socialLoginUseCase: sl<SocialLoginUseCase>(),
      logoutUseCase: sl<LogoutUseCase>(),
      firebaseAuthService: sl<FirebaseAuthService>(),
    ),
  );

  // ── Home ──────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<HomeRemoteDataSource>(
    () => HomeRemoteDataSourceImpl(sl<ApiClient>()),
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
    () => TrainingRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<TrainingRepository>(
    () => TrainingRepositoryImpl(sl<TrainingRemoteDataSource>()),
  );

  sl.registerLazySingleton(() => GetTodayTrainingUseCase(sl<TrainingRepository>()));
  sl.registerLazySingleton(() => GetTrainingsUseCase(sl<TrainingRepository>()));
  sl.registerLazySingleton(() => GetTrainingUseCase(sl<TrainingRepository>()));
  sl.registerLazySingleton(() => MarkExerciseCompletedUseCase(sl<TrainingRepository>()));

  sl.registerFactory(
    () => TrainingBloc(
      getTodayTrainingUseCase: sl<GetTodayTrainingUseCase>(),
      getTrainingsUseCase: sl<GetTrainingsUseCase>(),
      getTrainingUseCase: sl<GetTrainingUseCase>(),
      markExerciseCompletedUseCase: sl<MarkExerciseCompletedUseCase>(),
    ),
  );

  // ── Diets ─────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<DietRemoteDataSource>(
    () => DietRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<DietRepository>(
    () => DietRepositoryImpl(sl<DietRemoteDataSource>()),
  );

  sl.registerLazySingleton(() => GetTodayDietUseCase(sl<DietRepository>()));
  sl.registerLazySingleton(() => GetMealUseCase(sl<DietRepository>()));
  sl.registerLazySingleton(() => MarkMealCompletedUseCase(sl<DietRepository>()));

  sl.registerFactory(
    () => DietBloc(
      getTodayDietUseCase: sl<GetTodayDietUseCase>(),
      getMealUseCase: sl<GetMealUseCase>(),
      markMealCompletedUseCase: sl<MarkMealCompletedUseCase>(),
    ),
  );

  // ── Profile ───────────────────────────────────────────────────────────────
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl<ProfileRemoteDataSource>()),
  );

  sl.registerLazySingleton(() => GetProfileUseCase(sl<ProfileRepository>()));
  sl.registerLazySingleton(() => UploadAvatarUseCase(sl<ProfileRepository>()));

  sl.registerFactory(
    () => ProfileBloc(
      getProfileUseCase: sl<GetProfileUseCase>(),
      uploadAvatarUseCase: sl<UploadAvatarUseCase>(),
      metricsRepository: sl<MetricsRepository>(),
    ),
  );

  // ── Metrics ───────────────────────────────────────────────────────────────
  sl.registerLazySingleton<MetricsRemoteDataSource>(
    () => MetricsRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<MetricsRepository>(
    () => MetricsRepositoryImpl(sl<MetricsRemoteDataSource>()),
  );

  sl.registerLazySingleton(() => SaveMetricUseCase(sl<MetricsRepository>()));

  sl.registerFactory(
    () => MetricsBloc(saveMetricUseCase: sl<SaveMetricUseCase>()),
  );
}
