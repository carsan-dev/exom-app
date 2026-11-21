import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_notice_row.dart';
import 'package:exom_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One notification as an [ExomNoticeRow] (L5-A1): flat row, an unread dot and
/// weight 600 for the unread ones (distinguishable without colour), the icon
/// of its type in a 56 square (`.x-thumb`, sketch A4) and a compact relative
/// time in the active locale.
class NotificationTile extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;

  /// Clock of the screen; [DateTime.now] when null.
  final DateTime Function()? now;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.now,
  });

  static const double thumbSize = 56;

  /// Icon by `data.type`, the same mapping as the tile before L5-A1.
  IconData _iconForType() {
    final raw = notification.data?['type'];
    final type = raw is String ? raw.toLowerCase() : null;
    switch (type) {
      case 'training':
      case 'training_reminder':
      case 'training_note_reply':
        return ExomIcons.train;
      case 'diet':
      case 'diet_reminder':
      case 'meal':
        return ExomIcons.diet;
      case 'challenge':
      case 'challenge_update':
        return ExomIcons.trophy;
      case 'recap':
      case 'recap_reminder':
      case 'recap_feedback':
        return ExomIcons.barChart;
      case 'profile':
        return ExomIcons.profile;
      case 'calendar':
        return ExomIcons.calendar;
      default:
        return ExomIcons.notifications;
    }
  }

  String _relativeTime(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final diff = (now ?? DateTime.now)().difference(notification.createdAt);
    if (diff.inMinutes < 1) return l10n.noticeTimeNow;
    if (diff.inHours < 1) return l10n.noticeTimeMinutes(diff.inMinutes);
    if (diff.inDays < 1) return l10n.noticeTimeHours(diff.inHours);
    if (diff.inDays < 7) return l10n.noticeTimeDays(diff.inDays);
    // The sketch draws no date for older notices: keep the dd/MM/yy the tile
    // showed before L5-A1, with the active locale for its digits.
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('dd/MM/yy', locale).format(notification.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return ExomNoticeRow(
      title: notification.title,
      body: notification.body,
      time: _relativeTime(context),
      unread: notification.isUnread,
      onTap: onTap,
      leading: Container(
        key: ValueKey('notice-thumb-${notification.id}'),
        width: thumbSize,
        height: thumbSize,
        color: palette.surfaceElevated,
        alignment: Alignment.center,
        child: Icon(_iconForType(), size: 24, color: palette.textSecondary),
      ),
    );
  }
}
