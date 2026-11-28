// Labels of the live semantics tree, for tests that must prove what a screen
// reader can reach (find.bySemanticsLabel also matches render objects whose
// subtree was excluded, so it cannot prove an absence).
// Not a test file: it has no `main` and is only imported.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Labels of every node under the first [Scaffold] (the whole screen).
List<String> semanticLabels(WidgetTester tester) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    final label = node.getSemanticsData().label;
    if (label.isNotEmpty) labels.add(label);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(find.byType(Scaffold).first));
  return labels;
}

/// How many nodes of the live semantics tree have a label matching [pattern].
int semanticCount(WidgetTester tester, Pattern pattern) =>
    semanticLabels(tester).where((label) => label.contains(pattern)).length;
