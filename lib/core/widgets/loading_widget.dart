import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'exom_panel.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ExomPanel(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          raised: true,
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
        child: ExomPanel(
          padding: const EdgeInsets.all(24),
          raised: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StateIconBadge(icon: ExomIcons.error, color: palette.error),
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
        child: ExomPanel(
          padding: const EdgeInsets.all(28),
          raised: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StateIconBadge(icon: ExomIcons.offline, color: palette.error),
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
                    icon: const Icon(ExomIcons.retry, size: 18),
                    label: Text(l10n.retryButton),
                  ),
                ),
              if (onContactSupport != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onContactSupport,
                    icon: const Icon(ExomIcons.feedback, size: 18),
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
        child: ExomPanel(
          padding: const EdgeInsets.all(28),
          raised: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StateIconBadge(
                icon: ExomIcons.wifiOff,
                color: context.exomSemantic.warning,
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
                    icon: const Icon(ExomIcons.retry, size: 18),
                    label: Text(l10n.retryButton),
                  ),
                ),
              if (onViewOffline != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onViewOffline,
                    icon: const Icon(ExomIcons.offlineSaved, size: 18),
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
    // V4 tokens: raised panel with a panel-coloured sweep, in both themes.
    final baseColor = palette.surfaceElevated;
    final highlightColor = palette.surface;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(
            (borderRadius ?? BorderRadius.circular(16)).topLeft.x,
          ),
          border: Border.all(
            color: palette.glassBorder.withValues(alpha: 0.12),
          ),
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
    final palette = context.exomPalette;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.borderSoft),
      ),
      child: Icon(icon, color: color, size: 36),
    );
  }
}
