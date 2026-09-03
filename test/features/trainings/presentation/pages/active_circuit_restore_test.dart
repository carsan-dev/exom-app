import 'package:exom_app/features/trainings/presentation/pages/active_circuit_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'restores live circuit feedback states and drops discarded references',
    () {
      final feedbackIds = <String, String>{
        'exercise-live': 'feedback-live',
        'exercise-stale': 'feedback-stale',
        'exercise-complete': 'feedback-complete',
        'exercise-legacy': 'feedback-legacy',
      };
      final storedStatuses = <String, String>{
        'exercise-live': 'uploading',
        'exercise-stale': 'failed',
        'exercise-complete': 'completed',
      };

      final restored = restoreCircuitFeedbackStatuses(
        feedbackIds,
        storedStatuses,
        (id) => id == 'feedback-live' ? 'failed' : null,
      );

      expect(restored, {
        'exercise-live': 'failed',
        'exercise-complete': 'completed',
        'exercise-legacy': 'completed',
      });
      expect(feedbackIds, {
        'exercise-live': 'feedback-live',
        'exercise-complete': 'feedback-complete',
        'exercise-legacy': 'feedback-legacy',
      });
    },
  );
}
