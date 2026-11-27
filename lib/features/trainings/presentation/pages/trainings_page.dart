import 'dart:async';
import 'dart:math' as math;

import '../widgets/pending_training_executions.dart';
export '../widgets/pending_training_executions.dart';

import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:flutter/material.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/formatters/figure_format.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/utils/training_type_utils.dart';
import 'package:exom_app/core/widgets/exom_arrival.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_moment_pill.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_rich_row.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/home/presentation/widgets/home_session_photo.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/planned_sets.dart';
import 'package:exom_app/features/trainings/presentation/bloc/training_bloc.dart';
import 'package:exom_app/injection_container.dart';

class TrainingsPage extends StatelessWidget {
  const TrainingsPage({super.key, this.selectedDate});

  final String? selectedDate;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<TrainingBloc>()..add(TrainingsLoadRequested(date: selectedDate)),
      child: _TrainingsView(selectedDate: selectedDate),
    );
  }
}

class _TrainingsView extends StatefulWidget {
  const _TrainingsView({this.selectedDate});

  final String? selectedDate;

  @override
  State<_TrainingsView> createState() => _TrainingsViewState();
}

class _TrainingsViewState extends State<_TrainingsView> {
  StreamSubscription<void>? _syncChanges;
  String? _mountedSessionStamp;

  /// The pending list is running a confirmed discard (its row actions are
  /// disabled): the footer acts on the same sessions, so it waits too (I1).
  bool _pendingBusy = false;

  /// A pending session is being opened: repeated taps (double tap, row and
  /// footer) are ignored until that navigation ends or fails (I1).
  bool _opening = false;

  /// The day/history content has been shown once: later loads (refresh)
  /// change it in place, without the M3 arrival.
  bool _contentArrived = false;

  final ScrollController _pendingScroll = ScrollController();
  final GlobalKey _pendingKey = GlobalKey();
  final GlobalKey _firstActionsKey = GlobalKey();
  // Height the pending box needs to show the first session down to its
  // actions; 0 until measured. Large text makes it taller than 30 %.
  double _firstSessionHeight = 0;

  @override
  void initState() {
    super.initState();
    final storage = sl<LocalStorage>();
    _mountedSessionStamp = storage.sessionStamp;
    if (_mountedSessionStamp != null &&
        _mountedSessionStamp!.isNotEmpty &&
        sl.isRegistered<OfflineSyncService>()) {
      _syncChanges = sl<OfflineSyncService>().changes.listen((_) {
        if (!mounted || storage.sessionStamp != _mountedSessionStamp) return;
        // The pending execution list reads owner-scoped storage directly.
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _syncChanges?.cancel();
    _pendingScroll.dispose();
    super.dispose();
  }

  String? get selectedDate => widget.selectedDate;

  /// Whether the page shows today: no date given (the shell tab) or today's.
  bool _isToday(String resolvedDate) {
    if (selectedDate == null) return true;
    final parsed = DateTime.tryParse(resolvedDate);
    return parsed != null && DateUtils.isSameDay(parsed, DateTime.now());
  }

  String _dateLabel(BuildContext context, String resolvedDate) {
    final l10n = AppLocalizations.of(context);
    if (selectedDate == null) return l10n.todayLabel.toLowerCase();
    final parsed = DateTime.tryParse(resolvedDate);
    if (parsed == null) return l10n.selectedDateLabel;
    if (_isToday(resolvedDate)) return l10n.todayLabel.toLowerCase();
    // Day and month in the active locale (es «14/10», en «10/14»).
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.Md(locale).format(parsed);
  }

  void _onPendingBusyChanged(bool busy) {
    if (!mounted) return;
    // Also re-reads the pending list, so the footer follows a discard that
    // ended without a sync change event.
    setState(() => _pendingBusy = busy);
  }

  /// Opens the exact local session [entry] for [action] («continue» or
  /// «finalize»), only while the session generation captured in [stamp] is
  /// still current and the same entry is still pending.
  Future<void> _openPending(
    LocalStorage storage,
    String? stamp,
    Map<String, dynamic> entry,
    String action,
  ) async {
    if (_opening || _pendingBusy) return;
    if (stamp == null ||
        storage.sessionStamp != stamp ||
        !storage.getPendingTrainingExecutions().any(
          (candidate) =>
              candidate['id'] == entry['id'] &&
              candidate['training_id'] == entry['training_id'] &&
              candidate['assignment_date'] == entry['assignment_date'] &&
              candidate['status'] == entry['status'],
        )) {
      return;
    }
    final uri = Uri(
      path: '/trainings/${entry['training_id']}',
      queryParameters: {
        'date': entry['assignment_date'] as String,
        'execution': entry['id'] as String,
        if (action == 'finalize') 'action': 'finalize',
      },
    );
    _opening = true;
    final Future<Object?> opened;
    try {
      opened = context.push(uri.toString());
    } catch (_) {
      _opening = false;
      rethrow;
    }
    // The push is applied in the next frame; from then on the detail route
    // covers this page. go_router only completes [opened] when the detail is
    // popped, so a detail left with `go()` while this page stays mounted
    // would keep the guard set: release it once the push has been applied and
    // use [opened] only to refresh the list afterwards.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _opening = false;
    });
    await opened;
    if (mounted && storage.sessionStamp == stamp) setState(() {});
  }

  /// Measures the pending list from its top to the bottom of the first
  /// session's actions and the padding under them, and rebuilds when the box
  /// needs another height.
  void _measureFirstSession() {
    if (!mounted) return;
    final root = _pendingKey.currentContext?.findRenderObject();
    final actions = _firstActionsKey.currentContext?.findRenderObject();
    var height = 0.0;
    if (root is RenderBox &&
        actions is RenderBox &&
        root.attached &&
        actions.attached) {
      height = actions
          .localToGlobal(Offset(0, actions.size.height), ancestor: root)
          .dy +
          pendingActionsBottomPadding;
    }
    if ((height - _firstSessionHeight).abs() > .5) {
      setState(() => _firstSessionHeight = height);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = sl<LocalStorage>();
    final stamp = storage.sessionStamp;
    final pending = storage.getPendingTrainingExecutions();
    // The footer continues the first session that offers «continue» in the
    // list above (same order, same condition as its row action).
    Map<String, dynamic>? continuable;
    for (final entry in pending) {
      if (entry['status'] != 'pending-sync' && entry['status'] != 'conflict') {
        continuable = entry;
        break;
      }
    }
    final footerEntry = continuable;
    // The height the first session needs depends on the text scale: depend on
    // it so a change made while the tab is open rebuilds and measures again.
    MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Also measure when only the constraints change (rotation, split
        // screen): the cap below is computed from them.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _measureFirstSession(),
        );
        return _buildPage(context, constraints, pending, footerEntry, stamp, storage);
      },
    );
  }

  Widget _buildPage(
    BuildContext context,
    BoxConstraints constraints,
    List<Map<String, dynamic>> pending,
    Map<String, dynamic>? footerEntry,
    String? stamp,
    LocalStorage storage,
  ) {
    return Column(
        children: [
          if (pending.isNotEmpty)
            ConstrainedBox(
              // 30 % of the page, but never less than what the first session
              // needs to show its actions (large text), up to 75 %. More
              // sessions scroll; the scroll bar shows there are more.
              constraints: BoxConstraints(
                maxHeight: math.min(
                  math.max(constraints.maxHeight * .3, _firstSessionHeight),
                  constraints.maxHeight * .75,
                ),
              ),
              child: Scrollbar(
                controller: _pendingScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _pendingScroll,
                  child: SizeChangedLayoutNotifier(
                    child: NotificationListener<SizeChangedLayoutNotification>(
                      onNotification: (_) {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _measureFirstSession(),
                        );
                        return false;
                      },
                      child: PendingTrainingExecutions(
                        key: _pendingKey,
                        firstActionsKey: _firstActionsKey,
                        storage: storage,
                        inspectDiscard: sl.isRegistered<OfflineSyncService>()
                            ? sl<OfflineSyncService>()
                                  .inspectTrainingExecutionDiscard
                            : null,
                        discard: sl.isRegistered<OfflineSyncService>()
                            ? sl<OfflineSyncService>().discardTrainingExecution
                            : null,
                        onSelect: (entry, action) =>
                            _openPending(storage, stamp, entry, action),
                        onBusyChanged: _onPendingBusyChanged,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: BlocBuilder<TrainingBloc, TrainingState>(
              builder: (context, state) {
                if (state is TrainingLoading || state is TrainingInitial) {
                  return const _TrainingsLoadingView();
                }
                if (state is TrainingError) {
                  return ErrorWidget2(
                    message: state.apiException != null
                        ? localizedApiError(context, state.apiException!)
                        : AppLocalizations.of(context).errorServer,
                    onRetry: () => context.read<TrainingBloc>().add(
                      TrainingsLoadRequested(
                        date: state.selectedDate ?? selectedDate,
                        historyDate:
                            state.historyDate ??
                            state.selectedDate ??
                            selectedDate,
                      ),
                    ),
                  );
                }
                if (state is TrainingNoContent) {
                  final l10n = AppLocalizations.of(context);
                  return ListView(
                    children: [
                      ExomEmptyState(
                        first: l10n.trainingsNoPlanFirst,
                        second: l10n.trainingsNoPlanSecond,
                        lead: l10n.noTrainingsAssigned,
                        body: l10n.noTrainingsAssignedSubtitle,
                      ),
                    ],
                  );
                }
                if (state is TrainingsLoaded) {
                  // M3: only the first time the content replaces the
                  // skeleton; a refresh changes it in place.
                  final animate = !_contentArrived;
                  _contentArrived = true;
                  return ExomArrival(
                    animate: animate,
                    child: _buildContent(
                      context,
                      state,
                      _dateLabel(context, state.selectedDate),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          if (footerEntry != null)
            ExomPinnedFooter(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: ExomPrimaryButton(
                key: const Key('pending-footer-continue'),
                label: AppLocalizations.of(
                  context,
                ).trainingsContinueSessionButton,
                trailingIcon: ExomIcons.forward,
                onPressed: _pendingBusy
                    ? null
                    : () =>
                          _openPending(storage, stamp, footerEntry, 'continue'),
              ),
            ),
        ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    TrainingsLoaded state,
    String dateLabel,
  ) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final historyMonth = DateTime.parse(state.historyDate);
    final isCurrentMonth = _isCurrentMonth(historyMonth);
    final isToday = _isToday(state.selectedDate);

    void loadHistory(DateTime month) {
      context.read<TrainingBloc>().add(
        TrainingsLoadRequested(
          date: state.selectedDate,
          historyDate: _storageDate(_startOfMonth(month)),
        ),
      );
    }

    final Widget history;
    if (state.isHistoryLoading) {
      history = const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ExomSkeleton.row(), ExomSkeleton.row(), ExomSkeleton.row()],
      );
    } else if (state.historyFailed) {
      history = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ExomInlineMessage(
          kind: ExomMessageKind.error,
          title: l10n.errorServer,
          actionLabel: l10n.retryButton,
          onAction: () => context.read<TrainingBloc>().add(
            TrainingsLoadRequested(
              date: state.selectedDate,
              historyDate: state.historyDate,
            ),
          ),
        ),
      );
    } else if (state.history.isEmpty) {
      history = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ExomInlineMessage(
          kind: ExomMessageKind.info,
          title: l10n.noPastTrainingsThisMonth,
          body: l10n.noPastTrainingsThisMonthSubtitle,
        ),
      );
    } else {
      history = ExomFlatRowGroup(
        children: [
          for (final entry in state.history)
            _TrainingHistoryRow(
              entry: entry,
              selectedDate: state.selectedDate,
              historyDate: state.historyDate,
            ),
        ],
      );
    }

    // Blocks of the day, in order; each rises with the M3 arrival.
    final dayBlocks = <Widget>[
      _DayKicker(
        text: state.todayTrainings.isNotEmpty
            ? (selectedDate == null
                  ? l10n.todaysTrainingTitle
                  : '${l10n.training} $dateLabel')
            : (selectedDate == null ? l10n.todayLabel : dateLabel),
      ),
      if (state.todayTrainings.isNotEmpty) ...[
        // Sketch «Hoy sabes / qué hacer.»: only when the day is today.
        if (isToday)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
            child: ExomTwoLineHeadline(
              first: l10n.trainingsTodayHeadlineFirst,
              second: l10n.trainingsTodayHeadlineSecond,
            ),
          ),
        _TodaySession(
          training: state.todayTrainings.first,
          selectedDate: state.selectedDate,
          historyDate: state.historyDate,
          isToday: isToday,
        ),
        // Other trainings of the same day keep the rich row.
        if (state.todayTrainings.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ExomFlatRowGroup(
              children: [
                for (final training in state.todayTrainings.skip(1))
                  _TodayTrainingRow(
                    training: training,
                    selectedDate: state.selectedDate,
                    historyDate: state.historyDate,
                  ),
              ],
            ),
          ),
      ] else
        ExomEmptyState(
          first: l10n.trainingsRestDayFirst,
          second: l10n.trainingsRestDaySecond,
          lead: selectedDate == null
              ? l10n.noTrainingAssignedToday
              : l10n.noTrainingAssignedForDate,
          body: l10n.enjoyRestDay,
        ),
    ];

    // The day closes with a rule when it ends with the session's figure
    // columns or with the group of the other trainings: «Historial» then
    // shares that rule instead of opening an empty strip between two rules.
    final today = state.todayTrainings;
    final dayEndsWithRule =
        today.length > 1 ||
        (today.length == 1 && _TodaySession.closesWithRule(today.first));

    return RefreshIndicator(
      color: palette.data,
      backgroundColor: palette.surface,
      onRefresh: () async {
        context.read<TrainingBloc>().add(
          TrainingsLoadRequested(
            date: state.selectedDate,
            historyDate: state.historyDate,
          ),
        );
      },
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          for (final (index, dayBlock) in dayBlocks.indexed)
            ExomArrivalItem(index: index, child: dayBlock),
          if (!dayEndsWithRule) const SizedBox(height: 24),
          ExomArrivalItem(
            index: dayBlocks.length,
            child: ExomBand(
              joinsPrevious: dayEndsWithRule,
              kicker: l10n.history,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HistoryMonthSelector(
                    visibleMonth: historyMonth,
                    onPrevious: () => loadHistory(_addMonths(historyMonth, -1)),
                    onNext: isCurrentMonth
                        ? null
                        : () => loadHistory(_addMonths(historyMonth, 1)),
                  ),
                  const SizedBox(height: 8),
                  history,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// First load: flat blocks with the shape of the day row and the history.
class _TrainingsLoadingView extends StatelessWidget {
  const _TrainingsLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 32),
      children: const [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: ExomSkeleton.headline(),
        ),
        ExomSkeleton.row(),
        SizedBox(height: 24),
        ExomSkeleton.rule(),
        SizedBox(height: 20),
        ExomSkeleton.row(),
        ExomSkeleton.row(),
        ExomSkeleton.row(),
      ],
    );
  }
}

String _storageDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

DateTime _startOfMonth(DateTime date) => DateTime(date.year, date.month);

DateTime _addMonths(DateTime date, int monthDelta) {
  return DateTime(date.year, date.month + monthDelta, 1);
}

bool _isCurrentMonth(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month;
}

String _historyMonthLabel(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat('MMM yyyy', locale).format(date);
}

/// Date box of a rich row: day and short month in the active locale.
ExomRowLeading _dateLeading(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return ExomRowLeading.date(
    day: DateFormat('d', locale).format(date),
    label: DateFormat('MMM', locale).format(date),
  );
}

/// Secondary line of a training row: duration, exercises and up to two types,
/// figures in the active locale. Null when there is nothing to say.
String? _trainingFacts(
  BuildContext context, {
  required int? minutes,
  int? exercises,
  required List<String> types,
}) {
  final l10n = AppLocalizations.of(context);
  final labels = trainingTypeLabels(context, types);
  final parts = <String>[
    if (minutes != null)
      '${formatFigure(context, minutes)} ${l10n.activeExerciseUnitMinutes}',
    if (exercises != null)
      l10n.homeFactExercises(exercises),
    if (labels.isNotEmpty) trainingTypesSummaryLabel(context, types),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

class _DayKicker extends StatelessWidget {
  const _DayKicker({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 12),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(header: true, child: ExomKicker(text)),
      ),
    );
  }
}

/// Month of the history: previous / next arrows (48 dp, labelled) around the
/// month name. «Next» is disabled on the current month.
class _HistoryMonthSelector extends StatelessWidget {
  const _HistoryMonthSelector({
    required this.visibleMonth,
    required this.onPrevious,
    this.onNext,
  });

  final DateTime visibleMonth;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            tooltip: l10n.trainingsHistoryPreviousMonth,
            constraints: _arrowTarget,
            color: palette.textPrimary,
            disabledColor: palette.textDisabled,
            icon: const Icon(ExomIcons.previous),
          ),
          Expanded(
            child: Text(
              _historyMonthLabel(context, visibleMonth),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: palette.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            tooltip: l10n.trainingsHistoryNextMonth,
            constraints: _arrowTarget,
            color: palette.textPrimary,
            disabledColor: palette.textDisabled,
            icon: const Icon(ExomIcons.next),
          ),
        ],
      ),
    );
  }
}

/// Touch target of each month arrow (plan §2 and §11), whatever the theme's
/// visual density.
const BoxConstraints _arrowTarget = BoxConstraints(minWidth: 48, minHeight: 48);

/// «Hecha» of the client (D19): check and text in the data colour.
class _DoneStatus extends StatelessWidget {
  const _DoneStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: ExcludeSemantics(
            child: Icon(ExomIcons.check, size: 18, color: palette.data),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: palette.data,
            ),
          ),
        ),
      ],
    );
  }
}

/// Photo of a session: the `thumbnailUrl` of its first exercise, by `order`,
/// that is a usable http(s) URL (same rule as the Inicio photo, L4b-D1).
String? _sessionPhotoUrl(TrainingEntity training) {
  final ordered = training.exercises.indexed.toList()
    ..sort((a, b) {
      final byOrder = a.$2.order.compareTo(b.$2.order);
      return byOrder != 0 ? byOrder : a.$1.compareTo(b.$1);
    });
  for (final (_, item) in ordered) {
    final url = item.exercise.thumbnailUrl?.trim();
    if (url == null || url.isEmpty) continue;
    final uri = Uri.tryParse(url);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return url;
    }
  }
  return null;
}

/// Featured session of the day (sketch A2 «Entrenar · sin pendiente», L5-D36):
/// the photo of its first exercise bleeding edge to edge (with the «Hoy» pill
/// when the day is today), the name as a headline on the shared title hero of
/// the detail page, its types, and the numbered figures (exercises, planned
/// sets, approximate minutes). Only data the page already has: no week, no
/// coach block. The photo and title open the session, as the row did.
class _TodaySession extends StatelessWidget {
  const _TodaySession({
    required this.training,
    required this.selectedDate,
    required this.historyDate,
    required this.isToday,
  });

  final TrainingEntity training;
  final String selectedDate;
  final String historyDate;
  final bool isToday;

  /// Whether the block ends with its figure columns (and so with a rule).
  static bool closesWithRule(TrainingEntity training) =>
      training.exercises.isNotEmpty || training.estimatedDurationMin != null;

  Future<void> _open(BuildContext context) async {
    await context.push('/trainings/${training.id}?date=$selectedDate');
    if (context.mounted) {
      context.read<TrainingBloc>().add(
        TrainingsLoadRequested(date: selectedDate, historyDate: historyDate),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final photo = _sessionPhotoUrl(training);
    final types = trainingTypeLabels(context, training.types).isEmpty
        ? null
        : trainingTypesSummaryLabel(context, training.types);
    // Same rule as Inicio and the detail (circuit exercises weigh sets x
    // rounds, L4b-D5).
    final sets = tallyPlannedSets(
      training.exercises,
      plannedSets: (item) => plannedSetsOf(
        sets: item.sets,
        inBlock: item.blockId != null,
        blockRounds: item.blockRounds,
      ),
      isCompleted: (_) => false,
    ).total;
    final minutes = training.estimatedDurationMin;
    final figures = [
      if (training.exercises.isNotEmpty) ...[
        ExomFigure(
          value: formatFigure(context, training.exercises.length),
          label: l10n.homeFigureExercises(training.exercises.length),
        ),
        ExomFigure(
          value: formatFigure(context, sets),
          label: l10n.homeFigureSets(sets),
        ),
      ],
      if (minutes != null)
        ExomFigure(
          value: formatFigure(context, minutes),
          label: l10n.trainingsFigureMinutesApprox,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MergeSemantics(
          child: Semantics(
            button: true,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: Key('training-today-${training.id}'),
                onTap: () => _open(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (photo != null)
                      Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          HomeSessionPhoto(url: photo),
                          if (isToday)
                            PositionedDirectional(
                              start: 20,
                              bottom: 16,
                              // The kicker above already says «today».
                              child: ExcludeSemantics(
                                child: ExomMomentPill(l10n.todayLabel),
                              ),
                            ),
                        ],
                      ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        20,
                        16,
                        12,
                        16,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Origin of the detail page's title hero.
                                Hero(
                                  tag: 'training-${training.id}-title',
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: Semantics(
                                      label: training.name,
                                      excludeSemantics: true,
                                      child: Text(
                                        training.name.toUpperCase(),
                                        style: ExomType.headline2Section
                                            .copyWith(
                                              color: palette.textPrimary,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (types != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    types,
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
                          const SizedBox(width: 16),
                          Icon(
                            ExomIcons.next,
                            size: 22,
                            color: palette.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (figures.isNotEmpty) ExomFigureColumns(items: figures),
      ],
    );
  }
}

class _TodayTrainingRow extends StatelessWidget {
  const _TodayTrainingRow({
    required this.training,
    required this.selectedDate,
    required this.historyDate,
  });

  final TrainingEntity training;
  final String selectedDate;
  final String historyDate;

  @override
  Widget build(BuildContext context) {
    final day = DateTime.tryParse(selectedDate);
    return ExomRichRow(
      leading: day == null
          ? const ExomRowLeading.icon(ExomIcons.train)
          : _dateLeading(context, day),
      title: training.name,
      facts: _trainingFacts(
        context,
        minutes: training.estimatedDurationMin,
        exercises: training.exercises.length,
        types: training.types,
      ),
      onTap: () async {
        await context.push('/trainings/${training.id}?date=$selectedDate');
        if (context.mounted) {
          context.read<TrainingBloc>().add(
            TrainingsLoadRequested(
              date: selectedDate,
              historyDate: historyDate,
            ),
          );
        }
      },
    );
  }
}

class _TrainingHistoryRow extends StatelessWidget {
  const _TrainingHistoryRow({
    required this.entry,
    required this.selectedDate,
    required this.historyDate,
  });

  final TrainingHistoryEntity entry;
  final String selectedDate;
  final String historyDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entryDate = _storageDate(entry.date);
    return ExomRichRow(
      leading: _dateLeading(context, entry.date),
      title: entry.name,
      facts: _trainingFacts(
        context,
        minutes: entry.estimatedDurationMin,
        types: entry.types,
      ),
      status: entry.isCompleted
          ? _DoneStatus(label: l10n.trainingsHistoryDone)
          : ExomSyncStatus(state: ExomSyncState.pendiente, label: l10n.pending),
      onTap: () async {
        await context.push('/trainings/${entry.id}?date=$entryDate');
        if (context.mounted) {
          context.read<TrainingBloc>().add(
            TrainingsLoadRequested(
              date: selectedDate,
              historyDate: historyDate,
            ),
          );
        }
      },
    );
  }
}
