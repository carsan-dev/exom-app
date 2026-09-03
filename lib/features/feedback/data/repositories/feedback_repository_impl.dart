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
    String? uploadId,
    String? notes,
    String? exerciseId,
    String? clientUploadId,
    String? feedbackKind,
    String? trainingId,
    String? trainingExerciseId,
    String? assignmentDate,
  }) => _remoteDataSource.createFeedback(
    mediaType: mediaType,
    mediaUrl: mediaUrl,
    uploadId: uploadId,
    notes: notes,
    exerciseId: exerciseId,
    clientUploadId: clientUploadId,
    feedbackKind: feedbackKind,
    trainingId: trainingId,
    trainingExerciseId: trainingExerciseId,
    assignmentDate: assignmentDate,
  );

  @override
  Future<ManagedFeedbackUpload> uploadMedia(File file, String contentType) =>
      _remoteDataSource.uploadMedia(file, contentType);
}
