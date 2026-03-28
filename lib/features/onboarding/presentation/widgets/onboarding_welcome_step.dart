import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';

class OnboardingWelcomeStep extends StatelessWidget {
  const OnboardingWelcomeStep({
    super.key,
    required this.onStart,
    required this.onSkip,
  });

  final VoidCallback onStart;
  final VoidCallback onSkip;

  String _logoAsset(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? 'assets/images/logo_dark.svg'
        : 'assets/images/logo.svg';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          SvgPicture.asset(_logoAsset(context), height: 32),
          const SizedBox(height: 48),
          Text(
            l10n.onboardingWelcomeTitle,
            style: theme.textTheme.displayLarge?.copyWith(
              color: palette.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.onboardingWelcomeDescription,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: palette.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              child: Text(l10n.onboardingStartButton),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onSkip,
              child: Text(
                l10n.onboardingDoItLaterButton,
                style: TextStyle(color: palette.textMuted),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
