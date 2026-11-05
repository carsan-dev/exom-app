import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';
import 'package:exom_app/features/feedback/domain/usecases/get_my_feedback_usecase.dart';
import 'package:exom_app/features/feedback/domain/usecases/create_feedback_usecase.dart';
import 'package:exom_app/features/feedback/domain/usecases/upload_feedback_media_usecase.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';

part 'feedback_event.dart';
part 'feedback_state.dart';

class FeedbackBloc extends Bloc<FeedbackEvent, FeedbackState> {
  final GetMyFeedbackUseCase _getMyFeedbackUseCase;
  final CreateFeedbackUseCase _createFeedbackUseCase;
  final UploadFeedbackMediaUseCase _uploadFeedbackMediaUseCase;
  final LocalStorage _localStorage;
  final String? _ownerSession;
  StreamSubscription<FeedbackUploadNotice>? _uploadSubscription;
  int _loadEpoch = 0;
  bool _closing = false;
  List<FeedbackEntity> _cachedItems = const [];

  FeedbackBloc({
    required GetMyFeedbackUseCase getMyFeedbackUseCase,
    required CreateFeedbackUseCase createFeedbackUseCase,
    required UploadFeedbackMediaUseCase uploadFeedbackMediaUseCase,
    required Stream<FeedbackUploadNotice> uploadNotices,
    required LocalStorage localStorage,
  }) : _getMyFeedbackUseCase = getMyFeedbackUseCase,
       _createFeedbackUseCase = createFeedbackUseCase,
       _uploadFeedbackMediaUseCase = uploadFeedbackMediaUseCase,
       _localStorage = localStorage,
       _ownerSession = localStorage.sessionStamp,
       super(const FeedbackInitial()) {
    on<FeedbackLoadRequested>(_onLoadRequested);
    on<FeedbackSubmitRequested>(_onSubmitRequested);
    on<FeedbackUploadAndSubmit>(_onUploadAndSubmit);
    _uploadSubscription = uploadNotices.listen((notice) {
      if (notice.kind == FeedbackUploadNoticeKind.completed &&
          _isOwnerCurrent) {
        add(const FeedbackLoadRequested(silent: true));
      }
    });
  }

  bool get _isOwnerCurrent =>
      !_closing &&
      !isClosed &&
      _ownerSession != null &&
      _localStorage.sessionStamp == _ownerSession;

  @override
  Future<void> close() async {
    _closing = true;
    await _uploadSubscription?.cancel();
    await super.close();
  }

  Future<void> _onLoadRequested(
    FeedbackLoadRequested event,
    Emitter<FeedbackState> emit,
  ) async {
    if (!_isOwnerCurrent) return;
    final epoch = ++_loadEpoch;
    bool current() => _isOwnerCurrent && !emit.isDone && epoch == _loadEpoch;
    // A background confirmation must not unmount the user's next unsent draft.
    if (!event.silent) emit(const FeedbackLoading());
    try {
      final items = await _localStorage.sessionTask(_getMyFeedbackUseCase.call);
      if (!current()) return;
      _cachedItems = items;
      emit(FeedbackLoaded(items));
    } catch (error) {
      if (!current()) return;
      emit(_failure(error));
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
      emit(_failure(error));
    }
  }

  Future<void> _onUploadAndSubmit(
    FeedbackUploadAndSubmit event,
    Emitter<FeedbackState> emit,
  ) async {
    emit(FeedbackSubmitting(_cachedItems));
    try {
      final upload = await _uploadFeedbackMediaUseCase(
        event.file,
        event.contentType,
      );
      await _createFeedbackUseCase(
        mediaType: event.mediaType,
        mediaUrl: upload.fileUrl,
        uploadId: upload.uploadId,
        notes: event.notes,
        exerciseId: event.exerciseId,
      );
      final items = await _getMyFeedbackUseCase();
      _cachedItems = items;
      emit(FeedbackSubmitSuccess(items));
    } catch (error) {
      emit(_failure(error));
    }
  }

  FeedbackError _failure(Object error) {
    if (ApiException.maybeFrom(error)?.isNetworkError == true) {
      return FeedbackError.offline(_cachedItems);
    }
    return FeedbackError(_errorMessage(error), _cachedItems);
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
