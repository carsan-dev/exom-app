import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Spanish values that legitimately equal the English ones.
const Map<String, String> identicalValueAllowlist = {
  'feedbackMenuItem': 'Product term "Feedback" kept in Spanish by the owner.',
  'feedback': 'Product term "Feedback" kept in Spanish by the owner.',
  'tutorialFeedbackTitle':
      'Product term "Feedback" kept in Spanish by the owner.',
  'mealTypeSnack': 'Product term "Snack" kept in Spanish by the owner.',
  'recapGeneral': 'Shared Spanish/English word "General".',
  'general': 'Shared Spanish/English word "General".',
  'weightBadgeLabel': 'Abbreviation shared by both languages.',
  'ingredientUnitG': 'Unit symbol "g".',
  'ingredientUnitMl': 'Unit symbol "ml".',
  'errorTitle': 'Cognate "Error" is the same word in both languages.',
};

/// English words that must not appear in Spanish values. "Feedback", "Recap"
/// and "Snack" are intentionally absent: the owner keeps them as product terms.
const List<String> bannedEnglishWords = [
  'offline',
  'online',
  'backend',
  'home',
  'coach',
  'stack',
  'build',
  'tour',
  'fitness',
  'faq',
  'workout',
  'login',
  'logout',
];

Map<String, dynamic> _load(String lang) {
  final raw = File('lib/l10n/app_$lang.arb').readAsStringSync();
  return json.decode(raw) as Map<String, dynamic>;
}

Map<String, String> _messages(Map<String, dynamic> arb) => {
  for (final entry in arb.entries)
    if (!entry.key.startsWith('@') && entry.value is String)
      entry.key: entry.value as String,
};

/// Parses ICU text and returns the argument names and `kind -> forms` for
/// plural/select blocks, including nested ones.
class _Icu {
  final Set<String> args = {};
  final Map<String, Set<String>> forms = {};
}

_Icu _parseIcu(String message) {
  final result = _Icu();
  void parse(String text) {
    var i = 0;
    while (i < text.length) {
      if (text[i] != '{') {
        i++;
        continue;
      }
      var depth = 1;
      var j = i + 1;
      while (j < text.length && depth > 0) {
        if (text[j] == '{') depth++;
        if (text[j] == '}') depth--;
        j++;
      }
      final inner = text.substring(i + 1, j - 1);
      final head = RegExp(r'^\s*(\w+)\s*(?:,\s*(plural|select|selectordinal)\s*,)?')
          .firstMatch(inner);
      if (head != null) {
        result.args.add(head.group(1)!);
        final kind = head.group(2);
        if (kind != null) {
          final rest = inner.substring(head.end);
          final selectors = <String>{};
          var k = 0;
          while (k < rest.length) {
            final selector = RegExp(r'\s*([=\w]+)\s*\{').matchAsPrefix(rest, k);
            if (selector == null) {
              k++;
              continue;
            }
            selectors.add(selector.group(1)!);
            var d = 1;
            var m = selector.end;
            while (m < rest.length && d > 0) {
              if (rest[m] == '{') d++;
              if (rest[m] == '}') d--;
              m++;
            }
            parse(rest.substring(selector.end, m - 1));
            k = m;
          }
          result.forms['${head.group(1)}:$kind'] = selectors;
        }
      }
      i = j;
    }
  }

  parse(message);
  return result;
}

Map<String, String> _placeholderTypes(Map<String, dynamic> arb, String key) {
  final meta = arb['@$key'];
  if (meta is! Map<String, dynamic>) return {};
  final placeholders = meta['placeholders'];
  if (placeholders is! Map<String, dynamic>) return {};
  return {
    for (final entry in placeholders.entries)
      entry.key: ((entry.value as Map<String, dynamic>)['type'] ?? '')
          .toString(),
  };
}

void main() {
  final es = _load('es');
  final en = _load('en');
  final esMessages = _messages(es);
  final enMessages = _messages(en);

  test('es and en declare the same message keys', () {
    final missingInEn = esMessages.keys.toSet().difference(enMessages.keys.toSet());
    final missingInEs = enMessages.keys.toSet().difference(esMessages.keys.toSet());
    expect(missingInEn, isEmpty, reason: 'Missing in app_en.arb');
    expect(missingInEs, isEmpty, reason: 'Missing in app_es.arb');
  });

  test('no empty values', () {
    for (final entry in {...esMessages}.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: 'es ${entry.key}');
    }
    for (final entry in enMessages.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: 'en ${entry.key}');
    }
  });

  test('placeholder names and types match', () {
    final problems = <String>[];
    for (final key in esMessages.keys) {
      final enText = enMessages[key];
      if (enText == null) continue;
      final esIcu = _parseIcu(esMessages[key]!);
      final enIcu = _parseIcu(enText);
      if (!esIcu.args.containsAll(enIcu.args) ||
          !enIcu.args.containsAll(esIcu.args)) {
        problems.add('$key: es ${esIcu.args} vs en ${enIcu.args}');
      }
      final esTypes = _placeholderTypes(es, key);
      final enTypes = _placeholderTypes(en, key);
      for (final entry in enTypes.entries) {
        if (esTypes[entry.key] != entry.value) {
          problems.add(
            '$key.${entry.key}: es ${esTypes[entry.key]} vs en ${entry.value}',
          );
        }
      }
      final selectorNames = esIcu.forms.keys.map((f) => f.split(':').first);
      for (final name in esIcu.args) {
        // gen-l10n infers plural/select selector types without metadata.
        if (selectorNames.contains(name)) continue;
        if (!esTypes.containsKey(name)) {
          problems.add('$key: placeholder $name lacks metadata in app_es.arb');
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('plural and select forms match', () {
    final problems = <String>[];
    for (final key in esMessages.keys) {
      final enText = enMessages[key];
      if (enText == null) continue;
      final esForms = _parseIcu(esMessages[key]!).forms;
      final enForms = _parseIcu(enText).forms;
      if (esForms.keys.toSet().difference(enForms.keys.toSet()).isNotEmpty ||
          enForms.keys.toSet().difference(esForms.keys.toSet()).isNotEmpty) {
        problems.add('$key: ${esForms.keys} vs ${enForms.keys}');
        continue;
      }
      for (final form in esForms.entries) {
        final other = enForms[form.key]!;
        if (!form.value.containsAll(other) || !other.containsAll(form.value)) {
          problems.add('$key ${form.key}: ${form.value} vs $other');
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('Spanish equal to English is flagged unless allowlisted', () {
    final identical = [
      for (final entry in esMessages.entries)
        if (enMessages[entry.key] == entry.value) entry.key,
    ];
    final unexplained = identical
        .where((key) => !identicalValueAllowlist.containsKey(key))
        .toList();
    expect(
      unexplained,
      isEmpty,
      reason: 'Translate these or allowlist them with a reason',
    );
    final stale = identicalValueAllowlist.keys
        .where((key) => !identical.contains(key))
        .toList();
    expect(stale, isEmpty, reason: 'Stale identical-value allowlist entries');
    for (final reason in identicalValueAllowlist.values) {
      expect(reason.trim(), isNotEmpty);
    }
  });

  test('Spanish values contain no banned English words', () {
    final pattern = RegExp(
      '\\b(${bannedEnglishWords.join('|')})\\b',
      caseSensitive: false,
    );
    final offenders = <String>[
      for (final entry in esMessages.entries)
        if (pattern.hasMatch(entry.value)) '${entry.key}: ${entry.value}',
    ];
    expect(offenders, isEmpty);
  });
}
