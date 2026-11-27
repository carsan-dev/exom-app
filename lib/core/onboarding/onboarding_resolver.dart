import 'package:equatable/equatable.dart';
import 'package:exom_app/features/auth/domain/entities/user_entity.dart';

/// Values accepted by `POST /profile/me/onboarding` in `outcome`. A pending
/// entry without outcome is the self-repair of a legacy Hive mark (OP-D13).
abstract final class OnboardingOutcomes {
  static const completed = 'COMPLETED';
  static const skipped = 'SKIPPED';
}

/// Destination and side effects for one authenticated user (plan table 3.3).
class OnboardingResolution extends Equatable {
  const OnboardingResolution({
    required this.needsOnboarding,
    this.writeLocalCache = false,
    this.registerRepair = false,
    this.clearPending = false,
    this.sendPending = false,
  });

  /// The only case that routes to the onboarding flow (R6).
  final bool needsOnboarding;

  /// Server says done: mirror it in the Hive mark (R2/R3).
  final bool writeLocalCache;

  /// Server pending but Hive already done without a pending entry: register
  /// a pending entry without outcome (R4).
  final bool registerRepair;

  /// Drop this identity's pending entry: the server already decided (R3) or
  /// the account is not a client (R1).
  final bool clearPending;

  /// Send this identity's pending entry (R4, R5, R7).
  final bool sendPending;

  @override
  List<Object?> get props => [
    needsOnboarding,
    writeLocalCache,
    registerRepair,
    clearPending,
    sendPending,
  ];
}

/// Single decision point for every onboarding reader (OP-D5).
///
/// [localDone] is `true` when the Hive mark exists **or** a pending entry of
/// the same identity exists (OP-D16); [hasPending] distinguishes the latter.
/// Only a server-validated CLIENT whose server state is `pending` and with
/// nothing done locally needs the onboarding; `unknown` never does (OP-D6).
OnboardingResolution resolveOnboarding({
  required UserEntity user,
  required bool localDone,
  bool hasPending = false,
}) {
  // R9/R10: the offline entity carries assumptions, never server facts.
  if (!user.isServerValidated) {
    return const OnboardingResolution(needsOnboarding: false);
  }
  // R1: staff never go through onboarding and never send the mark.
  if (!user.isClient) {
    return const OnboardingResolution(
      needsOnboarding: false,
      clearPending: true,
    );
  }
  switch (user.onboardingStatus) {
    case OnboardingServerStatus.done:
      // R2/R3.
      return const OnboardingResolution(
        needsOnboarding: false,
        writeLocalCache: true,
        clearPending: true,
      );
    case OnboardingServerStatus.pending:
      if (!localDone) {
        // R6.
        return const OnboardingResolution(needsOnboarding: true);
      }
      // R4 (mark only) / R5 (pending present).
      return OnboardingResolution(
        needsOnboarding: false,
        registerRepair: !hasPending,
        sendPending: true,
      );
    case OnboardingServerStatus.unknown:
      // R7/R8: API without the column. Keep any pending; a send gets 404.
      return OnboardingResolution(
        needsOnboarding: false,
        sendPending: hasPending,
      );
  }
}
