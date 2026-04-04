import 'dart:io';
import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/feedback/data/models/feedback_model.dart';

abstract class FeedbackRemoteDataSource {
  Future<List<FeedbackModel>> getMyFeedback();
  Future<FeedbackModel> createFeedback({
    required String mediaType,
    required String mediaUrl,
    String? notes,
    String? exerciseId,
  });
  Future<String> uploadMedia(File file, String contentType);
}

class FeedbackRemoteDataSourceImpl implements FeedbackRemoteDataSource {
  final ApiClient _apiClient;

  const FeedbackRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<FeedbackModel>> getMyFeedback() async {
    final response = await _apiClient.dio.get<dynamic>('/feedback/my');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final wrapper = data['data'];
      if (wrapper is Map<String, dynamic>) {
        final items = wrapper['data'];
        if (items is List) {
          return items
              .map((e) => FeedbackModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      if (wrapper is List) {
        return wrapper
            .map((e) => FeedbackModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  @override
  Future<FeedbackModel> createFeedback({
    required String mediaType,
    required String mediaUrl,
    String? notes,
    String? exerciseId,
  }) async {
    final body = <String, dynamic>{
      'media_type': mediaType,
      'media_url': mediaUrl,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (exerciseId != null && exerciseId.isNotEmpty)
        'exercise_id': exerciseId,
    };
    final response = await _apiClient.dio.post<dynamic>(
      '/feedback',
      data: body,
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) {
        return FeedbackModel.fromJson(inner);
      }
    }
    throw Exception('Invalid create feedback response');
  }

  @override
  Future<String> uploadMedia(File file, String contentType) async {
    final ext = file.path.split('.').last.toLowerCase();
    final fileKey = 'feedback/${DateTime.now().millisecondsSinceEpoch}.$ext';

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: '${DateTime.now().millisecondsSinceEpoch}.$ext',
        contentType: DioMediaType.parse(contentType),
      ),
      'file_key': fileKey,
      'content_type': contentType,
    });

    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/uploads/file',
        data: formData,
      );

      final payload = response.data;
      if (payload is! Map<String, dynamic>) {
        throw Exception('Invalid upload response');
      }
      return ((payload['data'] as Map<String, dynamic>)['file_url'] as String?)
          ?? (payload['file_url'] as String);
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final message = statusCode == null
          ? 'No se pudo subir el archivo. Revisa tu conexion e intentalo de nuevo.'
          : 'No se pudo completar la subida del archivo ($statusCode).';
      throw Exception(message);
    }
  }
}
