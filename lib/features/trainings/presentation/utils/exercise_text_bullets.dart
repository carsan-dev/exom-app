/// Bullet parsing shared by the exercise detail sheet and the technique
/// sheet (L5-F4).
///
/// A dash or star needs a space after it to be a marker ("- item", "* item");
/// "•" is a marker on its own. "-5 kg" and "*nota*" are plain text, and the
/// numbers after a marker ("- 90 grados") are content.
library;

/// Items of [text] when it is a list, or an empty list when it is a paragraph.
List<String> extractExerciseBulletItems(String text) {
  final normalized = text.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) return const [];

  final lines = normalized
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  if (lines.length > 1) {
    return lines.map(_stripBulletPrefix).toList();
  }

  // A list of one bullet (a lone "- item") is still a list.
  // "-5 kg" or "*bold*" are text: a dash or star needs a space after it.
  if (RegExp(r'^(?:[-*]\s+|•\s*)\S').hasMatch(normalized) &&
      !normalized.substring(1).contains('•')) {
    final item = _stripMarker(normalized);
    return item.isEmpty ? const [] : [item];
  }

  if (normalized.contains('•')) {
    final inlineItems = normalized
        .split('•')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(_stripBulletPrefix)
        .toList();
    if (inlineItems.length > 1) {
      return inlineItems;
    }
  }

  return const [];
}

String _stripMarker(String value) =>
    value.replaceFirst(RegExp(r'^[-*•]+\s*'), '').trim();

/// Drops the marker; a numbered line without marker ("1. Pie") also loses
/// its number, but the numbers after a marker ("- 90 grados") are content.
String _stripBulletPrefix(String value) {
  final withoutMarker = _stripMarker(value);
  if (withoutMarker != value.trim()) return withoutMarker;
  return value.replaceFirst(RegExp(r'^\d+[.)-]?\s*'), '').trim();
}
