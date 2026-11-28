import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/formatters/figure_format.dart';
import 'package:exom_app/core/formatters/unit_converters.dart';
import 'package:exom_app/core/formatters/unit_formatters.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_index_list.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_line_chart.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_numeral_stepper.dart';
import 'package:exom_app/core/widgets/exom_operation_bar.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/core/widgets/media_picker_error_dialog.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// Keeps a value and its unit on one line.
const String _nbsp = '\u00A0';

/// Perfil (L5-B4, sketch `b-cuenta.html` «B1 · Perfil»): identity, two-line
/// headline, the weight as protagonist in the featured block, the flat muscle
/// mass and sleep figures (D14-7), the numbered index and the body data band.
///
/// EX-Q7 (L5-D28): a [ProfileError] that keeps the profile is painted as the
/// loaded page with the error in line; without a profile the error takes the
/// whole screen. The bloc is created here for this page only (a factory in
/// `injection_container.dart`), so a kept profile never outlives the page.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return ExomStaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Sketch B1: the bar only carries «Volver»; the name is the title.
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: Icon(ExomIcons.back, color: palette.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: BlocProvider(
          create: (_) => sl<ProfileBloc>()..add(const ProfileLoadRequested()),
          child: const _ProfileView(),
        ),
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        void retry() =>
            context.read<ProfileBloc>().add(const ProfileLoadRequested());
        String errorText(String message) => localizedErrorTextOf(
          context,
          message,
          fallback: (l10n) => l10n.profileOperationError,
        );
        return switch (state) {
          ProfileLoaded() => _ProfileContent(
            profile: state.profile,
            weightHistory: state.weightHistory,
            latestMetric: state.latestMetric,
            editable: true,
          ),
          ProfileAvatarUploading() => _ProfileContent(
            profile: state.profile,
            weightHistory: state.weightHistory,
            latestMetric: state.latestMetric,
            isUploadingAvatar: true,
          ),
          ProfileError(profile: final ProfileEntity profile) => _ProfileContent(
            profile: profile,
            weightHistory: state.weightHistory,
            latestMetric: state.latestMetric,
            errorMessage: errorText(state.message),
            onRetry: retry,
          ),
          ProfileError() => _ProfileFullError(
            message: errorText(state.message),
            onRetry: retry,
          ),
          _ => const _ProfileSkeleton(),
        };
      },
    );
  }
}

double _bottomSpacing(BuildContext context) =>
    math.max(40.0, 16.0 + MediaQuery.viewPaddingOf(context).bottom);

TextStyle _secondaryStyle(BuildContext context) => TextStyle(
  fontFamily: AppTheme.bodyFontFamily,
  fontSize: 14,
  height: 1.35,
  color: context.exomPalette.textSecondary,
);

/// Opens the metrics page and reloads the profile on return (as before).
Future<void> _openMetrics(BuildContext context) async {
  await context.push('/profile/metrics');
  if (context.mounted) {
    context.read<ProfileBloc>().add(const ProfileLoadRequested());
  }
}

/// Two equal columns with a hairline between them and rules above and below
/// (`.x-cols`). The middle rule is a positioned line over the full height of
/// the taller column: no intrinsic sizing (the bars and skeletons inside use
/// LayoutBuilder) and no Table (its cells confuse the semantics geometry).
Widget _twoColumns(Widget start, Widget end, BorderSide rule) => DecoratedBox(
  decoration: BoxDecoration(
    border: Border(top: rule, bottom: rule),
  ),
  child: LayoutBuilder(
    builder: (context, constraints) => Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: start),
            Expanded(child: end),
          ],
        ),
        PositionedDirectional(
          start: constraints.maxWidth / 2,
          top: 0,
          bottom: 0,
          width: rule.width,
          child: ColoredBox(color: rule.color),
        ),
      ],
    ),
  ),
);

// ── Loading ─────────────────────────────────────────────────────────────────

/// Skeletons with the final shape (sketch «Perfil · carga»): identity,
/// headline, the featured block with numeral and rule, two figure columns and
/// three rows.
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final rule = BorderSide(
      color: context.exomPalette.borderSoft,
      width: ExomRule.hairline,
    );
    Widget column({required bool first}) => Padding(
      padding: EdgeInsetsDirectional.fromSTEB(first ? 20 : 14, 14, 12, 16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExomSkeleton.numeral(),
          SizedBox(height: ExomSpacing.sm),
          ExomSkeleton.rule(),
        ],
      ),
    );
    return ListView(
      key: const Key('profile-skeleton'),
      padding: EdgeInsets.only(bottom: _bottomSpacing(context)),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: ExomSkeleton.headline(),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: ExomSkeleton.headline(),
        ),
        const SizedBox(height: ExomSpacing.lg),
        const ExomFeatureBlock(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExomSkeleton.numeral(),
                SizedBox(height: ExomSpacing.lg),
                ExomSkeleton.rule(),
              ],
            ),
          ),
        ),
        _twoColumns(column(first: true), column(first: false), rule),
        const SizedBox(height: ExomSpacing.xxl),
        const ExomSkeleton.row(),
        const ExomSkeleton.row(),
        const ExomSkeleton.row(),
      ],
    );
  }
}

// ── Full-screen error (first load) ──────────────────────────────────────────

class _ProfileFullError extends StatelessWidget {
  const _ProfileFullError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('profile-full-error'),
      padding: EdgeInsets.fromLTRB(20, 24, 20, _bottomSpacing(context)),
      children: [
        _ErrorBlock(
          message: message,
          onRetry: onRetry,
          messageKey: const Key('profile-full-error-message'),
        ),
      ],
    );
  }
}

/// Error with «Reintentar» (sketch «Perfil · error»: rule, icon and text,
/// then a secondary button).
class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.message,
    required this.onRetry,
    required this.messageKey,
  });

  final String message;
  final VoidCallback onRetry;
  final Key messageKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExomInlineMessage(
          key: messageKey,
          kind: ExomMessageKind.error,
          title: message,
        ),
        const SizedBox(height: ExomSpacing.md),
        ExomSecondaryButton(
          key: const Key('profile-retry'),
          label: AppLocalizations.of(context).retry,
          icon: ExomIcons.retry,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

// ── Content ─────────────────────────────────────────────────────────────────

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.weightHistory,
    required this.latestMetric,
    this.isUploadingAvatar = false,
    this.editable = false,
    this.errorMessage,
    this.onRetry,
  });

  final ProfileEntity profile;
  final List<BodyMetricEntity> weightHistory;
  final BodyMetricEntity? latestMetric;
  final bool isUploadingAvatar;

  /// Avatar and goal can change only from a loaded profile: the bloc ignores
  /// a goal update in any other state.
  final bool editable;

  /// EX-Q7: error painted in line, the profile stays visible.
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final entries = _weightEntries(weightHistory);
    final error = errorMessage;
    final showHeadline = error != null || entries.isNotEmpty;

    return RefreshIndicator(
      color: palette.textPrimary,
      backgroundColor: palette.surface,
      onRefresh: () async {
        context.read<ProfileBloc>().add(const ProfileLoadRequested());
      },
      child: ListView(
        padding: EdgeInsets.only(bottom: _bottomSpacing(context)),
        children: [
          _Identity(
            profile: profile,
            isUploadingAvatar: isUploadingAvatar,
            editable: editable,
          ),
          if (isUploadingAvatar)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ExomOperationBar(),
            ),
          if (showHeadline)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: ExomTwoLineHeadline(
                first: l10n.profileHeadlineFirst,
                second: l10n.profileHeadlineSecond,
              ),
            ),
          SizedBox(height: showHeadline ? ExomSpacing.lg : ExomSpacing.xl),
          _WeightFeature(
            entries: entries,
            errorMessage: error,
            onRetry: onRetry,
          ),
          _FlatIndicators(
            profile: profile,
            latestMetric: latestMetric,
            editable: editable,
          ),
          // The index starts on the bottom rule of the columns and shares it
          // (owner decision, alignment r3: no empty strip between two rules,
          // as in the active exercise and Entrenar; the sketch had
          // `.x-ixs.mt32`).
          const ProgressPhotosEntry(joinsPrevious: true),
          // «Datos corporales» shares the index's bottom rule too (owner
          // decision, alignment r4).
          _BodyData(
            profile: profile,
            weightHistory: weightHistory,
            latestMetric: latestMetric,
          ),
        ],
      ),
    );
  }
}

/// Latest weight of each day, oldest first (as the previous chart).
List<BodyMetricEntity> _weightEntries(List<BodyMetricEntity> history) {
  final latestByDay = <String, BodyMetricEntity>{};
  for (final entry in history.where((item) => item.weightKg != null)) {
    latestByDay[DateFormat('yyyy-MM-dd').format(entry.date)] = entry;
  }
  return latestByDay.values.toList()..sort((a, b) => a.date.compareTo(b.date));
}

// ── Identity and avatar ─────────────────────────────────────────────────────

class _Identity extends StatelessWidget {
  const _Identity({
    required this.profile,
    required this.isUploadingAvatar,
    required this.editable,
  });

  final ProfileEntity profile;
  final bool isUploadingAvatar;
  final bool editable;

  static String _levelLabel(AppLocalizations l10n, String? level) {
    switch (level?.toUpperCase()) {
      case 'BEGINNER':
      case 'PRINCIPIANTE':
        return l10n.beginnerLevel;
      case 'INTERMEDIATE':
      case 'INTERMEDIO':
        return l10n.intermediateLevel;
      case 'ADVANCED':
      case 'AVANZADO':
        return l10n.advancedLevel;
      default:
        return level ?? '';
    }
  }

  static String _goalLabel(AppLocalizations l10n, String? goal) {
    switch (goal?.toUpperCase()) {
      case 'LOSE_WEIGHT':
        return l10n.loseWeightGoal;
      case 'GAIN_MUSCLE':
        return l10n.gainMuscleGoal;
      case 'MAINTAIN':
        return l10n.maintainGoal;
      case 'IMPROVE_FITNESS':
        return l10n.improveFitnessGoal;
      default:
        return goal ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
      (cubit) => cubit.state.unitSystem,
    );
    final name = profile.fullName.isNotEmpty
        ? profile.fullName
        : l10n.profileFallbackUserName;
    final details = [
      _levelLabel(l10n, profile.level),
      _goalLabel(l10n, profile.goal),
      if (profile.heightCm != null)
        // No-break space: value and unit never split across lines (O4).
        formatLength(
          profile.heightCm,
          unitSystem,
          decimals: 0,
        ).replaceAll(' ', _nbsp),
    ].where((part) => part.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  label: name,
                  excludeSemantics: true,
                  child: Text(
                    name.toUpperCase(),
                    style: ExomType.screenTitle.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: ExomSpacing.sm),
                  Text(details, style: _secondaryStyle(context)),
                ],
                const SizedBox(height: ExomSpacing.sm),
                Text(
                  l10n.profileStreakDays(profile.streakDays),
                  style: _secondaryStyle(context),
                ),
                if (isUploadingAvatar) ...[
                  const SizedBox(height: ExomSpacing.sm),
                  ExomSyncStatus(
                    key: const Key('profile-avatar-sending'),
                    state: ExomSyncState.enviando,
                    label: l10n.profileAvatarSending,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: ExomSpacing.lg),
          _Avatar(profile: profile, canChange: editable && !isUploadingAvatar),
        ],
      ),
    );
  }
}

/// Square avatar (`.x-av`, 72): the photo, or the initials, with the camera
/// badge when it can be changed.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.canChange});

  final ProfileEntity profile;
  final bool canChange;

  static const double _size = 72;
  static const double _badge = 24;

  String get _initials {
    final parts = [profile.firstName, profile.lastName]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    return parts.map((part) => part.characters.first.toUpperCase()).join();
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(ExomIcons.camera),
              title: Text(l10n.feedbackFromCamera),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(ExomIcons.gallery),
              title: Text(l10n.feedbackFromGallery),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    var selectedSource = source;
    while (context.mounted) {
      try {
        final picked = await ImagePicker().pickImage(source: selectedSource);
        if (picked == null || !context.mounted) return;
        context.read<ProfileBloc>().add(
          ProfileAvatarUploadRequested(File(picked.path)),
        );
        return;
      } on Object catch (error) {
        if (!context.mounted) return;
        final action = await showMediaPickerErrorDialog(
          context,
          error,
          canUseGallery: selectedSource != ImageSource.gallery,
        );
        if (action == MediaPickerRecoveryAction.gallery) {
          selectedSource = ImageSource.gallery;
        } else if (action != MediaPickerRecoveryAction.retry) {
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final initials = _initials;
    final Widget fallback = Center(
      child: initials.isEmpty
          ? Icon(ExomIcons.profile, size: 32, color: palette.textPrimary)
          : Text(
              initials,
              style: ExomType.section.copyWith(color: palette.textPrimary),
            ),
    );
    final url = profile.avatarUrl;
    final avatar = SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: palette.surfaceElevated,
              child: url == null
                  ? fallback
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => fallback,
                    ),
            ),
          ),
          if (canChange)
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: SizedBox(
                width: _badge,
                height: _badge,
                child: ColoredBox(
                  color: palette.textPrimary,
                  child: Icon(
                    ExomIcons.camera,
                    size: 14,
                    color: palette.background,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Semantics(
      button: canChange,
      label: AppLocalizations.of(context).profileChangePhotoA11y,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('profile-avatar'),
        onTap: canChange ? () => _pickAndUpload(context) : null,
        child: avatar,
      ),
    );
  }
}

// ── Weight (featured block) ─────────────────────────────────────────────────

class _WeightFeature extends StatelessWidget {
  const _WeightFeature({
    required this.entries,
    required this.errorMessage,
    required this.onRetry,
  });

  final List<BodyMetricEntity> entries;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
      (cubit) => cubit.state.unitSystem,
    );
    final unit = weightUnitSymbol(unitSystem);
    String figure(double display) =>
        formatFigure(context, display, decimalDigits: 1);
    final error = errorMessage;
    final retry = onRetry;

    final List<Widget> content;
    if (entries.isEmpty) {
      content = [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: ExomLineChart(points: []),
        ),
        ExomEmptyState(
          first: l10n.profileEmptyFirst,
          second: l10n.profileEmptySecond,
          body: l10n.logMetricsPrompt,
          action: ExomSecondaryButton(
            label: l10n.logMetricsButton,
            onPressed: () => _openMetrics(context),
          ),
        ),
      ];
    } else {
      final display = [
        for (final entry in entries)
          UnitConverters.weightToDisplay(entry.weightKg!, unitSystem),
      ];
      final first = display.first;
      final last = display.last;
      final delta = last - first;
      // Rounded first so «−0,0» never shows.
      final deltaText = figure(delta.abs());
      final sign = deltaText == figure(0) ? '' : (delta < 0 ? '−' : '+');
      final dateFormat = DateFormat(
        'd MMM',
        Localizations.localeOf(context).languageCode,
      );
      final footStyle = _secondaryStyle(context);
      content = [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: ExomNumeral(
            key: const Key('profile-weight-hero'),
            value: figure(last),
            unit: unit,
            size: ExomNumeralSize.hero140,
            side: entries.length < 2
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$sign$deltaText$_nbsp$unit',
                        style: ExomType.headline2Section.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.profileWeightSince('${figure(first)}$_nbsp$unit'),
                        style: footStyle,
                      ),
                    ],
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: ExomLineChart(
            points: [
              for (var i = 0; i < display.length; i++)
                ExomPoint(i.toDouble(), display[i]),
            ],
            labelOf: figure,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dateFormat.format(entries.first.date),
                  style: footStyle,
                ),
              ),
              Text(dateFormat.format(entries.last.date), style: footStyle),
            ],
          ),
        ),
      ];
    }

    // The error in line is added to the weight, never in its place: the kept
    // figure, chart and dates stay visible (EX-Q7).
    return ExomFeatureBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ExomKicker(l10n.weightProgressTitle),
            ),
          ),
          if (error != null && retry != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _ErrorBlock(
                message: error,
                onRetry: retry,
                messageKey: const Key('profile-inline-error'),
              ),
            ),
          ...content,
        ],
      ),
    );
  }
}

// ── Muscle mass and sleep: flat blocks (D14-7) ──────────────────────────────

class _FlatIndicators extends StatelessWidget {
  const _FlatIndicators({
    required this.profile,
    required this.latestMetric,
    required this.editable,
  });

  final ProfileEntity profile;
  final BodyMetricEntity? latestMetric;
  final bool editable;

  static const double _sleepGoalHours = 8;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
      (cubit) => cubit.state.unitSystem,
    );
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final muscle = latestMetric?.muscleMassKg;
    final goal = profile.muscleMassGoalKg;
    final muscleShare = muscle != null && goal != null && goal > 0
        ? (muscle / goal).clamp(0.0, 1.0).toDouble()
        : null;
    final sleep = latestMetric?.sleepHours;
    final sleepShare = sleep == null
        ? null
        : (sleep / _sleepGoalHours).clamp(0.0, 1.0).toDouble();
    String weightFigure(double kg) => formatFigure(
      context,
      UnitConverters.weightToDisplay(kg, unitSystem),
      decimalDigits: 1,
    );
    final unit = weightUnitSymbol(unitSystem);

    final String muscleCaption;
    if (goal == null) {
      muscleCaption = l10n.setYourGoal;
    } else if (muscleShare != null) {
      muscleCaption = l10n.profileGoalShare(percent.format(muscleShare));
    } else {
      muscleCaption = l10n.profileGoalValue('${weightFigure(goal)}$_nbsp$unit');
    }

    final palette = context.exomPalette;
    final editButton = IconButton(
      key: const Key('profile-muscle-goal-edit'),
      tooltip: l10n.profileGoalEditA11y,
      onPressed: editable
          ? () => _editMuscleGoal(context, profile, latestMetric)
          : null,
      icon: Icon(ExomIcons.tune, size: 20, color: palette.textPrimary),
    );

    return _FigurePair(
      left: _FlatFigure(
        key: const Key('profile-muscle-block'),
        kicker: l10n.muscleMassLabel,
        value: muscle == null ? null : weightFigure(muscle),
        unit: unit,
        share: muscleShare,
        caption: muscleCaption,
        trailing: editButton,
      ),
      right: _FlatFigure(
        key: const Key('profile-sleep-block'),
        kicker: l10n.sleep,
        value: sleep == null
            ? null
            : formatFigure(context, sleep, decimalDigits: 1),
        unit: l10n.profileHoursUnit,
        share: sleepShare,
        caption: sleepShare == null
            ? l10n.noDataLabel
            : l10n.profileGoalShare(percent.format(sleepShare)),
      ),
    );
  }
}

/// Two figures side by side with a hairline between them and rules above and
/// below (`.x-cols`), stacked in one column when a column would be narrower
/// than [_minColumn] at the current text size.
class _FigurePair extends StatelessWidget {
  const _FigurePair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  static const double _minColumn = 136;

  @override
  Widget build(BuildContext context) {
    final rule = BorderSide(
      color: context.exomPalette.borderSoft,
      width: ExomRule.hairline,
    );
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final inRow = constraints.maxWidth / 2 - 34 >= scaler.scale(_minColumn);
        if (inRow) {
          return _twoColumns(
            _cell(left, first: true),
            _cell(right, first: false),
            rule,
          );
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: rule, bottom: rule),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cell(left, first: true),
              DecoratedBox(
                decoration: BoxDecoration(border: Border(top: rule)),
                child: _cell(right, first: true),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _cell(Widget child, {required bool first}) => Padding(
    padding: EdgeInsetsDirectional.fromSTEB(first ? 20 : 14, 14, 12, 16),
    child: child,
  );
}

/// One flat block: kicker, figure in the data colour (a dash without data),
/// a 4 px bar ([ExomProgressRule]) and a caption.
class _FlatFigure extends StatelessWidget {
  const _FlatFigure({
    super.key,
    required this.kicker,
    required this.value,
    required this.unit,
    required this.share,
    required this.caption,
    this.trailing,
  });

  final String kicker;
  final String? value;
  final String unit;
  final double? share;
  final String caption;
  final Widget? trailing;

  static const double _figureSize = 56;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final shown = value;
    final style = ExomType.section.copyWith(
      fontSize: _figureSize,
      height: 0.85,
      letterSpacing: -1.12,
      color: shown == null ? palette.textSecondary : palette.data,
    );
    final action = trailing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: ExomKicker(kicker)),
            ?action,
          ],
        ),
        const SizedBox(height: 6),
        Semantics(
          label: shown == null ? '$kicker: —' : '$kicker: $shown $unit',
          excludeSemantics: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.only(bottom: _figureSize * 0.025),
              child: Text.rich(
                TextSpan(
                  children: shown == null
                      ? const [TextSpan(text: '—')]
                      : exomFigureSpans(
                          value: shown,
                          unit: unit,
                          fontSize: _figureSize,
                        ),
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: style,
              ),
            ),
          ),
        ),
        const SizedBox(height: ExomSpacing.sm),
        ExomProgressRule(value: share ?? 0, thickness: ExomRule.bar),
        const SizedBox(height: ExomSpacing.sm),
        Text(caption, style: _secondaryStyle(context)),
      ],
    );
  }
}

// ── Muscle mass goal sheet (D17-2) ──────────────────────────────────────────

/// Draft of the goal while the sheet is open, in the display unit.
@immutable
class _GoalDraft {
  const _GoalDraft(
    this.value, {
    this.parses = true,
    this.showError = false,
    this.touched = true,
  });

  final double value;

  /// False while the starting point is only a suggestion (no goal saved yet
  /// and no ± or typing): «Guardar» sends nothing until it is true.
  final bool touched;

  /// False while the typed text does not parse.
  final bool parses;
  final bool showError;

  /// Today's rule: a number greater than 0, without a cap.
  bool get isValid => parses && value > 0;
}

/// Value the sheet starts at, in the display unit. With a goal it is the text
/// the previous dialog started with (`formatWeightValue`, one decimal), so
/// saving untouched sends what the dialog sent. Without a goal: the latest
/// muscle mass, else the dialog's example value; that start is an untouched
/// draft (the dialog started empty and sent nothing until something was typed).
double _initialGoal(
  ProfileEntity profile,
  BodyMetricEntity? latestMetric,
  UnitSystem unitSystem,
) {
  final start = profile.muscleMassGoalKg ?? latestMetric?.muscleMassKg;
  if (start == null) return unitSystem == UnitSystem.imperial ? 75.0 : 34.0;
  return double.parse(formatWeightValue(start, unitSystem));
}

Future<void> _editMuscleGoal(
  BuildContext context,
  ProfileEntity profile,
  BodyMetricEntity? latestMetric,
) async {
  final l10n = AppLocalizations.of(context);
  final unitSystem = context.read<AppPreferencesCubit>().state.unitSystem;
  final unit = weightUnitSymbol(unitSystem);
  // L5-D31: 0.5 kg in metric, 1 lb in imperial.
  final step = unitSystem == UnitSystem.imperial ? 1.0 : 0.5;
  final stepDigits = step % 1 == 0 ? 0 : 1;
  final stepText =
      '${formatFigure(context, step, decimalDigits: stepDigits)} $unit';
  final draft = ValueNotifier<_GoalDraft>(
    _GoalDraft(
      _initialGoal(profile, latestMetric, unitSystem),
      touched: profile.muscleMassGoalKg != null,
    ),
  );
  final latest = latestMetric?.muscleMassKg;

  final double? newGoalKg;
  try {
    newGoalKg = await showExomSheet<double>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ExomSpacing.xl,
          ExomSpacing.xs,
          ExomSpacing.xl,
          ExomSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ExomTwoLineHeadline(
              first: l10n.profileGoalSheetFirst,
              second: l10n.profileGoalSheetSecond,
              semanticsLabel: l10n.muscleMassGoalTitle,
            ),
            if (latest != null) ...[
              const SizedBox(height: ExomSpacing.sm),
              Text(
                l10n.profileGoalLatest(
                  '${formatFigure(sheetContext, UnitConverters.weightToDisplay(latest, unitSystem), decimalDigits: 1)}$_nbsp$unit',
                ),
                style: _secondaryStyle(sheetContext),
              ),
            ],
            const SizedBox(height: ExomSpacing.lg),
            ValueListenableBuilder<_GoalDraft>(
              valueListenable: draft,
              builder: (_, current, _) => ExomNumeralStepper(
                value: current.value,
                min: step,
                max: double.maxFinite,
                step: step,
                unit: unit,
                label: l10n.muscleMassGoalTitle,
                decrementLabel: l10n.profileGoalDecrease(stepText),
                incrementLabel: l10n.profileGoalIncrease(stepText),
                acceptsTypedOutOfRange: true,
                errorText: current.showError ? l10n.profileGoalInvalid : null,
                onChanged: (value) => draft.value = _GoalDraft(value),
                onInvalidInput: (_) => draft.value = _GoalDraft(
                  current.value,
                  parses: false,
                  showError: current.showError,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Builder(
          builder: (sheetContext) => ValueListenableBuilder<_GoalDraft>(
            valueListenable: draft,
            builder: (_, current, _) => ExomPrimaryButton(
              key: const Key('profile-goal-save'),
              label: l10n.save,
              trailingIcon: ExomIcons.check,
              // Disabled while the suggested start is untouched: nothing is
              // sent (and no goal invented) until a ± or a typed value.
              onPressed: !current.touched
                  ? null
                  : () {
                      final latest = draft.value;
                      if (!latest.isValid) {
                        draft.value = _GoalDraft(
                          latest.value,
                          parses: latest.parses,
                          showError: true,
                        );
                        return;
                      }
                      Navigator.of(sheetContext).pop(
                        UnitConverters.weightFromDisplay(
                          latest.value,
                          unitSystem,
                        ),
                      );
                    },
            ),
          ),
        ),
        Builder(
          builder: (sheetContext) => ExomQuietButton(
            key: const Key('profile-goal-cancel'),
            label: l10n.cancel,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ],
    );
  } finally {
    draft.dispose();
  }

  if (newGoalKg != null && context.mounted) {
    context.read<ProfileBloc>().add(ProfileMuscleGoalUpdated(newGoalKg));
  }
}

// ── Index 01-03 ─────────────────────────────────────────────────────────────

/// Numbered index of the profile (`.x-ixs`): 01 weight and measurements,
/// 02 progress photos, 03 weekly recap. Keeps the public name of the former
/// progress photos button, whose route test drives it.
class ProgressPhotosEntry extends StatelessWidget {
  const ProgressPhotosEntry({super.key, this.joinsPrevious = false});

  /// See [ExomIndexList.joinsPrevious].
  final bool joinsPrevious;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ExomIndexList(
      joinsPrevious: joinsPrevious,
      items: [
        ExomIndexItem(
          title: l10n.profileIndexMetrics,
          onTap: () => _openMetrics(context),
        ),
        ExomIndexItem(
          title: l10n.progressPhotosEntry,
          onTap: () => context.push(AppRoutes.progressPhotos),
        ),
        ExomIndexItem(
          title: l10n.weeklyRecapButton,
          onTap: () => context.push(AppRoutes.recap),
        ),
      ],
    );
  }
}

// ── Body data band ──────────────────────────────────────────────────────────

class _BodyData extends StatelessWidget {
  const _BodyData({
    required this.profile,
    required this.weightHistory,
    required this.latestMetric,
  });

  final ProfileEntity profile;
  final List<BodyMetricEntity> weightHistory;
  final BodyMetricEntity? latestMetric;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
      (cubit) => cubit.state.unitSystem,
    );
    final withWeight = weightHistory.where((e) => e.weightKg != null);
    final weightKg = withWeight.isNotEmpty
        ? withWeight.last.weightKg
        : profile.currentWeightKg;
    final metric = latestMetric;
    final heightCm = metric?.heightCm ?? profile.heightCm;
    final waistCm = metric?.waistCm;
    final hasMeasurements =
        metric != null &&
        (metric.neckCm != null ||
            metric.chestCm != null ||
            metric.waistCm != null ||
            metric.hipsCm != null);

    String length(double cm) =>
        formatFigure(context, UnitConverters.lengthToDisplay(cm, unitSystem));
    const dash = '—';
    final lengthUnit = lengthUnitSymbol(unitSystem);

    final String? footnote;
    if (hasMeasurements) {
      footnote = l10n.profileMeasurementsUpdated(
        DateFormat.MMMMd(
          Localizations.localeOf(context).languageCode,
        ).format(metric.date),
      );
    } else if (heightCm == null) {
      footnote = l10n.addHeightInMetrics;
    } else {
      footnote = null;
    }

    return ExomBand(
      key: const Key('profile-body-data'),
      // Always right under the index of the profile (see _ProfileContent).
      joinsPrevious: true,
      kicker: l10n.bodyDataTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExomFigureColumns(
            numbered: false,
            alignLabels: true,
            items: [
              ExomFigure(
                label: l10n.weight,
                value: weightKg == null
                    ? dash
                    : formatFigure(
                        context,
                        UnitConverters.weightToDisplay(weightKg, unitSystem),
                        decimalDigits: 1,
                      ),
                unit: weightKg == null ? null : weightUnitSymbol(unitSystem),
              ),
              ExomFigure(
                label: l10n.height,
                value: heightCm == null ? dash : length(heightCm),
                unit: heightCm == null ? null : lengthUnit,
              ),
              ExomFigure(
                label: waistCm == null
                    ? l10n.measurementsLabel
                    : l10n.measureWaist,
                value: waistCm == null ? dash : length(waistCm),
                unit: waistCm == null ? null : lengthUnit,
              ),
            ],
          ),
          if (footnote != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(footnote, style: _secondaryStyle(context)),
            ),
        ],
      ),
    );
  }
}
