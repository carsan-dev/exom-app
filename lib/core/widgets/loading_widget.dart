import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';
import '../theme/glass_decorations.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'glass_card.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return Center(
      child: GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        borderRadius: 24,
        elevated: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(color: palette.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorWidget2 extends StatelessWidget {
  const ErrorWidget2({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(24),
          borderRadius: 28,
          elevated: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StateIconBadge(
                icon: Icons.error_outline,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: palette.textSecondary,
                  fontSize: 16,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onRetry,
                  child: Text(l10n.retryButton),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyWidget extends StatelessWidget {
  const EmptyWidget({
    super.key,
    required this.message,
    this.subtitle,
    this.icon,
    this.action,
  });

  final String message;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(28),
          borderRadius: 28,
          elevated: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StateIconBadge(
                icon: icon ?? Icons.inbox_outlined,
                color: palette.textDisabled,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class ServerErrorWidget extends StatelessWidget {
  const ServerErrorWidget({
    super.key,
    this.errorCode,
    this.onRetry,
    this.onContactSupport,
  });

  final String? errorCode;
  final VoidCallback? onRetry;
  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(28),
          borderRadius: 28,
          elevated: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StateIconBadge(
                icon: Icons.cloud_off_outlined,
                color: AppColors.error,
              ),
              const SizedBox(height: 20),
              Text(
                l10n.serverErrorTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: palette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorCode != null
                    ? l10n.serverErrorMessageWithCode(errorCode!)
                    : l10n.serverErrorMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              if (onRetry != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(l10n.retryButton),
                  ),
                ),
              if (onContactSupport != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onContactSupport,
                    icon: const Icon(Icons.feedback_outlined, size: 18),
                    label: Text(l10n.contactSupportButton),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class NoConnectionWidget extends StatelessWidget {
  const NoConnectionWidget({super.key, this.onRetry, this.onViewOffline});

  final VoidCallback? onRetry;
  final VoidCallback? onViewOffline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(28),
          borderRadius: 28,
          elevated: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StateIconBadge(
                icon: Icons.wifi_off_outlined,
                color: AppColors.warning,
              ),
              const SizedBox(height: 20),
              Text(
                l10n.noConnectionTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: palette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.noConnectionMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              if (onRetry != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(l10n.retryButton),
                  ),
                ),
              if (onViewOffline != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onViewOffline,
                    icon: const Icon(Icons.offline_pin_outlined, size: 18),
                    label: Text(l10n.viewOfflineButton),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class NotFoundWidget extends StatelessWidget {
  const NotFoundWidget({super.key, this.onGoToCalendar, this.onGoHome});

  final VoidCallback? onGoToCalendar;
  final VoidCallback? onGoHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(28),
          borderRadius: 28,
          elevated: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StateIconBadge(
                icon: Icons.search_off_outlined,
                color: palette.textMuted,
              ),
              const SizedBox(height: 20),
              Text(
                l10n.notFoundTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: palette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.notFoundMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              if (onGoToCalendar != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onGoToCalendar,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(l10n.goToCalendarButton),
                  ),
                ),
              if (onGoHome != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onGoHome,
                    icon: const Icon(Icons.home_outlined, size: 18),
                    label: Text(l10n.goHomeButton),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({
    super.key,
    this.height = 80,
    this.width,
    this.borderRadius,
  });

  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final baseColor = Color.alphaBlend(
      palette.primary.withValues(alpha: 0.05),
      AppColors.glassBackgroundElevated,
    );
    final highlightColor = Color.alphaBlend(
      palette.primary.withValues(alpha: 0.12),
      const Color(0x33FFF7DB),
    );

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: GlassDecoration.card(
          borderRadius: (borderRadius ?? BorderRadius.circular(16)).topLeft.x,
          borderColor: palette.glassBorder.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}

class _StateIconBadge extends StatelessWidget {
  const _StateIconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: GlassDecoration.accentCard(color, borderRadius: 999),
      child: Icon(icon, color: color, size: 36),
    );
  }
}

class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 5, this.itemHeight = 80});

  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => ShimmerCard(height: itemHeight),
    );
  }
}
