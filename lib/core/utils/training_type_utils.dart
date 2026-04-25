import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/l10n/app_localizations.dart';

const _trainingAccentColorRegex = r'^#?(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$';

String normalizeTrainingTypeLabel(String? type) {
  return (type ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
}

String trainingTypeKey(String? type) {
  final normalized = normalizeTrainingTypeLabel(type).toLowerCase();
  if (normalized.isEmpty) return '';

  return normalized
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> resolveTrainingTypes({
  List<String>? types,
  String? legacyType,
}) {
  final uniqueTypes = <String, String>{};
  final rawTypes = <String>[...?types];

  if (legacyType != null) {
    rawTypes.add(legacyType);
  }

  for (final rawType in rawTypes) {
    final normalizedType = normalizeTrainingTypeLabel(rawType);

    if (normalizedType.isEmpty) {
      continue;
    }

    uniqueTypes.putIfAbsent(
      trainingTypeKey(normalizedType),
      () => normalizedType,
    );
  }

  return uniqueTypes.values.toList(growable: false);
}

List<String> trainingTypeLabels(
  BuildContext context,
  List<String>? types, {
  String? legacyType,
}) {
  return resolveTrainingTypes(types: types, legacyType: legacyType)
      .map((type) => trainingTypeLabel(context, type))
      .toList(growable: false);
}

String primaryTrainingType(
  List<String>? types, {
  String? legacyType,
}) {
  final resolvedTypes = resolveTrainingTypes(
    types: types,
    legacyType: legacyType,
  );
  return resolvedTypes.isNotEmpty
      ? resolvedTypes.first
      : normalizeTrainingTypeLabel(legacyType);
}

String trainingTypesSummaryLabel(
  BuildContext context,
  List<String>? types, {
  String? legacyType,
  int maxVisible = 2,
}) {
  final labels = trainingTypeLabels(
    context,
    types,
    legacyType: legacyType,
  );

  if (labels.isEmpty) {
    return trainingTypeLabel(context, legacyType);
  }

  final visibleLabels = labels.take(maxVisible).toList(growable: true);

  if (labels.length > maxVisible) {
    visibleLabels.add('+${labels.length - maxVisible}');
  }

  return visibleLabels.join(' · ');
}

String trainingTypeLabel(BuildContext context, String? type) {
  final l10n = AppLocalizations.of(context);
  final normalized = normalizeTrainingTypeLabel(type);
  final key = trainingTypeKey(normalized);

  if (key.isEmpty) return l10n.training;
  if (_matchesAnyExact(key, const ['fuerza', 'strength'])) {
    return l10n.trainingStrength;
  }
  if (_matchesAnyExact(key, const ['cardio'])) {
    return 'Cardio';
  }
  if (_matchesAnyExact(key, const ['hiit'])) {
    return 'HIIT';
  }
  if (_matchesAnyExact(
    key,
    const ['flexibilidad', 'movilidad', 'mobility'],
  )) {
    return l10n.trainingMobility;
  }

  return _toTitleCase(normalized);
}

Color trainingTypeColor(BuildContext context, String? type) {
  final semantic = context.exomSemantic;
  final key = trainingTypeKey(type);

  if (key.isEmpty) {
    return context.trainingAccent;
  }

  if (_matchesAnyFragment(
    key,
    const [
      'fuerza',
      'strength',
      'pesas',
      'muscul',
      'gym',
      'empuje',
      'push',
      'torso',
      'upper',
      'pecho',
      'hombro',
      'shoulder',
      'tricep',
      'triceps',
    ],
  )) {
    return context.trainingAccent;
  }

  if (_matchesAnyFragment(
    key,
    const [
      'cardio',
      'run',
      'running',
      'correr',
      'bici',
      'bike',
      'cycle',
      'cycling',
      'spinning',
      'endurance',
      'tiron',
      'pull',
      'espalda',
      'back',
      'bicep',
      'biceps',
    ],
  )) {
    return semantic.info;
  }

  if (_matchesAnyFragment(
    key,
    const [
      'hiit',
      'tabata',
      'metcon',
      'circuit',
      'circuito',
      'cross',
      'funcional',
    ],
  )) {
    return semantic.accent;
  }

  if (_matchesAnyFragment(
    key,
    const [
      'pierna',
      'piernas',
      'leg',
      'legs',
      'lower',
      'glute',
      'quad',
      'cuad',
      'hamstring',
      'femoral',
    ],
  )) {
    return semantic.success;
  }

  if (_matchesAnyFragment(
    key,
    const [
      'flexibilidad',
      'movilidad',
      'mobility',
      'stretch',
      'stretching',
      'recovery',
      'recuperacion',
      'yoga',
      'pilates',
      'core',
      'abdomen',
      'abs',
      'full body',
      'fullbody',
      'cuerpo completo',
    ],
  )) {
    return semantic.warning;
  }

  final fallbackColors = <Color>[
    context.trainingAccent,
    semantic.info,
    semantic.accent,
    semantic.success,
    semantic.warning,
    semantic.sleep,
    context.exomPalette.primary,
  ];

  return fallbackColors[_stableIndex(key, fallbackColors.length)];
}

String? normalizeTrainingAccentHex(String? value) {
  if (value == null) {
    return null;
  }

  final normalizedValue = value.trim();
  if (normalizedValue.isEmpty) {
    return null;
  }

  if (!RegExp(_trainingAccentColorRegex).hasMatch(normalizedValue)) {
    return null;
  }

  return '#${normalizedValue.replaceFirst(RegExp('^#'), '').toUpperCase()}';
}

Color? tryParseTrainingAccentColor(String? value) {
  final normalizedValue = normalizeTrainingAccentHex(value);

  if (normalizedValue == null) {
    return null;
  }

  final hex = normalizedValue.substring(1);
  final argbHex =
      hex.length == 6
          ? 'FF$hex'
          : '${hex.substring(6, 8)}${hex.substring(0, 6)}';

  return Color(int.parse(argbHex, radix: 16));
}

Color trainingAccentColor(
  BuildContext context, {
  String? accentColor,
  List<String>? types,
  String? legacyType,
}) {
  return tryParseTrainingAccentColor(accentColor) ??
      trainingTypeColor(
        context,
        primaryTrainingType(types, legacyType: legacyType),
      );
}

bool _matchesAnyExact(String key, List<String> options) {
  return options.any((option) => key == option);
}

bool _matchesAnyFragment(String key, List<String> fragments) {
  return fragments.any((fragment) => key.contains(fragment));
}

int _stableIndex(String key, int length) {
  var hash = 0;
  for (final rune in key.runes) {
    hash = (hash * 31 + rune) & 0x7fffffff;
  }
  return hash % length;
}

String _toTitleCase(String value) {
  return value
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) {
        if (word.length <= 4 && word == word.toUpperCase()) {
          return word;
        }
        return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
      })
      .join(' ');
}
