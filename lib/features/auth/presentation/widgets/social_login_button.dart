import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/tappable_scale.dart';

/// Social sign-in action (sketch «Inicio de sesión», `.btn-out.d-soc`): an
/// outlined full-width button with the provider mark and its label, same
/// shape as [ExomSecondaryButton] (1.5 px `text` border, radius 4, min height
/// 56). While [isLoading] (another attempt is running) it is dimmed and
/// ignores taps; the spinner lives on the primary button, not here (`.d-off`).
class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final enabled = onPressed != null && !isLoading;
    return MergeSemantics(
      child: Semantics(
        container: true,
        button: true,
        enabled: enabled,
        child: Opacity(
          opacity: isLoading ? 0.5 : 1,
          child: TappableScale(
            enabled: enabled,
            onTap: enabled ? onPressed : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: palette.textPrimary, width: 1.5),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: kExomButtonMinHeight,
                  minWidth: double.infinity,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            letterSpacing: 0.32,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
