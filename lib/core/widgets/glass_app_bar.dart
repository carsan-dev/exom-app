import 'dart:ui';
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

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.headerGlass,
            border: Border(
              bottom: BorderSide(
                color: palette.glassBorder.withValues(alpha: 0.15),
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
                    ?title,
                    const Spacer(),
                    if (actions != null) ...actions!,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
