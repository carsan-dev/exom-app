// L5 sweep (docs/plans/rediseno-app-l5-contrato-v2.md, section 5.2): files
// already repainted for L5 must not use the legacy surface vocabulary. The list
// of repainted files grows with each batch; it starts empty in T0.1.
//
// Forbidden in a repainted file: `GlassCard`, `AppColors.`, `Color(0x`, a
// literal `fontSize` below 13, and a corner radius above 4. A line that needs a
// documented exception (video `Colors.black`, scrims, the brand mark) carries
// the marker `// l5-allow: <reason>` and is skipped.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Repainted files, relative to the repository root. Empty until the first
/// L5 batch repaints a screen.
const List<String> kRepaintedFiles = <String>[];

const String _allowMarker = 'l5-allow:';

final RegExp _fontSize = RegExp(r'fontSize\s*:\s*(\d+(?:\.\d+)?)');
final RegExp _radiusLiteral = RegExp(
  r'(?:Radius|BorderRadius)\.(?:circular|all)\(\s*(?:Radius\.circular\(\s*)?(\d+(?:\.\d+)?)',
);
final RegExp _legacyRadius = RegExp(
  r'ExomRadius\.(?:xs|sm|md|lg|xl|xxl|all(?:Xs|Sm|Md|Lg|Xl|Xxl))\b',
);

/// Returns one message per forbidden pattern found in [source].
List<String> findForbiddenSurfacePatterns(String source) {
  final problems = <String>[];
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains(_allowMarker)) continue;
    final n = i + 1;
    if (line.contains('GlassCard')) problems.add('$n: GlassCard');
    if (line.contains('AppColors.')) problems.add('$n: AppColors.');
    if (line.contains('Color(0x')) problems.add('$n: Color(0x literal');
    for (final m in _fontSize.allMatches(line)) {
      if (double.parse(m.group(1)!) < 13) {
        problems.add('$n: fontSize ${m.group(1)} < 13');
      }
    }
    for (final m in _radiusLiteral.allMatches(line)) {
      if (double.parse(m.group(1)!) > 4) {
        problems.add('$n: radius ${m.group(1)} > 4');
      }
    }
    if (_legacyRadius.hasMatch(line)) {
      problems.add('$n: legacy ExomRadius xs..xxl');
    }
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
}
