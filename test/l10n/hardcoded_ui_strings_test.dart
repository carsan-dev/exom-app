import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'hardcoded_ui_scanner.dart';
import 'ui_string_allowlist.dart';

List<File> _libDartFiles() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) {
        final normalized = file.path.replaceAll(r'\', '/');
        return !normalized.startsWith('lib/l10n/');
      })
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

String _normalize(String path) => path.replaceAll(r'\', '/');

void main() {
  group('hardcoded UI string scanner', () {
    test('flags a new Text literal with words', () {
      const sample = '''
class Sample extends StatelessWidget {
  Widget build(BuildContext context) => Text('Hello world');
}
''';
      final findings = findHardcodedUiStrings('lib/sample.dart', sample);
      expect(findings, hasLength(1));
      expect(findings.single.text, 'Hello world');
      expect(findings.single.line, 2);
    });

    test('flags the other user-visible sinks', () {
      const sample = '''
Widget a() => IconButton(tooltip: 'Close dialog', onPressed: null, icon: x);
InputDecoration b() => const InputDecoration(
  labelText: 'Full name',
  hintText: "Type here",
  helperText: 'Helper words',
  errorText: 'Bad value',
);
Widget c() => Semantics(label: 'Play video', child: x);
Widget d() => Text.rich(TextSpan(text: 'Rich words'));
Widget e() => AlertDialog(title: const Text('Dialog title'), content: Text("Body text"));
Widget f() => SnackBar(content: Text('Saved ok'));
Widget g() => Image(semanticsLabel: 'Photo here');
''';
      final texts = findHardcodedUiStrings('lib/sample.dart', sample)
          .map((finding) => finding.text)
          .toSet();
      expect(texts, {
        'Close dialog',
        'Full name',
        'Type here',
        'Helper words',
        'Bad value',
        'Play video',
        'Rich words',
        'Dialog title',
        'Body text',
        'Saved ok',
        'Photo here',
      });
    });

    test('ignores localized access, symbols, interpolation-only and comments',
        () {
      const sample = '''
Widget a(l10n) => Text(l10n.title);
Widget b() => const Text('•');
Widget c() => Text('\$value');
Widget d() => Text('\${a + b}');
Widget e() => Text('12');
// Widget f() => Text('Commented out');
/* Text('Block comment') */
final url = 'https://example.com/x'; // Text('Trailing comment')
''';
      expect(findHardcodedUiStrings('lib/sample.dart', sample), isEmpty);
    });
  });

  group('lib/ user-visible strings', () {
    final allowKeys = {
      for (final allowance in uiStringAllowlist)
        '${allowance.path}|${allowance.text}': allowance,
    };

    test('every allowlist entry has a reason', () {
      for (final allowance in uiStringAllowlist) {
        expect(
          allowance.reason.trim(),
          isNotEmpty,
          reason: '${allowance.path} "${allowance.text}" needs a reason',
        );
      }
    });

    test('no hardcoded user-visible literals outside the allowlist', () {
      final used = <String>{};
      final violations = <String>[];
      for (final file in _libDartFiles()) {
        final path = _normalize(file.path);
        final findings = findHardcodedUiStrings(path, file.readAsStringSync());
        for (final finding in findings) {
          final key = '$path|${finding.text}';
          if (allowKeys.containsKey(key)) {
            used.add(key);
          } else {
            violations.add(finding.toString());
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Move these strings to app_es.arb/app_en.arb or add a '
            'reviewed entry to test/l10n/ui_string_allowlist.dart:\n'
            '${violations.join('\n')}',
      );
      final stale = allowKeys.keys.where((key) => !used.contains(key)).toList();
      expect(
        stale,
        isEmpty,
        reason: 'Stale allowlist entries (remove them):\n${stale.join('\n')}',
      );
    });
  });
}
