import 'package:flutter/material.dart' show IconData, Icons;

/// Icons of the «Retos» screen, named by meaning (L5-D38).
///
/// The app is moving to Lucide through a central `ExomIcons` class that does
/// not exist on this branch yet. Every Material icon of the feature goes
/// through this file only, so the switch to `ExomIcons` is a one-file change.
abstract final class ChallengeIcons {
  /// Streak kicker (sketch `i-flame`).
  static const IconData streak = Icons.local_fire_department_outlined;

  /// Unlocked achievement tile (sketch `i-medal`).
  static const IconData achievement = Icons.workspace_premium_outlined;

  /// Locked achievement tile (sketch `i-lock`).
  static const IconData locked = Icons.lock_outline;

  /// Completed challenge, «hecha» mark (sketch `i-check`, `.x-ok`).
  static const IconData done = Icons.check;
}
