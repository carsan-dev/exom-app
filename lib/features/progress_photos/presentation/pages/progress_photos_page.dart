import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/utils/operation_id.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_index_list.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/core/widgets/media_picker_error_dialog.dart';
import 'package:exom_app/features/progress_photos/domain/entities/progress_photo.dart';
import 'package:exom_app/features/home/presentation/widgets/home_headline.dart';
import 'package:exom_app/features/progress_photos/domain/repositories/progress_photo_repository.dart';
import 'package:exom_app/features/progress_photos/presentation/progress_photo_queue.dart';
import 'package:exom_app/features/progress_photos/presentation/progress_photo_upload_state.dart';
import 'package:exom_app/features/progress_photos/services/progress_photo_upload_queue_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

typedef ProgressPhotoPicker = Future<XFile?> Function(ImageSource source);
typedef ProgressPhotoLostData = Future<LostDataResponse> Function();

abstract interface class ProgressPhotoPickerIntentStore {
  Map<String, dynamic>? get current;
  Future<void> save(Map<String, dynamic> intent);
  Future<void> clear();
}

class LocalProgressPhotoPickerIntentStore
    implements ProgressPhotoPickerIntentStore {
  const LocalProgressPhotoPickerIntentStore(this._storage);
  final LocalStorage _storage;
  @override
  Map<String, dynamic>? get current => _storage.getProgressPhotoPickerIntent();
  @override
  Future<void> save(Map<String, dynamic> intent) =>
      _storage.saveProgressPhotoPickerIntent(intent);
  @override
  Future<void> clear() => _storage.clearProgressPhotoPickerIntent();
}

class ProgressPhotosPage extends StatefulWidget {
  const ProgressPhotosPage({
    super.key,
    this.repository,
    this.queue,
    this.sessionStamp,
    this.pickImage,
    this.retrieveLostData,
    this.pickerIntentStore,
    this.queuePollInterval = const Duration(seconds: 1),
  });

  final ProgressPhotoRepository? repository;
  final ProgressPhotoQueue? queue;
  final String? Function()? sessionStamp;
  final ProgressPhotoPicker? pickImage;
  final ProgressPhotoLostData? retrieveLostData;
  final ProgressPhotoPickerIntentStore? pickerIntentStore;
  final Duration? queuePollInterval;

  @override
  State<ProgressPhotosPage> createState() => _ProgressPhotosPageState();
}

class _ProgressPhotosPageState extends State<ProgressPhotosPage> {
  static const _views = <_CanonicalView>[
    _CanonicalView('FRONT', ExomIcons.profile),
    _CanonicalView('LEFT', ExomIcons.turnLeft),
    _CanonicalView('RIGHT', ExomIcons.turnRight),
    _CanonicalView('BACK', ExomIcons.body),
  ];

  late final ProgressPhotoRepository _repository;
  late final ProgressPhotoQueue _queue;
  late final String? Function() _sessionStamp;
  late final ProgressPhotoPicker _picker;
  late final ProgressPhotoLostData _retrieveLostData;
  ProgressPhotoPickerIntentStore? _pickerIntentStore;
  Timer? _queueRefresh;
  String? _loadedSession;
  List<ProgressPhotoSession> _sessions = const [];
  List<Map<String, dynamic>> _pending = const [];
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  int? _nextPage;
  static const _retainedPages = 3;
  final Set<String> _confirmedQueueIds = <String>{};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? sl<ProgressPhotoRepository>();
    _queue =
        widget.queue ??
        ProgressPhotoQueueAdapter(sl<ProgressPhotoUploadQueueService>());
    _sessionStamp =
        widget.sessionStamp ?? () => sl<LocalStorage>().sessionStamp;
    _picker =
        widget.pickImage ?? (source) => ImagePicker().pickImage(source: source);
    _retrieveLostData =
        widget.retrieveLostData ?? ImagePicker().retrieveLostData;
    _pickerIntentStore =
        widget.pickerIntentStore ??
        (sl.isRegistered<LocalStorage>()
            ? LocalProgressPhotoPickerIntentStore(sl<LocalStorage>())
            : null);
    final pollInterval = widget.queuePollInterval;
    if (pollInterval != null) {
      _queueRefresh = Timer.periodic(pollInterval, (_) => _syncScope());
    }
    _load();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _recoverLostPickerData(),
    );
  }

  @override
  void dispose() {
    _queueRefresh?.cancel();
    super.dispose();
  }

  void _syncScope() {
    final current = _sessionStamp();
    if (current == _loadedSession) {
      final pending = _queue.pendingItems;
      final newConfirmations = pending
          .where(_hasDurableAssociationConfirmation)
          .map((item) => item['id'] as String?)
          .whereType<String>()
          .where(_confirmedQueueIds.add)
          .isNotEmpty;
      if (mounted && !_samePending(pending, _pending)) {
        setState(() => _pending = pending);
      }
      // Do not query the remote history while bytes are only staged/uploading.
      // A confirmed association is the durable boundary after which the server
      // can safely become the visual source for the active view.
      if (newConfirmations) unawaited(_load(background: true));
      return;
    }
    if (mounted) {
      setState(() {
        _sessions = const [];
        _pending = const [];
        _error = null;
        _loading = true;
        _loadingMore = false;
        _nextPage = null;
        _loadedSession = null;
        _confirmedQueueIds.clear();
      });
    }
    _load();
  }

  bool _hasDurableAssociationConfirmation(Map<String, dynamic> item) =>
      item['status'] == 'completed' &&
      (item['association_checkpoint'] as Map?)?['state'] == 'confirmed';

  bool _samePending(
    List<Map<String, dynamic>> left,
    List<Map<String, dynamic>> right,
  ) =>
      left.length == right.length &&
      left.asMap().entries.every(
        (entry) => entry.value.toString() == right[entry.key].toString(),
      );

  Future<void> _load({bool background = false}) async {
    final expected = _sessionStamp();
    if (expected == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted && !background) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final history = await _repository.getHistory(page: 1, limit: 20);
      if (!mounted || _sessionStamp() != expected) return;
      setState(() {
        _loadedSession = expected;
        _sessions = history.sessions;
        _error = null;
        _nextPage = history.nextPage;
        _pending = _queue.pendingItems;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || _sessionStamp() != expected) return;
      setState(() {
        _loadedSession = expected;
        if (!background) _error = error;
        _pending = _queue.pendingItems;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final expected = _loadedSession;
    final page = _nextPage;
    if (expected == null ||
        page == null ||
        _loadingMore ||
        _sessionStamp() != expected) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final history = await _repository.getHistory(page: page, limit: 20);
      if (!mounted || _sessionStamp() != expected) return;
      final known = _sessions.map((item) => item.id).toSet();
      final merged = [
        ..._sessions,
        ...history.sessions.where((item) => known.add(item.id)),
      ];
      setState(() {
        _sessions = retainNewestProgressPhotoSessions(
          merged,
          maximum: _retainedPages * 20,
        );
        _nextPage = history.nextPage;
      });
    } on Object catch (error) {
      if (mounted && _sessionStamp() == expected) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && _sessionStamp() == expected) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _createSession() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) return;
    final expected = _sessionStamp();
    if (expected == null) return;
    final civilDate = DateFormat('yyyy-MM-dd').format(selected);
    try {
      final created = await _repository.createSession(
        civilDate: civilDate,
        operationId: newOperationId(),
      );
      if (!mounted || _sessionStamp() != expected) return;
      setState(() {
        _sessions = [
          created,
          ..._sessions.where((item) => item.id != created.id),
        ];
      });
    } on Object {
      if (!mounted || _sessionStamp() != expected) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).progressPhotosCreateError),
        ),
      );
    }
  }

  Future<void> _choosePhoto(
    ProgressPhotoSession session,
    _CanonicalView view, {
    ProgressPhoto? replacement,
  }) async {
    // Freeze target ownership before any UI await. A later callback cannot
    // repurpose a selection into whichever account is currently visible.
    final expected = _sessionStamp();
    if (expected == null) return;
    final l10n = AppLocalizations.of(context);
    // L5-F1 (L5-D21, sketch f1-origen): a straight EXOM sheet instead of the
    // AlertDialog. «Cancelar», a tap outside, back and a router location
    // change close it with null: no source is chosen and nothing is queued.
    // The picker opens only after the sheet is gone (showExomSheet waits for
    // its disposal), as it did after the dialog.
    final source = await showExomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => _SourceSheetContent(
        kicker: l10n.progressPhotosSourceKicker(
          view.label(l10n),
          progressPhotoSessionDateText(context, session.sessionDate),
        ),
        title: l10n.progressPhotosChooseSource,
        cameraLabel: l10n.progressPhotosCamera,
        galleryLabel: l10n.progressPhotosGallery,
        onCamera: () => Navigator.of(sheetContext).pop(ImageSource.camera),
        onGallery: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
      ),
      actions: [
        Builder(
          builder: (sheetContext) => ExomQuietButton(
            label: l10n.cancel,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ],
    );
    if (source == null || !mounted || _sessionStamp() != expected) return;
    await _pickAndQueue(
      session,
      view,
      source,
      expected,
      replacement: replacement,
    );
  }

  Future<void> _pickAndQueue(
    ProgressPhotoSession session,
    _CanonicalView view,
    ImageSource source,
    String expected, {
    ProgressPhoto? replacement,
  }) async {
    var selectedSource = source;
    while (mounted && _sessionStamp() == expected) {
      final intent = <String, dynamic>{
        'session_id': session.id,
        'civil_session_date': session.sessionDate,
        'view': view.apiValue,
        'replaces_photo_id': replacement?.id,
        'source': selectedSource.name,
        'state': 'picking',
      };
      try {
        // Durable intent is written before Android can destroy the activity.
        await _pickerIntentStore?.save(intent);
        if (!mounted || _sessionStamp() != expected) return;
        final picked = await _picker(selectedSource);
        if (!mounted || _sessionStamp() != expected) return;
        if (picked == null) {
          await _pickerIntentStore?.clear(); // Explicit cancellation/discard.
          return;
        }
        if (replacement != null) {
          if (_sessionStamp() != expected) return;
          final approved = await _confirmReplacement(view.apiValue);
          if (!approved || !mounted || _sessionStamp() != expected) {
            if (mounted && _sessionStamp() == expected) {
              await _pickerIntentStore?.clear();
            }
            return;
          }
        }
        await _queue.enqueue(
          file: File(picked.path),
          civilSessionDate: session.sessionDate,
          canonicalView: view.apiValue,
          contentType: _contentType(picked.path),
          resolvedSessionId: session.id,
          replacesPhotoId: replacement?.id,
          expectedSession: expected,
        );
        if (!mounted || _sessionStamp() != expected) return;
        await _pickerIntentStore?.clear();
        setState(() => _pending = _queue.pendingItems);
        return;
      } on Object catch (error) {
        if (!mounted || _sessionStamp() != expected) return;
        final action = await showMediaPickerErrorDialog(
          context,
          error,
          canUseGallery: selectedSource != ImageSource.gallery,
        );
        if (!mounted || _sessionStamp() != expected) return;
        if (action == MediaPickerRecoveryAction.gallery) {
          selectedSource = ImageSource.gallery;
        } else if (action != MediaPickerRecoveryAction.retry) {
          await _pickerIntentStore?.clear();
          return;
        }
      }
    }
  }

  Future<void> _recoverLostPickerData() async {
    final intent = _pickerIntentStore?.current;
    final expected = _sessionStamp();
    if (intent == null ||
        expected == null ||
        intent['session_stamp'] != expected) {
      return;
    }

    late LostDataResponse response;
    try {
      response = await _retrieveLostData();
    } on Object {
      await _retainLostPickerIntent(
        intent,
        expected,
        state: 'recovery_error',
        showError: true,
      );
      return;
    }
    if (!mounted || _sessionStamp() != expected) return;
    final file = response.file;
    if (file == null) {
      await _retainLostPickerIntent(
        intent,
        expected,
        state: response.exception == null
            ? 'recovery_required'
            : 'recovery_error',
        showError: response.exception != null,
      );
      return;
    }
    final replacementId = intent['replaces_photo_id'] as String?;
    if (replacementId != null) {
      // The recovered selection still needs the same explicit approval as a
      // normal replacement. Keep the original owner bound across the dialog.
      if (!mounted || _sessionStamp() != expected) return;
      final approved = await _confirmReplacement(intent['view'] as String);
      if (!approved || !mounted || _sessionStamp() != expected) {
        if (!approved && mounted && _sessionStamp() == expected) {
          await _pickerIntentStore?.clear();
        }
        return;
      }
    }
    try {
      await _queue.enqueue(
        file: File(file.path),
        civilSessionDate: intent['civil_session_date'] as String,
        canonicalView: intent['view'] as String,
        contentType: _contentType(file.path),
        resolvedSessionId: intent['session_id'] as String,
        replacesPhotoId: replacementId,
        expectedSession: expected,
      );
      if (!mounted || _sessionStamp() != expected) return;
      await _pickerIntentStore?.clear();
      setState(() => _pending = _queue.pendingItems);
    } on Object {
      await _retainLostPickerIntent(
        intent,
        expected,
        state: 'recovery_error',
        showError: true,
      );
    }
  }

  Future<void> _retainLostPickerIntent(
    Map<String, dynamic> intent,
    String expected, {
    required String state,
    required bool showError,
  }) async {
    if (!mounted || _sessionStamp() != expected) return;
    await _pickerIntentStore?.save({...intent, 'state': state});
    if (!mounted || _sessionStamp() != expected || !showError) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).progressPhotosRecoveryError),
      ),
    );
  }

  Future<bool> _confirmReplacement(String canonicalView) async {
    final l10n = AppLocalizations.of(context);
    final viewLabel =
        _views
            .where((view) => view.apiValue == canonicalView)
            .firstOrNull
            ?.label(l10n)
            .toLowerCase() ??
        canonicalView.toLowerCase();
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.progressPhotosReplaceTitle),
            content: Text(l10n.progressPhotosReplaceMessage(viewLabel)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.progressPhotosReplaceConfirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _contentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _retryPending(Map<String, dynamic> item) async {
    final expected = _sessionStamp();
    final id = item['id'] as String?;
    if (expected == null || id == null) return;
    await _queue.retry(id);
    if (!mounted || _sessionStamp() != expected) return;
    setState(() => _pending = _queue.pendingItems);
  }

  Future<void> _reviewReplacement(Map<String, dynamic> item) async {
    final expected = _sessionStamp();
    final id = item['id'] as String?;
    final sessionId = item['session_id'] as String?;
    final view = item['view'] as String?;
    if (expected == null || id == null || sessionId == null || view == null) {
      return;
    }

    ProgressPhotoSession session;
    try {
      session = await _repository.getSession(sessionId);
    } on Object {
      return;
    }
    if (!mounted || _sessionStamp() != expected) return;
    final active = session.photos
        .where((photo) => photo.view == view)
        .firstOrNull;
    if (active == null) return;

    final l10n = AppLocalizations.of(context);
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.progressPhotosRebaseTitle),
            content: Text(l10n.progressPhotosRebaseMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.progressPhotosRebaseConfirm),
              ),
            ],
          ),
        ) ??
        false;
    if (!approved || !mounted || _sessionStamp() != expected) return;
    await _queue.rebaseReplacement(id, active.id);
    if (!mounted || _sessionStamp() != expected) return;
    setState(() => _pending = _queue.pendingItems);
  }

  Future<void> _discardPending(Map<String, dynamic> item) async {
    final expected = _sessionStamp();
    final id = item['id'] as String?;
    if (expected == null || id == null) return;
    final l10n = AppLocalizations.of(context);
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.progressPhotosDiscardTitle),
            content: Text(l10n.progressPhotosDiscardMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.progressPhotosDiscardConfirm),
              ),
            ],
          ),
        ) ??
        false;
    if (!approved || !mounted || _sessionStamp() != expected) return;
    await _queue.discard(id);
    if (!mounted || _sessionStamp() != expected) return;
    setState(() => _pending = _queue.pendingItems);
  }

  Map<String, dynamic>? _pendingFor(String sessionId, String view) {
    Map<String, dynamic>? selected;
    for (final item in _pending) {
      if (item['session_id'] != sessionId || item['view'] != view) continue;
      if (selected == null || _comparePendingPriority(item, selected) > 0) {
        selected = item;
      }
    }
    return selected;
  }

  int _comparePendingPriority(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final leftActionable = _isActionable(left);
    final rightActionable = _isActionable(right);
    if (leftActionable != rightActionable) return leftActionable ? 1 : -1;

    final queuedAt = _compareQueuedAt(left, right);
    if (queuedAt != 0) return queuedAt;

    return (left['id'] as String? ?? '').compareTo(
      right['id'] as String? ?? '',
    );
  }

  int _compareQueuedAt(Map<String, dynamic> left, Map<String, dynamic> right) {
    final leftQueuedAt = _queuedAt(left);
    final rightQueuedAt = _queuedAt(right);
    if (leftQueuedAt == null) return rightQueuedAt == null ? 0 : -1;
    if (rightQueuedAt == null) return 1;
    return leftQueuedAt.compareTo(rightQueuedAt);
  }

  DateTime? _queuedAt(Map<String, dynamic> item) {
    final value = item['queued_at'];
    return value is String ? DateTime.tryParse(value)?.toUtc() : null;
  }

  bool _isActionable(Map<String, dynamic> item) =>
      item['status'] != 'completed' || item['cleanup_pending'] == true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!_loading && _loadedSession != _sessionStamp()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncScope());
      return Scaffold(body: Center(child: Text(l10n.progressPhotosLoading)));
    }
    final palette = context.exomPalette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ExomStaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Sketch f1 (`.hdr-push`): the bar only carries «Volver» and the
        // reload action; the screen title is the first line of the body.
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: Icon(ExomIcons.back, color: palette.textPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            IconButton(
              tooltip: l10n.progressPhotosRefresh,
              onPressed: _load,
              icon: Icon(ExomIcons.retry, color: palette.textPrimary),
            ),
          ],
        ),
        body: KeyedSubtree(
          key: const Key('progress-photos-scroll'),
          child: _body(context),
        ),
        // L5-F1 (L5-D21): «Nueva sesión» leaves the floating button for the
        // pinned footer, visible in every state (list, empty, loading and
        // error) and outside the list, so it never covers «Cargar más» or the
        // last action. The one lime of the screen. In the Scaffold's bottom
        // slot (L5-F1 r2) so the floating SnackBars sit above it instead of
        // covering the button (the create error would hide its own retry).
        bottomNavigationBar: ExomPinnedFooter(
          key: const Key('progress-photos-footer'),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
          child: ExomPrimaryButton(
            key: const Key('progress-photos-new-session'),
            label: l10n.progressPhotosNewSession,
            trailingIcon: ExomIcons.add,
            onPressed: _createSession,
          ),
        ),
      ),
    );
  }

  /// Screen title (sketch `.t1`), the first line of every state.
  Widget _title(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    child: HomeTitle(AppLocalizations.of(context).progressPhotosTitle),
  );

  Widget _body(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    if (_loading) {
      // Skeleton with the shape of a session (sketch f1-carga-error); the
      // current loading text is its accessible label.
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _title(context),
          Semantics(
            container: true,
            label: l10n.progressPhotosLoading,
            child: const _SessionSkeleton(),
          ),
        ],
      );
    }
    if (_error != null) {
      // Load error, also without connection: in line with icon, red edge and
      // «Reintentar» (sketch f1-carga-error).
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _title(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: ExomInlineMessage(
              kind: ExomMessageKind.error,
              title: l10n.progressPhotosLoadError,
              actionLabel: l10n.progressPhotosRetry,
              onAction: _load,
            ),
          ),
        ],
      );
    }
    if (_sessions.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _title(context),
          const SizedBox(height: 16),
          ExomEmptyState(
            first: l10n.progressPhotosEmptyFirst,
            second: l10n.progressPhotosEmptySecond,
            body: l10n.progressPhotosEmpty,
          ),
        ],
      );
    }
    final hasMore = _nextPage != null;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: 1 + _sessions.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            // «Última sesión» is the newest session date, not the first of
            // the list: a session created with an older date is put first
            // until the next reload (L5-F1 r2).
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    l10n.progressPhotosLastSession(
                      progressPhotoSessionDateText(
                        context,
                        _newestSessionDate(_sessions),
                      ),
                    ),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFontFamily,
                      fontSize: 14,
                      height: 1.4,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: ExomTwoLineHeadline(
                    first: l10n.progressPhotosHeadlineFirst,
                    second: l10n.progressPhotosHeadlineSecond,
                  ),
                ),
              ],
            );
          }
          final sessionIndex = index - 1;
          if (sessionIndex == _sessions.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton(
                  onPressed: _loadingMore ? null : _loadMore,
                  child: Text(
                    _loadingMore
                        ? l10n.progressPhotosLoadingMore
                        : l10n.progressPhotosLoadMore,
                  ),
                ),
              ),
            );
          }
          return _SessionSection(
            n: sessionIndex + 1,
            session: _sessions[sessionIndex],
            views: _views,
            pendingFor: _pendingFor,
            onAdd: _choosePhoto,
            onRetry: _retryPending,
            onReviewReplacement: _reviewReplacement,
            onDiscard: _discardPending,
          );
        },
      ),
    );
  }
}

/// Date of a progress photo session (`yyyy-MM-dd`) as «18 nov 2026» in the
/// active locale; the raw value when it does not parse.
/// The newest `sessionDate` of [sessions] (civil dates `yyyy-MM-dd`, so the
/// string order is the date order). [sessions] must not be empty.
String _newestSessionDate(List<ProgressPhotoSession> sessions) => sessions
    .map((session) => session.sessionDate)
    .reduce((newest, date) => date.compareTo(newest) > 0 ? date : newest);

String progressPhotoSessionDateText(BuildContext context, String sessionDate) {
  final date = DateTime.tryParse(sessionDate);
  return date == null
      ? sessionDate
      : DateFormat(
          'd MMM yyyy',
          Localizations.localeOf(context).toLanguageTag(),
        ).format(date);
}

const double _viewGap = 12;
const double _viewRowGap = 20;

/// Columns of the views of a session (sketch `.f-views`: columns of at least
/// 9 em, at most two; one column when the text grows).
int _viewColumns(BuildContext context, double width) {
  final minColumn = MediaQuery.textScalerOf(context).scale(16) * 9;
  return width >= minColumn * 2 + _viewGap ? 2 : 1;
}

/// Lays out [children] in one or two columns of equal width; each child is
/// built with its column width.
class _ViewGrid extends StatelessWidget {
  const _ViewGrid({required this.width, required this.children});

  final double width;
  final List<Widget Function(double columnWidth)> children;

  @override
  Widget build(BuildContext context) {
    final columns = _viewColumns(context, width);
    final columnWidth = columns == 2 ? (width - _viewGap) / 2 : width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < children.length; index += columns) ...[
          if (index > 0) const SizedBox(height: _viewRowGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: _viewGap),
                SizedBox(
                  width: columnWidth,
                  child: index + c < children.length
                      ? children[index + c](columnWidth)
                      : null,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// Loading skeleton with the shape of a session: date and state lines and
/// four 3:4 views (sketch f1-carga-error).
///
/// Text lines and photo blocks are [ExomSkeleton.rule] given a tight box: the
/// rule fills the size it is given, so it keeps the shared colour and pulse.
class _SessionSkeleton extends StatelessWidget {
  const _SessionSkeleton();

  static Widget _line(double widthFactor, double height) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: FractionallySizedBox(
      widthFactor: widthFactor,
      child: SizedBox(height: height, child: const ExomSkeleton.rule()),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _line(0.4, 12.8),
          const SizedBox(height: 24),
          _line(0.6, 16),
          const SizedBox(height: 8),
          _line(0.4, 12.8),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) => _ViewGrid(
              width: constraints.maxWidth,
              children: [
                for (var i = 0; i < 4; i++)
                  (_) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _line(0.4, 12.8),
                      const SizedBox(height: 6),
                      const AspectRatio(
                        aspectRatio: 3 / 4,
                        child: ExomSkeleton.rule(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Content of the image source sheet (sketch f1-origen): the view and date as
/// kicker, the title, and the two sources as a numbered index.
class _SourceSheetContent extends StatelessWidget {
  const _SourceSheetContent({
    required this.kicker,
    required this.title,
    required this.cameraLabel,
    required this.galleryLabel,
    required this.onCamera,
    required this.onGallery,
  });

  final String kicker;
  final String title;
  final String cameraLabel;
  final String galleryLabel;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExomKicker(kicker),
              const SizedBox(height: ExomSpacing.xs),
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
            ],
          ),
        ),
        const SizedBox(height: 10),
        ExomIndexList(
          items: [
            ExomIndexItem(
              title: cameraLabel,
              icon: ExomIcons.camera,
              onTap: onCamera,
            ),
            ExomIndexItem(title: galleryLabel, onTap: onGallery),
          ],
        ),
      ],
    );
  }
}

/// One session: numbered header with the date and a rule, its state and the
/// four views, without boxes (sketch f1-lista).
class _SessionSection extends StatelessWidget {
  const _SessionSection({
    required this.n,
    required this.session,
    required this.views,
    required this.pendingFor,
    required this.onAdd,
    required this.onRetry,
    required this.onReviewReplacement,
    required this.onDiscard,
  });

  final int n;
  final ProgressPhotoSession session;
  final List<_CanonicalView> views;
  final Map<String, dynamic>? Function(String sessionId, String view)
  pendingFor;
  final Future<void> Function(
    ProgressPhotoSession session,
    _CanonicalView view, {
    ProgressPhoto? replacement,
  })
  onAdd;
  final Future<void> Function(Map<String, dynamic> item) onRetry;
  final Future<void> Function(Map<String, dynamic> item) onReviewReplacement;
  final Future<void> Function(Map<String, dynamic> item) onDiscard;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final dateText = progressPhotoSessionDateText(context, session.sessionDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExomNumberedSectionHeader(n: n, title: dateText),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            session.isComplete
                ? l10n.progressPhotosComplete
                : l10n.progressPhotosIncomplete,
            style: TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              color: palette.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: LayoutBuilder(
            builder: (context, constraints) => _ViewGrid(
              width: constraints.maxWidth,
              children: [
                for (final view in views)
                  (columnWidth) => _ViewTile(
                    key: Key(
                      'progress-photo-view-${session.id}-${view.apiValue}',
                    ),
                    session: session,
                    dateText: dateText,
                    view: view,
                    active: session.photos
                        .where((photo) => photo.view == view.apiValue)
                        .firstOrNull,
                    pending: pendingFor(session.id, view.apiValue),
                    tileWidth: columnWidth,
                    onAdd: onAdd,
                    onRetry: onRetry,
                    onReviewReplacement: onReviewReplacement,
                    onDiscard: onDiscard,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ViewTile extends StatelessWidget {
  const _ViewTile({
    super.key,
    required this.session,
    required this.dateText,
    required this.view,
    required this.active,
    required this.pending,
    required this.tileWidth,
    required this.onAdd,
    required this.onRetry,
    required this.onReviewReplacement,
    required this.onDiscard,
  });

  final ProgressPhotoSession session;
  final String dateText;
  final _CanonicalView view;
  final ProgressPhoto? active;
  final Map<String, dynamic>? pending;
  final double tileWidth;
  final Future<void> Function(
    ProgressPhotoSession session,
    _CanonicalView view, {
    ProgressPhoto? replacement,
  })
  onAdd;
  final Future<void> Function(Map<String, dynamic> item) onRetry;
  final Future<void> Function(Map<String, dynamic> item) onReviewReplacement;
  final Future<void> Function(Map<String, dynamic> item) onDiscard;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final viewLabel = view.label(l10n);
    final uploadState = progressPhotoUploadState(pending);
    final staleReplacement = uploadState == ProgressPhotoUploadState.conflict;
    final actionLabel = active != null
        ? l10n.progressPhotosReplace(viewLabel)
        : l10n.progressPhotosAdd(viewLabel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          viewLabel,
          style: TextStyle(
            fontFamily: AppTheme.bodyFontFamily,
            color: palette.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 6),
        // 3:4 at the full width of the column, square corners (`.x-thumb`).
        AspectRatio(
          key: Key('progress-photo-${session.id}-${view.apiValue}'),
          aspectRatio: 3 / 4,
          child: active == null
              ? _missingPhoto(
                  palette,
                  uploadState == null ? l10n.progressPhotosMissing : null,
                )
              : _photo(context, palette, l10n.progressPhotosEnlarge(viewLabel)),
        ),
        if (uploadState != null) ...[
          const SizedBox(height: 6),
          ProgressPhotoUploadStatus(
            key: Key('upload-status-${session.id}-${view.apiValue}'),
            state: uploadState,
          ),
        ],
        // Actions as 48 dp text links (`.f-acts`). The short visible label
        // keeps the full "Replace/Add <view>" text as accessible label and
        // tooltip.
        Wrap(
          spacing: 16,
          runSpacing: 0,
          children: [
            Tooltip(
              message: actionLabel,
              excludeFromSemantics: true,
              child: ExomTextLink(
                label: active != null
                    ? l10n.progressPhotosReplaceShort
                    : l10n.progressPhotosAddShort,
                semanticsLabel: actionLabel,
                icon: active != null ? null : ExomIcons.add,
                onTap: active != null
                    ? () => onAdd(session, view, replacement: active)
                    : () => onAdd(session, view),
              ),
            ),
            if (pending?['status'] == 'failed') ...[
              if (staleReplacement)
                ExomTextLink(
                  label: l10n.progressPhotosReviewReplacement,
                  onTap: () => onReviewReplacement(pending!),
                )
              else
                ExomTextLink(
                  label: l10n.retry,
                  semanticsLabel: l10n.progressPhotosRetryView(
                    viewLabel.toLowerCase(),
                  ),
                  onTap: () => onRetry(pending!),
                ),
              ExomTextLink(
                label: l10n.progressPhotosDiscard,
                semanticsLabel: l10n.progressPhotosDiscardView(
                  viewLabel.toLowerCase(),
                ),
                onTap: () => onDiscard(pending!),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// The active photo. Tapping it opens the viewer; there is no magnifier
  /// over it (L5-D21). The placeholder is the flat `raised` block of
  /// `.x-thumb`.
  Widget _photo(
    BuildContext context,
    ExomThemePalette palette,
    String enlargeLabel,
  ) {
    final photo = active!;
    return Tooltip(
      message: enlargeLabel,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: enlargeLabel,
        child: InkWell(
          onTap: () => _showEnlarged(context, photo),
          child: ClipRect(
            child: CachedNetworkImage(
              imageUrl: photo.imageUrl,
              useOldImageOnUrlChange: true,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              width: double.infinity,
              height: double.infinity,
              memCacheWidth:
                  (tileWidth * MediaQuery.devicePixelRatioOf(context)).round(),
              placeholder: (_, _) => ColoredBox(color: palette.surfaceElevated),
              errorWidget: (_, _, _) => ColoredBox(
                color: palette.surfaceElevated,
                child: Center(
                  child: Icon(view.icon, color: palette.textSecondary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Placeholder of a view without active photo: a 1 px rule outline and the
  /// camera icon (`.f-miss`). [message] is the "missing" text; it is null
  /// when the tile carries an upload status (shown under it), so the same
  /// state is never said twice.
  Widget _missingPhoto(ExomThemePalette palette, String? message) =>
      DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: palette.borderSoft),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(ExomIcons.camera, color: palette.textSecondary),
                ),
                if (message != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFontFamily,
                      color: palette.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );

  /// Full-screen viewer (sketch f1-visor): a minimal bar with the 48 dp close
  /// button, the view in Barlow and the session date under it; the photo to
  /// the edges with pinch zoom.
  void _showEnlarged(BuildContext context, ProgressPhoto photo) {
    final l10n = AppLocalizations.of(context);
    final viewLabel = view.label(l10n);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.exomPalette;
        return Dialog.fullscreen(
          key: const Key('progress-photos-viewer'),
          backgroundColor: palette.background,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 20, 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l10n.progressPhotosCloseImage,
                        constraints: const BoxConstraints(
                          minWidth: kExomMinTapTarget,
                          minHeight: kExomMinTapTarget,
                        ),
                        icon: Icon(ExomIcons.close, color: palette.textPrimary),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              header: true,
                              label: viewLabel,
                              excludeSemantics: true,
                              child: Text(
                                viewLabel.toUpperCase(),
                                style: ExomType.section.copyWith(
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateText,
                              style: TextStyle(
                                fontFamily: AppTheme.bodyFontFamily,
                                fontSize: 14,
                                height: 1.4,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    child: CachedNetworkImage(
                      imageUrl: photo.imageUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CanonicalView {
  const _CanonicalView(this.apiValue, this.icon);
  final String apiValue;
  final IconData icon;

  String label(AppLocalizations l10n) => switch (apiValue) {
    'FRONT' => l10n.progressPhotosFront,
    'LEFT' => l10n.progressPhotosLeft,
    'RIGHT' => l10n.progressPhotosRight,
    'BACK' => l10n.progressPhotosBack,
    _ => apiValue,
  };
}

List<ProgressPhotoSession> retainNewestProgressPhotoSessions(
  List<ProgressPhotoSession> sessions, {
  required int maximum,
}) => sessions.length > maximum ? sessions.sublist(0, maximum) : sessions;

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
