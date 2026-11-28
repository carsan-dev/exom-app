import 'dart:async';

import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/formatters/figure_format.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/domain/entities/home_week_marks.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/home/presentation/widgets/home_clock.dart';
import 'package:exom_app/features/home/presentation/widgets/home_row.dart';
import 'package:exom_app/core/widgets/home_session_photo.dart';
import 'package:exom_app/features/home/presentation/widgets/stats_row.dart';
import 'package:exom_app/features/home/presentation/widgets/today_diet_card.dart';
import 'package:exom_app/features/home/presentation/widgets/today_training_card.dart';
import 'package:exom_app/features/home/presentation/widgets/week_day_selector.dart';
import 'package:exom_app/l10n/app_localizations.dart';

/// Return to Inicio from «Sesión hecha» (E6a): reloads Inicio and, with the
/// identity of what the server confirmed, lets HomeBloc paint that session
/// done at once (owner decision 2026-11-26). Each navigation passes a new
/// instance; the same instance again (a route rebuild) does nothing.
class HomeCompletionRefresh {
  const HomeCompletionRefresh({this.trainingId, this.date, this.sessionStamp});

  /// The confirmed training.
  final String? trainingId;

  /// Its assignment date, `yyyy-mm-dd`.
  final String? date;

  /// The session (account and sign-in generation) that confirmed it.
  final String? sessionStamp;
}

/// Instances whose patch was applied already: a route rebuilt with the same
/// retained `extra` must not paint a completion that the reload may have
/// said undone since. Identity based, nothing persisted.
final Expando<bool> _consumedRefreshes = Expando<bool>('HomeCompletionRefresh');

/// Inicio, direction A «Sesión de hoy» (redesign L3), repainted in L5-E1
/// (sketch `e-migradas.html` «Inicio»).
///
/// The session is the first thing on screen; the only lime fill is the
/// action pinned above the bottom navigation (and the «Hoy» pill on the
/// session photo). Data comes only from HomeBloc.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.completionRefresh, this.now = DateTime.now});

  final HomeCompletionRefresh? completionRefresh;

  /// Clock for "today" in the presentation layer (decision D10). Tests pass a
  /// fixed clock; production uses the real one.
  final HomeNow now;

  /// Upper bound for keeping the pull-to-refresh indicator open while the
  /// reload runs. The bloc emits nothing when a refresh fails with content on
  /// screen, so the wait must end on its own.
  static const Duration refreshTimeout = Duration(seconds: 10);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Bumped when HomeBloc patched a confirmed completion: the view is built
  /// anew so every part of Inicio reads the patched content in its first
  /// frame (a mounted bloc builder would paint its previous state until the
  /// bloc's asynchronous emission reaches it).
  int _patches = 0;

  @override
  void initState() {
    super.initState();
    _refreshCompletion();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.completionRefresh, oldWidget.completionRefresh)) {
      _refreshCompletion();
    }
  }

  /// Called from [initState] and [didUpdateWidget], so the patch is in
  /// place before the build that follows. One reload either way.
  void _refreshCompletion() {
    final refresh = widget.completionRefresh;
    if (refresh == null) return;
    final bloc = context.read<HomeBloc>();
    final trainingId = refresh.trainingId;
    final date = refresh.date;
    final fresh = _consumedRefreshes[refresh] != true;
    _consumedRefreshes[refresh] = true;
    if (fresh &&
        trainingId != null &&
        date != null &&
        bloc.applyConfirmedCompletion(
          trainingId: trainingId,
          date: date,
          sessionStamp: refresh.sessionStamp,
        )) {
      _patches++;
    }
    bloc.add(const HomeLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return HomeClock(
      now: widget.now,
      child: _HomeView(key: ValueKey(_patches)),
    );
  }
}

/// Reloads [date] and completes when the bloc emits its next settled state
/// (loaded, rest day or error), or after [HomePage.refreshTimeout]. Subscribes
/// before dispatching so a fast emission is never missed. A failed reload with
/// content on screen arrives as that content flagged with its error: the wait
/// ends and Inicio shows the failure inline (D14-3), the data stays. Returns
/// the settled state, or `null` when the wait ended without one.
Future<HomeState?> _refreshHome(BuildContext context, DateTime date) async {
  final bloc = context.read<HomeBloc>();
  final settled = bloc.stream.firstWhere(
    (state) => state is! HomeLoading && state is! HomeInitial,
  );
  bloc.add(HomeLoadRequested(date: date));
  try {
    return await settled.timeout(HomePage.refreshTimeout);
  } on TimeoutException {
    // The reload may still land later; the indicator just stops waiting.
  } on StateError {
    // Bloc closed while waiting.
  }
  return null;
}

/// D14-3 (L5-E1): the last reload failed and the data on screen is the
/// previous one. Kept by the page until a load succeeds: a re-emission of
/// the same content (the week marks arriving) does not clear it.
class _ReloadFailure {
  const _ReloadFailure(this.raw, this.summary);

  final String raw;

  /// Content the failure was reported over.
  final HomeSummaryEntity summary;

  /// A connectivity failure (`ApiException` with status 0).
  bool get isOffline => raw.startsWith('ApiException(0)');
}

class _HomeView extends StatefulWidget {
  const _HomeView({super.key});

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  _ReloadFailure? _failure;

  static (HomeSummaryEntity?, String?) _contentOf(
    HomeState state,
  ) => switch (state) {
    HomeLoaded(:final summary, :final refreshError) => (summary, refreshError),
    HomeRestDay(:final summary, :final refreshError) => (summary, refreshError),
    _ => (null, null),
  };

  void _onState(BuildContext context, HomeState state) {
    final (summary, error) = _contentOf(state);
    final current = _failure;
    if (summary != null && error != null) {
      setState(() => _failure = _ReloadFailure(error, summary));
    } else if (current != null &&
        (summary == null || !identical(summary, current.summary))) {
      setState(() => _failure = null);
    }
  }

  /// Pull to refresh and «Reintentar»: a reload that settles without error
  /// clears the inline failure, even when it brings the same content back.
  Future<void> _reload(DateTime date) async {
    final settled = await _refreshHome(context, date);
    if (!mounted || settled == null || _failure == null) return;
    final (summary, error) = _contentOf(settled);
    if (summary != null && error == null) setState(() => _failure = null);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      listener: _onState,
      builder: (context, state) => _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, HomeState state) {
    if (state is HomeLoading || state is HomeInitial) {
      return const _HomeLoadingBody();
    }

    if (state is HomeError) {
      return ErrorWidget2(
        message: localizedErrorTextOf(
          context,
          state.message,
          fallback: (l10n) => l10n.homeLoadError,
        ),
        onRetry: () => context.read<HomeBloc>().add(const HomeLoadRequested()),
      );
    }

    if (state is HomeRestDay) {
      return _HomeContent(
        summary: state.summary,
        selectedDate: state.selectedDate,
        noPlan: state.dayPlan == HomeDayPlan.unassigned,
        failure: _failure,
        onReload: _reload,
      );
    }

    if (state is HomeLoaded) {
      return _HomeContent(
        summary: state.summary,
        selectedDate: state.selectedDate,
        noPlan: false,
        failure: _failure,
        onReload: _reload,
      );
    }

    return const SizedBox.shrink();
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.summary,
    required this.selectedDate,
    required this.noPlan,
    required this.failure,
    required this.onReload,
  });

  final HomeSummaryEntity summary;
  final DateTime selectedDate;

  /// L5-D27: the calendar says the day has no assignment.
  final bool noPlan;
  final _ReloadFailure? failure;
  final Future<void> Function(DateTime date) onReload;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final hasTraining = HomeSessionAction.appliesTo(summary);
    final reload = failure;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: palette.textPrimary,
            backgroundColor: palette.surface,
            onRefresh: () => onReload(selectedDate),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                if (reload != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: ExomInlineMessage(
                      kind: ExomMessageKind.pendiente,
                      title: reload.isOffline
                          ? l10n.homeOfflineSavedData
                          : localizedErrorTextOf(
                              context,
                              reload.raw,
                              fallback: (l10n) => l10n.homeLoadError,
                            ),
                      actionLabel: l10n.retry,
                      onAction: () => onReload(selectedDate),
                    ),
                  ),
                if (hasTraining)
                  TodayTrainingCard(
                    summary: summary,
                    selectedDate: selectedDate,
                  )
                else if (noPlan)
                  const HomeNoPlanHeader()
                else
                  HomeRestDayHeader(
                    selectedDate: selectedDate,
                    programWeek: summary.programWeek,
                  ),
                SizedBox(height: noPlan ? 0 : 24),
                if (noPlan)
                  const WeekDaySelector()
                else
                  _HomeWeekSection(featured: !hasTraining),
                const SizedBox(height: 24),
                HomeRowGroup(
                  children: [
                    TodayDietCard(summary: summary, selectedDate: selectedDate),
                    StatsRow(summary: summary, selectedDate: selectedDate),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (hasTraining)
          HomeSessionAction(summary: summary, selectedDate: selectedDate),
      ],
    );
  }
}

/// «Tu semana» (L5-E1): the week strip under its title and, when the calendar
/// marks of the clock's week are loaded, the count of done sessions derived
/// from them («N de M sesiones hechas»). On a day without training
/// ([featured]) the count is the protagonist: a 96 figure «N/M» in a feature
/// block (sketch «Inicio · día de descanso»). Without marks, no count.
class _HomeWeekSection extends StatelessWidget {
  const _HomeWeekSection({required this.featured});

  final bool featured;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final theme = Theme.of(context);
    final weekStart = WeekDaySelector.weekStartOf(HomeClock.todayOf(context));

    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        var marks = switch (state) {
          HomeLoaded(:final weekMarks) => weekMarks,
          HomeRestDay(:final weekMarks) => weekMarks,
          _ => null,
        };
        if (marks != null &&
            HomeWeekMarks.dayKey(marks.weekStart) !=
                HomeWeekMarks.dayKey(weekStart)) {
          marks = null;
        }
        final total = marks?.sessionCount ?? 0;
        final done = marks?.doneCount ?? 0;
        final secondary = theme.textTheme.bodyMedium?.copyWith(
          color: palette.textSecondary,
          fontSize: 14,
          height: 1.35,
        );

        if (featured) {
          return ExomFeatureBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: ExomKicker(l10n.homeWeekTitle),
                      ),
                      if (total > 0) ...[
                        const SizedBox(height: 12),
                        ExomNumeral(
                          value: formatFigure(context, done),
                          unit: '/${formatFigure(context, total)}',
                          side: Text(
                            l10n.homeWeekSessionsDoneFoot(total),
                            style: secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const WeekDaySelector(),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Semantics(
                    header: true,
                    label: l10n.homeWeekTitle,
                    excludeSemantics: true,
                    child: Text(
                      l10n.homeWeekTitle.toUpperCase(),
                      style: ExomType.section.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  if (total > 0)
                    Text(
                      l10n.homeWeekSessionsDone(done, total),
                      style: secondary,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const WeekDaySelector(),
          ],
        );
      },
    );
  }
}

/// First load (L5-E1, sketch «Inicio · carga»): skeletons with the final
/// shape (headline, photo, three figure columns, the week and two rows), no
/// footer until there is data. Announced once as one status node.
class _HomeLoadingBody extends StatelessWidget {
  const _HomeLoadingBody();

  @override
  Widget build(BuildContext context) {
    final raised = context.exomPalette.surfaceElevated;
    return Semantics(
      container: true,
      liveRegion: true,
      label: AppLocalizations.of(context).homeLoadingLabel,
      child: ExcludeSemantics(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: ExomSkeleton.headline(),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: ExomSkeleton.rule(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: HomeSessionPhoto.height,
              child: ColoredBox(color: raised),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ExomSkeleton.numeral(),
                          SizedBox(height: 8),
                          ExomSkeleton.rule(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: SizedBox(
                          height: 64,
                          child: ColoredBox(color: raised),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const ExomSkeleton.row(),
            const ExomSkeleton.row(),
          ],
        ),
      ),
    );
  }
}
