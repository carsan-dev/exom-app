import 'dart:io';

import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';
import 'package:exom_app/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:exom_app/features/feedback/presentation/feedback_notice_snack_bars.dart';
import 'package:exom_app/features/feedback/presentation/inline_upload_status_scope.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_media_picker.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_upload_status.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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

/// Places a feedback form in its screen: [form] is the scrolling content (the
/// numbered questions) and [footer] the send action with its inline message.
typedef FeedbackFormLayout = Widget Function(Widget form, Widget footer);

/// Feedback screen (L5-C2, sketch «C1 · Feedback»): headline, the transfer
/// status of every queued upload pinned on top, the numbered questions, the
/// history with the coach reply and the send button in the pinned footer.
///
/// This screen's own events (history failure, a file that could not be
/// queued) are inline messages (D14-3). For a single exercise the page shows
/// every upload's state in line, so while it is the current route the
/// app-wide upload SnackBars stay hidden ([InlineUploadStatusScope]); the
/// circuit page closes right after queueing, so it keeps them.
class FeedbackPage extends StatefulWidget {
  final FeedbackPageArgs? args;

  const FeedbackPage({super.key, this.args});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  ModalRoute<Object?>? _route;

  bool get _isCircuit => widget.args?.isCircuit == true;

  bool _isCurrentRoute() => mounted && (_route?.isCurrent ?? false);

  late final bool _reportsInline = !_isCircuit;

  @override
  void initState() {
    super.initState();
    if (_reportsInline) {
      InlineUploadStatusScope.register(_isCurrentRoute);
      // A notice opened before entering would cover the footer; close the
      // feedback ones once, after the first frame (never during build).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FeedbackNoticeSnackBars.closeAll();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    if (_reportsInline) InlineUploadStatusScope.unregister(_isCurrentRoute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final args = widget.args;
    final title = _isCircuit ? l10n.circuitFeedbackTitle : l10n.feedback;
    final subtitle = _isCircuit ? null : args?.exercise?.exerciseName;

    return BlocProvider(
      create: (_) => sl<FeedbackBloc>()..add(const FeedbackLoadRequested()),
      child: ExomStaticBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // Sketch C1: the bar only carries «Volver»; the title is the body
          // headline.
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(ExomIcons.back, color: palette.textPrimary),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => context.pop(),
            ),
          ),
          body: FeedbackQueueLayout(
            queue: sl<FeedbackUploadQueueService>(),
            child: BlocBuilder<FeedbackBloc, FeedbackState>(
              builder: (context, state) {
                if (state is FeedbackLoading) {
                  return const _FeedbackLoadingBody();
                }
                final items = state is FeedbackLoaded
                    ? state.items
                    : <FeedbackEntity>[];
                Widget layout(Widget form, Widget footer) => _PageLayout(
                  header: _ScreenTitle(title: title, subtitle: subtitle),
                  message: _pageMessage(context, state),
                  form: form,
                  history: _History(
                    items: items,
                    showEmpty: state is FeedbackLoaded && state is! FeedbackError,
                  ),
                  footer: footer,
                );
                if (args != null && args.isCircuit) {
                  return CircuitFeedbackForm(
                    circuitName: args.circuitName ?? '',
                    targets: args.circuitExercises,
                    onQueued: () => context.pop(),
                    layout: layout,
                  );
                }
                return _FeedbackForm(
                  exerciseId: args?.exercise?.exerciseId,
                  layout: layout,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// This screen's bloc events in line (D14-3; they were SnackBars).
  Widget? _pageMessage(BuildContext context, FeedbackState state) {
    final l10n = AppLocalizations.of(context);
    if (state is FeedbackError) {
      return state.isOffline
          ? ExomInlineMessage(
              kind: ExomMessageKind.pendiente,
              title: l10n.feedbackOfflineMessage,
            )
          : ExomInlineMessage(
              kind: ExomMessageKind.error,
              title: localizedErrorTextOf(
                context,
                state.message,
                fallback: (l10n) => l10n.feedbackOperationError,
              ),
            );
    }
    if (state is FeedbackSubmitSuccess) {
      return ExomInlineMessage(
        kind: ExomMessageKind.ok,
        title: l10n.feedbackSentSuccessfully,
      );
    }
    return null;
  }
}

/// Scrolling body (headline, message, form, history) over the pinned footer.
class _PageLayout extends StatelessWidget {
  const _PageLayout({
    required this.header,
    required this.message,
    required this.form,
    required this.history,
    required this.footer,
  });

  final Widget header;
  final Widget? message;
  final Widget form;
  final Widget history;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final pageMessage = message;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: palette.textPrimary,
            backgroundColor: palette.surface,
            onRefresh: () async {
              context.read<FeedbackBloc>().add(const FeedbackLoadRequested());
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: ExomSpacing.xxl),
              children: [
                header,
                // Always present, so the form keeps its index (and its
                // state, the draft) when a message comes or goes.
                pageMessage == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          ExomSpacing.xl,
                          ExomSpacing.lg,
                          ExomSpacing.xl,
                          0,
                        ),
                        child: pageMessage,
                      ),
                const SizedBox(height: ExomSpacing.xxl),
                KeyedSubtree(key: const ValueKey('feedback-form'), child: form),
                history,
              ],
            ),
          ),
        ),
        SafeArea(top: false, child: footer),
      ],
    );
  }
}

TextStyle _secondaryStyle(BuildContext context) => TextStyle(
  fontFamily: AppTheme.bodyFontFamily,
  fontSize: 14,
  height: 1.35,
  color: context.exomPalette.textSecondary,
);

/// Screen headline (sketch `.t1`): Barlow Condensed 800 painted upper case,
/// one header node with the original text, then the secondary line.
class _ScreenTitle extends StatelessWidget {
  const _ScreenTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ExomSpacing.xl,
        ExomSpacing.sm,
        ExomSpacing.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
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
          if (subtitleText != null) ...[
            const SizedBox(height: ExomSpacing.sm),
            Text(subtitleText, style: _secondaryStyle(context)),
          ],
        ],
      ),
    );
  }
}

/// Send action of a form in the pinned footer, with this form's failure in
/// line above it (D14-3: it was a SnackBar).
class _FormFooter extends StatelessWidget {
  const _FormFooter({required this.button, required this.failed});

  final Widget button;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (failed) ...[
          ExomInlineMessage(
            kind: ExomMessageKind.error,
            title: AppLocalizations.of(context).feedbackUploadFailed,
          ),
          const SizedBox(height: ExomSpacing.md),
        ],
        button,
      ],
    );
  }
}

const EdgeInsetsGeometry _footerPadding = EdgeInsets.fromLTRB(
  ExomSpacing.xl,
  ExomSpacing.md,
  ExomSpacing.xl,
  ExomSpacing.md,
);

/// Notes answer of a question: the existing optional notes field.
class _NotesField extends StatelessWidget {
  const _NotesField({
    required this.controller,
    required this.enabled,
    required this.maxLines,
    this.hint,
  });

  final TextEditingController controller;
  final bool enabled;
  final int maxLines;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      style: TextStyle(
        fontFamily: AppTheme.bodyFontFamily,
        fontSize: 16,
        color: palette.textPrimary,
      ),
      decoration: InputDecoration(hintText: hint, alignLabelWithHint: true),
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

/// Circuit feedback (sketch C1 f): the circuit name and description, one
/// numbered question per exercise (video and optional note) and the plural
/// send button. Inside the feedback page the button sits in the pinned
/// footer ([layout]); without a [layout] (the missing-videos sheet of the
/// active circuit) it follows the questions.
class CircuitFeedbackForm extends StatefulWidget {
  final String circuitName;
  final List<FeedbackExerciseTarget> targets;
  final CircuitFeedbackEnqueue? enqueue;
  final VoidCallback? onQueued;
  final bool requireAll;
  final FeedbackFormLayout? layout;

  const CircuitFeedbackForm({
    super.key,
    required this.circuitName,
    required this.targets,
    this.enqueue,
    this.onQueued,
    this.requireAll = false,
    this.layout,
  });

  @override
  State<CircuitFeedbackForm> createState() => _CircuitFeedbackFormState();
}

class _CircuitFeedbackFormState extends State<CircuitFeedbackForm> {
  final String? _ownerSession = sl.isRegistered<LocalStorage>()
      ? sl<LocalStorage>().sessionStamp
      : null;
  final Map<String, File> _selectedFiles = {};
  final Map<String, TextEditingController> _notesControllers = {};
  bool _isQueueing = false;
  bool _failed = false;

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
      expectedSession: _ownerSession,
      file: upload.file,
      contentType: _feedbackContentType(upload.file, 'VIDEO'),
      mediaType: 'VIDEO',
      notes: upload.notes,
      exerciseId: upload.target.exerciseId,
    );
  }

  Future<void> _submit() async {
    if (_selectedFiles.isEmpty || _isQueueing) return;
    setState(() {
      _isQueueing = true;
      _failed = false;
    });

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
    setState(() {
      _isQueueing = false;
      _failed = failed > 0;
    });
    if (failed == 0) widget.onQueued?.call();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final selectedCount = _selectedFiles.length;
    final targets = widget.targets;

    final form = Padding(
      padding: const EdgeInsets.symmetric(horizontal: ExomSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.circuitName,
            style: TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: ExomSpacing.xs),
          Text(l10n.circuitFeedbackDescription, style: _secondaryStyle(context)),
          for (var i = 0; i < targets.length; i++) ...[
            const SizedBox(height: ExomSpacing.xxl),
            FeedbackQuestion(
              key: ValueKey('circuit-feedback-${targets[i].key}'),
              n: i + 1,
              label: targets[i].exerciseName,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FeedbackMediaPicker(
                    selectedFile: _selectedFiles[targets[i].key],
                    mediaType: 'VIDEO',
                    videoOnly: true,
                    isUploading: _isQueueing,
                    onMediaTypeChanged: (_) {},
                    onFileSelected: (file) => setState(() {
                      _selectedFiles[targets[i].key] = file;
                      _failed = false;
                    }),
                    onClear: () =>
                        setState(() => _selectedFiles.remove(targets[i].key)),
                  ),
                  const SizedBox(height: ExomSpacing.md),
                  _NotesField(
                    controller: _notesControllers[targets[i].key]!,
                    enabled: !_isQueueing,
                    maxLines: 2,
                    hint: l10n.additionalNotesOptional,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: ExomSpacing.xxl),
        ],
      ),
    );

    final button = ExomPrimaryButton(
      key: const ValueKey('send-circuit-feedback'),
      label: l10n.circuitFeedbackSendCount(selectedCount),
      busy: _isQueueing,
      onPressed:
          selectedCount == 0 ||
              (widget.requireAll && selectedCount != widget.targets.length)
          ? null
          : _submit,
    );
    final footer = _FormFooter(button: button, failed: _failed);

    final layout = widget.layout;
    if (layout != null) {
      return layout(form, ExomPinnedFooter(padding: _footerPadding, child: footer));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: ExomSpacing.lg),
        form,
        Padding(padding: _footerPadding, child: footer),
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

/// First load: skeletons with the shape of the headline, the questions and
/// the history rows.
class _FeedbackLoadingBody extends StatelessWidget {
  const _FeedbackLoadingBody();

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
        SizedBox(height: ExomSpacing.xxl),
        ExomSkeleton.row(),
        SizedBox(height: ExomSpacing.md),
        ExomSkeleton.row(),
        SizedBox(height: ExomSpacing.xxl),
        ExomSkeleton.rule(),
        SizedBox(height: ExomSpacing.md),
        ExomSkeleton.row(),
        SizedBox(height: ExomSpacing.md),
        ExomSkeleton.row(),
      ],
    );
  }
}

/// Single-exercise form (sketch C1): 01 evidence type, 02 file, 03 notes; the
/// send button in the pinned footer, off until there is a file.
class _FeedbackForm extends StatefulWidget {
  const _FeedbackForm({required this.layout, this.exerciseId});

  final String? exerciseId;
  final FeedbackFormLayout layout;

  @override
  State<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<_FeedbackForm> {
  final String? _ownerSession = sl.isRegistered<LocalStorage>()
      ? sl<LocalStorage>().sessionStamp
      : null;
  final _notesController = TextEditingController();
  String _mediaType = 'IMAGE';
  File? _selectedFile;
  bool _isQueueing = false;
  bool _failed = false;

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
    setState(() {
      _isQueueing = true;
      _failed = false;
    });
    try {
      await sl<FeedbackUploadQueueService>().enqueue(
        expectedSession: _ownerSession,
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
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _isQueueing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final form = Padding(
      padding: const EdgeInsets.symmetric(horizontal: ExomSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FeedbackMediaPicker(
            selectedFile: _selectedFile,
            mediaType: _mediaType,
            isUploading: _isQueueing,
            onMediaTypeChanged: (type) => setState(() {
              _mediaType = type;
              _selectedFile = null;
              _failed = false;
            }),
            onFileSelected: (file) => setState(() {
              _selectedFile = file;
              _failed = false;
            }),
            onClear: () => setState(() => _selectedFile = null),
          ),
          const SizedBox(height: ExomSpacing.xxl),
          FeedbackQuestion(
            n: 3,
            label: l10n.additionalNotesOptional,
            child: _NotesField(
              controller: _notesController,
              enabled: true,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );

    final button = ExomPrimaryButton(
      key: const ValueKey('send-feedback'),
      label: l10n.sendFeedback,
      busy: _isQueueing,
      onPressed: _selectedFile == null ? null : _submit,
    );
    return widget.layout(
      form,
      ExomPinnedFooter(
        padding: _footerPadding,
        child: _FormFooter(button: button, failed: _failed),
      ),
    );
  }
}

/// History (sketch C1 j): one flat row per sent feedback with its review
/// state and the coach reply ([ExomReplyBlock]); empty, «Sin feedback. /
/// Todavía.» with the existing sentence.
class _History extends StatelessWidget {
  const _History({required this.items, required this.showEmpty});

  final List<FeedbackEntity> items;
  final bool showEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (items.isEmpty) {
      if (!showEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: ExomSpacing.lg),
        child: ExomEmptyState(
          first: l10n.feedbackEmptyFirst,
          second: l10n.feedbackEmptySecond,
          lead: l10n.noFeedbackYet,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ExomSpacing.xl,
            ExomSpacing.xl,
            ExomSpacing.xl,
            ExomSpacing.md,
          ),
          child: Semantics(
            header: true,
            label: l10n.history,
            excludeSemantics: true,
            child: Text(
              l10n.history.toUpperCase(),
              style: ExomType.section.copyWith(
                color: context.exomPalette.textPrimary,
              ),
            ),
          ),
        ),
        for (final item in items)
          _FeedbackRow(key: ValueKey('feedback-row-${item.id}'), feedback: item),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: context.exomPalette.borderSoft,
                width: ExomRule.hairline,
              ),
            ),
          ),
          child: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({super.key, required this.feedback});

  final FeedbackEntity feedback;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final date = DateFormat(
      'dd MMM yyyy',
      Localizations.localeOf(context).languageCode,
    ).format(feedback.createdAt);
    final media = feedback.isVideo ? l10n.video : l10n.image;
    final notes = feedback.notes;
    final reply = feedback.adminResponse;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: palette.borderSoft, width: ExomRule.hairline),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ExomSpacing.xl,
          vertical: ExomSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              feedback.exerciseName ?? media,
              style: TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: ExomSpacing.xs),
            Text(
              '$date · ${media.toLowerCase()}',
              style: _secondaryStyle(context),
            ),
            const SizedBox(height: ExomSpacing.sm),
            _ReviewStatus(isReviewed: feedback.isReviewed),
            if (notes != null) ...[
              const SizedBox(height: ExomSpacing.sm),
              Text(
                notes,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFontFamily,
                  fontSize: 15,
                  height: 1.4,
                  color: palette.textPrimary,
                ),
              ),
            ],
            if (reply != null) ...[
              const SizedBox(height: ExomSpacing.md),
              ExomReplyBlock(text: reply, author: l10n.trainerReply),
            ],
          ],
        ),
      ),
    );
  }
}

/// «Revisado» with a check in the text colour (a state of the system, never
/// lime, D19); «Pendiente» with the amber clock. Icon and text, not colour.
class _ReviewStatus extends StatelessWidget {
  const _ReviewStatus({required this.isReviewed});

  final bool isReviewed;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final colour = isReviewed
        ? palette.textPrimary
        : context.exomSemantic.warning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: ExcludeSemantics(
            child: Icon(
              isReviewed ? ExomIcons.check : ExomIcons.time,
              size: MediaQuery.textScalerOf(context).scale(16),
              color: colour,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            isReviewed ? l10n.reviewed : l10n.pending,
            style: TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: colour,
            ),
          ),
        ),
      ],
    );
  }
}
