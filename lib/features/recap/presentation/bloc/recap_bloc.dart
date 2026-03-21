import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/domain/usecases/get_my_recaps_usecase.dart';
import 'package:exom_app/features/recap/domain/usecases/create_recap_usecase.dart';
import 'package:exom_app/features/recap/domain/usecases/update_recap_usecase.dart';
import 'package:exom_app/features/recap/domain/usecases/submit_recap_usecase.dart';

part 'recap_event.dart';
part 'recap_state.dart';

class RecapBloc extends Bloc<RecapEvent, RecapState> {
  final GetMyRecapsUseCase _getMyRecapsUseCase;
  final CreateRecapUseCase _createRecapUseCase;
  final UpdateRecapUseCase _updateRecapUseCase;
  final SubmitRecapUseCase _submitRecapUseCase;

  RecapBloc({
    required GetMyRecapsUseCase getMyRecapsUseCase,
    required CreateRecapUseCase createRecapUseCase,
    required UpdateRecapUseCase updateRecapUseCase,
    required SubmitRecapUseCase submitRecapUseCase,
  })  : _getMyRecapsUseCase = getMyRecapsUseCase,
        _createRecapUseCase = createRecapUseCase,
        _updateRecapUseCase = updateRecapUseCase,
        _submitRecapUseCase = submitRecapUseCase,
        super(const RecapInitial()) {
    on<RecapLoadRequested>(_onLoadRequested);
    on<RecapCreateRequested>(_onCreateRequested);
    on<RecapFormStarted>(_onFormStarted);
    on<RecapFieldUpdated>(_onFieldUpdated);
    on<RecapStepChanged>(_onStepChanged);
    on<RecapSaveRequested>(_onSaveRequested);
    on<RecapSubmitRequested>(_onSubmitRequested);
    on<RecapFormCancelled>(_onFormCancelled);
  }

  Map<String, dynamic> _formData = {};
  String? _editingRecapId;

  Future<void> _onLoadRequested(
    RecapLoadRequested event,
    Emitter<RecapState> emit,
  ) async {
    emit(const RecapLoading());
    try {
      final recaps = await _getMyRecapsUseCase();
      emit(RecapListLoaded(recaps));
    } catch (e) {
      emit(RecapError(e.toString()));
    }
  }

  Future<void> _onCreateRequested(
    RecapCreateRequested event,
    Emitter<RecapState> emit,
  ) async {
    final now = DateTime.now();
    final weekday = now.weekday;
    final weekStart = now.subtract(Duration(days: weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final fmt = DateFormat('yyyy-MM-dd');

    _formData = {
      'week_start_date': fmt.format(weekStart),
      'week_end_date': fmt.format(weekEnd),
    };
    _editingRecapId = null;
    emit(RecapFormActive(step: 0, formData: Map.from(_formData)));
  }

  void _onFormStarted(
    RecapFormStarted event,
    Emitter<RecapState> emit,
  ) {
    _editingRecapId = event.recapId;
    _formData = Map.from(event.initialData);
    emit(RecapFormActive(step: 0, formData: Map.from(_formData), recapId: event.recapId));
  }

  void _onFieldUpdated(
    RecapFieldUpdated event,
    Emitter<RecapState> emit,
  ) {
    _formData[event.field] = event.value;
    final current = state;
    if (current is RecapFormActive) {
      emit(RecapFormActive(
        step: current.step,
        formData: Map.from(_formData),
        recapId: _editingRecapId,
      ));
    }
  }

  void _onStepChanged(
    RecapStepChanged event,
    Emitter<RecapState> emit,
  ) {
    emit(RecapFormActive(
      step: event.step,
      formData: Map.from(_formData),
      recapId: _editingRecapId,
    ));
  }

  Future<void> _onSaveRequested(
    RecapSaveRequested event,
    Emitter<RecapState> emit,
  ) async {
    emit(const RecapLoading());
    try {
      if (_editingRecapId != null) {
        await _updateRecapUseCase(_editingRecapId!, _formData);
      } else {
        final created = await _createRecapUseCase(_formData);
        _editingRecapId = created.id;
      }
      final recaps = await _getMyRecapsUseCase();
      emit(RecapListLoaded(recaps));
    } catch (e) {
      emit(RecapError(e.toString()));
    }
  }

  Future<void> _onSubmitRequested(
    RecapSubmitRequested event,
    Emitter<RecapState> emit,
  ) async {
    emit(const RecapLoading());
    try {
      final targetId = event.recapId ?? _editingRecapId;
      if (targetId == null) {
        final created = await _createRecapUseCase(_formData);
        await _submitRecapUseCase(created.id);
      } else {
        if (_formData.isNotEmpty) {
          await _updateRecapUseCase(targetId, _formData);
        }
        await _submitRecapUseCase(targetId);
      }
      final recaps = await _getMyRecapsUseCase();
      emit(RecapSubmitted(recaps));
    } catch (e) {
      emit(RecapError(e.toString()));
    }
  }

  void _onFormCancelled(
    RecapFormCancelled event,
    Emitter<RecapState> emit,
  ) {
    _formData = {};
    _editingRecapId = null;
    add(const RecapLoadRequested());
  }
}
