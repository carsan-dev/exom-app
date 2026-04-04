import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/api/api_client.dart';
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
  List<FeedbackEntity> _cachedItems = const [];

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
      _cachedItems = items;
      emit(FeedbackLoaded(items));
    } catch (error) {
      emit(FeedbackError(_errorMessage(error), _cachedItems));
    }
  }

  Future<void> _onSubmitRequested(
    FeedbackSubmitRequested event,
    Emitter<FeedbackState> emit,
  ) async {
    emit(FeedbackSubmitting(_cachedItems));
    try {
      await _createFeedbackUseCase(
        mediaType: event.mediaType,
        mediaUrl: event.mediaUrl,
        notes: event.notes,
        exerciseId: event.exerciseId,
      );
      final items = await _getMyFeedbackUseCase();
      _cachedItems = items;
      emit(FeedbackSubmitSuccess(items));
    } catch (error) {
      emit(FeedbackError(_errorMessage(error), _cachedItems));
    }
  }

  Future<void> _onUploadAndSubmit(
    FeedbackUploadAndSubmit event,
    Emitter<FeedbackState> emit,
  ) async {
    emit(FeedbackSubmitting(_cachedItems));
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
      _cachedItems = items;
      emit(FeedbackSubmitSuccess(items));
    } catch (error) {
      emit(FeedbackError(_errorMessage(error), _cachedItems));
    }
  }

  String _errorMessage(Object error) {
    final apiException = ApiException.maybeFrom(error);
    if (apiException != null) {
      return apiException.message;
    }

    final message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }
}
