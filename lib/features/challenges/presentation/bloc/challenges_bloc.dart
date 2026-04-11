import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';
import 'package:exom_app/features/challenges/domain/entities/achievement_entity.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_my_challenges_usecase.dart';
import 'package:exom_app/features/challenges/domain/usecases/update_challenge_progress_usecase.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_achievement_catalog_usecase.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_my_achievements_usecase.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_my_streak_usecase.dart';

part 'challenges_event.dart';
part 'challenges_state.dart';

class ChallengesBloc extends Bloc<ChallengesEvent, ChallengesState> {
  final GetMyChallengesUseCase _getMyChallengesUseCase;
  final UpdateChallengeProgressUseCase _updateChallengeProgressUseCase;
  final GetAchievementCatalogUseCase _getAchievementCatalogUseCase;
  final GetMyAchievementsUseCase _getMyAchievementsUseCase;
  final GetMyStreakUseCase _getMyStreakUseCase;

  ChallengesBloc({
    required GetMyChallengesUseCase getMyChallengesUseCase,
    required UpdateChallengeProgressUseCase updateChallengeProgressUseCase,
    required GetAchievementCatalogUseCase getAchievementCatalogUseCase,
    required GetMyAchievementsUseCase getMyAchievementsUseCase,
    required GetMyStreakUseCase getMyStreakUseCase,
  }) : _getMyChallengesUseCase = getMyChallengesUseCase,
       _updateChallengeProgressUseCase = updateChallengeProgressUseCase,
       _getAchievementCatalogUseCase = getAchievementCatalogUseCase,
       _getMyAchievementsUseCase = getMyAchievementsUseCase,
       _getMyStreakUseCase = getMyStreakUseCase,
       super(const ChallengesInitial()) {
    on<ChallengesLoadRequested>(_onLoadRequested);
    on<ChallengeProgressUpdated>(_onProgressUpdated);
  }

  Future<void> _onLoadRequested(
    ChallengesLoadRequested event,
    Emitter<ChallengesState> emit,
  ) async {
    emit(const ChallengesLoading());
    try {
      final results = await Future.wait<dynamic>([
        _getMyChallengesUseCase(),
        _getAchievementCatalogUseCase(),
        _getMyAchievementsUseCase(),
        _getMyStreakUseCase(),
      ]);
      final challenges = results[0] as List<ChallengeEntity>;
      final achievementCatalog = results[1] as List<AchievementEntity>;
      final achievements = results[2] as List<AchievementEntity>;
      final streakDays = results[3] as int;

      final mainGoal = challenges.where((c) => c.isMainGoal).toList();
      final weekly = challenges.where((c) => !c.isMainGoal).toList();

      if (mainGoal.isEmpty && weekly.isEmpty) {
        emit(
          ChallengesEmpty(
            achievements: achievements,
            achievementCatalog: achievementCatalog,
            streakDays: streakDays,
          ),
        );
        return;
      }

      emit(
        ChallengesLoaded(
          mainGoals: mainGoal,
          weeklyChallenges: weekly,
          achievements: achievements,
          achievementCatalog: achievementCatalog,
          streakDays: streakDays,
        ),
      );
    } catch (error) {
      final apiException = ApiException.maybeFrom(error);
      emit(
        ChallengesError(
          message: apiException?.message ?? error.toString(),
          apiException: apiException,
        ),
      );
    }
  }

  Future<void> _onProgressUpdated(
    ChallengeProgressUpdated event,
    Emitter<ChallengesState> emit,
  ) async {
    try {
      await _updateChallengeProgressUseCase(event.challengeId, event.newValue);
      add(const ChallengesLoadRequested());
    } catch (error) {
      final apiException = ApiException.maybeFrom(error);
      emit(
        ChallengesError(
          message: apiException?.message ?? error.toString(),
          apiException: apiException,
        ),
      );
    }
  }
}
