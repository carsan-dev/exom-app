/// Static scanner for string literals handed to user-visible Flutter sinks.
///
/// It is intentionally lexical (no analyzer dependency): it looks for known
/// sink call shapes followed by a plain string literal and keeps the ones that
/// contain real words (two or more consecutive ASCII letters outside of
/// interpolations).
library;

class UiStringFinding {
  const UiStringFinding({
    required this.path,
    required this.line,
    required this.sink,
    required this.text,
  });

  final String path;
  final int line;
  final String sink;
  final String text;

  @override
  String toString() => '$path:$line [$sink] "$text"';
}

const String _literal =
    r'''(?:r?'((?:[^'\\\n]|\\.)*)'|r?"((?:[^"\\\n]|\\.)*)")''';

final List<MapEntry<String, RegExp>> _sinks = [
  MapEntry('Text(', RegExp(r'\bText\(\s*(?:const\s+)?' + _literal)),
  MapEntry('Text.rich/TextSpan(text:', RegExp(r'\bTextSpan\(\s*text:\s*' + _literal)),
  MapEntry('tooltip:', RegExp(r'\btooltip:\s*' + _literal)),
  MapEntry('labelText:', RegExp(r'\blabelText:\s*' + _literal)),
  MapEntry('hintText:', RegExp(r'\bhintText:\s*' + _literal)),
  MapEntry('helperText:', RegExp(r'\bhelperText:\s*' + _literal)),
  MapEntry('errorText:', RegExp(r'\berrorText:\s*' + _literal)),
  MapEntry('semanticsLabel:', RegExp(r'\bsemanticsLabel:\s*' + _literal)),
  MapEntry(
    'Semantics(label:',
    RegExp(r'\bSemantics\((?:[^;{}]|\{[^}]*\}){0,200}?\blabel:\s*' + _literal),
  ),
  MapEntry('title: Text(', RegExp(r'\btitle:\s*(?:const\s+)?Text\(\s*' + _literal)),
];

/// Removes `${...}` and `$name` interpolations so that only literal prose is
/// inspected.
String _stripInterpolation(String value) {
  // An unterminated `${` means the interpolation itself contains quotes, so
  // the literal match stopped early: drop the rest, it is code, not prose.
  var out = value.replaceAll(RegExp(r'\$\{[^}]*\}'), ' ');
  out = out.replaceAll(RegExp(r'\$\{.*$'), ' ');
  out = out.replaceAll(RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*'), ' ');
  return out;
}

bool _hasWords(String value) =>
    RegExp(r'[A-Za-z]{2,}').hasMatch(_stripInterpolation(value));

/// Blanks line comments and block comments, preserving offsets and newlines.
String _blankComments(String source) {
  final buffer = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < source.length && source[i] != '\n') {
        buffer.write(' ');
        i++;
      }
    } else if (c == '/' && next == '*') {
      while (i < source.length &&
          !(source[i] == '*' && i + 1 < source.length && source[i + 1] == '/')) {
        buffer.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
      if (i < source.length) {
        buffer.write('  ');
        i += 2;
      }
    } else if (c == "'" || c == '"') {
      // Copy a string literal untouched so '//' inside URLs is not a comment.
      final quote = c;
      buffer.write(c);
      i++;
      while (i < source.length && source[i] != quote && source[i] != '\n') {
        if (source[i] == r'\' && i + 1 < source.length) {
          buffer.write(source[i]);
          i++;
        }
        buffer.write(source[i]);
        i++;
      }
      if (i < source.length && source[i] == quote) {
        buffer.write(quote);
        i++;
      }
    } else {
      buffer.write(c);
      i++;
    }
  }
  return buffer.toString();
}

List<UiStringFinding> findHardcodedUiStrings(String path, String source) {
  final cleaned = _blankComments(source);
  final findings = <UiStringFinding>[];
  final seen = <String>{};
  for (final sink in _sinks) {
    for (final match in sink.value.allMatches(cleaned)) {
      final text = match.group(1) ?? match.group(2) ?? '';
      if (!_hasWords(text)) continue;
      final line = '\n'.allMatches(cleaned.substring(0, match.start)).length + 1;
      final key = '$line|$text';
      if (!seen.add(key)) continue;
      findings.add(
        UiStringFinding(path: path, line: line, sink: sink.key, text: text),
      );
    }
  }
  findings.sort((a, b) => a.line.compareTo(b.line));
  return findings;
}
