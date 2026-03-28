import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';
import 'package:exom_app/l10n/app_localizations.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: context.exomPalette.primary),
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
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 56),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.inbox_outlined,
              color: palette.textDisabled,
              size: 72,
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
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                color: AppColors.error,
                size: 36,
              ),
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
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_outlined,
                color: AppColors.warning,
                size: 36,
              ),
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
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: palette.textDisabled.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_outlined,
                color: palette.textMuted,
                size: 36,
              ),
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

    return Shimmer.fromColors(
      baseColor: palette.surfaceVariant,
      highlightColor: palette.surface,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: borderRadius ?? BorderRadius.circular(16),
        ),
      ),
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
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => ShimmerCard(height: itemHeight),
    );
  }
}
