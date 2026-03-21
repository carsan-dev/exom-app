import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/diets/data/models/diet_model.dart';

abstract class DietRemoteDataSource {
  Future<DietModel?> getTodayDiet();
  Future<MealModel> getMeal(String mealId);
  Future<void> markMealCompleted(String mealId, String date);
}

class DietRemoteDataSourceImpl implements DietRemoteDataSource {
  final ApiClient _apiClient;

  const DietRemoteDataSourceImpl(this._apiClient);

  @override
  Future<DietModel?> getTodayDiet() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/diets/today');
      if (response.statusCode == 204 || response.data == null) return null;
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) {
          return DietModel.fromJson(inner);
        }
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 204 || e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<MealModel> getMeal(String mealId) async {
    final response = await _apiClient.dio.get<dynamic>('/meals/$mealId');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) {
        return MealModel.fromJson(inner);
      }
    }
    throw Exception('Invalid response');
  }

  @override
  Future<void> markMealCompleted(String mealId, String date) async {
    await _apiClient.dio.post<dynamic>(
      '/progress/meals/complete',
      data: {'meal_id': mealId, 'date': date},
    );
  }
}
