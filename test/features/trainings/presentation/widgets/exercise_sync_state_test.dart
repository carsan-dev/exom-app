import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/features/trainings/presentation/widgets/exercise_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _action(
  String status, {
  String type = 'mark_exercise_completed',
  String date = '2026-09-05',
  String exercise = 'te-1',
  String? session = 'session-1',
  String training = 'training-1',
}) => {
  'id': '$type-$status-$exercise',
  'type': type,
  'date': date,
  'training_id': training,
  'training_exercise_id': exercise,
  'training_session_id': session,
  'status': status,
};

/// A `complete_training` action as OfflineSyncService.queueTrainingCompletion
/// enqueues it: no exercise id, keyed by training, date and session.
Map<String, dynamic> _completion(
  String status, {
  String date = '2026-09-05',
  String? session = 'session-1',
  String training = 'training-1',
}) => {
  'id': 'complete_training-$status-$training',
  'type': 'complete_training',
  'date': date,
  'training_id': training,
  'training_session_id': ?session,
  'status': status,
};

ExomSyncState? _state(
  List<Map<String, dynamic>> actions, {
  bool completed = false,
  bool draft = false,
  String? session = 'session-1',
}) => exerciseSyncState(
  ownedActions: actions,
  trainingId: 'training-1',
  date: '2026-09-05',
  trainingExerciseId: 'te-1',
  sessionId: session,
  isCompleted: completed,
  hasLocalDraft: draft,
);

void main() {
  group('exerciseSyncState', () {
    test('queue status wins over local state', () {
      for (final completed in [true, false]) {
        for (final draft in [true, false]) {
          expect(_state([_action('queued')], completed: completed, draft: draft),
              ExomSyncState.pendiente);
          expect(
              _state([_action('uploading')], completed: completed, draft: draft),
              ExomSyncState.enviando);
          expect(_state([_action('failed')], completed: completed, draft: draft),
              ExomSyncState.fallida);
        }
      }
    });

    test('an unknown status of a matching action is still pending', () {
      expect(_state([_action('retrying')], completed: true),
          ExomSyncState.pendiente);
    });

    test('the last matching action decides', () {
      expect(
        _state([
          _action('failed'),
          _action('queued', type: 'unmark_exercise_completed'),
        ]),
        ExomSyncState.pendiente,
      );
      expect(
        _state([
          _action('queued', type: 'unmark_exercise_completed'),
          _action('uploading'),
        ], completed: true),
        ExomSyncState.enviando,
      );
    });

    test('a pending unmark is pending sync', () {
      expect(
        _state([_action('queued', type: 'unmark_exercise_completed')]),
        ExomSyncState.pendiente,
      );
    });

    test('without an action: completed is confirmed, a draft is local only', () {
      expect(_state(const [], completed: true), ExomSyncState.confirmada);
      expect(_state(const [], completed: true, draft: true),
          ExomSyncState.confirmada);
      expect(_state(const [], draft: true), ExomSyncState.guardadaEnMovil);
      expect(_state(const []), isNull);
    });

    test('actions of another exercise, date, session or type are ignored', () {
      final others = [
        _action('failed', exercise: 'te-2'),
        _action('failed', date: '2026-09-06'),
        _action('failed', session: 'session-2'),
        _action('failed', session: null),
        _completion('failed', training: 'training-2'),
        _completion('failed', date: '2026-09-06'),
        _completion('failed', session: 'session-2'),
        _completion('failed', session: null),
        _action('failed', type: 'mark_meal_completed'),
      ];
      expect(_state(others, completed: true), ExomSyncState.confirmada);
      expect(_state(others), isNull);
    });

    test('without a session only session-less actions match', () {
      expect(
        _state([_action('queued', session: null)], session: null),
        ExomSyncState.pendiente,
      );
      expect(_state([_action('queued')], session: null), isNull);
    });
  });

  group('exerciseSyncState after "Completar todo"', () {
    // TrainingBloc marks every exercise complete after enqueueing
    // complete_training (no mark action per exercise): the row must follow
    // that action until the server acknowledges it.
    test('a queued complete_training keeps a completed row pending', () {
      expect(_state([_completion('queued')], completed: true),
          ExomSyncState.pendiente);
    });

    test('an uploading complete_training shows the row sending', () {
      expect(_state([_completion('uploading')], completed: true),
          ExomSyncState.enviando);
    });

    test('a failed complete_training shows the row failed', () {
      expect(_state([_completion('failed')], completed: true),
          ExomSyncState.fallida);
    });

    test('with no complete_training the completed row is confirmed', () {
      expect(_state(const [], completed: true), ExomSyncState.confirmada);
    });

    test('a not completed row ignores complete_training', () {
      expect(_state([_completion('failed')]), isNull);
      expect(_state([_completion('queued')], draft: true),
          ExomSyncState.guardadaEnMovil);
    });

    test('without a session only a session-less complete_training matches', () {
      expect(
        _state([_completion('failed', session: null)],
            completed: true, session: null),
        ExomSyncState.fallida,
      );
      expect(
        _state([_completion('failed')], completed: true, session: null),
        ExomSyncState.confirmada,
      );
    });

    test('a mark or unmark action of the exercise still decides, last wins', () {
      expect(
        _state([
          _action('queued'),
          _action('failed', type: 'unmark_exercise_completed'),
          _completion('queued'),
        ], completed: true),
        ExomSyncState.fallida,
      );
      expect(
        _state([
          _completion('failed'),
          _action('failed'),
          _action('queued', type: 'unmark_exercise_completed'),
        ]),
        ExomSyncState.pendiente,
      );
      expect(
        _state([
          _action('queued', type: 'unmark_exercise_completed'),
          _action('uploading'),
          _completion('failed'),
        ], completed: true),
        ExomSyncState.enviando,
      );
    });
  });

  group('circuitSyncState', () {
    test('failure, sending and pending take precedence in that order', () {
      expect(
        circuitSyncState(const [
          ExomSyncState.pendiente,
          ExomSyncState.fallida,
          ExomSyncState.enviando,
        ], allCompleted: true),
        ExomSyncState.fallida,
      );
      expect(
        circuitSyncState(const [
          ExomSyncState.pendiente,
          ExomSyncState.enviando,
          ExomSyncState.confirmada,
        ], allCompleted: true),
        ExomSyncState.enviando,
      );
      expect(
        circuitSyncState(const [
          ExomSyncState.confirmada,
          ExomSyncState.pendiente,
        ], allCompleted: true),
        ExomSyncState.pendiente,
      );
    });

    test('confirmed only when every member is completed', () {
      expect(
        circuitSyncState(const [
          ExomSyncState.confirmada,
          ExomSyncState.confirmada,
        ], allCompleted: true),
        ExomSyncState.confirmada,
      );
      expect(
        circuitSyncState(const [ExomSyncState.confirmada, null],
            allCompleted: false),
        isNull,
      );
    });
  });
}
