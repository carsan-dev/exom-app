import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/features/recap/data/models/recap_model.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';

void main() {
  test(
    'only nullable publications are decoded and feedback copies preserve them',
    () {
      final base = <String, Object?>{
        'id': 'published',
        'week_start_date': '2026-10-05',
        'week_end_date': '2026-10-11',
        'created_at': '2026-10-05',
        'draft_coach_summary': 'PRIVATE DRAFT',
        'draft_changes': 'PRIVATE DRAFT',
        'draft_next_week_goals': 'PRIVATE DRAFT',
        'admin_comments': 'PRIVATE NOTE',
        'review_version': 99,
      };
      for (final extra in [
        <String, Object?>{},
        {
          'published_coach_summary': null,
          'published_changes': null,
          'published_next_week_goals': null,
        },
      ]) {
        final legacy = RecapModel.fromJson({...base, ...extra});
        expect(legacy.publishedCoachSummary, isNull);
        expect(legacy.publishedChanges, isNull);
        expect(legacy.publishedNextWeekGoals, isNull);
        expect(legacy.hasPublishedReview, isFalse);
      }
      final published = RecapModel.fromJson({
        ...base,
        'published_coach_summary': 'Resumen',
        'published_changes': 'Cambios',
        'published_next_week_goals': 'Objetivos',
        'client_feedback_text': 'Legacy',
      });
      final readAt = DateTime(2026, 10, 8);
      final copied = published.copyWith(clientFeedbackReadAt: readAt);
      expect(copied.publishedCoachSummary, 'Resumen');
      expect(copied.publishedChanges, 'Cambios');
      expect(copied.publishedNextWeekGoals, 'Objetivos');
      expect(copied.clientFeedbackText, 'Legacy');
      expect(copied.hasPublishedReview, isTrue);
      expect(
        copied.copyWith(clientFeedbackReadAt: null).clientFeedbackReadAt,
        readAt,
      );
    },
  );

  test(
    'client create/update never forward publication or private review fields',
    () {
      final form = <String, dynamic>{
        'general_notes': 'Cliente',
        'hunger_level': null,
        'published_coach_summary': 'Published',
        'published_changes': 'Published',
        'published_next_week_goals': 'Published',
        'draft_coach_summary': 'PRIVATE',
        'draft_changes': 'PRIVATE',
        'draft_next_week_goals': 'PRIVATE',
        'admin_comments': 'PRIVATE',
        'review_version': 4,
      };
      for (final payload in [
        RecapModel.toCreateJson(form),
        RecapModel.toUpdateJson(form),
      ]) {
        expect(payload['general_notes'], 'Cliente');
        for (final key in form.keys.where(
          (key) => key != 'general_notes' && key != 'hunger_level',
        )) {
          expect(payload, isNot(contains(key)), reason: key);
        }
      }
      expect(RecapModel.toUpdateJson(form), containsPair('hunger_level', null));
    },
  );
  test(
    'optional habits survive server draft reload and feedback copy; old recaps have no data',
    () {
      final json = <String, Object?>{
        'id': 'recap-p1',
        'week_start_date': '2026-09-07',
        'week_end_date': '2026-09-13',
        'status': 'DRAFT',
        'created_at': '2026-09-07',
      };
      final old = RecapModel.fromJson(json);
      expect(old.hungerLevel, isNull);
      expect(old.energyLevel, isNull);
      expect(old.digestionLevel, isNull);
      json.addAll({
        'hunger_level': 1,
        'energy_level': 10,
        'digestion_level': 5,
        'stress_level': 0,
      });
      final restored = RecapModel.fromJson(
        json,
      ).copyWith(clientFeedbackReadAt: DateTime(2026));
      expect(restored.hungerLevel, 1);
      expect(restored.energyLevel, 10);
      expect(restored.digestionLevel, 5);
      expect(restored.stressLevel, 0);
      final form = {
        'hunger_level': 1,
        'energy_level': 10,
        'digestion_level': null,
      };
      expect(RecapModel.toCreateJson(form)['hunger_level'], 1);
      expect(
        RecapModel.toCreateJson(form).containsKey('digestion_level'),
        isFalse,
      );
      expect(
        RecapModel.toUpdateJson(form),
        containsPair('digestion_level', null),
      );
    },
  );

  test('preserves recap anatomy ids and legacy zones in create payload', () {
    final payload = RecapModel.toCreateJson({
      'average_daily_steps': 8500,
      'sleep_hours_range': 'ENTRE_6_7',
      'muscle_pain_zones': ['quadriceps_left', 'lower_back', 'thigh'],
      'improvement_areas': <String>[],
    });

    expect(payload['muscle_pain_zones'], [
      'quadriceps_left',
      'lower_back',
      'thigh',
    ]);
    expect(payload['average_daily_steps'], 8500);
  });

  test('parses recap anatomy ids from detail payload', () {
    final model = RecapModel.fromJson({
      'id': 'recap-1',
      'week_start_date': '2026-05-18T00:00:00.000Z',
      'week_end_date': '2026-05-24T00:00:00.000Z',
      'status': 'DRAFT',
      'average_daily_steps': 12345,
      'muscle_pain_zones': ['calves_right', 'calf'],
      'created_at': '2026-05-24T10:00:00.000Z',
    });

    expect(model.musclePainZones, ['calves_right', 'calf']);
    expect(model.averageDailySteps, 12345);
  });

  test(
    'preserves null average daily steps so a saved value can be cleared',
    () {
      final payload = RecapModel.toUpdateJson({
        'average_daily_steps': null,
        'muscle_pain_zones': <String>[],
        'improvement_areas': <String>[],
      });

      expect(payload, containsPair('average_daily_steps', null));
    },
  );

  test('create omits nulls while update preserves explicit clears', () {
    final formData = {
      'average_daily_steps': null,
      'training_notes': '',
      'hydration_enabled': false,
      'hydration_level': 'ALTA',
      'stress_enabled': false,
      'stress_level': 4,
    };

    expect(
      RecapModel.toCreateJson(formData),
      isNot(contains('average_daily_steps')),
    );

    final update = RecapModel.toUpdateJson(formData);
    expect(update, containsPair('average_daily_steps', null));
    expect(update, containsPair('training_notes', null));
    expect(update, containsPair('hydration_level', null));
    expect(update, containsPair('stress_level', null));
  });

  test('validates the shared average daily steps range', () {
    expect(isValidRecapAverageDailySteps(null), isTrue);
    expect(isValidRecapAverageDailySteps(0), isTrue);
    expect(isValidRecapAverageDailySteps(recapAverageDailyStepsMax), isTrue);
    expect(isValidRecapAverageDailySteps(-1), isFalse);
    expect(
      isValidRecapAverageDailySteps(recapAverageDailyStepsMax + 1),
      isFalse,
    );
    expect(isValidRecapAverageDailySteps('8500'), isFalse);
  });
}
