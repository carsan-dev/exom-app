import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Dash bullets (`.g-bul`) of an exercise text that is a list, shared by the
/// exercise detail sheet and the technique sheet (L5-F4): a 6x2 dash on the
/// first line's x-height, 9 dp before the text, 8 dp between items.
class ExerciseBulletList extends StatelessWidget {
  const ExerciseBulletList({
    super.key,
    required this.items,
    this.fontSize = 14,
    this.height = 1.5,
  });

  final List<String> items;
  final double fontSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final style = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      color: palette.textSecondary,
      fontSize: fontSize,
      height: height,
    );
    // The dash sits on the first line's x-height (`top: .62em`), at the
    // scaled size.
    final dashTop = MediaQuery.textScalerOf(context).scale(fontSize) * 0.62;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, item) in items.indexed)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: dashTop),
                  child: ExcludeSemantics(
                    child: Container(
                      key: const Key('exercise-bullet-mark'),
                      width: 6,
                      height: 2,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(child: Text(item, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}
