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
    'lib/features/diets/presentation/pages/diets_page.dart',
    r'${meal.calories} kcal',
    'Unit symbol kcal, language neutral.',
  ),
  UiStringAllowance(
    'lib/features/onboarding/presentation/widgets/onboarding_body_step.dart',
    r'${_height.toStringAsFixed(0)} cm',
    'Metric unit symbol, language neutral.',
  ),
  UiStringAllowance(
    'lib/features/onboarding/presentation/widgets/onboarding_body_step.dart',
    r'${_weight.toStringAsFixed(1)} kg',
    'Metric unit symbol, language neutral.',
  ),
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
    'lib/features/splash/presentation/pages/splash_page.dart',
    r'EXOM',
    'Brand name.',
  ),
  UiStringAllowance(
    'lib/main.dart',
    r'EXOM',
    'Brand name (bootstrap screens, no locale available).',
  ),
];
