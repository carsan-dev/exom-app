import 'dart:async';

import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/home/presentation/widgets/home_clock.dart';
import 'package:exom_app/features/home/presentation/widgets/home_row.dart';
import 'package:exom_app/features/home/presentation/widgets/stats_row.dart';
import 'package:exom_app/features/home/presentation/widgets/today_diet_card.dart';
import 'package:exom_app/features/home/presentation/widgets/today_training_card.dart';
import 'package:exom_app/features/home/presentation/widgets/week_day_selector.dart';

class HomeCompletionRefresh {
  const HomeCompletionRefresh();
}

/// Inicio, direction A «Sesión de hoy» (redesign L3).
///
/// The session is the first thing on screen; the only lime element is the
/// action pinned above the bottom navigation. Data comes only from HomeBloc.
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

  void _refreshCompletion() {
    if (widget.completionRefresh != null) {
      context.read<HomeBloc>().add(const HomeLoadRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomeClock(now: widget.now, child: const _HomeView());
  }
}

/// Reloads [date] and completes when the bloc emits its next settled state
/// (loaded, rest day or error), or after [HomePage.refreshTimeout]. Subscribes
/// before dispatching so a fast emission is never missed. A failed reload with
/// content on screen arrives as that content flagged with its error: the wait
/// ends and the load error is shown, the data stays.
Future<void> _refreshHome(BuildContext context, DateTime date) async {
  final bloc = context.read<HomeBloc>();
  final settled = bloc.stream.firstWhere(
    (state) => state is! HomeLoading && state is! HomeInitial,
  );
  bloc.add(HomeLoadRequested(date: date));
  try {
    final state = await settled.timeout(HomePage.refreshTimeout);
    final refreshError = switch (state) {
      HomeLoaded(:final refreshError) => refreshError,
      HomeRestDay(:final refreshError) => refreshError,
      _ => null,
    };
    if (refreshError != null && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            localizedErrorTextOf(
              context,
              refreshError,
              fallback: (l10n) => l10n.homeLoadError,
            ),
          ),
        ),
      );
    }
  } on TimeoutException {
    // The reload may still land later; the indicator just stops waiting.
  } on StateError {
    // Bloc closed while waiting.
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
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
      );
    }

    if (state is HomeLoaded) {
      return _HomeContent(
        summary: state.summary,
        selectedDate: state.selectedDate,
      );
    }

    return const SizedBox.shrink();
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.summary, required this.selectedDate});

  final HomeSummaryEntity summary;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final hasTraining = HomeSessionAction.appliesTo(summary);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: palette.textPrimary,
            backgroundColor: palette.surface,
            onRefresh: () => _refreshHome(context, selectedDate),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                if (hasTraining)
                  TodayTrainingCard(
                    summary: summary,
                    selectedDate: selectedDate,
                  )
                else
                  HomeRestDayHeader(
                    selectedDate: selectedDate,
                    programWeek: summary.programWeek,
                  ),
                const SizedBox(height: 24),
                const WeekDaySelector(),
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

class _HomeLoadingBody extends StatelessWidget {
  const _HomeLoadingBody();

  static const _radius = BorderRadius.all(Radius.circular(4));

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const ShimmerCard(height: 42, width: 260, borderRadius: _radius),
        const SizedBox(height: 4),
        const ShimmerCard(height: 42, width: 180, borderRadius: _radius),
        const SizedBox(height: 12),
        const ShimmerCard(height: 16, width: 200, borderRadius: _radius),
        const SizedBox(height: 12),
        const ShimmerCard(height: 20, width: 240, borderRadius: _radius),
        const SizedBox(height: 24),
        Row(
          children: List.generate(
            7,
            (index) => const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 1),
                child: ShimmerCard(height: 64, borderRadius: _radius),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < 3; i++) ...[
          const ShimmerCard(height: 48, borderRadius: _radius),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
