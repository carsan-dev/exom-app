import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/features/notifications/domain/entities/notification_entity.dart';

class NotificationTile extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  IconData _iconForType() {
    final type = (notification.data?['type'] as String?)?.toLowerCase();
    switch (type) {
      case 'training':
      case 'training_reminder':
        return Icons.fitness_center;
      case 'diet':
      case 'diet_reminder':
      case 'meal':
        return Icons.restaurant;
      case 'challenge':
      case 'challenge_update':
        return Icons.emoji_events;
      case 'recap':
      case 'recap_reminder':
      case 'recap_feedback':
        return Icons.bar_chart;
      case 'profile':
        return Icons.person_outline;
      case 'calendar':
        return Icons.calendar_today;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _relativeTime(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(notification.createdAt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('dd/MM/yy').format(notification.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final unread = notification.isUnread;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: GlassDecoration.elevated(borderRadius: 16).copyWith(
            color: unread
                ? palette.primary.withValues(alpha: 0.08)
                : palette.glassBackground,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconForType(),
                  color: palette.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 14,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _relativeTime(context),
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
