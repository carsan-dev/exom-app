import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';
import 'package:exom_app/features/feedback/domain/usecases/get_my_feedback_usecase.dart';
import 'package:exom_app/features/feedback/domain/usecases/create_feedback_usecase.dart';
import 'package:exom_app/features/feedback/domain/usecases/upload_feedback_media_usecase.dart';

part 'feedback_event.dart';
part 'feedback_state.dart';

class FeedbackBloc extends Bloc<FeedbackEvent, FeedbackState> {
  final GetMyFeedbackUseCase _getMyFeedbackUseCase;
  final CreateFeedbackUseCase _createFeedbackUseCase;
  final UploadFeedbackMediaUseCase _uploadFeedbackMediaUseCase;

  FeedbackBloc({
    required GetMyFeedbackUseCase getMyFeedbackUseCase,
    required CreateFeedbackUseCase createFeedbackUseCase,
    required UploadFeedbackMediaUseCase uploadFeedbackMediaUseCase,
  }) : _getMyFeedbackUseCase = getMyFeedbackUseCase,
       _createFeedbackUseCase = createFeedbackUseCase,
       _uploadFeedbackMediaUseCase = uploadFeedbackMediaUseCase,
       super(const FeedbackInitial()) {
    on<FeedbackLoadRequested>(_onLoadRequested);
    on<FeedbackSubmitRequested>(_onSubmitRequested);
    on<FeedbackUploadAndSubmit>(_onUploadAndSubmit);
  }

  Future<void> _onLoadRequested(
    FeedbackLoadRequested event,
    Emitter<FeedbackState> emit,
  ) async {
    emit(const FeedbackLoading());
    try {
      final items = await _getMyFeedbackUseCase();
      emit(FeedbackLoaded(items));
    } catch (e) {
      emit(FeedbackError(e.toString()));
    }
  }

  Future<void> _onSubmitRequested(
    FeedbackSubmitRequested event,
    Emitter<FeedbackState> emit,
  ) async {
    emit(const FeedbackSubmitting());
    try {
      await _createFeedbackUseCase(
        mediaType: event.mediaType,
        mediaUrl: event.mediaUrl,
        notes: event.notes,
        exerciseId: event.exerciseId,
      );
      final items = await _getMyFeedbackUseCase();
      emit(FeedbackSubmitSuccess(items));
    } catch (e) {
      emit(FeedbackError(e.toString()));
    }
  }

  Future<void> _onUploadAndSubmit(
    FeedbackUploadAndSubmit event,
    Emitter<FeedbackState> emit,
  ) async {
    emit(const FeedbackSubmitting());
    try {
      final fileUrl = await _uploadFeedbackMediaUseCase(
        event.file,
        event.contentType,
      );
      await _createFeedbackUseCase(
        mediaType: event.mediaType,
        mediaUrl: fileUrl,
        notes: event.notes,
        exerciseId: event.exerciseId,
      );
      final items = await _getMyFeedbackUseCase();
      emit(FeedbackSubmitSuccess(items));
    } catch (e) {
      emit(FeedbackError(e.toString()));
    }
  }
}
