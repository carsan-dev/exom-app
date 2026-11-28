import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/app_theme.dart';

/// Flat V4 app bar (redesign L2).
///
/// Opaque theme background with a 1 px `rule` at the bottom. Content sits in a
/// [SafeArea] (top only) row of [height]; actions should be at least 48x48
/// (e.g. [IconButton], whose default tap target is 48).
class ExomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ExomAppBar({
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(bottom: BorderSide(color: palette.borderSoft, width: 1)),
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
                        fontFamily: AppTheme.bodyFontFamily,
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
  }
}
