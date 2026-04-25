import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:exom_app/core/navigation/notification_route_utils.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:exom_app/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:exom_app/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationsBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = sl<NotificationsBloc>()..add(const NotificationsRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationsBloc>.value(
      value: _bloc,
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatefulWidget {
  const _NotificationsView();

  @override
  State<_NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<_NotificationsView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      context
          .read<NotificationsBloc>()
          .add(const NotificationsLoadMoreRequested());
    }
  }

  Future<void> _onRefresh() async {
    context.read<NotificationsBloc>().add(const NotificationsRequested());
  }

  Future<void> _onNotificationTap(NotificationEntity notification) async {
    final bloc = context.read<NotificationsBloc>();
    if (notification.isUnread) {
      bloc.add(NotificationsMarkReadRequested(notification.id));
    }

    final route = normalizeNotificationRoute(
      notification.route,
      createdAt: notification.createdAt,
    );
    if (route != null && route.isNotEmpty) {
      _openRoute(context, route);
    }
  }

  Future<void> _confirmDeleteRead() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.notificationsDeleteReadDialogTitle),
          content: Text(l10n.notificationsDeleteReadDialogBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.notificationsDeleteReadConfirm),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      context
          .read<NotificationsBloc>()
          .add(const NotificationsDeleteReadRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return ExomStaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l10n.notificationsTitle),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: context.canPop()
              ? IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
          actions: [
            BlocBuilder<NotificationsBloc, NotificationsState>(
              builder: (context, state) {
                if (state is! NotificationsLoaded) {
                  return const SizedBox.shrink();
                }

                final hasUnread = state.unreadCount > 0;
                final hasRead = state.items.any((notification) => !notification.isUnread);
                if (!hasUnread && !hasRead) {
                  return const SizedBox.shrink();
                }

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasUnread)
                      TextButton(
                        onPressed: () => context
                            .read<NotificationsBloc>()
                            .add(const NotificationsMarkAllReadRequested()),
                        child: Text(
                          l10n.notificationsMarkAllRead,
                          style: TextStyle(color: palette.primary, fontSize: 13),
                        ),
                      ),
                    if (hasRead)
                      IconButton(
                        onPressed: state.deletingRead ? null : _confirmDeleteRead,
                        tooltip: l10n.notificationsDeleteRead,
                        icon: state.deletingRead
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: palette.primary,
                                ),
                              )
                            : Icon(
                                Icons.delete_sweep_outlined,
                                color: palette.primary,
                              ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<NotificationsBloc, NotificationsState>(
          builder: (context, state) {
            if (state is NotificationsLoading ||
                state is NotificationsInitial) {
              return const Center(child: LoadingWidget());
            }

            if (state is NotificationsError) {
              return _ErrorView(
                message: state.message,
                onRetry: () => context
                    .read<NotificationsBloc>()
                    .add(const NotificationsRequested()),
              );
            }

            if (state is NotificationsLoaded) {
              if (state.items.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      Icon(
                        Icons.notifications_off_outlined,
                        color: palette.textSecondary,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          l10n.notificationsEmpty,
                          style: TextStyle(color: palette.textSecondary),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: state.items.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= state.items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final n = state.items[index];
                    return NotificationTile(
                      notification: n,
                      onTap: () => _onNotificationTap(n),
                    );
                  },
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

void _openRoute(BuildContext context, String route) {
  if (shouldPushNotificationRoute(route)) {
    context.push(route);
    return;
  }

  context.go(route);
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: palette.error,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textPrimary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
