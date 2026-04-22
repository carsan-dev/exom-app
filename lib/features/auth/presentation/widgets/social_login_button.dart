import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';

class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.icon,
    this.label,
    this.onPressed,
    this.isLoading = false,
  });

  final Widget icon;
  final String? label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        side: BorderSide(
          color: palette.glassBorder.withValues(alpha: 0.16),
          width: 0.6,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        minimumSize: const Size.fromHeight(52),
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: Ink(
        decoration: GlassDecoration.card(borderRadius: 18),
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 52),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    if (label != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        label!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
