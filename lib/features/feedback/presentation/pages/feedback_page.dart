import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/services/feature_gate_service.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/premium_locked_overlay.dart';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';
import 'package:exom_app/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_media_picker.dart';
import 'package:exom_app/injection_container.dart';

class FeedbackPage extends StatelessWidget {
  final String? exerciseId;
  final String? exerciseName;

  const FeedbackPage({super.key, this.exerciseId, this.exerciseName});

  @override
  Widget build(BuildContext context) {
    final gate = GetIt.instance<FeatureGateService>();
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    if (!gate.canUseFeedback) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(l10n.feedback),
          backgroundColor: theme.scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
        ),
        body: const PremiumLockedPage(),
      );
    }

    return BlocProvider(
      create: (_) => sl<FeedbackBloc>()..add(const FeedbackLoadRequested()),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(l10n.feedback),
          backgroundColor: theme.scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
        ),
        body: BlocConsumer<FeedbackBloc, FeedbackState>(
          listener: (context, state) {
            if (state is FeedbackSubmitSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context).feedbackSentSuccessfully,
                  ),
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
                  _FeedbackForm(
                    isSubmitting: state is FeedbackSubmitting,
                    exerciseId: exerciseId,
                    exerciseName: exerciseName,
                  ),
                  if (items.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        l10n.history,
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
                          l10n.noFeedbackYet,
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
  const _FeedbackForm({
    required this.isSubmitting,
    this.exerciseId,
    this.exerciseName,
  });

  final bool isSubmitting;
  final String? exerciseId;
  final String? exerciseName;

  @override
  State<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<_FeedbackForm> {
  final _notesController = TextEditingController();
  String _mediaType = 'IMAGE';
  File? _selectedFile;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _contentType() {
    if (_selectedFile == null) {
      return _mediaType == 'VIDEO' ? 'video/mp4' : 'image/jpeg';
    }
    final ext = _selectedFile!.path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mp4':
        return 'video/mp4';
      default:
        return _mediaType == 'VIDEO' ? 'video/mp4' : 'image/jpeg';
    }
  }

  void _submit() {
    if (_selectedFile == null) return;
    context.read<FeedbackBloc>().add(
      FeedbackUploadAndSubmit(
        file: _selectedFile!,
        contentType: _contentType(),
        mediaType: _mediaType,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        exerciseId: widget.exerciseId,
      ),
    );
    setState(() => _selectedFile = null);
    _notesController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sendFeedback,
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.exerciseName != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.exerciseName!,
              style: TextStyle(
                color: palette.primary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FeedbackMediaPicker(
            selectedFile: _selectedFile,
            mediaType: _mediaType,
            isUploading: widget.isSubmitting,
            onMediaTypeChanged: (type) => setState(() {
              _mediaType = type;
              _selectedFile = null;
            }),
            onFileSelected: (file) => setState(() => _selectedFile = file),
            onClear: () => setState(() => _selectedFile = null),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            style: TextStyle(color: palette.textPrimary, fontSize: 14),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.additionalNotesOptional,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (widget.isSubmitting || _selectedFile == null)
                  ? null
                  : _submit,
              child: widget.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(l10n.sendFeedback),
            ),
          ),
        ],
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
    final l10n = AppLocalizations.of(context);
    final dateStr = DateFormat(
      'dd MMM yyyy',
      Localizations.localeOf(context).languageCode,
    ).format(feedback.createdAt);

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
                      (feedback.isVideo ? l10n.video : l10n.image),
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
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isReviewed
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isReviewed ? l10n.reviewed : l10n.pending,
        style: TextStyle(
          color: isReviewed ? AppColors.success : AppColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
