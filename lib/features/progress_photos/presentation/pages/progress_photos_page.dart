import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/utils/operation_id.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/glass_app_bar.dart';
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
    _CanonicalView('FRONT', Icons.person_outline),
    _CanonicalView('LEFT', Icons.turn_left),
    _CanonicalView('RIGHT', Icons.turn_right),
    _CanonicalView('BACK', Icons.accessibility_new_outlined),
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
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.progressPhotosChooseSource),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.progressPhotosCamera),
              onTap: () => Navigator.pop(dialogContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.progressPhotosGallery),
              onTap: () => Navigator.pop(dialogContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ExomStaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: Icon(Icons.arrow_back, color: palette.textPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            IconButton(
              tooltip: l10n.progressPhotosRefresh,
              onPressed: _load,
              icon: Icon(Icons.refresh, color: palette.textPrimary),
            ),
          ],
        ),
        // The one lime action of the screen (plan §6): carbon label, radius 4;
        // in the light theme a 1.5 px carbon border (lime is never text).
        floatingActionButton: FloatingActionButton.extended(
          tooltip: l10n.progressPhotosCreateSession,
          onPressed: _createSession,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: isDark
                ? BorderSide.none
                : const BorderSide(color: AppColors.textOnPrimary, width: 1.5),
          ),
          icon: const Icon(Icons.add),
          label: Text(
            l10n.progressPhotosNewSession,
            style: const TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: HomeTitle(l10n.progressPhotosTitle),
            ),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final message = TextStyle(
      color: palette.textSecondary,
      fontSize: 16,
      height: 1.4,
    );
    if (_loading) {
      return Center(child: Text(l10n.progressPhotosLoading, style: message));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.progressPhotosLoadError,
                textAlign: TextAlign.center,
                style: message,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _load,
                child: Text(l10n.progressPhotosRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (_sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            l10n.progressPhotosEmpty,
            textAlign: TextAlign.center,
            style: message,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: _sessions.length + (_nextPage == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (index == _sessions.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Center(
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
          return _SessionCard(
            session: _sessions[index],
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

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.views,
    required this.pendingFor,
    required this.onAdd,
    required this.onRetry,
    required this.onReviewReplacement,
    required this.onDiscard,
  });

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
    final date = DateTime.tryParse(session.sessionDate);
    final dateText = date == null
        ? session.sessionDate
        : DateFormat(
            'd MMM yyyy',
            Localizations.localeOf(context).toLanguageTag(),
          ).format(date);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.borderSoft, width: 1)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                dateText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.displayFontFamily,
                  color: palette.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              session.isComplete
                  ? l10n.progressPhotosComplete
                  : l10n.progressPhotosIncomplete,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 12.0;
                final tileWidth = (constraints.maxWidth - gap) / 2;
                final tiles = views
                    .map((view) {
                      final active = session.photos
                          .where((photo) => photo.view == view.apiValue)
                          .firstOrNull;
                      return _ViewTile(
                        session: session,
                        view: view,
                        active: active,
                        pending: pendingFor(session.id, view.apiValue),
                        tileWidth: tileWidth,
                        onAdd: onAdd,
                        onRetry: onRetry,
                        onReviewReplacement: onReviewReplacement,
                        onDiscard: onDiscard,
                      );
                    })
                    .toList(growable: false);
                // Rows of two tiles sized to their content: IntrinsicHeight
                // gives both tiles of a row the height of the taller one so
                // the actions line up at the bottom.
                return Column(
                  children: [
                    for (var index = 0; index < tiles.length; index += 2) ...[
                      if (index > 0) const SizedBox(height: gap),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: tiles[index]),
                            const SizedBox(width: gap),
                            Expanded(
                              child: index + 1 < tiles.length
                                  ? tiles[index + 1]
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewTile extends StatelessWidget {
  const _ViewTile({
    required this.session,
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

  // 48 px tap target (plan §6), DM Sans 14/600: no text below 13.
  static final _compactAction = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    minimumSize: const Size(kExomMinTapTarget, kExomMinTapTarget),
    tapTargetSize: MaterialTapTargetSize.padded,
    textStyle: const TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );

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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: palette.borderSoft, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              viewLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: active == null
                    ? _missingPhoto(
                        palette,
                        uploadState == null ? l10n.progressPhotosMissing : null,
                      )
                    : _photo(
                        context,
                        palette,
                        l10n.progressPhotosEnlarge(viewLabel),
                      ),
              ),
            ),
            if (uploadState != null) ...[
              const SizedBox(height: 8),
              ProgressPhotoUploadStatus(
                key: Key('upload-status-${session.id}-${view.apiValue}'),
                state: uploadState,
              ),
            ],
            const Spacer(),
            // Short visible label; the full "Replace/Add <view>" text stays the
            // accessible label and the tooltip.
            Tooltip(
              message: actionLabel,
              excludeFromSemantics: true,
              child: TextButton.icon(
                style: _compactAction,
                onPressed: active != null
                    ? () => onAdd(session, view, replacement: active)
                    : () => onAdd(session, view),
                icon: Icon(
                  active != null ? Icons.swap_horiz : Icons.add,
                  size: 18,
                ),
                label: Text(
                  active != null
                      ? l10n.progressPhotosReplaceShort
                      : l10n.progressPhotosAddShort,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  semanticsLabel: actionLabel,
                ),
              ),
            ),
            if (pending?['status'] == 'failed')
              Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [
                  if (staleReplacement)
                    TextButton(
                      style: _compactAction,
                      onPressed: () => onReviewReplacement(pending!),
                      child: Text(l10n.progressPhotosReviewReplacement),
                    )
                  else
                    TextButton(
                      style: _compactAction,
                      onPressed: () => onRetry(pending!),
                      child: Text(l10n.retry),
                    ),
                  TextButton(
                    style: _compactAction,
                    onPressed: () => onDiscard(pending!),
                    child: Text(l10n.progressPhotosDiscard),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

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
          onTap: () => _showEnlarged(context, photo, view),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: photo.imageUrl,
                useOldImageOnUrlChange: true,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                width: double.infinity,
                height: double.infinity,
                memCacheWidth:
                    (tileWidth * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                placeholder: (_, _) => ColoredBox(
                  color: palette.surface,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (_, _, _) => ColoredBox(
                  color: palette.surface,
                  child: Center(
                    child: Icon(view.icon, color: palette.textSecondary),
                  ),
                ),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: ExcludeSemantics(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0x8C000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.zoom_in,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Placeholder of a view without active photo. [message] is the "missing"
  /// text; it is null when the tile carries an upload status (shown under the
  /// photo), so the same state is never said twice.
  Widget _missingPhoto(ExomThemePalette palette, String? message) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: palette.borderSoft),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(view.icon, color: palette.textSecondary),
                ),
                if (message != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
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

  void _showEnlarged(
    BuildContext context,
    ProgressPhoto photo,
    _CanonicalView view,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: AppLocalizations.of(context).progressPhotosCloseImage,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            title: Text(view.label(AppLocalizations.of(context))),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: photo.imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
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
