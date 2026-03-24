import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';
import 'package:exom_app/features/challenges/domain/entities/achievement_entity.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_my_challenges_usecase.dart';
import 'package:exom_app/features/challenges/domain/usecases/update_challenge_progress_usecase.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_my_achievements_usecase.dart';

part 'challenges_event.dart';
part 'challenges_state.dart';

class ChallengesBloc extends Bloc<ChallengesEvent, ChallengesState> {
  final GetMyChallengesUseCase _getMyChallengesUseCase;
  final UpdateChallengeProgressUseCase _updateChallengeProgressUseCase;
  final GetMyAchievementsUseCase _getMyAchievementsUseCase;

  ChallengesBloc({
    required GetMyChallengesUseCase getMyChallengesUseCase,
    required UpdateChallengeProgressUseCase updateChallengeProgressUseCase,
    required GetMyAchievementsUseCase getMyAchievementsUseCase,
  }) : _getMyChallengesUseCase = getMyChallengesUseCase,
       _updateChallengeProgressUseCase = updateChallengeProgressUseCase,
       _getMyAchievementsUseCase = getMyAchievementsUseCase,
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
      final results = await Future.wait([
        _getMyChallengesUseCase(),
        _getMyAchievementsUseCase(),
      ]);
      final challenges = results[0] as List<ChallengeEntity>;
      final achievements = results[1] as List<AchievementEntity>;

      final mainGoal = challenges.where((c) => c.isMainGoal).toList();
      final weekly = challenges.where((c) => !c.isMainGoal).toList();

      emit(
        ChallengesLoaded(
          mainGoals: mainGoal,
          weeklyChallenges: weekly,
          achievements: achievements,
        ),
      );
    } catch (e) {
      emit(ChallengesError(e.toString()));
    }
  }

  Future<void> _onProgressUpdated(
    ChallengeProgressUpdated event,
    Emitter<ChallengesState> emit,
  ) async {
    try {
      await _updateChallengeProgressUseCase(event.challengeId, event.newValue);
      add(const ChallengesLoadRequested());
    } catch (e) {
      emit(ChallengesError(e.toString()));
    }
  }
}
