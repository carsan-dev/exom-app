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
  // L5-A4 · Calendario: A4a repainted the screen, A4b its sheets.
  'lib/features/calendar/presentation/pages/calendar_page.dart',
  // L5-B1 · Ayuda.
  'lib/features/help/presentation/pages/help_page.dart',
  // L5-C1 · Subidas pendientes.
  'lib/features/feedback/presentation/pages/pending_uploads_page.dart',
  // L5-C2 · Feedback.
  'lib/features/feedback/presentation/pages/feedback_page.dart',
  'lib/features/feedback/presentation/widgets/feedback_upload_status.dart',
  'lib/features/feedback/presentation/widgets/feedback_media_picker.dart',
  // L5-D1 · Acceso.
  'lib/features/auth/presentation/pages/login_page.dart',
  'lib/features/auth/presentation/pages/forgot_password_page.dart',
  'lib/features/auth/presentation/pages/account_locked_page.dart',
  'lib/features/auth/presentation/widgets/social_login_button.dart',
  // L5-E7 · Nutrición y detalle de comida.
  'lib/features/diets/presentation/pages/diets_page.dart',
  'lib/features/diets/presentation/widgets/meal_detail_sheet.dart',
  'lib/features/diets/presentation/widgets/diet_history_button.dart',
  // L5-E9a · Progreso.
  'lib/features/metrics/presentation/pages/metrics_progress_page.dart',
  // L5-E2a · Detalle del entreno (piel). The closing dialog (E2b) carries no
  // legacy vocabulary, so the whole file is swept.
  'lib/features/trainings/presentation/pages/training_detail_page.dart',
  // L5-E4 · Hoja de serie (piel).
  'lib/features/trainings/presentation/widgets/set_performance_sheet.dart',
  'lib/features/trainings/presentation/widgets/set_value_text.dart',
  // L5-B2 · Retos.
  'lib/features/challenges/presentation/pages/challenges_page.dart',
  'lib/features/challenges/presentation/widgets/achievement_tiles.dart',
  'lib/features/challenges/presentation/widgets/challenge_streak_weeks.dart',
  'lib/features/challenges/presentation/widgets/challenge_milestone_mark.dart',
  'lib/features/challenges/presentation/widgets/challenge_tick_rule.dart',
  'lib/features/settings/presentation/pages/settings_page.dart',
  // L5-B4 · Perfil.
  'lib/features/profile/presentation/pages/profile_page.dart',
  // L5-C3 · Recap, detalle.
  'lib/features/recap/presentation/pages/recap_detail_page.dart',
  'lib/features/recap/presentation/widgets/recap_feedback_card.dart',
  'lib/features/recap/presentation/widgets/recap_published_review_card.dart',
  // L5-C4 · Recap, lista, and L5-C5a · Recap, formulario por pasos.
  'lib/features/recap/presentation/pages/recap_page.dart',
  'lib/features/recap/presentation/widgets/recap_start_view.dart',
  'lib/features/recap/presentation/widgets/recap_form_fields.dart',
  'lib/features/recap/presentation/widgets/recap_optional_rating.dart',
  'lib/features/recap/presentation/widgets/recap_anatomy_selector.dart',
  'lib/features/recap/presentation/widgets/recap_step_training.dart',
  'lib/features/recap/presentation/widgets/recap_step_nutrition.dart',
  'lib/features/recap/presentation/widgets/recap_step_recovery.dart',
  'lib/features/recap/presentation/widgets/recap_step_general.dart',
  'lib/features/recap/presentation/widgets/recap_step_improvement.dart',
  // L5-D2 · Onboarding.
  'lib/features/onboarding/presentation/pages/onboarding_page.dart',
  'lib/features/onboarding/presentation/widgets/onboarding_welcome_step.dart',
  'lib/features/onboarding/presentation/widgets/onboarding_basics_step.dart',
  'lib/features/onboarding/presentation/widgets/onboarding_body_step.dart',
  'lib/features/onboarding/presentation/widgets/onboarding_goals_step.dart',
  'lib/features/onboarding/presentation/widgets/onboarding_summary_step.dart',
  'lib/features/onboarding/presentation/widgets/onboarding_progress_indicator.dart',
  'lib/features/onboarding/presentation/widgets/onboarding_step_layout.dart',
];

/// Files repainted only up to a marker line: the code from the marker on
/// belongs to a later batch and keeps its legacy vocabulary until then.
/// L5-A4a repainted the Calendario screen up to its month and year picker
/// dialog; L5-A4b replaced that dialog and moved the file to
/// [kRepaintedFiles]. L5-C4 repainted the recap list (and its pinned action)
/// up to the step form, which L5-C5 repaints.
const Map<String, String> kPartlyRepaintedFiles = <String, String>{};

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

  test('partly repainted files use no legacy surface vocabulary before '
      'their marker', () {
    final failures = <String>[];
    kPartlyRepaintedFiles.forEach((path, marker) {
      final file = File(path);
      if (!file.existsSync()) {
        failures.add('$path: file does not exist');
        return;
      }
      final source = file.readAsStringSync();
      final end = source.indexOf(marker);
      if (end < 0) {
        failures.add('$path: marker not found');
        return;
      }
      for (final problem in findForbiddenSurfacePatterns(
        source.substring(0, end),
      )) {
        failures.add('$path:$problem');
      }
    });
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
