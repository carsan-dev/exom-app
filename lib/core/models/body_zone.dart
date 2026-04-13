import 'package:exom_app/l10n/app_localizations.dart';

enum BodyZone {
  neck,
  shoulders,
  chest,
  upperArm,
  forearm,
  waist,
  hips,
  thigh,
  calf;

  /// All SVG element IDs that belong to this zone (front + back views).
  List<String> get svgIds => _zoneSvgIds[this]!;

  /// SVG IDs visible in the front view only.
  List<String> get frontSvgIds =>
      svgIds.where((id) => id.endsWith('_front')).toList();

  /// SVG IDs visible in the back view only.
  List<String> get backSvgIds =>
      svgIds.where((id) => id.endsWith('_back')).toList();

  /// Resolve a raw SVG element ID to the business zone it belongs to.
  static BodyZone? fromSvgId(String svgId) => _svgIdToZone[svgId];

  /// Localized display label for this zone.
  String label(AppLocalizations l10n) {
    switch (this) {
      case BodyZone.neck:
        return l10n.measureNeck;
      case BodyZone.shoulders:
        return l10n.measureShoulders;
      case BodyZone.chest:
        return l10n.measureChest;
      case BodyZone.upperArm:
        return l10n.measureArm;
      case BodyZone.forearm:
        return l10n.measureForearm;
      case BodyZone.waist:
        return l10n.measureWaist;
      case BodyZone.hips:
        return l10n.measureHips;
      case BodyZone.thigh:
        return l10n.measureThigh;
      case BodyZone.calf:
        return l10n.measureCalf;
    }
  }
}

// ── Zone → SVG ID mapping ──────────────────────────────────────────────────

const _zoneSvgIds = <BodyZone, List<String>>{
  BodyZone.neck: [
    'neck_center_front',
    'neck_center_back',
  ],
  BodyZone.shoulders: [
    'shoulder_center_front',
    'shoulder_center_back',
  ],
  BodyZone.chest: [
    'chest_center_front',
  ],
  BodyZone.upperArm: [
    'upper_arm_left_front',
    'upper_arm_right_front',
    'upper_arm_left_back',
    'upper_arm_right_back',
  ],
  BodyZone.forearm: [
    'forearm_left_front',
    'forearm_right_front',
    'forearm_left_back',
    'forearm_right_back',
  ],
  BodyZone.waist: [
    'waist_center_front',
    'waist_center_back',
  ],
  BodyZone.hips: [
    'hips_center_front',
    'hips_center_back',
  ],
  BodyZone.thigh: [
    'thigh_left_front',
    'thigh_right_front',
    'thigh_left_back',
    'thigh_right_back',
  ],
  BodyZone.calf: [
    'calf_left_front',
    'calf_right_front',
    'calf_left_back',
    'calf_right_back',
  ],
};

// ── Reverse lookup: SVG ID → Zone ──────────────────────────────────────────

final _svgIdToZone = <String, BodyZone>{
  for (final entry in _zoneSvgIds.entries)
    for (final id in entry.value) id: entry.key,
};
