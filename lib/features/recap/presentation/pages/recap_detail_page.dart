import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_anatomy_selector.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_feedback_card.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_published_review_card.dart';
import 'package:exom_app/injection_container.dart';

class RecapDetailPage extends StatelessWidget {
  final String recapId;

  const RecapDetailPage({super.key, required this.recapId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RecapBloc>()..add(RecapDetailRequested(recapId)),
      child: _RecapDetailView(recapId: recapId),
    );
  }
}

class _RecapDetailView extends StatefulWidget {
  final String recapId;

  const _RecapDetailView({required this.recapId});

  @override
  State<_RecapDetailView> createState() => _RecapDetailViewState();
}

class _RecapDetailViewState extends State<_RecapDetailView> {
  bool _feedbackMarked = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final theme = Theme.of(context);

    return ExomStaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Sketch C5: the bar only carries «Volver»; the week is the body title.
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(ExomIcons.back, color: palette.textPrimary),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => context.pop(),
          ),
        ),
        body: BlocConsumer<RecapBloc, RecapState>(
          listener: (context, state) {
            if (state is RecapDetailLoaded && !_feedbackMarked) {
              if (state.recap.hasUnreadClientFeedback) {
                _feedbackMarked = true;
                context.read<RecapBloc>().add(
                  RecapFeedbackMarkReadRequested(widget.recapId),
                );
              }
            }
          },
          builder: (context, state) {
            if (state is RecapDetailLoading) {
              return const _RecapDetailLoadingView();
            }

            if (state is RecapDetailError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(ExomIcons.error, color: palette.error, size: 42),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).couldNotLoadRecap,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.message == RecapDetailError.signInRequiredMessage
                            ? AppLocalizations.of(context).recapSignInRequired
                            : localizedErrorTextOf(context, state.message, fallback: (l10n) => l10n.recapDetailLoadError),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => context.read<RecapBloc>().add(
                          RecapDetailRequested(widget.recapId),
                        ),
                        child: Text(AppLocalizations.of(context).retry),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is RecapDetailLoaded) {
              return _RecapDetailContent(recap: state.recap);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

/// Loading: skeletons with the shape of the final screen (sketch C5, «Carga»):
/// title, headline, reply, a section numeral with its rule and value rows.
class _RecapDetailLoadingView extends StatelessWidget {
  const _RecapDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        ExomSpacing.xl,
        ExomSpacing.sm,
        ExomSpacing.xl,
        ExomSpacing.huge + bottomInset,
      ),
      children: const [
        ExomSkeleton.headline(),
        SizedBox(height: ExomSpacing.lg),
        ExomSkeleton.headline(),
        SizedBox(height: ExomSpacing.lg),
        ExomSkeleton.row(),
        SizedBox(height: ExomSpacing.xxl),
        ExomSkeleton.numeral(),
        SizedBox(height: ExomSpacing.lg),
        ExomSkeleton.rule(),
        SizedBox(height: ExomSpacing.md),
        ExomSkeleton.row(),
        ExomSkeleton.row(),
        ExomSkeleton.row(),
      ],
    );
  }
}

/// One line of a section that is not a figure: a [label] and its [value].
/// [isEmpty] marks «no answer» values («—», «No valorado», «Sin dato»…), which
/// are painted in the secondary colour; a real answer is in the text colour.
/// [stacked] puts the value under the label (free text such as notes).
class _RecapField {
  const _RecapField(
    this.label,
    this.value, {
    this.isEmpty = false,
    this.stacked = false,
  });

  final String label;
  final String value;
  final bool isEmpty;
  final bool stacked;
}

/// Figures and rows of one numbered section.
class _RecapSection {
  final List<ExomFigure> figures = [];
  final List<_RecapField> fields = [];

  /// A whole number answer: a figure when there is one, else an empty row.
  void number(
    String label,
    int? value, {
    String? unit,
    String emptyText = '—',
  }) {
    if (value == null) {
      fields.add(_RecapField(label, emptyText, isEmpty: true));
    } else {
      figures.add(ExomFigure(value: '$value', unit: unit, label: label));
    }
  }

  /// A plain value row; blank text counts as empty.
  void text(String label, String? value, {String emptyText = '—'}) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      fields.add(_RecapField(label, emptyText, isEmpty: true));
    } else {
      fields.add(_RecapField(label, trimmed));
    }
  }

  /// Free text under its label (notes, feedback).
  void note(String label, String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      fields.add(_RecapField(label, '—', isEmpty: true));
    } else {
      fields.add(_RecapField(label, trimmed, stacked: true));
    }
  }

  void empty(String label, String text) =>
      fields.add(_RecapField(label, text, isEmpty: true));
}

class _RecapDetailContent extends StatelessWidget {
  final RecapEntity recap;

  const _RecapDetailContent({required this.recap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final training = _RecapSection()
      ..number('Esfuerzo', recap.trainingEffort)
      ..number('Sesiones', recap.trainingSessions)
      ..text(
        l10n.averageDailySteps,
        recap.averageDailySteps != null
            ? '${NumberFormat.decimalPattern(l10n.localeName).format(recap.averageDailySteps)} ${l10n.stepsPerDay}'
            : null,
      )
      ..text('Progreso', _opt(recap.trainingProgress))
      ..note('Notas', recap.trainingNotes);

    final nutrition = _RecapSection()
      ..text('Calidad alimentación', _opt(recap.nutritionQuality))
      ..number('Calidad comidas', recap.foodQuality);
    if (recap.hydrationEnabled) {
      nutrition.text('Hidratación', _opt(recap.hydrationLevel));
    } else {
      nutrition.empty('Hidratación', 'No valorado');
    }
    nutrition.note('Notas', recap.nutritionNotes);

    final recovery = _RecapSection()
      ..text('Sueño', _opt(recap.sleepHoursRange))
      ..text('Fatiga', _opt(recap.fatigueLevel));
    if (recap.musclePainZones.isEmpty) {
      recovery.empty('Zonas con dolor', 'Sin zonas');
    } else {
      recovery.text(
        'Zonas con dolor',
        recap.musclePainZones.map((zone) => _formatZone(zone, l10n)).join(', '),
      );
    }
    recovery.note('Notas', recap.recoveryNotes);

    final feelings = _RecapSection()..text('Estado de ánimo', _opt(recap.mood));
    if (recap.stressEnabled && recap.stressLevel != null) {
      feelings.number('Estrés', recap.stressLevel, unit: '/5');
    } else {
      feelings.empty('Estrés', 'No valorado');
    }
    feelings
      ..number(
        l10n.weeklyHunger,
        recap.hungerLevel,
        unit: '/10',
        emptyText: l10n.optionalRatingNoData,
      )
      ..number(
        l10n.weeklyEnergy,
        recap.energyLevel,
        unit: '/10',
        emptyText: l10n.optionalRatingNoData,
      )
      ..number(
        l10n.weeklyDigestion,
        recap.digestionLevel,
        unit: '/10',
        emptyText: l10n.optionalRatingNoData,
      )
      ..note('Notas', recap.generalNotes);

    final improvement = _RecapSection()
      ..number('App', recap.improvementAppRating, unit: '/5')
      ..number('Servicio', recap.improvementServiceRating, unit: '/5');
    if (recap.improvementAreas.isEmpty) {
      improvement.empty('Áreas de mejora', 'Sin áreas destacadas');
    } else {
      improvement.text('Áreas de mejora', recap.improvementAreas.map(_opt).join(', '));
    }
    improvement.note(l10n.feedback, recap.improvementFeedbackText);

    final sections = [
      ('Entreno', training),
      ('Nutrición', nutrition),
      ('Recuperación', recovery),
      ('Sensaciones', feelings),
      ('Mejora', improvement),
    ];

    return ListView(
      padding: EdgeInsets.only(top: ExomSpacing.sm, bottom: 32 + bottomInset),
      children: [
        _RecapHeader(recap: recap),
        const SizedBox(height: ExomSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ExomSpacing.xl),
          child: ExomTwoLineHeadline(
            first: l10n.recapDetailHeadlineFirst,
            second: l10n.recapDetailHeadlineSecond,
          ),
        ),
        const SizedBox(height: ExomSpacing.lg),
        if (recap.hasPublishedReview) ...[
          RecapPublishedReviewCard(recap: recap),
          const SizedBox(height: ExomSpacing.lg),
        ],
        if (recap.hasClientFeedback) ...[
          RecapFeedbackCard(recap: recap),
          const SizedBox(height: ExomSpacing.lg),
        ],
        for (var i = 0; i < sections.length; i++) ...[
          const SizedBox(height: ExomSpacing.sm),
          _RecapSectionView(
            n: i + 1,
            title: sections[i].$1,
            section: sections[i].$2,
          ),
        ],
      ],
    );
  }

  String _opt(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    return value
        .replaceAll('_', ' ')
        .toLowerCase()
        .replaceAllMapped(
          RegExp(r'(^|\s)\S'),
          (m) => m.group(0)!.toUpperCase(),
        );
  }

  String _formatZone(String value, AppLocalizations l10n) {
    final zone = RecapAnatomyZone.fromId(value);
    if (zone != null) {
      final isEnglish = l10n.localeName.startsWith('en');
      return isEnglish ? zone.englishLabel : zone.spanishLabel;
    }

    return recapCopyFromLocale(value, l10n);
  }
}

String recapCopyFromLocale(String value, AppLocalizations l10n) {
  const legacyLabels = <String, List<String>>{
    'neck': ['Cuello', 'Neck'],
    'shoulders': ['Hombros', 'Shoulders'],
    'chest': ['Pecho', 'Chest'],
    'upperArm': ['Brazo', 'Upper arm'],
    'forearm': ['Antebrazo', 'Forearm'],
    'waist': ['Cintura', 'Waist'],
    'hips': ['Caderas', 'Hips'],
    'thigh': ['Muslo', 'Thigh'],
    'calf': ['Pantorrilla', 'Calf'],
  };

  final label = legacyLabels[value];
  if (label != null) {
    return l10n.localeName.startsWith('en') ? label[1] : label[0];
  }

  return value
      .replaceAll('_', ' ')
      .toLowerCase()
      .replaceAllMapped(
        RegExp(r'(^|\s)\S'),
        (match) => match.group(0)!.toUpperCase(),
      );
}

/// Header (sketch C5): the week as the screen title and one status line
/// (icon + text, no pill).
class _RecapHeader extends StatelessWidget {
  const _RecapHeader({required this.recap});

  final RecapEntity recap;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final week = _weekRange(context, recap);
    final reviewedAt = recap.reviewedAt;
    final reviewed = recap.status == 'REVIEWED';
    final status = switch (recap.status) {
      'REVIEWED' =>
        reviewedAt != null
            ? l10n.recapReviewedOn(
                DateFormat(
                  'dd MMM yyyy',
                  Localizations.localeOf(context).languageCode,
                ).format(reviewedAt.toLocal()),
              )
            : 'Revisado',
      'SUBMITTED' => 'Enviado',
      _ => 'Borrador',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ExomSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            label: week,
            excludeSemantics: true,
            child: Text(
              week.toUpperCase(),
              style: ExomType.screenTitle.copyWith(color: palette.textPrimary),
            ),
          ),
          const SizedBox(height: ExomSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                reviewed ? ExomIcons.done : ExomIcons.time,
                size: 16,
                color: reviewed ? palette.textPrimary : palette.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  status,
                  style: TextStyle(
                    color: reviewed ? palette.textPrimary : palette.textSecondary,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _weekRange(BuildContext context, RecapEntity recap) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final fmt = DateFormat('dd MMM', languageCode);
    return '${fmt.format(recap.weekStartDate)} - ${DateFormat('dd MMM yyyy', languageCode).format(recap.weekEndDate)}';
  }
}

/// Numbered section (`.x-sh`): header, figures in columns for the numeric
/// answers and one row per remaining answer.
class _RecapSectionView extends StatelessWidget {
  const _RecapSectionView({
    required this.n,
    required this.title,
    required this.section,
  });

  final int n;
  final String title;
  final _RecapSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExomNumberedSectionHeader(n: n, title: title),
        const SizedBox(height: ExomSpacing.md),
        if (section.figures.isNotEmpty)
          ExomFigureColumns(items: section.figures, numbered: false),
        if (section.fields.isNotEmpty)
          ExomFlatRowGroup(
            children: [
              for (final field in section.fields) _RecapFieldRow(field: field),
            ],
          ),
      ],
    );
  }
}

/// Row of an answer that is not a figure (`.r` / `.rv`): label in the text
/// colour, value at the end; free text goes under its label. A real value is
/// in the text colour and semibold, an empty one in the secondary colour.
class _RecapFieldRow extends StatelessWidget {
  const _RecapFieldRow({required this.field});

  final _RecapField field;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.3);
    final valueStyle = field.isEmpty
        ? style?.copyWith(color: palette.textSecondary)
        : style?.copyWith(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          );
    if (field.stacked) {
      return MergeSemantics(
        child: ExomRowSurface(
          padding: const EdgeInsets.symmetric(
            horizontal: ExomSpacing.xl,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                field.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: ExomSpacing.xs),
              Text(
                field.value,
                style: style?.copyWith(color: palette.textPrimary),
              ),
            ],
          ),
        ),
      );
    }
    return MergeSemantics(
      child: ExomRowSurface(
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: Text(
                  field.label,
                  style: style?.copyWith(color: palette.textPrimary),
                ),
              ),
              const SizedBox(width: ExomSpacing.md),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
                child: Text(
                  field.value,
                  textAlign: TextAlign.end,
                  style: valueStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
