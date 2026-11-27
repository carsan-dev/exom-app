/// Reviewed exceptions for `hardcoded_ui_strings_test.dart`.
///
/// Each entry is keyed by file + literal text (not line number) and needs a
/// reason. Do not add user-visible product copy here: put it in the ARB files.
class UiStringAllowance {
  const UiStringAllowance(this.path, this.text, this.reason);

  final String path;
  final String text;
  final String reason;
}

const List<UiStringAllowance> uiStringAllowlist = [
  UiStringAllowance(
    'lib/features/settings/presentation/pages/settings_page.dart',
    r'Carlos Sánchez Román',
    'Proper name of the author.',
  ),
  UiStringAllowance(
    'lib/features/settings/presentation/pages/settings_page.dart',
    r'github.com/carsan-dev',
    'URL/handle, not translatable.',
  ),
  UiStringAllowance(
    'lib/features/help/presentation/pages/help_page.dart',
    r'EXOM',
    'Brand name (decorative watermark, excluded from semantics).',
  ),
];
