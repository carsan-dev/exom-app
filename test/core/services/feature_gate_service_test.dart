import 'package:flutter_test/flutter_test.dart';
import 'package:exom_app/core/services/feature_gate_service.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';

void main() {
  group('FeatureGateService', () {
    late FeatureGateService gate;

    UserEntity _makeUser({
      String tier = 'HIGH_TICKET',
      DateTime? trialExpiresAt,
    }) {
      return UserEntity(
        id: 'user-1',
        email: 'test@exom.app',
        role: 'CLIENT',
        tier: tier,
        trialExpiresAt: trialExpiresAt,
      );
    }

    // ── HIGH_TICKET: everything unlocked ──

    group('HIGH_TICKET user', () {
      setUp(() {
        gate = FeatureGateService(_makeUser(tier: 'HIGH_TICKET'));
      });

      test('can see meal macros', () {
        expect(gate.canSeeMealMacros, isTrue);
      });

      test('can see meal ingredients', () {
        expect(gate.canSeeMealIngredients, isTrue);
      });

      test('can see nutritional badges', () {
        expect(gate.canSeeMealNutritionalBadges, isTrue);
      });

      test('can search recipe', () {
        expect(gate.canSearchRecipe, isTrue);
      });

      test('can see exercise explanation', () {
        expect(gate.canSeeExerciseExplanation, isTrue);
      });

      test('can see common errors', () {
        expect(gate.canSeeCommonErrors, isTrue);
      });

      test('can register weight', () {
        expect(gate.canRegisterWeight, isTrue);
      });

      test('can see registered weight', () {
        expect(gate.canSeeRegisteredWeight, isTrue);
      });

      test('can use rest timer', () {
        expect(gate.canUseRestTimer, isTrue);
      });

      test('can send exercise feedback', () {
        expect(gate.canSendExerciseFeedback, isTrue);
      });

      test('can see muscle mass chart', () {
        expect(gate.canSeeMuscleMassChart, isTrue);
      });

      test('can see sleep chart', () {
        expect(gate.canSeeSleepChart, isTrue);
      });

      test('can use body composition calculator', () {
        expect(gate.canUseBodyCompositionCalculator, isTrue);
      });

      test('can use anatomical model', () {
        expect(gate.canUseAnatomicalModel, isTrue);
      });

      test('can use detailed recap', () {
        expect(gate.canUseDetailedRecap, isTrue);
      });

      test('can see recap history', () {
        expect(gate.canSeeRecapHistory, isTrue);
      });

      test('can use feedback', () {
        expect(gate.canUseFeedback, isTrue);
      });

      test('can access feedback shortcut', () {
        expect(gate.canAccessFeedbackShortcut, isTrue);
      });

      test('is not trial', () {
        expect(gate.isTrial, isFalse);
      });

      test('is not trial expired', () {
        expect(gate.isTrialExpired, isFalse);
      });
    });

    // ── LOW_TICKET: premium features locked ──

    group('LOW_TICKET user', () {
      setUp(() {
        gate = FeatureGateService(_makeUser(tier: 'LOW_TICKET'));
      });

      test('cannot see meal macros', () {
        expect(gate.canSeeMealMacros, isFalse);
      });

      test('cannot see meal ingredients', () {
        expect(gate.canSeeMealIngredients, isFalse);
      });

      test('cannot see nutritional badges', () {
        expect(gate.canSeeMealNutritionalBadges, isFalse);
      });

      test('cannot search recipe', () {
        expect(gate.canSearchRecipe, isFalse);
      });

      test('cannot see exercise explanation', () {
        expect(gate.canSeeExerciseExplanation, isFalse);
      });

      test('cannot see common errors', () {
        expect(gate.canSeeCommonErrors, isFalse);
      });

      test('cannot register weight', () {
        expect(gate.canRegisterWeight, isFalse);
      });

      test('cannot see registered weight', () {
        expect(gate.canSeeRegisteredWeight, isFalse);
      });

      test('cannot use rest timer', () {
        expect(gate.canUseRestTimer, isFalse);
      });

      test('cannot send exercise feedback', () {
        expect(gate.canSendExerciseFeedback, isFalse);
      });

      test('cannot see muscle mass chart', () {
        expect(gate.canSeeMuscleMassChart, isFalse);
      });

      test('cannot see sleep chart', () {
        expect(gate.canSeeSleepChart, isFalse);
      });

      test('cannot use body composition calculator', () {
        expect(gate.canUseBodyCompositionCalculator, isFalse);
      });

      test('cannot use anatomical model', () {
        expect(gate.canUseAnatomicalModel, isFalse);
      });

      test('cannot use detailed recap', () {
        expect(gate.canUseDetailedRecap, isFalse);
      });

      test('cannot see recap history', () {
        expect(gate.canSeeRecapHistory, isFalse);
      });

      test('cannot use feedback', () {
        expect(gate.canUseFeedback, isFalse);
      });

      test('cannot access feedback shortcut', () {
        expect(gate.canAccessFeedbackShortcut, isFalse);
      });
    });

    // ── Trial ──

    group('Trial user (active)', () {
      setUp(() {
        gate = FeatureGateService(_makeUser(
          tier: 'LOW_TICKET',
          trialExpiresAt: DateTime.now().add(const Duration(days: 7)),
        ));
      });

      test('isTrial is true', () {
        expect(gate.isTrial, isTrue);
      });

      test('isTrialExpired is false', () {
        expect(gate.isTrialExpired, isFalse);
      });

      test('trialDaysRemaining is approximately 7', () {
        expect(gate.trialDaysRemaining, inInclusiveRange(6, 7));
      });

      test('premium features still locked (LOW_TICKET)', () {
        expect(gate.canUseFeedback, isFalse);
        expect(gate.canSeeMealMacros, isFalse);
      });
    });

    group('Trial user (expired)', () {
      setUp(() {
        gate = FeatureGateService(_makeUser(
          tier: 'LOW_TICKET',
          trialExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
        ));
      });

      test('isTrial is true', () {
        expect(gate.isTrial, isTrue);
      });

      test('isTrialExpired is true', () {
        expect(gate.isTrialExpired, isTrue);
      });

      test('trialDaysRemaining is 0', () {
        expect(gate.trialDaysRemaining, equals(0));
      });
    });

    // ── updateUser ──

    group('updateUser', () {
      test('switching from LOW_TICKET to HIGH_TICKET unlocks features', () {
        gate = FeatureGateService(_makeUser(tier: 'LOW_TICKET'));
        expect(gate.canUseFeedback, isFalse);

        gate.updateUser(_makeUser(tier: 'HIGH_TICKET'));
        expect(gate.canUseFeedback, isTrue);
      });

      test('switching from HIGH_TICKET to LOW_TICKET locks features', () {
        gate = FeatureGateService(_makeUser(tier: 'HIGH_TICKET'));
        expect(gate.canSeeMealMacros, isTrue);

        gate.updateUser(_makeUser(tier: 'LOW_TICKET'));
        expect(gate.canSeeMealMacros, isFalse);
      });
    });
  });
}
