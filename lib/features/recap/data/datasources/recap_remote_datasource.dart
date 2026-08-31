import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/recap/data/models/recap_model.dart';

abstract class RecapRemoteDataSource {
  Future<List<RecapModel>> getMyRecaps();
  Future<RecapModel> getMyRecapById(String id);
  Future<RecapModel> createRecap(Map<String, dynamic> data);
  Future<RecapModel> updateRecap(String id, Map<String, dynamic> data);
  Future<void> submitRecap(String id);
  Future<void> markFeedbackRead(String id);
}

class RecapRemoteDataSourceImpl implements RecapRemoteDataSource {
  final ApiClient _apiClient;

  const RecapRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<RecapModel>> getMyRecaps() async {
    final response = await _apiClient.dio.get<dynamic>('/recaps/my');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final wrapper = data['data'];
      if (wrapper is Map<String, dynamic>) {
        final items = wrapper['data'];
        if (items is List) {
          return items
              .map((e) => RecapModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      if (wrapper is List) {
        return wrapper
            .map((e) => RecapModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  @override
  Future<RecapModel> getMyRecapById(String id) async {
    final response = await _apiClient.dio.get<dynamic>('/recaps/my/$id');
    final respData = response.data;
    if (respData is Map<String, dynamic>) {
      final inner = respData['data'];
      if (inner is Map<String, dynamic>) {
        return RecapModel.fromJson(inner);
      }
    }
    throw Exception('Invalid recap detail response');
  }

  @override
  Future<RecapModel> createRecap(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/recaps',
      data: RecapModel.toCreateJson(data),
    );
    final respData = response.data;
    if (respData is Map<String, dynamic>) {
      final inner = respData['data'];
      if (inner is Map<String, dynamic>) {
        return RecapModel.fromJson(inner);
      }
    }
    throw Exception('Invalid create recap response');
  }

  @override
  Future<RecapModel> updateRecap(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.dio.put<dynamic>(
      '/recaps/$id',
      data: RecapModel.toUpdateJson(data),
    );
    final respData = response.data;
    if (respData is Map<String, dynamic>) {
      final inner = respData['data'];
      if (inner is Map<String, dynamic>) {
        return RecapModel.fromJson(inner);
      }
    }
    throw Exception('Invalid update recap response');
  }

  @override
  Future<void> submitRecap(String id) async {
    await _apiClient.dio.post<dynamic>('/recaps/$id/submit');
  }

  @override
  Future<void> markFeedbackRead(String id) async {
    await _apiClient.dio.post<dynamic>('/recaps/my/$id/read-feedback');
  }
}
