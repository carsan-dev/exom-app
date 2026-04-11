import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_feedback_card.dart';
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
        appBar: AppBar(
          title: const Text('Detalle del recap'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
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
              return Center(
                child: CircularProgressIndicator(color: palette.primary),
              );
            }

            if (state is RecapDetailError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: palette.error, size: 42),
                      const SizedBox(height: 16),
                      Text(
                        'No se pudo cargar el recap',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => context.read<RecapBloc>().add(
                          RecapDetailRequested(widget.recapId),
                        ),
                        child: const Text('Reintentar'),
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

class _RecapDetailContent extends StatelessWidget {
  final RecapEntity recap;

  const _RecapDetailContent({required this.recap});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final theme = Theme.of(context);
    final fmt = DateFormat('dd MMM yyyy');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Header card
        GlassCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(18),
          borderRadius: 22,
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _weekRange(recap),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  _StatusChip(status: recap.status),
                ],
              ),
              const SizedBox(height: 6),
              if (recap.reviewedAt != null)
                Text(
                  'Revisado el ${fmt.format(recap.reviewedAt!.toLocal())}',
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Trainer feedback
        if (recap.hasClientFeedback) ...[
          RecapFeedbackCard(recap: recap),
          const SizedBox(height: 16),
        ],

        // Recap sections
        _SectionCard(
          title: 'Entreno',
          palette: palette,
          theme: theme,
          children: [
            _Item('Esfuerzo', recap.trainingEffort?.toString() ?? '—'),
            _Item('Sesiones', recap.trainingSessions?.toString() ?? '—'),
            _Item('Progreso', _opt(recap.trainingProgress)),
            _Item('Notas', recap.trainingNotes ?? '—'),
          ],
        ),

        _SectionCard(
          title: 'Nutrición',
          palette: palette,
          theme: theme,
          children: [
            _Item('Calidad alimentación', _opt(recap.nutritionQuality)),
            _Item('Calidad comidas', recap.foodQuality?.toString() ?? '—'),
            _Item(
              'Hidratación',
              recap.hydrationEnabled
                  ? _opt(recap.hydrationLevel)
                  : 'No valorado',
            ),
            _Item('Notas', recap.nutritionNotes ?? '—'),
          ],
        ),

        _SectionCard(
          title: 'Recuperación',
          palette: palette,
          theme: theme,
          children: [
            _Item('Sueño', _opt(recap.sleepHoursRange)),
            _Item('Fatiga', _opt(recap.fatigueLevel)),
            _Item(
              'Zonas con dolor',
              recap.musclePainZones.isEmpty
                  ? 'Sin zonas'
                  : recap.musclePainZones.map(_opt).join(', '),
            ),
            _Item('Notas', recap.recoveryNotes ?? '—'),
          ],
        ),

        _SectionCard(
          title: 'Sensaciones',
          palette: palette,
          theme: theme,
          children: [
            _Item('Estado de ánimo', _opt(recap.mood)),
            _Item(
              'Estrés',
              recap.stressEnabled
                  ? '${recap.stressLevel ?? 0}/5'
                  : 'No valorado',
            ),
            _Item('Notas', recap.generalNotes ?? '—'),
          ],
        ),

        _SectionCard(
          title: 'Mejora',
          palette: palette,
          theme: theme,
          children: [
            _Item(
              'App',
              recap.improvementAppRating != null
                  ? '${recap.improvementAppRating}/5'
                  : '—',
            ),
            _Item(
              'Servicio',
              recap.improvementServiceRating != null
                  ? '${recap.improvementServiceRating}/5'
                  : '—',
            ),
            _Item(
              'Áreas de mejora',
              recap.improvementAreas.isEmpty
                  ? 'Sin áreas destacadas'
                  : recap.improvementAreas.map(_opt).join(', '),
            ),
            _Item('Feedback', recap.improvementFeedbackText ?? '—'),
          ],
        ),
      ],
    );
  }

  String _weekRange(RecapEntity recap) {
    final fmt = DateFormat('dd MMM');
    return '${fmt.format(recap.weekStartDate)} - ${DateFormat('dd MMM yyyy').format(recap.weekEndDate)}';
  }

  String _opt(String? value) {
    if (value == null || value.trim().isEmpty) return '—';
    return value
        .replaceAll('_', ' ')
        .toLowerCase()
        .replaceAllMapped(
          RegExp(r'(^|\s)\S'),
          (m) => m.group(0)!.toUpperCase(),
        );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final dynamic palette;
  final ThemeData theme;

  const _SectionCard({
    required this.title,
    required this.children,
    required this.palette,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: GlassDecoration.card(borderRadius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: context.exomPalette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final String label;
  final String value;

  const _Item(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.textDisabled,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final color = switch (status) {
      'REVIEWED' => semantic.success,
      'SUBMITTED' => palette.primary,
      _ => semantic.warning,
    };
    final label = switch (status) {
      'REVIEWED' => 'Revisado',
      'SUBMITTED' => 'Enviado',
      _ => 'Borrador',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: GlassDecoration.accentCard(color, borderRadius: 999),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
