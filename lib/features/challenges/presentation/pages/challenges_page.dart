import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/formatters/figure_format.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/challenges/domain/entities/achievement_entity.dart';
import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';
import 'package:exom_app/features/challenges/presentation/bloc/challenges_bloc.dart';
import 'package:exom_app/features/challenges/presentation/widgets/achievement_tiles.dart';
import 'package:exom_app/features/challenges/presentation/widgets/challenge_icons.dart';
import 'package:exom_app/features/challenges/presentation/widgets/challenge_milestone_mark.dart';
import 'package:exom_app/features/challenges/presentation/widgets/challenge_tick_rule.dart';
import 'package:exom_app/l10n/app_localizations.dart';

/// «Retos» tab (sketch b-cuenta.html «B4 · Retos», L5-B2): the streak as the
/// milestone with bands at ±12°, the main goal as a figure with its 50-mark
/// rule, the weekly challenges numbered with their percentage and rule, and
/// the achievements as flat tiles. «Ver todos» opens every achievement of the
/// catalog in a straight EXOM sheet, which closes when the router location
/// changes (CC 11). No behaviour changes: same bloc, same data, same actions.
class ChallengesPage extends StatelessWidget {
  const ChallengesPage({super.key});

  Future<void> _refreshChallenges(BuildContext context) async {
    context.read<ChallengesBloc>().add(const ChallengesLoadRequested());
  }

  Widget _buildErrorState(BuildContext context, ChallengesError state) {
    void retry() =>
        context.read<ChallengesBloc>().add(const ChallengesLoadRequested());

    final apiException = state.apiException;
    if (apiException?.isNetworkError == true) {
      return NoConnectionWidget(onRetry: retry);
    }
    if (apiException?.isServerError == true) {
      return ServerErrorWidget(
        errorCode: apiException!.statusCode.toString(),
        onRetry: retry,
      );
    }
    return ErrorWidget2(
      message: apiException != null
          ? localizedApiError(context, apiException)
          : AppLocalizations.of(context).challengesLoadError,
      onRetry: retry,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          GetIt.I<ChallengesBloc>()..add(const ChallengesLoadRequested()),
      child: BlocBuilder<ChallengesBloc, ChallengesState>(
        builder: (context, state) {
          if (state is ChallengesInitial || state is ChallengesLoading) {
            return const _ChallengesLoadingContent();
          }
          if (state is ChallengesError) {
            return _buildErrorState(context, state);
          }
          if (state is ChallengesLoaded) {
            return _ChallengesContent(
              streakDays: state.streakDays,
              mainGoals: state.mainGoals,
              weeklyChallenges: state.weeklyChallenges,
              achievements: state.achievements,
              achievementCatalog: state.achievementCatalog,
              alwaysShowAchievements: false,
              onRefresh: () => _refreshChallenges(context),
            );
          }
          if (state is ChallengesEmpty) {
            return _ChallengesContent(
              streakDays: state.streakDays,
              mainGoals: const [],
              weeklyChallenges: const [],
              achievements: state.achievements,
              achievementCatalog: state.achievementCatalog,
              alwaysShowAchievements: true,
              onRefresh: () => _refreshChallenges(context),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

/// Loading: skeletons with the final shape (numeral, headline, rule, rows).
class _ChallengesLoadingContent extends StatelessWidget {
  const _ChallengesLoadingContent();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: ExomSpacing.xxxl),
      children: const [
        _ScreenTitle(),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: ExomSkeleton.numeral(),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: ExomSkeleton.headline(),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: ExomSkeleton.rule(),
        ),
        SizedBox(height: ExomSpacing.xxl),
        ExomSkeleton.row(),
        ExomSkeleton.row(),
        ExomSkeleton.row(),
      ],
    );
  }
}

/// Screen headline (sketch `.t1`), painted upper case; one header node with
/// the original text.
class _ScreenTitle extends StatelessWidget {
  const _ScreenTitle();

  @override
  Widget build(BuildContext context) {
    final title = AppLocalizations.of(context).challengesTitle;
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

/// Section title (sketch `.t2`): Barlow 800 22 painted upper case, header.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: text,
      excludeSemantics: true,
      child: Text(
        text.toUpperCase(),
        style: ExomType.section.copyWith(
          color: context.exomPalette.textPrimary,
        ),
      ),
    );
  }
}

TextStyle _bodyStyle(
  Color color, {
  double size = 14,
  FontWeight weight = FontWeight.w400,
}) => TextStyle(
  fontFamily: AppTheme.bodyFontFamily,
  fontSize: size,
  fontWeight: weight,
  height: 1.35,
  color: color,
);

class _ChallengesContent extends StatelessWidget {
  const _ChallengesContent({
    required this.streakDays,
    required this.mainGoals,
    required this.weeklyChallenges,
    required this.achievements,
    required this.achievementCatalog,
    required this.alwaysShowAchievements,
    required this.onRefresh,
  });

  final int streakDays;
  final List<ChallengeEntity> mainGoals;
  final List<ChallengeEntity> weeklyChallenges;
  final List<AchievementEntity> achievements;
  final List<AchievementEntity> achievementCatalog;

  /// The empty state always shows the achievements band (as before).
  final bool alwaysShowAchievements;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final showCatalogButton = achievementCatalog.isNotEmpty;
    final noChallenges = mainGoals.isEmpty && weeklyChallenges.isEmpty;
    final showAchievements =
        alwaysShowAchievements || achievements.isNotEmpty || showCatalogButton;

    return RefreshIndicator(
      color: palette.data,
      backgroundColor: palette.surface,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: ExomSpacing.xxl),
        children: [
          const _ScreenTitle(),
          const SizedBox(height: ExomSpacing.lg),
          _StreakSection(days: streakDays),
          if (noChallenges) const _EmptyChallenges(),
          for (final goal in mainGoals) ...[
            const SizedBox(height: ExomSpacing.xxxl),
            _MainGoalBlock(challenge: goal),
          ],
          if (weeklyChallenges.isNotEmpty) ...[
            const SizedBox(height: ExomSpacing.xxxl),
            _WeeklyChallenges(challenges: weeklyChallenges),
          ],
          if (showAchievements) ...[
            const SizedBox(height: ExomSpacing.xxxl),
            _AchievementsBand(
              achievements: achievements,
              onViewAll: showCatalogButton
                  ? () => _showAchievementsBoard(
                      context,
                      catalog: achievementCatalog,
                      unlockedIds: achievements.map((a) => a.id).toSet(),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// Streak (sketch `.x-mark` + kicker + «Días / seguidos.»): the milestone of
/// the screen, once.
class _StreakSection extends StatelessWidget {
  const _StreakSection({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = formatFigure(context, days);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChallengeMilestoneMark(
          value: value,
          semanticsLabel: '$value ${l10n.days}',
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExomKicker(l10n.streak, icon: ChallengeIcons.streak),
              const SizedBox(height: ExomSpacing.md),
              ExomTwoLineHeadline(
                first: l10n.challengesStreakHeadlineFirst,
                second: l10n.challengesStreakHeadlineSecond,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// No active challenges (sketch `.x-empty`): flat, no card and no icon.
class _EmptyChallenges extends StatelessWidget {
  const _EmptyChallenges();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l10n.noActiveChallenges),
          const SizedBox(height: 14),
          Text(
            l10n.noActiveChallengesMessage,
            style: _bodyStyle(palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

String _figures(BuildContext context, ChallengeEntity challenge, String sep) =>
    '${formatFigure(context, challenge.currentValue)}$sep'
    '${formatFigure(context, challenge.targetValue)} ${challenge.unit}';

int _percent(ChallengeEntity challenge) => (challenge.progress * 100).toInt();

/// Main goal (sketch `.x-feat`): kicker, title, the percentage at 96 with the
/// figures and the deadline beside it, and the 50-mark rule with its scale.
class _MainGoalBlock extends StatelessWidget {
  const _MainGoalBlock({required this.challenge});

  final ChallengeEntity challenge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final figures = _figures(context, challenge, ' / ');
    final deadline = challenge.deadline;
    final scaleStyle = _bodyStyle(palette.textSecondary, size: 13);
    return ExomFeatureBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExomKicker(l10n.mainGoalSection),
                const SizedBox(height: ExomSpacing.sm),
                _SectionTitle(challenge.title),
                if (challenge.description.isNotEmpty) ...[
                  const SizedBox(height: ExomSpacing.sm),
                  Text(
                    challenge.description,
                    style: _bodyStyle(palette.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: ExomSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ExomNumeral(
              value: formatFigure(context, _percent(challenge)),
              unit: '%',
              side: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    figures,
                    style: ExomType.headline2Section.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  if (deadline != null) ...[
                    const SizedBox(height: ExomSpacing.xs),
                    Text(
                      '${l10n.challengeDeadlineLabel}: ${DateFormat('dd MMM yyyy', Localizations.localeOf(context).languageCode).format(deadline)}',
                      style: _bodyStyle(palette.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: ExomSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChallengeTickRule(
                  value: challenge.progress,
                  semanticsLabel: figures,
                ),
                const SizedBox(height: 6),
                ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatFigure(context, 0), style: scaleStyle),
                      const SizedBox(width: ExomSpacing.md),
                      Text(
                        formatFigure(context, challenge.targetValue / 2),
                        style: scaleStyle,
                      ),
                      const SizedBox(width: ExomSpacing.md),
                      Flexible(
                        child: Text(
                          '${formatFigure(context, challenge.targetValue)} ${challenge.unit}',
                          textAlign: TextAlign.end,
                          style: scaleStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Weekly challenges (sketch «Tu semana. / También cuenta.» + `.x-rows`): each
/// challenge numbered 01, 02, 03… with its figures, deadline, percentage (or
/// the «hecha» mark) and rule. The model has no category to group them by, so
/// the numbering follows the challenges.
class _WeeklyChallenges extends StatelessWidget {
  const _WeeklyChallenges({required this.challenges});

  final List<ChallengeEntity> challenges;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ExomTwoLineHeadline(
              first: l10n.challengesWeekHeadlineFirst,
              second: l10n.challengesWeekHeadlineSecond,
            ),
          ),
        ),
        const SizedBox(height: ExomSpacing.lg),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: palette.borderSoft,
                width: ExomRule.hairline,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < challenges.length; i++) ...[
                ExomNumberedSectionHeader(n: i + 1, title: challenges[i].title),
                _ChallengeMeter(challenge: challenges[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One weekly challenge (sketch `.x-meter`).
class _ChallengeMeter extends StatelessWidget {
  const _ChallengeMeter({required this.challenge});

  final ChallengeEntity challenge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final deadline = challenge.deadline;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A wrap, not a row: with very large text on a narrow screen the
          // figures and the percentage or the «Completado» mark go on two
          // lines instead of splitting a word of the figures.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: ExomSpacing.md,
            runSpacing: ExomSpacing.sm,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _figures(context, challenge, '/'),
                    style: _bodyStyle(
                      palette.textPrimary,
                      size: 16,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (deadline != null) ...[
                    const SizedBox(height: ExomSpacing.xs),
                    Text(
                      '${l10n.challengeUntilLabel} ${DateFormat('dd MMM', Localizations.localeOf(context).languageCode).format(deadline)}',
                      style: _bodyStyle(palette.textSecondary),
                    ),
                  ],
                ],
              ),
              if (challenge.isCompleted)
                const _DoneMark()
              else
                _Percent(value: _percent(challenge)),
            ],
          ),
          const SizedBox(height: 10),
          ExomProgressRule(value: challenge.progress),
        ],
      ),
    );
  }
}

/// Percentage of a weekly challenge (sketch `.x-pct`): Barlow 800 36 in the
/// data colour with a half-size «%».
class _Percent extends StatelessWidget {
  const _Percent({required this.value});

  final int value;

  static const double size = 36;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: formatFigure(context, value)),
          const TextSpan(
            text: '%',
            style: TextStyle(fontSize: size / 2),
          ),
        ],
      ),
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontFamily: AppTheme.displayFontFamily,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 0.85,
        color: context.exomPalette.data,
      ),
    );
  }
}

/// «Hecha» of the client (sketch `.x-ok`, rule D19): check in the data colour
/// and the text in the text colour.
class _DoneMark extends StatelessWidget {
  const _DoneMark();

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ChallengeIcons.done, size: 16, color: palette.data),
        const SizedBox(width: 6),
        Text(
          AppLocalizations.of(context).completed,
          style: _bodyStyle(palette.textPrimary),
        ),
      ],
    );
  }
}

/// Unlocked achievements (sketch `.x-band` + `.x-tiles`) with «Ver todos».
class _AchievementsBand extends StatelessWidget {
  const _AchievementsBand({required this.achievements, this.onViewAll});

  final List<AchievementEntity> achievements;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final viewAll = onViewAll;
    return ExomBand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: ExomSpacing.md,
              children: [
                _SectionTitle(l10n.unlockedAchievementsSection),
                if (viewAll != null)
                  ExomTextLink(label: l10n.viewAllButton, onTap: viewAll),
              ],
            ),
          ),
          const SizedBox(height: ExomSpacing.sm),
          if (achievements.isNotEmpty)
            AchievementTiles(
              items: [
                for (final achievement in achievements)
                  AchievementTileData(name: achievement.name, unlocked: true),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.noUnlockedAchievementsTitle,
                    style: _bodyStyle(
                      palette.textPrimary,
                      size: 16,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: ExomSpacing.xs),
                  Text(
                    l10n.noUnlockedAchievementsMessage,
                    style: _bodyStyle(palette.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Every achievement of the catalog in a straight EXOM sheet (was
/// `showPageAwareModalBottomSheet`). Colours are read inside the sheet from
/// the live theme, so a theme change while it is open repaints it (the
/// captured-colour defect fixed in E7). It closes with «Cerrar», back, the
/// scrim, a drag, or when the router location changes (CC 11).
Future<void> _showAchievementsBoard(
  BuildContext context, {
  required List<AchievementEntity> catalog,
  required Set<String> unlockedIds,
}) {
  return showExomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) =>
        _AchievementsBoard(catalog: catalog, unlockedIds: unlockedIds),
    actions: [
      Builder(
        builder: (sheetContext) => ExomQuietButton(
          label: MaterialLocalizations.of(sheetContext).closeButtonLabel,
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    ],
  );
}

class _AchievementsBoard extends StatelessWidget {
  const _AchievementsBoard({required this.catalog, required this.unlockedIds});

  final List<AchievementEntity> catalog;
  final Set<String> unlockedIds;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final title = l10n.achievementBoardTitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: 18),
          ExomNumeral(
            value: formatFigure(context, unlockedIds.length),
            unit: '/${formatFigure(context, catalog.length)}',
          ),
          const SizedBox(height: 18),
          AchievementTiles(
            padding: EdgeInsets.zero,
            items: [
              for (final achievement in catalog)
                AchievementTileData(
                  name: achievement.name,
                  description: achievement.description,
                  unlocked: unlockedIds.contains(achievement.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
