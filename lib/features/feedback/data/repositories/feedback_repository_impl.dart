import 'dart:io';
import 'package:exom_app/features/feedback/data/datasources/feedback_remote_datasource.dart';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';

class FeedbackRepositoryImpl implements FeedbackRepository {
  final FeedbackRemoteDataSource _remoteDataSource;

  const FeedbackRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<FeedbackEntity>> getMyFeedback() =>
      _remoteDataSource.getMyFeedback();

  @override
  Future<FeedbackEntity> createFeedback({
    required String mediaType,
    required String mediaUrl,
    String? notes,
    String? exerciseId,
    String? clientUploadId,
  }) => _remoteDataSource.createFeedback(
    mediaType: mediaType,
    mediaUrl: mediaUrl,
    notes: notes,
    exerciseId: exerciseId,
    clientUploadId: clientUploadId,
  );

  @override
  Future<String> uploadMedia(File file, String contentType) =>
      _remoteDataSource.uploadMedia(file, contentType);
}
