import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/onboarding/onboarding_resolver.dart';
import 'package:exom_app/core/prompts/automatic_prompt_coordinator.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/auth/presentation/bloc/auth_state.dart';

/// Feeds [resolveOnboarding] with the authenticated user and what this device
/// knows for the current Firebase identity. `null` when there is no
/// authenticated user with a local session (R11-R13: the reader keeps its
/// previous routing and nothing is decided about onboarding).
OnboardingResolution? resolveOnboardingForSession({
  required AuthState authState,
  required LocalAuthSession? session,
  required LocalStorage storage,
}) {
  if (authState is! AuthAuthenticated || session == null) return null;
  return resolveOnboarding(
    user: authState.user,
    localDone: storage.isOnboardingLocallyDone(
      uid: session.uid,
      email: session.email,
    ),
    hasPending: storage.onboardingPendingFor(session.uid) != null,
  );
}

/// The onboarding no longer blocks the user.
bool isOnboardingSettled(OnboardingResolution? resolution) =>
    resolution != null && !resolution.needsOnboarding;

/// Tutorial prompt in `MainShell`: only once the onboarding is settled.
bool shouldOfferTutorial({
  required OnboardingResolution? resolution,
  required bool tutorialDone,
}) => isOnboardingSettled(resolution) && !tutorialDone;

/// Session for the automatic prompts of `MainShell` (quick tour, Sunday recap
/// reminder): `null` while there is no session or the onboarding is not
/// settled, so the prompt layer checks again on a later build.
AutomaticPromptSession? automaticPromptSessionFor({
  required AuthState authState,
  required LocalAuthSession? session,
  required LocalStorage storage,
}) {
  if (session == null) return null;
  final resolution = resolveOnboardingForSession(
    authState: authState,
    session: session,
    storage: storage,
  );
  if (!isOnboardingSettled(resolution)) return null;
  final done = storage.isTutorialCompleteFor(
    uid: session.uid,
    email: session.email,
  );
  return AutomaticPromptSession(
    uid: session.uid,
    email: session.email,
    tutorialDue: shouldOfferTutorial(
      resolution: resolution,
      tutorialDone: done,
    ),
  );
}

/// Notification navigation: only with the onboarding settled and outside the
/// splash, login and onboarding routes.
bool isNotificationNavigationReady({
  required OnboardingResolution? resolution,
  required String location,
}) =>
    isOnboardingSettled(resolution) &&
    location != AppRoutes.splash &&
    location != AppRoutes.login &&
    location != AppRoutes.onboarding;
