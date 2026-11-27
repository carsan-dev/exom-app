import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/utils/date_utils.dart';
import 'package:exom_app/core/formatters/figure_format.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/home/presentation/widgets/home_clock.dart';
import 'package:exom_app/features/home/presentation/widgets/home_headline.dart';
import 'package:exom_app/features/home/presentation/widgets/home_row.dart';
import 'package:exom_app/core/widgets/home_session_photo.dart';

/// Opens a training of the selected day and reloads Home on return, exactly
/// as the previous card did: `/trainings/<id>?date=<assignmentDate>`.
Future<void> openHomeTraining(
  BuildContext context, {
  required String trainingId,
  required DateTime selectedDate,
}) async {
  final assignmentDate = AppDateUtils.toIso(selectedDate);
  await context.push('/trainings/$trainingId?date=$assignmentDate');
  if (context.mounted) {
    context.read<HomeBloc>().add(HomeLoadRequested(date: selectedDate));
  }
}

/// Which session of the day leads Inicio, derived only from the summary that
/// HomeBloc already exposes.
///
/// The hero is the first unfinished training of the day (or the first one if
/// every training is done); the rest are listed below it. Summaries without
/// the `trainings` list fall back to `trainingId`/`trainingName`.
class HomeSessionPlan {
  const HomeSessionPlan._({
    required this.heroId,
    required this.heroName,
    required this.heroCompleted,
    required this.heroUnfinished,
    required this.heroThumbnailUrl,
    required this.others,
  });

  factory HomeSessionPlan.of(HomeSummaryEntity summary) {
    if (summary.trainings.isNotEmpty) {
      final hero = summary.trainings.firstWhere(
        (training) => !training.completed,
        orElse: () => summary.trainings.first,
      );
      return HomeSessionPlan._(
        heroId: hero.id,
        heroName: hero.name,
        heroCompleted: hero.completed,
        heroUnfinished: hero.unfinished,
        heroThumbnailUrl: hero.thumbnailUrl,
        others: summary.trainings
            .where((training) => !identical(training, hero))
            .toList(growable: false),
      );
    }
    return HomeSessionPlan._(
      heroId: summary.trainingId,
      heroName: summary.trainingName,
      heroCompleted: summary.trainingCompleted,
      heroUnfinished:
          !summary.trainingCompleted &&
          summary.totalExercises > 0 &&
          summary.exercisesCompleted >= summary.totalExercises,
      heroThumbnailUrl: summary.trainingThumbnailUrl,
      others: const [],
    );
  }

  final String? heroId;
  final String? heroName;
  final bool heroCompleted;

  /// L5-D49 O5: every exercise of the hero is marked but «Terminar sesión»
  /// was not pressed: «Sin terminar» instead of «Hecha».
  final bool heroUnfinished;

  /// L4b-D1: photo of the hero session (first exercise with a thumbnail).
  final String? heroThumbnailUrl;
  final List<HomeTrainingItemEntity> others;

  bool get hasTraining => heroId != null;
}

/// Session block of Inicio (L5-E1, sketch `e-migradas.html` «Inicio»): the
/// session name as the screen title, the date line, the photo with the «Hoy»
/// pill on today, the quiet «Hecha» status when it applies and the figures of
/// the session in numbered columns (exercises, sets, minutes; «2/6» and the
/// minutes left with a 4 dp progress rule while in progress). When the day
/// has several trainings, a kicker counts them and the others follow as
/// rule-separated rows. Tapping the block opens the hero session.
///
/// Renders nothing when the day has no training.
class TodayTrainingCard extends StatelessWidget {
  const TodayTrainingCard({
    super.key,
    required this.summary,
    required this.selectedDate,
  });

  final HomeSummaryEntity summary;
  final DateTime selectedDate;

  bool get _inProgress =>
      !summary.trainingCompleted && summary.exercisesCompleted > 0;

  /// Figures of the session (L4b-D5 sets, circuits counted by rounds), each
  /// read as the fact line it replaces («6 ejercicios», «22 series»…).
  List<ExomFigure> _figures(BuildContext context, AppLocalizations l10n) {
    String figure(int value) => formatFigure(context, value);
    final inProgress = _inProgress;
    final remaining = summary.remainingTrainingDurationMin;
    final duration = summary.trainingDurationMin;
    // L5-D49 O5 r2: a «Sin terminar» hero with nothing else left to do
    // shows no minutes: neither «≈0» left nor the planned duration.
    final nothingLeft =
        HomeSessionPlan.of(summary).heroUnfinished && (remaining ?? 0) == 0;
    return [
      if (summary.totalExercises > 0)
        inProgress
            ? ExomFigure(
                value: figure(summary.exercisesCompleted),
                unit: '/${figure(summary.totalExercises)}',
                label: l10n.homeFigureExercises(summary.totalExercises),
                semanticsLabel: l10n.homeFactExercisesProgress(
                  summary.exercisesCompleted,
                  summary.totalExercises,
                ),
              )
            : ExomFigure(
                value: figure(summary.totalExercises),
                label: l10n.homeFigureExercises(summary.totalExercises),
                semanticsLabel: l10n.homeFactExercises(summary.totalExercises),
              ),
      if (summary.totalSets > 0)
        ExomFigure(
          value: figure(summary.totalSets),
          label: l10n.homeFigureSets(summary.totalSets),
          semanticsLabel: l10n.homeFactSets(summary.totalSets),
        ),
      if (!nothingLeft && inProgress && remaining != null)
        ExomFigure(
          value: '≈${figure(remaining)}',
          label: l10n.homeFigureMinutesLeft,
          semanticsLabel: l10n.remainingTrainingMinutes(remaining),
        )
      else if (!nothingLeft && !summary.trainingCompleted && duration != null)
        ExomFigure(
          value: figure(duration),
          label: l10n.homeFigureMinutes,
          semanticsLabel: l10n.homeFactDuration(duration),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final plan = HomeSessionPlan.of(summary);
    if (!plan.hasTraining) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final figures = _figures(context, l10n);
    final photoUrl = plan.heroThumbnailUrl;
    final isToday = HomeClock.isToday(context, selectedDate);
    final total = summary.totalExercises;

    final hero = MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => openHomeTraining(
              context,
              trainingId: plan.heroId!,
              selectedDate: selectedDate,
            ),
            // L4b-I9: the photo and the figure columns run edge to edge, so
            // the 20 dp margin is applied to the text blocks around them
            // instead of the whole column.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HomeTitle(plan.heroName ?? l10n.trainingUntitledLabel),
                      const SizedBox(height: 12),
                      HomeDateLine(
                        date: selectedDate,
                        programWeek: summary.programWeek,
                        programDay: summary.programDay,
                      ),
                    ],
                  ),
                ),
                if (photoUrl != null && photoUrl.isNotEmpty)
                  HomeSessionPhoto(
                    url: photoUrl,
                    pill: isToday ? l10n.todayLabel : null,
                  ),
                if (plan.heroCompleted ||
                    plan.heroUnfinished ||
                    plan.others.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (plan.others.isNotEmpty)
                          ExomKicker(
                            l10n.homeFactSessions(summary.trainings.length),
                          ),
                        if (plan.heroCompleted)
                          HomeDoneStatus(label: l10n.homeSessionDone)
                        else if (plan.heroUnfinished)
                          _UnfinishedStatus(label: l10n.homeSessionUnfinished),
                      ],
                    ),
                  ),
                if (figures.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ExomFigureColumns(items: figures),
                ],
                if (_inProgress && total > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: ExomProgressRule(
                      value: summary.exercisesCompleted / total,
                      thickness: ExomRule.bar,
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );

    if (plan.others.isEmpty) return hero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hero,
        const SizedBox(height: 16),
        HomeRowGroup(
          children: [
            for (final training in plan.others)
              HomeRow(
                icon: ExomIcons.train,
                title: training.name,
                trailing: training.completed
                    ? HomeDoneStatus(label: l10n.homeSessionDone)
                    : training.unfinished
                    ? _UnfinishedStatus(label: l10n.homeSessionUnfinished)
                    : null,
                onTap: () => openHomeTraining(
                  context,
                  trainingId: training.id,
                  selectedDate: selectedDate,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// L5-D49 O5: «Sin terminar», a session with every exercise marked whose
/// «Terminar sesión» is missing. Same status line as a local session pending
/// to be finished (`trainingPendingFinalize`): icon and text, never colour
/// alone.
class _UnfinishedStatus extends StatelessWidget {
  const _UnfinishedStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) =>
      ExomSyncStatus(state: ExomSyncState.pendiente, label: label);
}

/// Header of a day without training (L5-E1, sketch «Inicio · día de
/// descanso»): the two-line headline «Descanso. / También cuenta.», the date
/// line, one line of copy and a secondary button to the calendar. There is no
/// lime action: the day has no next step. It is also the single state of a
/// day the calendar has not described yet (Q11).
class HomeRestDayHeader extends StatelessWidget {
  const HomeRestDayHeader({
    super.key,
    required this.selectedDate,
    this.programWeek,
  });

  final DateTime selectedDate;

  /// L4b-I5: program week of the day; the date line shows it without a day.
  final int? programWeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final isToday = HomeClock.isToday(context, selectedDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExomTwoLineHeadline(
            first: l10n.homeRestHeadlineFirst,
            second: l10n.homeRestHeadlineSecond,
            size: ExomHeadlineSize.screen,
          ),
          const SizedBox(height: 12),
          HomeDateLine(date: selectedDate, programWeek: programWeek),
          const SizedBox(height: 16),
          Text(
            isToday ? l10n.homeRestDayToday : l10n.homeRestDayOther,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: palette.textPrimary,
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          ExomSecondaryButton(
            label: l10n.openCalendarButton,
            icon: ExomIcons.calendar,
            onPressed: () => context.go('/calendar'),
          ),
        ],
      ),
    );
  }
}

/// Day without assignment (L5-E1, L5-D27; sketch «Inicio · sin asignación»):
/// «Sin plan. / Todavía.», the existing «Tu entrenador aún no te ha asignado un
/// plan», when the plan will show and a secondary button to the calendar.
/// Shown only when the calendar of the week says the day has no training, no
/// diet and no rest day.
class HomeNoPlanHeader extends StatelessWidget {
  const HomeNoPlanHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ExomEmptyState(
      first: l10n.trainingsNoPlanFirst,
      second: l10n.trainingsNoPlanSecond,
      lead: l10n.noTrainingsAssignedSubtitle,
      body: l10n.homeNoPlanBody,
      action: ExomSecondaryButton(
        label: l10n.openCalendarButton,
        icon: ExomIcons.calendar,
        onPressed: () => context.go('/calendar'),
      ),
    );
  }
}

/// Action pinned above the bottom navigation.
///
/// Today with an unfinished session: the single lime [ExomPrimaryButton]
/// («Empezar sesión», or «Continuar sesión» when the summary reports completed
/// exercises of a single training). A finished day, or a past or future day,
/// gets the secondary «Ver entrenamiento» instead: lime only marks today's
/// next step. Every variant opens the hero session like tapping it.
///
/// Renders nothing when the day has no training.
class HomeSessionAction extends StatelessWidget {
  const HomeSessionAction({
    super.key,
    required this.summary,
    required this.selectedDate,
  });

  final HomeSummaryEntity summary;
  final DateTime selectedDate;

  /// Whether this summary/date pair shows any action at all.
  static bool appliesTo(HomeSummaryEntity summary) =>
      HomeSessionPlan.of(summary).hasTraining;

  @override
  Widget build(BuildContext context) {
    final plan = HomeSessionPlan.of(summary);
    if (!plan.hasTraining) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final isToday = HomeClock.isToday(context, selectedDate);

    void open() {
      HapticFeedback.selectionClick();
      openHomeTraining(
        context,
        trainingId: plan.heroId!,
        selectedDate: selectedDate,
      );
    }

    final Widget button;
    if (isToday && !plan.heroCompleted) {
      final continues =
          plan.others.isEmpty &&
          !summary.trainingCompleted &&
          summary.exercisesCompleted > 0;
      button = ExomPrimaryButton(
        label: continues
            ? l10n.homeContinueSessionButton
            : l10n.homeStartSessionButton,
        trailingIcon: ExomIcons.forward,
        onPressed: open,
      );
    } else {
      button = ExomSecondaryButton(
        label: l10n.viewTrainingButton,
        onPressed: open,
      );
    }

    return ExomPinnedFooter(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: button,
    );
  }
}
