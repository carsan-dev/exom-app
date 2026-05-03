import 'dart:ui';
import 'package:exom_app/core/performance/performance_profile.dart';
import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';

/// Frosted glass app bar with real BackdropFilter blur.
///
/// Uses ClipRect + BackdropFilter for a true frosted glass effect.
/// Safe for performance since the app bar area is small.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.height = kToolbarHeight,
  });

  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blurSigma = PerformanceProfile.blurSigma(context, 20);
    final content = Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.headerGlass : AppColors.headerGlassLightTheme,
        border: Border(
          bottom: BorderSide(
            color: palette.glassBorder.withValues(alpha: isDark ? 0.15 : 0.10),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ?leading,
                if (leading != null) const SizedBox(width: 12),
                if (title != null)
                  Expanded(
                    child: DefaultTextStyle(
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: title!,
                      ),
                    ),
                  ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
        ),
      ),
    );

    if (blurSigma == 0) {
      return content;
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: content,
      ),
    );
  }
}
