import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';

class RecapFeedbackCard extends StatelessWidget {
  final RecapEntity recap;

  const RecapFeedbackCard({super.key, required this.recap});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final theme = Theme.of(context);

    if (!recap.hasClientFeedback) {
      return const SizedBox.shrink();
    }

    final isUnread = recap.hasUnreadClientFeedback;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isUnread
            ? palette.primary.withValues(alpha: 0.08)
            : palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnread
              ? palette.primary.withValues(alpha: 0.4)
              : palette.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.record_voice_over_outlined,
                color: palette.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Comentario de tu entrenador',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isUnread)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Nuevo',
                    style: TextStyle(
                      color: palette.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            recap.clientFeedbackText!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textPrimary,
              height: 1.5,
            ),
          ),
          if (recap.clientFeedbackSentAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Enviado el ${_formatDate(recap.clientFeedbackSentAt!)}',
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
          ],
          if (isUnread && recap.clientFeedbackSentAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule_outlined, size: 13, color: palette.primary),
                const SizedBox(width: 4),
                Text(
                  'Pendiente de lectura',
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (!isUnread && recap.clientFeedbackReadAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 13,
                  color: semantic.success,
                ),
                const SizedBox(width: 4),
                Text(
                  'Leído el ${_formatDate(recap.clientFeedbackReadAt!)}',
                  style: TextStyle(color: semantic.success, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm').format(date.toLocal());
  }
}
