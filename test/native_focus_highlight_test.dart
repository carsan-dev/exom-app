// The whole Flutter UI lives in one focusable FlutterView that covers the
// window. With Android's default focus highlight enabled, once the window
// leaves touch mode (any navigation key event), the framework draws the theme's
// focused `selectableItemBackground` around that view: on Samsung the legacy
// `list_selector_background_focused` nine-patch, a 3 px #99CC00 frame around
// the entire screen that stays after touch mode returns, because the view is
// focusable in touch mode and keeps focus. Flutter draws its own focus
// indicators, so the native highlight must be off in every NormalTheme
// variant (the theme FlutterActivity applies before creating the FlutterView).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

String? _normalThemeItem(String xml, String name) {
  final theme = RegExp(
    r'<style name="NormalTheme"[^>]*>([\s\S]*?)</style>',
  ).firstMatch(xml);
  if (theme == null) return null;
  final item = RegExp(
    '<item name="${RegExp.escape(name)}">([^<]*)</item>',
  ).firstMatch(theme.group(1)!);
  return item?.group(1)?.trim();
}

void main() {
  for (final dir in [
    'values',
    'values-night',
    'values-v31',
    'values-night-v31',
  ]) {
    test('$dir NormalTheme disables the default focus highlight', () {
      final xml = File('$_res/$dir/styles.xml').readAsStringSync();
      expect(
        _normalThemeItem(xml, 'android:defaultFocusHighlightEnabled'),
        'false',
      );
    });
  }
}
