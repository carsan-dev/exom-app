import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:exom_app/core/navigation/notification_route_utils.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_arrival.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/core/widgets/tappable_scale.dart';
import 'package:exom_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:exom_app/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:exom_app/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';

class NotificationsPage extends StatefulWidget {
  /// [now] is the screen's clock (day groups and relative times); tests
  /// inject a fixed one. [DateTime.now] when null.
  const NotificationsPage({super.key, this.now});

  final DateTime Function()? now;

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
      child: _NotificationsView(now: widget.now ?? DateTime.now),
    );
  }
}

class _NotificationsView extends StatefulWidget {
  const _NotificationsView({required this.now});

  final DateTime Function() now;

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
      context.read<NotificationsBloc>().add(
        const NotificationsLoadMoreRequested(),
      );
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
    // An EXOM sheet closes itself, without running its action, when the router
    // location changes (CC 11). Destructive confirmation (sketch A4, state c):
    // a red 3 px bar on top, an outlined error action and no lime at all.
    final confirmed = await showExomSheet<bool>(
      context: context,
      builder: (_) => _DeleteReadSheetContent(
        title: l10n.notificationsDeleteReadDialogTitle,
        body: l10n.notificationsDeleteReadDialogBody,
      ),
      actions: [
        Builder(
          builder: (sheetContext) => _DestructiveButton(
            label: l10n.notificationsDeleteReadConfirm,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
        ),
        Builder(
          builder: (sheetContext) => ExomQuietButton(
            label: l10n.cancel,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ),
      ],
    );

    if (confirmed == true && mounted) {
      context.read<NotificationsBloc>().add(
        const NotificationsDeleteReadRequested(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ExomStaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Sketch A4: the bar only carries «Volver»; the title is the body
        // headline (_ScreenTitle).
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: context.canPop()
              ? IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(ExomIcons.back),
                )
              : null,
        ),
        body: BlocBuilder<NotificationsBloc, NotificationsState>(
          builder: (context, state) {
            if (state is NotificationsLoading ||
                state is NotificationsInitial) {
              return const _LoadingView();
            }

            if (state is NotificationsError) {
              return _ErrorView(
                message: localizedErrorTextOf(
                  context,
                  state.message,
                  fallback: (l10n) => l10n.notificationsLoadError,
                ),
                onRetry: () => context.read<NotificationsBloc>().add(
                  const NotificationsRequested(),
                ),
              );
            }

            if (state is NotificationsLoaded) {
              if (state.items.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: ExomSpacing.xxl),
                    children: [
                      const _ScreenTitle(),
                      _UnreadHero(count: 0, footnote: l10n.noticesAllCaughtUp),
                      ExomEmptyState(
                        first: l10n.noticesEmptyFirst,
                        second: l10n.noticesEmptySecond,
                        body: l10n.notificationsEmpty,
                      ),
                    ],
                  ),
                );
              }

              return _buildList(context, state);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, NotificationsLoaded state) {
    final hasUnread = state.unreadCount > 0;
    final hasRead = state.items.any((n) => !n.isUnread);
    final entries = _entriesFor(state, now: widget.now());
    // Every entry is keyed by what it shows (a notice by its id), so a row
    // never inherits the state of another one that used to sit at its index
    // (e.g. the folded state of a deleted read row, I2).
    final keyIndex = <Key, int>{
      for (var i = 0; i < entries.length; i++) entries[i].key: i,
    };

    return RefreshIndicator(
      onRefresh: _onRefresh,
      // A pull-to-refresh replays this arrival: the bloc emits
      // NotificationsLoading first, the skeleton replaces the list and the
      // list is inserted again (behaviour kept from before L5-A1).
      child: ExomArrival(
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: ExomSpacing.xxl),
          itemCount: entries.length,
          findChildIndexCallback: (key) => keyIndex[key],
          itemBuilder: (context, index) {
            final entry = entries[index];
            return switch (entry) {
              _LeadEntry() => KeyedSubtree(
                key: entry.key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _ScreenTitle(),
                    _UnreadHero(count: state.unreadCount),
                    if (hasUnread || hasRead)
                      _ActionLinks(
                        onMarkAll: hasUnread
                            ? () => context.read<NotificationsBloc>().add(
                                const NotificationsMarkAllReadRequested(),
                              )
                            : null,
                        onDeleteRead: hasRead && !state.deletingRead
                            ? _confirmDeleteRead
                            : null,
                        showMarkAll: hasUnread,
                        showDeleteRead: hasRead,
                      ),
                  ],
                ),
              ),
              _GroupEntry(:final group, :final number, :final collapsed) =>
                _FoldingRow(
                  key: entry.key,
                  collapsed: collapsed,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: ExomSpacing.xl,
                      bottom: ExomSpacing.sm,
                    ),
                    child: ExomNumberedSectionHeader(
                      n: number,
                      title: _groupTitle(context, group),
                    ),
                  ),
                ),
              _NoticeEntry(:final notification, :final row) => ExomArrivalItem(
                key: entry.key,
                index: row,
                child: _FoldingRow(
                  collapsed: state.deletingRead && !notification.isUnread,
                  child: NotificationTile(
                    notification: notification,
                    now: widget.now,
                    onTap: () => _onNotificationTap(notification),
                  ),
                ),
              ),
              _MoreEntry() => ExomSkeleton.row(key: entry.key),
            };
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

/// Day groups of sketch A4 («Hoy», «Esta semana»), plus «Anteriores» for
/// anything before the current week.
enum _NoticeGroup { today, thisWeek, earlier }

String _groupTitle(BuildContext context, _NoticeGroup group) {
  final l10n = AppLocalizations.of(context);
  return switch (group) {
    _NoticeGroup.today => l10n.noticesGroupToday,
    _NoticeGroup.thisWeek => l10n.noticesGroupThisWeek,
    _NoticeGroup.earlier => l10n.noticesGroupEarlier,
  };
}

/// Group of [createdAt] relative to [now]: the same calendar day, the same
/// calendar week (always starting on Monday, L5-D37) or earlier. A date in
/// the future counts as today.
_NoticeGroup _groupOf(DateTime createdAt, DateTime now) {
  final local = createdAt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (!day.isBefore(today)) return _NoticeGroup.today;
  // The week always starts on Monday, in every language (L5-D37).
  final offset = now.weekday - DateTime.monday;
  final weekStart = DateTime(today.year, today.month, today.day - offset);
  if (!day.isBefore(weekStart)) return _NoticeGroup.thisWeek;
  return _NoticeGroup.earlier;
}

sealed class _Entry {
  const _Entry();

  Key get key;
}

/// Title, unread hero and the action links.
class _LeadEntry extends _Entry {
  const _LeadEntry();

  @override
  Key get key => const ValueKey('notices-lead');
}

class _GroupEntry extends _Entry {
  const _GroupEntry({
    required this.group,
    required this.number,
    required this.collapsed,
  });

  final _NoticeGroup group;
  final int number;

  /// Every notice of the group is read and folding away (M7).
  final bool collapsed;

  @override
  Key get key => ValueKey('notice-group-${group.name}-$number');
}

class _NoticeEntry extends _Entry {
  const _NoticeEntry({required this.notification, required this.row});

  final NotificationEntity notification;

  /// Position among the notices (arrival stagger).
  final int row;

  @override
  Key get key => ValueKey('notice-${notification.id}');
}

class _MoreEntry extends _Entry {
  const _MoreEntry();

  @override
  Key get key => const ValueKey('notices-more');
}

/// Flattens the loaded notices, in the bloc's order, into the lead, a numbered
/// header each time the day group changes, the notices and the "more" row.
List<_Entry> _entriesFor(NotificationsLoaded state, {required DateTime now}) {
  final items = state.items;
  final groups = [for (final n in items) _groupOf(n.createdAt, now)];
  final entries = <_Entry>[const _LeadEntry()];
  var number = 0;
  for (var i = 0; i < items.length; i++) {
    if (i == 0 || groups[i] != groups[i - 1]) {
      number++;
      var end = i;
      while (end < items.length && groups[end] == groups[i]) {
        end++;
      }
      final allRead = items.sublist(i, end).every((n) => !n.isUnread);
      entries.add(
        _GroupEntry(
          group: groups[i],
          number: number,
          collapsed: state.deletingRead && allRead,
        ),
      );
    }
    entries.add(_NoticeEntry(notification: items[i], row: i));
  }
  if (state.hasMore) entries.add(const _MoreEntry());
  return entries;
}

/// Screen headline (sketch `.t1`): «Avisos» in Barlow Condensed 800, painted
/// upper case; one header node with the original text.
class _ScreenTitle extends StatelessWidget {
  const _ScreenTitle();

  @override
  Widget build(BuildContext context) {
    final title = AppLocalizations.of(context).noticesScreenTitle;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ExomSpacing.xl,
        ExomSpacing.sm,
        ExomSpacing.xl,
        0,
      ),
      child: Semantics(
        header: true,
        label: title,
        excludeSemantics: true,
        child: Text(
          title.toUpperCase(),
          style: ExomType.screenTitle.copyWith(
            color: context.exomPalette.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Unread count at 96 (`.x-hero-96`) with «sin leer» beside it. Data colour
/// while there is something unread; text colour at 0 (`.x-plain`). The total
/// («de N avisos») is not drawn: the state does not carry it (L5-D36).
class _UnreadHero extends StatelessWidget {
  const _UnreadHero({required this.count, this.footnote});

  final int count;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final locale = Localizations.localeOf(context).toString();
    final note = footnote;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ExomSpacing.xl,
        ExomSpacing.lg,
        ExomSpacing.xl,
        0,
      ),
      child: MergeSemantics(
        child: ExomNumeral(
          value: NumberFormat.decimalPattern(locale).format(count),
          isData: count > 0,
          side: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: l10n.noticesUnreadHero,
                excludeSemantics: true,
                child: Text(
                  l10n.noticesUnreadHero.toUpperCase(),
                  style: ExomType.headline2Section.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: ExomSpacing.xs),
                Text(
                  note,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFontFamily,
                    fontSize: 14,
                    height: 1.35,
                    color: palette.textSecondary,
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

/// «Marcar todas» and «Eliminar leídas» as in-line links under the hero
/// (`.x-sh-row`): both spread to the ends; a lone link sits at the end.
class _ActionLinks extends StatelessWidget {
  final VoidCallback? onMarkAll;
  final VoidCallback? onDeleteRead;
  final bool showMarkAll;
  final bool showDeleteRead;

  const _ActionLinks({
    required this.onMarkAll,
    required this.onDeleteRead,
    required this.showMarkAll,
    required this.showDeleteRead,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final links = [
      if (showMarkAll)
        ExomTextLink(label: l10n.notificationsMarkAllRead, onTap: onMarkAll),
      if (showDeleteRead)
        ExomTextLink(label: l10n.notificationsDeleteRead, onTap: onDeleteRead),
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ExomSpacing.xl,
        ExomSpacing.sm,
        ExomSpacing.xl,
        0,
      ),
      child: links.length == 1
          ? Align(alignment: AlignmentDirectional.centerEnd, child: links.first)
          : Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: ExomSpacing.md,
              children: links,
            ),
    );
  }
}

/// Content-shaped loading (M3, sketch A4 state d): the title, the shape of
/// the unread figure and five rows. The pulse is static with reduced motion.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        _ScreenTitle(),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            ExomSpacing.xl,
            ExomSpacing.lg,
            ExomSpacing.xl,
            ExomSpacing.xl,
          ),
          child: ExomSkeleton.numeral(),
        ),
        ExomSkeleton.row(),
        ExomSkeleton.row(),
        ExomSkeleton.row(),
        ExomSkeleton.row(),
        ExomSkeleton.row(),
      ],
    );
  }
}

/// Folds a read notification (or a day header left with only read ones) away
/// while the bulk delete runs (M7): height and fade over the expand timings,
/// or a fade only with reduced motion. If the delete fails the bloc restores
/// its state and the row unfolds again.
class _FoldingRow extends StatefulWidget {
  final bool collapsed;
  final Widget child;

  const _FoldingRow({super.key, required this.collapsed, required this.child});

  @override
  State<_FoldingRow> createState() => _FoldingRowState();
}

class _FoldingRowState extends State<_FoldingRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.collapsed ? 0 : 1,
  );
  late final CurvedAnimation _height = CurvedAnimation(
    parent: _controller,
    curve: ExomMotion.expandCurve,
  );

  @override
  void didUpdateWidget(_FoldingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapsed == oldWidget.collapsed) return;
    final motion = ExomMotion.of(context);
    _controller.duration = motion.expandAnimatesHeight
        ? motion.expandHeight
        : motion.expandContentFade;
    if (widget.collapsed) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _height.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animatesHeight = ExomMotion.of(context).expandAnimatesHeight;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        if (_controller.isDismissed) return const SizedBox.shrink();
        final faded = FadeTransition(opacity: _controller, child: child);
        return IgnorePointer(
          ignoring: widget.collapsed,
          child: animatesHeight
              ? SizeTransition(
                  sizeFactor: _height,
                  axisAlignment: -1,
                  child: faded,
                )
              : faded,
        );
      },
    );
  }
}

/// Load error (sketch A4 state b): the title and the inline error with
/// «Reintentar»; no figure, there is no data.
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ScreenTitle(),
          Padding(
            padding: const EdgeInsets.all(ExomSpacing.xl),
            child: ExomInlineMessage(
              kind: ExomMessageKind.error,
              title: message,
              actionLabel: l10n.retry,
              onAction: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

/// Body of the delete-read sheet: the destructive 3 px bar in the error colour
/// (`.sheet.a-bar-err`), then the title and body with the same type as the
/// confirmation sheets of [showExomSheet]. The bar sits right under the drag
/// handle: [showExomSheet] has no hook to paint the panel's own top edge.
class _DeleteReadSheetContent extends StatelessWidget {
  const _DeleteReadSheetContent({required this.title, required this.body});

  final String title;
  final String body;

  static const double barHeight = 3;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: barHeight,
          child: ColoredBox(
            key: const Key('notices-delete-bar'),
            color: palette.error,
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                label: title,
                excludeSemantics: true,
                child: Text(
                  title.toUpperCase(),
                  style: ExomType.headline2Section.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: ExomSpacing.xs),
              Text(
                body,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFontFamily,
                  fontSize: 14,
                  height: 1.35,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Destructive action of the delete sheet (`.btn.a-btn-err`): a 1.5 px outline
/// and the label in the error colour, transparent fill, never lime. Same size,
/// label type and press feedback as [ExomSecondaryButton].
class _DestructiveButton extends StatelessWidget {
  const _DestructiveButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colour = context.exomPalette.error;
    return MergeSemantics(
      child: Semantics(
        container: true,
        button: true,
        enabled: true,
        child: TappableScale(
          onTap: onPressed,
          child: DecoratedBox(
            key: const Key('notices-delete-confirm'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: colour, width: ExomRule.outline),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kExomButtonMinHeight,
                minWidth: double.infinity,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      letterSpacing: 0.32,
                      color: colour,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
