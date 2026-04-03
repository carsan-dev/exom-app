import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/challenges/data/models/challenge_model.dart';
import 'package:exom_app/features/challenges/data/models/achievement_model.dart';

abstract class ChallengesRemoteDataSource {
  Future<List<ChallengeModel>> getMyChallenges();
  Future<void> updateProgress(String challengeId, double value);
  Future<List<AchievementModel>> getMyAchievements();
  Future<int> getMyStreakDays();
}

class ChallengesRemoteDataSourceImpl implements ChallengesRemoteDataSource {
  final ApiClient _apiClient;

  const ChallengesRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<ChallengeModel>> getMyChallenges() async {
    final response = await _apiClient.dio.get<dynamic>('/challenges/my');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final items = data['data'];
      if (items is List) {
        return items
            .map((e) => ChallengeModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  @override
  Future<void> updateProgress(String challengeId, double value) async {
    await _apiClient.dio.put<dynamic>(
      '/challenges/$challengeId/progress',
      data: {'current_value': value},
    );
  }

  @override
  Future<List<AchievementModel>> getMyAchievements() async {
    final response = await _apiClient.dio.get<dynamic>('/achievements/my');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final items = data['data'];
      if (items is List) {
        return items
            .map((e) => AchievementModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  @override
  Future<int> getMyStreakDays() async {
    final response = await _apiClient.dio.get<dynamic>('/streaks/me');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final payload = data['data'];
      if (payload is Map<String, dynamic>) {
        return (payload['current_days'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }
}
