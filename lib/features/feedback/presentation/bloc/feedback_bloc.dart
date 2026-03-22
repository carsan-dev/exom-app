import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';
import 'package:exom_app/features/feedback/domain/usecases/get_my_feedback_usecase.dart';
import 'package:exom_app/features/feedback/domain/usecases/create_feedback_usecase.dart';

part 'feedback_event.dart';
part 'feedback_state.dart';

class FeedbackBloc extends Bloc<FeedbackEvent, FeedbackState> {
  final GetMyFeedbackUseCase _getMyFeedbackUseCase;
  final CreateFeedbackUseCase _createFeedbackUseCase;

  FeedbackBloc({
    required GetMyFeedbackUseCase getMyFeedbackUseCase,
    required CreateFeedbackUseCase createFeedbackUseCase,
  })  : _getMyFeedbackUseCase = getMyFeedbackUseCase,
        _createFeedbackUseCase = createFeedbackUseCase,
        super(const FeedbackInitial()) {
    on<FeedbackLoadRequested>(_onLoadRequested);
    on<FeedbackSubmitRequested>(_onSubmitRequested);
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
}
