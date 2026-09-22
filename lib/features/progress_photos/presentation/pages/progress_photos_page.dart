import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/utils/operation_id.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/glass_app_bar.dart';
import 'package:exom_app/core/widgets/media_picker_error_dialog.dart';
import 'package:exom_app/features/progress_photos/domain/entities/progress_photo.dart';
import 'package:exom_app/features/progress_photos/domain/repositories/progress_photo_repository.dart';
import 'package:exom_app/features/progress_photos/presentation/progress_photo_queue.dart';
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

class LocalProgressPhotoPickerIntentStore implements ProgressPhotoPickerIntentStore {
  const LocalProgressPhotoPickerIntentStore(this._storage);
  final LocalStorage _storage;
  @override
  Map<String, dynamic>? get current => _storage.getProgressPhotoPickerIntent();
  @override
  Future<void> save(Map<String, dynamic> intent) => _storage.saveProgressPhotoPickerIntent(intent);
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
    _queue = widget.queue ??
        ProgressPhotoQueueAdapter(sl<ProgressPhotoUploadQueueService>());
    _sessionStamp = widget.sessionStamp ?? () => sl<LocalStorage>().sessionStamp;
    _picker = widget.pickImage ?? (source) => ImagePicker().pickImage(source: source);
    _retrieveLostData = widget.retrieveLostData ?? ImagePicker().retrieveLostData;
    _pickerIntentStore = widget.pickerIntentStore ??
        (sl.isRegistered<LocalStorage>() ? LocalProgressPhotoPickerIntentStore(sl<LocalStorage>()) : null);
    final pollInterval = widget.queuePollInterval;
    if (pollInterval != null) {
      _queueRefresh = Timer.periodic(pollInterval, (_) => _syncScope());
    }
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostPickerData());
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
      if (newConfirmations) unawaited(_load());
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

  bool _samePending(List<Map<String, dynamic>> left, List<Map<String, dynamic>> right) =>
      left.length == right.length &&
      left.asMap().entries.every((entry) => entry.value.toString() == right[entry.key].toString());

  Future<void> _load() async {
    final expected = _sessionStamp();
    if (expected == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) {
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
        _nextPage = history.nextPage;
        _pending = _queue.pendingItems;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || _sessionStamp() != expected) return;
      setState(() {
        _loadedSession = expected;
        _error = error;
        _pending = _queue.pendingItems;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final expected = _loadedSession;
    final page = _nextPage;
    if (expected == null || page == null || _loadingMore || _sessionStamp() != expected) return;
    setState(() => _loadingMore = true);
    try {
      final history = await _repository.getHistory(page: page, limit: 20);
      if (!mounted || _sessionStamp() != expected) return;
      final known = _sessions.map((item) => item.id).toSet();
      final merged = [..._sessions, ...history.sessions.where((item) => known.add(item.id))];
      setState(() {
        _sessions = retainNewestProgressPhotoSessions(
          merged,
          maximum: _retainedPages * 20,
        );
        _nextPage = history.nextPage;
      });
    } on Object catch (error) {
      if (mounted && _sessionStamp() == expected) setState(() => _error = error);
    } finally {
      if (mounted && _sessionStamp() == expected) setState(() => _loadingMore = false);
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
        _sessions = [created, ..._sessions.where((item) => item.id != created.id)];
      });
    } on Object {
      if (!mounted || _sessionStamp() != expected) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).progressPhotosCreateError)),
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
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt_outlined), title: Text(l10n.progressPhotosCamera), onTap: () => Navigator.pop(dialogContext, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(l10n.progressPhotosGallery), onTap: () => Navigator.pop(dialogContext, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null || !mounted || _sessionStamp() != expected) return;
    await _pickAndQueue(session, view, source, expected, replacement: replacement);
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
          file: File(picked.path), civilSessionDate: session.sessionDate,
          canonicalView: view.apiValue, contentType: _contentType(picked.path),
          resolvedSessionId: session.id, replacesPhotoId: replacement?.id,
          expectedSession: expected,
        );
        if (!mounted || _sessionStamp() != expected) return;
        await _pickerIntentStore?.clear();
        setState(() => _pending = _queue.pendingItems);
        return;
      } on Object catch (error) {
        if (!mounted || _sessionStamp() != expected) return;
        final action = await showMediaPickerErrorDialog(context, error,
          canUseGallery: selectedSource != ImageSource.gallery);
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
    if (intent == null || expected == null || intent['session_stamp'] != expected) return;

    late LostDataResponse response;
    try {
      response = await _retrieveLostData();
    } on Object {
      await _retainLostPickerIntent(intent, expected, state: 'recovery_error', showError: true);
      return;
    }
    if (!mounted || _sessionStamp() != expected) return;
    final file = response.file;
    if (file == null) {
      await _retainLostPickerIntent(
        intent,
        expected,
        state: response.exception == null ? 'recovery_required' : 'recovery_error',
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
        file: File(file.path), civilSessionDate: intent['civil_session_date'] as String,
        canonicalView: intent['view'] as String, contentType: _contentType(file.path),
        resolvedSessionId: intent['session_id'] as String,
        replacesPhotoId: replacementId, expectedSession: expected,
      );
      if (!mounted || _sessionStamp() != expected) return;
      await _pickerIntentStore?.clear();
      setState(() => _pending = _queue.pendingItems);
    } on Object {
      await _retainLostPickerIntent(intent, expected, state: 'recovery_error', showError: true);
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
      SnackBar(content: Text(AppLocalizations.of(context).progressPhotosRecoveryError)),
    );
  }

  Future<bool> _confirmReplacement(String canonicalView) async {
    final l10n = AppLocalizations.of(context);
    final viewLabel = _views
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
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.progressPhotosReplaceConfirm)),
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
    if (expected == null || id == null || sessionId == null || view == null) return;

    ProgressPhotoSession session;
    try {
      session = await _repository.getSession(sessionId);
    } on Object {
      return;
    }
    if (!mounted || _sessionStamp() != expected) return;
    final active = session.photos.where((photo) => photo.view == view).firstOrNull;
    if (active == null) return;

    final l10n = AppLocalizations.of(context);
    final approved = await showDialog<bool>(
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
    final approved = await showDialog<bool>(
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

  int _comparePendingPriority(Map<String, dynamic> left, Map<String, dynamic> right) {
    final leftActionable = _isActionable(left);
    final rightActionable = _isActionable(right);
    if (leftActionable != rightActionable) return leftActionable ? 1 : -1;

    final queuedAt = _compareQueuedAt(left, right);
    if (queuedAt != 0) return queuedAt;

    return (left['id'] as String? ?? '').compareTo(right['id'] as String? ?? '');
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
    return ExomStaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(
          title: Text(AppLocalizations.of(context).progressPhotosTitle, style: TextStyle(color: context.exomPalette.textPrimary, fontWeight: FontWeight.w700)),
          actions: [
            IconButton(tooltip: l10n.progressPhotosRefresh, onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          tooltip: l10n.progressPhotosCreateSession,
          onPressed: _createSession,
          icon: const Icon(Icons.add),
          label: Text(AppLocalizations.of(context).progressPhotosNewSession),
        ),
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) return Center(child: Text(l10n.progressPhotosLoading));
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.progressPhotosLoadError),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: Text(l10n.progressPhotosRetry)),
          ],
        ),
      );
    }
    if (_sessions.isEmpty) {
      return Center(child: Text(l10n.progressPhotosEmpty));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _sessions.length + (_nextPage == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (index == _sessions.length) {
            return Center(
              child: OutlinedButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: Text(_loadingMore ? l10n.progressPhotosLoadingMore : l10n.progressPhotosLoadMore),
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
  final Map<String, dynamic>? Function(String sessionId, String view) pendingFor;
  final Future<void> Function(ProgressPhotoSession session, _CanonicalView view, {ProgressPhoto? replacement}) onAdd;
  final Future<void> Function(Map<String, dynamic> item) onRetry;
  final Future<void> Function(Map<String, dynamic> item) onReviewReplacement;
  final Future<void> Function(Map<String, dynamic> item) onDiscard;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final date = DateTime.tryParse(session.sessionDate);
    final dateText = date == null ? session.sessionDate : DateFormat('d MMM yyyy', Localizations.localeOf(context).toLanguageTag()).format(date);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: GlassDecoration.card(borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(dateText, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w700))),
              Text(session.isComplete ? AppLocalizations.of(context).progressPhotosComplete : AppLocalizations.of(context).progressPhotosIncomplete, style: TextStyle(color: palette.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 0.88,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: views.map((view) {
              final active = session.photos.where((photo) => photo.view == view.apiValue).firstOrNull;
              return _ViewTile(
                session: session,
                view: view,
                active: active,
                pending: pendingFor(session.id, view.apiValue),
                onAdd: onAdd,
                onRetry: onRetry,
                onReviewReplacement: onReviewReplacement,
                onDiscard: onDiscard,
              );
            }).toList(growable: false),
          ),
        ],
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
    required this.onAdd,
    required this.onRetry,
    required this.onReviewReplacement,
    required this.onDiscard,
  });

  final ProgressPhotoSession session;
  final _CanonicalView view;
  final ProgressPhoto? active;
  final Map<String, dynamic>? pending;
  final Future<void> Function(ProgressPhotoSession session, _CanonicalView view, {ProgressPhoto? replacement}) onAdd;
  final Future<void> Function(Map<String, dynamic> item) onRetry;
  final Future<void> Function(Map<String, dynamic> item) onReviewReplacement;
  final Future<void> Function(Map<String, dynamic> item) onDiscard;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final viewLabel = view.label(l10n);
    final status = _status(l10n, pending);
    final staleReplacement = _isStaleReplacement(pending);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: GlassDecoration.elevated(borderRadius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(viewLabel, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Expanded(
            child: active == null
                ? Center(child: Text(status ?? l10n.progressPhotosMissing, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary)))
                : Semantics(
                    button: true,
                    label: l10n.progressPhotosEnlarge(viewLabel),
                    child: InkWell(
                      onTap: () => _showEnlarged(context, active!, view),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: active!.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorWidget: (_, _, _) => Icon(view.icon, color: palette.textSecondary),
                        ),
                      ),
                    ),
                  ),
          ),
          if (active != null) ...[
            IconButton(
              tooltip: l10n.progressPhotosEnlarge(viewLabel),
              icon: const Icon(Icons.zoom_in),
              onPressed: () => _showEnlarged(context, active!, view),
            ),
            TextButton(
              onPressed: () => onAdd(session, view, replacement: active),
              child: Text(l10n.progressPhotosReplace(viewLabel)),
            ),
          ] else
            TextButton(onPressed: () => onAdd(session, view), child: Text(l10n.progressPhotosAdd(viewLabel))),
          if (pending?['status'] == 'failed') ...[
            if (staleReplacement)
              TextButton(
                onPressed: () => onReviewReplacement(pending!),
                child: Text(l10n.progressPhotosReviewReplacement),
              )
            else
              TextButton(
                onPressed: () => onRetry(pending!),
                child: Text(l10n.retry),
              ),
            TextButton(
              onPressed: () => onDiscard(pending!),
              child: Text(l10n.progressPhotosDiscard),
            ),
          ],
          if (status != null) Text(status, style: TextStyle(color: palette.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  bool _isStaleReplacement(Map<String, dynamic>? item) {
    final error = item?['last_error'] as String? ?? '';
    return error.contains('STALE') || error.contains('409');
  }

  String? _status(AppLocalizations l10n, Map<String, dynamic>? item) {
    if (item == null) return null;
    if (_isStaleReplacement(item)) return l10n.progressPhotosConflict;
    switch (item['status']) {
      case 'staging':
      case 'queued':
        return l10n.progressPhotosPending;
      case 'processing':
        return l10n.progressPhotosSynchronizing;
      case 'completed':
        return item['cleanup_pending'] == true
            ? l10n.progressPhotosConfirmedCleanup
            : l10n.progressPhotosConfirmed;
      case 'failed':
        return l10n.progressPhotosFailed;
      default:
        return l10n.progressPhotosPending;
    }
  }

  void _showEnlarged(BuildContext context, ProgressPhoto photo, _CanonicalView view) {
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
          body: Center(child: InteractiveViewer(child: CachedNetworkImage(imageUrl: photo.imageUrl, fit: BoxFit.contain))),
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
