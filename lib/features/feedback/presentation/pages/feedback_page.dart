import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/glass_app_bar.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';
import 'package:exom_app/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_media_picker.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';

class FeedbackExerciseTarget {
  final String key;
  final String exerciseId;
  final String exerciseName;

  const FeedbackExerciseTarget({
    required this.key,
    required this.exerciseId,
    required this.exerciseName,
  });
}

class FeedbackPageArgs {
  final FeedbackExerciseTarget? exercise;
  final String? circuitName;
  final List<FeedbackExerciseTarget> circuitExercises;

  const FeedbackPageArgs.exercise(this.exercise)
    : circuitName = null,
      circuitExercises = const [];

  const FeedbackPageArgs.circuit({
    required this.circuitName,
    required this.circuitExercises,
  }) : exercise = null;

  bool get isCircuit => circuitExercises.isNotEmpty;
}

class FeedbackPage extends StatelessWidget {
  final FeedbackPageArgs? args;

  const FeedbackPage({super.key, this.args});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return BlocProvider(
      create: (_) => sl<FeedbackBloc>()..add(const FeedbackLoadRequested()),
      child: ExomStaticBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: GlassAppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: palette.textPrimary),
              onPressed: () => context.pop(),
            ),
            title: Text(
              args?.isCircuit == true
                  ? l10n.circuitFeedbackTitle
                  : l10n.feedback,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.374,
              ),
            ),
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
                return const _FeedbackLoadingBody();
              }

              final items = (state is FeedbackLoaded)
                  ? state.items
                  : <FeedbackEntity>[];

              final bottomInset = MediaQuery.paddingOf(context).bottom;
              return RefreshIndicator(
                color: palette.primary,
                backgroundColor: palette.surface,
                onRefresh: () async {
                  context.read<FeedbackBloc>().add(
                    const FeedbackLoadRequested(),
                  );
                },
                child: ListView(
                  padding: EdgeInsets.only(bottom: 40 + bottomInset),
                  children: [
                    if (args?.isCircuit == true)
                      CircuitFeedbackForm(
                        circuitName: args!.circuitName ?? '',
                        targets: args!.circuitExercises,
                        onQueued: () => context.pop(),
                      )
                    else
                      _FeedbackForm(
                        isSubmitting: false,
                        exerciseId: args?.exercise?.exerciseId,
                        exerciseName: args?.exercise?.exerciseName,
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
      ),
    );
  }
}

class CircuitFeedbackUpload {
  final FeedbackExerciseTarget target;
  final File file;
  final String? notes;

  const CircuitFeedbackUpload({
    required this.target,
    required this.file,
    this.notes,
  });
}

typedef CircuitFeedbackEnqueue =
    Future<void> Function(CircuitFeedbackUpload upload);

class CircuitFeedbackForm extends StatefulWidget {
  final String circuitName;
  final List<FeedbackExerciseTarget> targets;
  final CircuitFeedbackEnqueue? enqueue;
  final VoidCallback? onQueued;
  final bool requireAll;

  const CircuitFeedbackForm({
    super.key,
    required this.circuitName,
    required this.targets,
    this.enqueue,
    this.onQueued,
    this.requireAll = false,
  });

  @override
  State<CircuitFeedbackForm> createState() => _CircuitFeedbackFormState();
}

class _CircuitFeedbackFormState extends State<CircuitFeedbackForm> {
  final Map<String, File> _selectedFiles = {};
  final Map<String, TextEditingController> _notesControllers = {};
  bool _isQueueing = false;

  @override
  void initState() {
    super.initState();
    for (final target in widget.targets) {
      _notesControllers[target.key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _enqueue(CircuitFeedbackUpload upload) async {
    final customEnqueue = widget.enqueue;
    if (customEnqueue != null) return customEnqueue(upload);
    await sl<FeedbackUploadQueueService>().enqueue(
      file: upload.file,
      contentType: _feedbackContentType(upload.file, 'VIDEO'),
      mediaType: 'VIDEO',
      notes: upload.notes,
      exerciseId: upload.target.exerciseId,
    );
  }

  Future<void> _submit() async {
    if (_selectedFiles.isEmpty || _isQueueing) return;
    setState(() => _isQueueing = true);

    var failed = 0;
    final selectedTargets = widget.targets
        .where((target) => _selectedFiles.containsKey(target.key))
        .toList(growable: false);

    for (final target in selectedTargets) {
      final file = _selectedFiles[target.key]!;
      final notes = _notesControllers[target.key]!.text.trim();
      try {
        await _enqueue(
          CircuitFeedbackUpload(
            target: target,
            file: file,
            notes: notes.isEmpty ? null : notes,
          ),
        );
        _selectedFiles.remove(target.key);
        _notesControllers[target.key]!.clear();
      } catch (_) {
        failed++;
      }
    }

    if (!mounted) return;
    setState(() => _isQueueing = false);
    if (failed == 0) {
      widget.onQueued?.call();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).feedbackUploadFailed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final selectedCount = _selectedFiles.length;

    return Column(
      children: [
        GlassCard(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.all(20),
          borderRadius: 22,
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.circuitName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.circuitFeedbackDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
        for (final target in widget.targets)
          GlassCard(
            key: ValueKey('circuit-feedback-${target.key}'),
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.exerciseName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                FeedbackMediaPicker(
                  selectedFile: _selectedFiles[target.key],
                  mediaType: 'VIDEO',
                  videoOnly: true,
                  isUploading: _isQueueing,
                  onMediaTypeChanged: (_) {},
                  onFileSelected: (file) =>
                      setState(() => _selectedFiles[target.key] = file),
                  onClear: () =>
                      setState(() => _selectedFiles.remove(target.key)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesControllers[target.key],
                  enabled: !_isQueueing,
                  maxLines: 2,
                  style: TextStyle(color: palette.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: l10n.additionalNotesOptional,
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const ValueKey('send-circuit-feedback'),
              onPressed:
                  selectedCount == 0 ||
                      _isQueueing ||
                      (widget.requireAll &&
                          selectedCount != widget.targets.length)
                  ? null
                  : _submit,
              child: _isQueueing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(l10n.circuitFeedbackSendCount(selectedCount)),
            ),
          ),
        ),
      ],
    );
  }
}

String _feedbackContentType(File file, String mediaType) {
  final ext = file.path.split('.').last.toLowerCase();
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'mov':
      return 'video/quicktime';
    case 'm4v':
      return 'video/x-m4v';
    case 'webm':
      return 'video/webm';
    case 'mp4':
      return 'video/mp4';
    default:
      return mediaType == 'VIDEO' ? 'video/mp4' : 'image/jpeg';
  }
}

class _FeedbackLoadingBody extends StatelessWidget {
  const _FeedbackLoadingBody();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.only(bottom: 40 + bottomInset),
      children: const [
        _FeedbackFormSkeleton(),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: ShimmerCard(
            height: 22,
            width: 92,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        _FeedbackHistorySkeletonCard(),
        _FeedbackHistorySkeletonCard(),
      ],
    );
  }
}

class _FeedbackFormSkeleton extends StatelessWidget {
  const _FeedbackFormSkeleton();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      borderRadius: 22,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerCard(
            height: 18,
            width: 132,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          SizedBox(height: 8),
          ShimmerCard(
            height: 14,
            width: 116,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              ShimmerCard(
                height: 32,
                width: 118,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              SizedBox(width: 8),
              ShimmerCard(
                height: 32,
                width: 118,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ],
          ),
          SizedBox(height: 12),
          ShimmerCard(
            height: 56,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          SizedBox(height: 12),
          ShimmerCard(
            height: 92,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          SizedBox(height: 16),
          ShimmerCard(
            height: 48,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ],
      ),
    );
  }
}

class _FeedbackHistorySkeletonCard extends StatelessWidget {
  const _FeedbackHistorySkeletonCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              ShimmerCard(
                height: 16,
                width: 16,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ShimmerCard(
                  height: 16,
                  width: 156,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
              SizedBox(width: 12),
              ShimmerCard(
                height: 24,
                width: 72,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
            ],
          ),
          SizedBox(height: 10),
          ShimmerCard(
            height: 14,
            width: 188,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          SizedBox(height: 8),
          ShimmerCard(
            height: 54,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          SizedBox(height: 8),
          ShimmerCard(
            height: 12,
            width: 84,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ],
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
  bool _isQueueing = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _contentType() {
    if (_selectedFile == null) {
      return _mediaType == 'VIDEO' ? 'video/mp4' : 'image/jpeg';
    }
    return _feedbackContentType(_selectedFile!, _mediaType);
  }

  Future<void> _submit() async {
    if (_selectedFile == null) return;
    setState(() => _isQueueing = true);
    try {
      await sl<FeedbackUploadQueueService>().enqueue(
        file: _selectedFile!,
        contentType: _contentType(),
        mediaType: _mediaType,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        exerciseId: widget.exerciseId,
      );
      if (!mounted) return;
      setState(() => _selectedFile = null);
      _notesController.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).feedbackUploadFailed),
        ),
      );
    } finally {
      if (mounted) setState(() => _isQueueing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      borderRadius: 22,
      elevated: true,
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
            isUploading: _isQueueing,
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
              onPressed: (_isQueueing || _selectedFile == null)
                  ? null
                  : _submit,
              child: _isQueueing
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

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
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
              decoration: GlassDecoration.card(borderRadius: 12),
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
      decoration: GlassDecoration.accentCard(
        isReviewed ? AppColors.success : AppColors.warning,
        borderRadius: 999,
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
