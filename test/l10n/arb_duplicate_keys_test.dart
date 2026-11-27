import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `jsonDecode` keeps the last duplicate silently, so a repeated top-level
/// key is only visible in the raw text. Top-level keys sit at depth 1; keys
/// nested in `@key` metadata (placeholders, type, ...) are deeper and ignored.
List<String> duplicatedTopLevelKeys(String source) {
  final seen = <String>{};
  final duplicated = <String>[];
  var depth = 0;
  var inString = false;
  var escaped = false;
  final token = StringBuffer();
  String? lastString;
  var lastStringDepth = -1;
  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    if (inString) {
      if (escaped) {
        escaped = false;
        token.write(c);
      } else if (c == r'\') {
        escaped = true;
        token.write(c);
      } else if (c == '"') {
        inString = false;
        lastString = token.toString();
        lastStringDepth = depth;
      } else {
        token.write(c);
      }
      continue;
    }
    if (c == '"') {
      inString = true;
      token.clear();
    } else if (c == '{' || c == '[') {
      depth++;
    } else if (c == '}' || c == ']') {
      depth--;
    } else if (c == ':' && depth == 1 && lastStringDepth == 1) {
      if (!seen.add(lastString!)) duplicated.add(lastString);
    }
  }
  return duplicated;
}

void main() {
  final arbs = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('there are ARB files to check', () {
    expect(arbs, isNotEmpty);
  });

  for (final file in arbs) {
    test('${file.uri.pathSegments.last} has no duplicated top-level keys', () {
      expect(duplicatedTopLevelKeys(file.readAsStringSync()), isEmpty);
    });
  }
}
