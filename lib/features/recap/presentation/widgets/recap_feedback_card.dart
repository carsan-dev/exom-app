import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Trainer comment of a recap (sketch C5): the text as an [ExomReplyBlock]
/// whose byline carries «Nuevo» as plain text while it is unread, followed by
/// the sent / read lines in the secondary colour. No card and no pill.
class RecapFeedbackCard extends StatelessWidget {
  final RecapEntity recap;

  const RecapFeedbackCard({super.key, required this.recap});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    if (!recap.hasClientFeedback) {
      return const SizedBox.shrink();
    }

    final isUnread = recap.hasUnreadClientFeedback;
    final sentAt = recap.clientFeedbackSentAt;
    final readAt = recap.clientFeedbackReadAt;
    final noteStyle = TextStyle(
      color: palette.textSecondary,
      fontSize: 13,
      height: 1.3,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ExomSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExomReplyBlock(
            text: recap.clientFeedbackText!,
            author: l10n.recapCoachCommentTitle,
            time: isUnread ? l10n.recapBadgeNew : null,
          ),
          if (sentAt != null) ...[
            const SizedBox(height: 10),
            Text(
              l10n.recapFeedbackSentOn(_formatDate(context, sentAt)),
              style: noteStyle,
            ),
          ],
          if (isUnread && sentAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(ExomIcons.time, size: 13, color: palette.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(l10n.recapFeedbackPendingRead, style: noteStyle),
                ),
              ],
            ),
          ],
          if (!isUnread && readAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(ExomIcons.done, size: 13, color: palette.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    l10n.recapFeedbackReadOn(_formatDate(context, readAt)),
                    style: noteStyle,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    return DateFormat(
      'dd MMM yyyy, HH:mm',
      Localizations.localeOf(context).languageCode,
    ).format(date.toLocal());
  }
}
