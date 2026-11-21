// L5 sweep (docs/plans/rediseno-app-l5-contrato-v2.md, section 5.2): files
// already repainted for L5 must not use the legacy surface vocabulary. The list
// of repainted files grows with each batch; it started empty in T0.1.
//
// Forbidden in a repainted file: `GlassCard`, `AppColors.`, `Color(0x`, a
// literal `fontSize` below 13, and a corner radius above 4. A line that needs a
// documented exception (video `Colors.black`, scrims, the brand mark) carries
// the marker `// l5-allow: <reason>` and is skipped.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Repainted files, relative to the repository root. T0.2 adds the text and
/// figure components of the base (no screen is repainted yet).
const List<String> kRepaintedFiles = <String>[
  'lib/core/widgets/exom_two_line_headline.dart',
  'lib/core/widgets/exom_numeral.dart',
  'lib/core/widgets/exom_index_number.dart',
  'lib/core/widgets/exom_kicker.dart',
  'lib/core/widgets/exom_numbered_section_header.dart',
  'lib/core/widgets/exom_figure_columns.dart',
  'lib/core/widgets/exom_moment_pill.dart',
  'lib/core/widgets/exom_band.dart',
  'lib/core/widgets/exom_flat_row.dart',
  'lib/core/widgets/exom_rich_row.dart',
  'lib/core/widgets/exom_index_list.dart',
  'lib/core/widgets/exom_accordion.dart',
  'lib/core/widgets/exom_notice_row.dart',
  'lib/core/widgets/exom_coach_block.dart',
  'lib/core/widgets/exom_inline_message.dart',
  'lib/core/widgets/exom_empty_state.dart',
  'lib/core/widgets/exom_skeleton.dart',
  'lib/core/widgets/exom_text_link.dart',
  'lib/core/widgets/media_picker_error_dialog.dart',
  'lib/core/widgets/exom_segmented_control.dart',
  'lib/core/widgets/exom_scale_chips.dart',
  'lib/core/widgets/exom_numeral_stepper.dart',
  'lib/core/widgets/exom_step_header.dart',
  'lib/core/widgets/exom_month_grid.dart',
  'lib/core/widgets/exom_progress_rule.dart',
  'lib/core/widgets/exom_operation_bar.dart',
  'lib/core/widgets/exom_line_chart.dart',
  'lib/features/notifications/presentation/pages/notifications_page.dart',
  'lib/features/notifications/presentation/widgets/notification_tile.dart',
  'lib/features/trainings/presentation/pages/exercise_video_player_page.dart',
  // L5-A3 · Entrenar: lista e historial.
  'lib/features/trainings/presentation/pages/trainings_page.dart',
  'lib/features/trainings/presentation/widgets/pending_training_executions.dart',
  // L5-C1 · Subidas pendientes.
  'lib/features/feedback/presentation/pages/pending_uploads_page.dart',
];

const String _allowMarker = 'l5-allow:';

final RegExp _fontSize = RegExp(r'fontSize\s*:\s*(\d+(?:\.\d+)?)');
final RegExp _radiusLiteral = RegExp(
  r'(?:Radius|BorderRadius)\.(?:circular|all)\(\s*(?:Radius\.circular\(\s*)?(\d+(?:\.\d+)?)',
);
final RegExp _legacyRadius = RegExp(
  r'ExomRadius\.(?:xs|sm|md|lg|xl|xxl|all(?:Xs|Sm|Md|Lg|Xl|Xxl))\b',
);

/// Line (0-based) of the character at [offset] in [source].
int _lineOf(String source, int offset) {
  var line = 0;
  for (var i = 0; i < offset; i++) {
    if (source.codeUnitAt(i) == 0x0A) line++;
  }
  return line;
}

/// Last line (0-based) touched by the construct a match opened: when the match
/// leaves parentheses open (`BorderRadius.circular(` + number), it runs on to
/// the line that closes them, so an `l5-allow` marker after `);` still counts.
int _endLine(String source, Match match) {
  final text = match.group(0)!;
  var depth = '('.allMatches(text).length - ')'.allMatches(text).length;
  var end = match.end;
  while (depth > 0 && end < source.length) {
    final c = source.codeUnitAt(end);
    if (c == 0x28) depth++;
    if (c == 0x29) depth--;
    end++;
  }
  return _lineOf(source, end > match.end ? end - 1 : match.end);
}

/// Returns one message per forbidden pattern found in [source]. The numeric
/// patterns (font size, radius) are matched over the whole source, not line by
/// line, so values that `dart format` splits over several lines
/// (a radius literal on its own line after `BorderRadius.circular(`) are still
/// found.
List<String> findForbiddenSurfacePatterns(String source) {
  final problems = <String>[];
  final lines = source.split('\n');
  bool allowed(int from, int to) {
    for (var i = from; i <= to && i < lines.length; i++) {
      if (lines[i].contains(_allowMarker)) return true;
    }
    return false;
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains(_allowMarker)) continue;
    final n = i + 1;
    if (line.contains('GlassCard')) problems.add('$n: GlassCard');
    if (line.contains('AppColors.')) problems.add('$n: AppColors.');
    if (line.contains('Color(0x')) problems.add('$n: Color(0x literal');
    if (_legacyRadius.hasMatch(line)) {
      problems.add('$n: legacy ExomRadius xs..xxl');
    }
  }
  for (final m in _fontSize.allMatches(source)) {
    if (double.parse(m.group(1)!) >= 13) continue;
    final start = _lineOf(source, m.start);
    if (allowed(start, _endLine(source, m))) continue;
    problems.add('${start + 1}: fontSize ${m.group(1)} < 13');
  }
  for (final m in _radiusLiteral.allMatches(source)) {
    if (double.parse(m.group(1)!) <= 4) continue;
    final start = _lineOf(source, m.start);
    if (allowed(start, _endLine(source, m))) continue;
    problems.add('${start + 1}: radius ${m.group(1)} > 4');
  }
  return problems;
}

void main() {
  test('repainted files use no legacy surface vocabulary', () {
    final failures = <String>[];
    for (final path in kRepaintedFiles) {
      final file = File(path);
      if (!file.existsSync()) {
        failures.add('$path: file does not exist');
        continue;
      }
      for (final problem in findForbiddenSurfacePatterns(
        file.readAsStringSync(),
      )) {
        failures.add('$path:$problem');
      }
    }
    expect(failures, isEmpty);
  });

  test('detector finds every forbidden pattern in a sample', () {
    const sample = '''
final a = GlassCard(child: x);
final b = AppColors.primary;
final c = Color(0xFF123456);
final d = TextStyle(fontSize: 12);
final e = BorderRadius.circular(18);
final f = Radius.circular(20);
final g = ExomRadius.allLg();
''';
    final problems = findForbiddenSurfacePatterns(sample);
    expect(problems, hasLength(7));
    expect(problems.join('\n'), contains('GlassCard'));
    expect(problems.join('\n'), contains('AppColors.'));
    expect(problems.join('\n'), contains('Color(0x'));
    expect(problems.join('\n'), contains('fontSize 12'));
    expect(problems.join('\n'), contains('radius 18'));
    expect(problems.join('\n'), contains('radius 20'));
    expect(problems.join('\n'), contains('legacy ExomRadius'));
  });

  test('detector accepts allowed values and marked exceptions', () {
    const sample = '''
final a = TextStyle(fontSize: 13);
final b = BorderRadius.circular(4);
final c = Radius.circular(0);
final d = Color(0xCC000000); // l5-allow: video scrim
final e = ExomRadius.control;
''';
    expect(findForbiddenSurfacePatterns(sample), isEmpty);
  });

  test('detector sees values split across lines by dart format', () {
    const sample = '''
final a = BorderRadius.circular(
  18,
);
final b = TextStyle(
  fontSize:
      12,
);
final c = Radius.circular(
  Radius.circular(
    20,
  ),
);
''';
    final problems = findForbiddenSurfacePatterns(sample);
    expect(problems.join(' '), contains('radius 18'));
    expect(problems.join(' '), contains('fontSize 12'));
    expect(problems.join(' '), contains('radius 20'));
  });

  test('a marked exception still skips a value split across lines', () {
    const sample = '''
final a = BorderRadius.circular(
  18,
); // l5-allow: brand mark
''';
    expect(findForbiddenSurfacePatterns(sample), isEmpty);
  });
}
