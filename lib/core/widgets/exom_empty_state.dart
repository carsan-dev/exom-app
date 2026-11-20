import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:flutter/material.dart';

/// Empty state of the L5 redesign (`.x-empty`): a two-line headline, an
/// optional [lead] line in strong text (`.strong`), an optional sentence and
/// an optional [action] (usually a button), start aligned with a 28 / 20 dp
/// inset and a 14 dp gap. Flat: no card, no icon
/// badge. The headline is a header node for assistive technology; the
/// [action] keeps its own semantics.
class ExomEmptyState extends StatelessWidget {
  const ExomEmptyState({
    super.key,
    required this.first,
    required this.second,
    this.lead,
    this.body,
    this.action,
  });

  final String first;
  final String second;

  /// The cause in the primary text colour, weight 600, above [body].
  final String? lead;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final leadText = lead;
    final bodyText = body;
    final actionWidget = action;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 20,
        vertical: 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExomTwoLineHeadline(first: first, second: second),
          if (leadText != null) ...[
            const SizedBox(height: 14),
            Text(
              leadText,
              style: TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: palette.textPrimary,
              ),
            ),
          ],
          if (bodyText != null) ...[
            const SizedBox(height: 14),
            Text(
              bodyText,
              style: TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.4,
                color: palette.textSecondary,
              ),
            ),
          ],
          if (actionWidget != null) ...[
            const SizedBox(height: 14),
            actionWidget,
          ],
        ],
      ),
    );
  }
}
