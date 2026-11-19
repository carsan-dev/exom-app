import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/utils/date_utils.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/features/home/domain/entities/home_summary_entity.dart';
import 'package:exom_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:exom_app/features/home/presentation/widgets/home_clock.dart';
import 'package:exom_app/features/home/presentation/widgets/home_headline.dart';
import 'package:exom_app/features/home/presentation/widgets/home_row.dart';
import 'package:exom_app/features/home/presentation/widgets/home_session_photo.dart';

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
      heroThumbnailUrl: summary.trainingThumbnailUrl,
      others: const [],
    );
  }

  final String? heroId;
  final String? heroName;
  final bool heroCompleted;

  /// L4b-D1: photo of the hero session (first exercise with a thumbnail).
  final String? heroThumbnailUrl;
  final List<HomeTrainingItemEntity> others;

  bool get hasTraining => heroId != null;
}

/// Session block of Inicio (sketch «A «Sesión de hoy»»): the session name as
/// the screen title, the date line, the quiet "done" status when it applies,
/// the fact line and, when the day has several trainings, the others as
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

  List<String> _facts(AppLocalizations l10n, HomeSessionPlan plan) {
    final inProgress =
        !summary.trainingCompleted && summary.exercisesCompleted > 0;
    return [
      if (plan.others.isNotEmpty)
        l10n.homeFactSessions(summary.trainings.length),
      if (summary.totalExercises > 0)
        inProgress
            ? l10n.homeFactExercisesProgress(
                summary.exercisesCompleted,
                summary.totalExercises,
              )
            : l10n.homeFactExercises(summary.totalExercises),
      // L4b-D5: planned sets of the day, circuits counted by rounds.
      if (summary.totalSets > 0) l10n.homeFactSets(summary.totalSets),
      if (inProgress && summary.remainingTrainingDurationMin != null)
        l10n.remainingTrainingMinutes(summary.remainingTrainingDurationMin!)
      else if (!summary.trainingCompleted &&
          summary.trainingDurationMin != null)
        l10n.homeFactDuration(summary.trainingDurationMin!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final plan = HomeSessionPlan.of(summary);
    if (!plan.hasTraining) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final facts = _facts(l10n, plan);
    final photoUrl = plan.heroThumbnailUrl;

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
            // L4b-I9: the photo runs edge to edge, so the 20 dp margin is
            // applied to the text blocks around it instead of the whole
            // column.
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
                  HomeSessionPhoto(url: photoUrl),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (plan.heroCompleted) ...[
                        const SizedBox(height: 12),
                        HomeDoneStatus(label: l10n.homeSessionDone),
                      ],
                      if (facts.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          facts.join(' · '),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: palette.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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
                icon: Icons.fitness_center,
                title: training.name,
                trailing: training.completed
                    ? HomeDoneStatus(label: l10n.homeSessionDone)
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

/// Header of a day without training (sketch «Día sin asignación»): title
/// «DESCANSO», date line, one line of copy and a secondary button to the
/// calendar. There is no lime action: the day has no next step.
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
          HomeTitle(l10n.homeRestDayTitle),
          const SizedBox(height: 12),
          HomeDateLine(date: selectedDate, programWeek: programWeek),
          const SizedBox(height: 12),
          Text(
            isToday ? l10n.homeRestDayToday : l10n.homeRestDayOther,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: palette.textPrimary,
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          ExomSecondaryButton(
            label: l10n.openCalendarButton,
            icon: Icons.calendar_today_outlined,
            onPressed: () => context.go('/calendar'),
          ),
        ],
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
        trailingIcon: Icons.arrow_forward,
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
