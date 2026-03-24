import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';
import 'package:exom_app/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:exom_app/injection_container.dart';

class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return BlocProvider(
      create: (_) => sl<FeedbackBloc>()..add(const FeedbackLoadRequested()),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Feedback'),
          backgroundColor: theme.scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
        ),
        body: BlocConsumer<FeedbackBloc, FeedbackState>(
          listener: (context, state) {
            if (state is FeedbackSubmitSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Feedback enviado correctamente'),
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
            if (state is FeedbackError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: palette.error,
                ),
              );
              context.read<FeedbackBloc>().add(const FeedbackLoadRequested());
            }
          },
          builder: (context, state) {
            if (state is FeedbackLoading) {
              return Center(
                child: CircularProgressIndicator(color: palette.primary),
              );
            }

            final items = (state is FeedbackLoaded)
                ? state.items
                : <FeedbackEntity>[];

            return RefreshIndicator(
              color: palette.primary,
              backgroundColor: palette.surface,
              onRefresh: () async {
                context.read<FeedbackBloc>().add(const FeedbackLoadRequested());
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  _FeedbackForm(isSubmitting: state is FeedbackSubmitting),
                  if (items.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        'Historial',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: palette.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ...items.map((f) => _FeedbackCard(feedback: f)),
                  ] else if (state is FeedbackLoaded)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Aún no has enviado ningún feedback',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.textDisabled,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeedbackForm extends StatefulWidget {
  const _FeedbackForm({required this.isSubmitting});

  final bool isSubmitting;

  @override
  State<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<_FeedbackForm> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();
  String _mediaType = 'IMAGE';

  @override
  void dispose() {
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<FeedbackBloc>().add(
      FeedbackSubmitRequested(
        mediaType: _mediaType,
        mediaUrl: _urlController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
    _urlController.clear();
    _notesController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enviar feedback',
              style: theme.textTheme.titleMedium?.copyWith(
                color: palette.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _TypeChip(
                  label: 'Imagen',
                  icon: Icons.image_outlined,
                  selected: _mediaType == 'IMAGE',
                  onTap: () => setState(() => _mediaType = 'IMAGE'),
                ),
                const SizedBox(width: 8),
                _TypeChip(
                  label: 'Vídeo',
                  icon: Icons.videocam_outlined,
                  selected: _mediaType == 'VIDEO',
                  onTap: () => setState(() => _mediaType = 'VIDEO'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _urlController,
              style: TextStyle(color: palette.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'URL del archivo (imagen o vídeo)',
                prefixIcon: Icon(
                  Icons.link,
                  color: palette.textDisabled,
                  size: 18,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'La URL es obligatoria';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              style: TextStyle(color: palette.textPrimary, fontSize: 14),
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Notas adicionales (opcional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.isSubmitting ? null : _submit,
                child: widget.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Enviar feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? palette.primary.withValues(alpha: 0.15)
              : palette.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? palette.primary : palette.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? palette.primary : palette.textDisabled,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: selected ? palette.primary : palette.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.feedback});

  final FeedbackEntity feedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final dateStr = DateFormat('dd MMM yyyy', 'es').format(feedback.createdAt);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                feedback.isVideo
                    ? Icons.videocam_outlined
                    : Icons.image_outlined,
                color: palette.primary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  feedback.exerciseName ??
                      (feedback.isVideo ? 'Vídeo' : 'Imagen'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusBadge(isReviewed: feedback.isReviewed),
            ],
          ),
          if (feedback.notes != null) ...[
            const SizedBox(height: 8),
            Text(
              feedback.notes!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
          if (feedback.adminResponse != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: palette.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.reply, color: palette.primary, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      feedback.adminResponse!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            dateStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textDisabled,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isReviewed});

  final bool isReviewed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isReviewed
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isReviewed ? 'Revisado' : 'Pendiente',
        style: TextStyle(
          color: isReviewed ? AppColors.success : AppColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
