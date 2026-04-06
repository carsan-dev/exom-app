import '../../features/auth/domain/entities/user_entity.dart';

class FeatureGateService {
  UserEntity _user;

  FeatureGateService(this._user);

  void updateUser(UserEntity user) {
    _user = user;
  }

  // ── Dietas ──
  bool get canSeeMealMacros => _user.isHighTicket;
  bool get canSeeMealIngredients => _user.isHighTicket;
  bool get canSeeMealNutritionalBadges => _user.isHighTicket;
  bool get canSearchRecipe => _user.isHighTicket;

  // ── Entrenos ──
  bool get canSeeExerciseExplanation => _user.isHighTicket;
  bool get canSeeCommonErrors => _user.isHighTicket;
  bool get canRegisterWeight => _user.isHighTicket;
  bool get canSeeRegisteredWeight => _user.isHighTicket;
  bool get canUseRestTimer => _user.isHighTicket;
  bool get canSendExerciseFeedback => _user.isHighTicket;

  // ── Perfil ──
  bool get canSeeMuscleMassChart => _user.isHighTicket;
  bool get canSeeSleepChart => _user.isHighTicket;
  bool get canUseBodyCompositionCalculator => _user.isHighTicket;
  bool get canUseAnatomicalModel => _user.isHighTicket;

  // ── Recap ──
  bool get canUseDetailedRecap => _user.isHighTicket;
  bool get canSeeRecapHistory => _user.isHighTicket;

  // ── Feedback ──
  bool get canUseFeedback => _user.isHighTicket;

  // ── Ayuda ──
  bool get canAccessFeedbackShortcut => _user.isHighTicket;

  // ── Trial ──
  bool get isTrial => _user.isTrial;
  bool get isTrialExpired => _user.isTrialExpired;
  int get trialDaysRemaining => _user.trialDaysRemaining;
}
