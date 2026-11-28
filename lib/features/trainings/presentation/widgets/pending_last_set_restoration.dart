import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

/// Reads what the image picker could not deliver because Android destroyed
/// the activity while it was open (`ImagePicker().retrieveLostData`).
typedef LastSetLostVideoData = Future<LostDataResponse> Function();

/// The last set of the active exercise that is saved but still waiting for
/// its video (P-E3b-1), as kept in Android's saved instance state.
///
/// It is not attributed to anyone by itself: [ownerId] and [environment] are
/// checked against the current account before the page uses it. It holds no
/// token, only the account id, the set values and, at most, the path of the
/// video the picker recovered.
@immutable
class PendingLastSetEntry {
  const PendingLastSetEntry({
    required this.ownerId,
    required this.environment,
    required this.trainingId,
    required this.trainingExerciseId,
    required this.assignmentDate,
    required this.sessionId,
    required this.setNumber,
    required this.reps,
    required this.seconds,
    required this.weightKg,
    required this.rir,
    required this.skipped,
    this.picking = false,
    this.videoPath,
    this.videoLost = false,
  });

  static const int version = 1;

  final String ownerId;
  final String environment;
  final String trainingId;
  final String trainingExerciseId;
  final String assignmentDate;
  final String? sessionId;
  final int setNumber;
  final int? reps;
  final int? seconds;
  final double? weightKg;
  final int? rir;
  final bool skipped;

  /// The picker was open for this set when the state was saved.
  final bool picking;

  /// The video the picker recovered after the activity was recreated.
  final String? videoPath;

  /// The picker reported an error (or an unusable result, or no answer in
  /// time) when recovering.
  final bool videoLost;

  ({int? reps, int? seconds, double? weight, int? rir, bool skipped})
  get performance => (
    reps: reps,
    seconds: seconds,
    weight: weightKg,
    rir: rir,
    skipped: skipped,
  );

  /// Same account (id and environment) as [ownerId] / [environment].
  bool belongsTo(String? ownerId, String environment) =>
      ownerId != null &&
      ownerId == this.ownerId &&
      environment == this.environment;

  /// Same training, exercise, day and execution.
  bool isFor({
    required String trainingId,
    required String trainingExerciseId,
    required String assignmentDate,
    required String? sessionId,
  }) =>
      trainingId == this.trainingId &&
      trainingExerciseId == this.trainingExerciseId &&
      assignmentDate == this.assignmentDate &&
      sessionId == this.sessionId;

  /// Same account, exercise, execution and set as [other], whatever the
  /// picker state or the video.
  bool isSameSet(PendingLastSetEntry other) =>
      belongsTo(other.ownerId, other.environment) &&
      setNumber == other.setNumber &&
      isFor(
        trainingId: other.trainingId,
        trainingExerciseId: other.trainingExerciseId,
        assignmentDate: other.assignmentDate,
        sessionId: other.sessionId,
      );

  PendingLastSetEntry copyWith({
    bool? picking,
    String? videoPath,
    bool clearVideoPath = false,
    bool? videoLost,
  }) => PendingLastSetEntry(
    ownerId: ownerId,
    environment: environment,
    trainingId: trainingId,
    trainingExerciseId: trainingExerciseId,
    assignmentDate: assignmentDate,
    sessionId: sessionId,
    setNumber: setNumber,
    reps: reps,
    seconds: seconds,
    weightKg: weightKg,
    rir: rir,
    skipped: skipped,
    picking: picking ?? this.picking,
    videoPath: clearVideoPath ? null : videoPath ?? this.videoPath,
    videoLost: videoLost ?? this.videoLost,
  );

  Map<String, Object?> toJson() => {
    'v': version,
    'owner_id': ownerId,
    'environment': environment,
    'training_id': trainingId,
    'training_exercise_id': trainingExerciseId,
    'assignment_date': assignmentDate,
    'session_id': sessionId,
    'set_number': setNumber,
    'reps': reps,
    'seconds': seconds,
    'weight_kg': weightKg,
    'rir': rir,
    'skipped': skipped,
    'picking': picking,
    'video_path': videoPath,
    'video_lost': videoLost,
  };

  /// Null for anything that is not a version-1 entry.
  static PendingLastSetEntry? fromJson(Object? json) {
    if (json is! Map<String, Object?> || json['v'] != version) return null;
    final ownerId = json['owner_id'];
    final environment = json['environment'];
    final trainingId = json['training_id'];
    final trainingExerciseId = json['training_exercise_id'];
    final assignmentDate = json['assignment_date'];
    final sessionId = json['session_id'];
    final setNumber = json['set_number'];
    final reps = json['reps'];
    final seconds = json['seconds'];
    final weightKg = json['weight_kg'];
    final rir = json['rir'];
    final skipped = json['skipped'];
    final picking = json['picking'];
    final videoPath = json['video_path'];
    final videoLost = json['video_lost'];
    if (ownerId is! String ||
        environment is! String ||
        trainingId is! String ||
        trainingExerciseId is! String ||
        assignmentDate is! String ||
        (sessionId != null && sessionId is! String) ||
        setNumber is! int ||
        (reps != null && reps is! int) ||
        (seconds != null && seconds is! int) ||
        (weightKg != null && weightKg is! num) ||
        (rir != null && rir is! int) ||
        skipped is! bool ||
        picking is! bool ||
        (videoPath != null && videoPath is! String) ||
        videoLost is! bool) {
      return null;
    }
    return PendingLastSetEntry(
      ownerId: ownerId,
      environment: environment,
      trainingId: trainingId,
      trainingExerciseId: trainingExerciseId,
      assignmentDate: assignmentDate,
      sessionId: sessionId as String?,
      setNumber: setNumber,
      reps: reps as int?,
      seconds: seconds as int?,
      weightKg: (weightKg as num?)?.toDouble(),
      rir: rir as int?,
      skipped: skipped,
      picking: picking,
      videoPath: videoPath as String?,
      videoLost: videoLost,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PendingLastSetEntry && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

/// How the entries live in the saved instance state (one string).
///
/// Version 2 keeps one entry per account (owner id and environment), oldest
/// first: `{"v": 2, "entries": [...]}`, each entry in its version-1 form. A
/// version-1 value (a single entry, written by r1) is read as one entry. At
/// most [maxEntries] accounts are kept; writing a new one drops the oldest
/// (its set and the reference to its recovered clip, never the clip itself).
abstract final class PendingLastSetEntries {
  static const int version = 2;

  /// Enough for a phone shared by a few accounts while keeping the saved
  /// state (Android's `Bundle`) small.
  static const int maxEntries = 3;

  /// The entries in [raw], oldest first; malformed values or entries are
  /// left out.
  static List<PendingLastSetEntry> decode(String? raw) {
    if (raw == null) return const [];
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (json is! Map<String, Object?>) return const [];
    if (json['v'] == PendingLastSetEntry.version) {
      final entry = PendingLastSetEntry.fromJson(json);
      return entry == null ? const [] : [entry];
    }
    final entries = json['entries'];
    if (json['v'] != version || entries is! List<Object?>) return const [];
    return entries.map(PendingLastSetEntry.fromJson).nonNulls.toList();
  }

  /// Null when there is nothing to keep.
  static String? encode(List<PendingLastSetEntry> entries) => entries.isEmpty
      ? null
      : jsonEncode({
          'v': version,
          'entries': [for (final entry in entries) entry.toJson()],
        });

  /// [entry] as its account's only entry and the newest one; the oldest
  /// accounts beyond [maxEntries] are dropped.
  static List<PendingLastSetEntry> upsert(
    List<PendingLastSetEntry> entries,
    PendingLastSetEntry entry,
  ) {
    final next = [
      for (final other in entries)
        if (!other.belongsTo(entry.ownerId, entry.environment)) other,
      entry,
    ];
    return next.length > maxEntries
        ? next.sublist(next.length - maxEntries)
        : next;
  }
}

/// What the active exercise page reads and writes; see
/// [PendingLastSetRestoration]. One entry per account.
abstract class PendingLastSetStore {
  /// Every account's entry, oldest first.
  List<PendingLastSetEntry> get entries;

  /// The entry of the account [ownerId] in [environment], if any.
  PendingLastSetEntry? entryFor(String? ownerId, String environment);

  /// Completes once a lost video (if any was being picked) has been asked
  /// for after a restore: with the picker's answer or, after the store's
  /// recovery timeout, with the video counted as lost. An empty answer makes
  /// it wait for the app to be in the foreground and for the picker to
  /// answer (or its late-result window to end).
  Future<void> get settled;

  /// Makes [entry] its account's entry (and the newest one).
  void write(PendingLastSetEntry entry);

  /// Replaces [expected] with [next] (same account) only if it is still the
  /// stored entry. Only one entry can have the picker open: a [next] with
  /// `picking` closes it on the others.
  void replace(PendingLastSetEntry expected, PendingLastSetEntry next);

  /// Removes its account's entry if it is still for the same set.
  void remove(PendingLastSetEntry entry);
}

/// Waits for the engine's restoration data before the app is mounted
/// (P-E3b-1 r2).
///
/// `RootRestorationScope` asks the engine for the data and, until it comes
/// back (an asynchronous platform-channel answer on a device), defers the
/// first frame and builds nothing. Mounted after the bootstrap splash has
/// already drawn the first frame, deferring has no effect: the hand-off would
/// show an empty frame. Asked early with [start] and awaited with [ready]
/// before `runApp`, the restoration manager holds the data and hands it to
/// the scope synchronously (a `SynchronousFuture`), so its first build is
/// already the app.
class RestorationDataPreload {
  /// Starts asking the engine (once per process) for the restoration data.
  RestorationDataPreload.start([RestorationManager? manager]) {
    try {
      (manager ?? ServicesBinding.instance.restorationManager).rootBucket.then(
        (_) {
          _ready = true;
          _finish();
        },
        onError: (Object _) => _finish(),
      );
    } on Object {
      _finish();
    }
  }

  final Completer<void> _done = Completer<void>();
  bool _ready = false;

  /// The data has arrived: a root scope mounted now gets it synchronously.
  bool get isReady => _ready;

  void _finish() {
    if (!_done.isCompleted) _done.complete();
  }

  /// Whether the data is there, waiting at most [cap] for it. False (the
  /// engine did not answer in time, or failed): mount the app without
  /// restoration rather than with an empty frame.
  Future<bool> ready({Duration cap = const Duration(milliseconds: 300)}) async {
    if (_done.isCompleted) return _ready;
    try {
      await _done.future.timeout(cap);
    } on TimeoutException {
      return false;
    }
    return _ready;
  }
}

/// The app's bounded restoration (P-E3b-1): a root restoration scope with
/// only [PendingLastSetRestoration] under it. With [restorationReady] false
/// the scope has no id, so nothing waits for (or saves) restoration data and
/// the store keeps its entries in memory only.
class BoundedRestorationScope extends StatelessWidget {
  const BoundedRestorationScope({
    super.key,
    required this.restorationReady,
    required this.child,
    this.retrieveLostData,
  });

  /// [RestorationDataPreload.ready]: the data is already in the manager.
  final bool restorationReady;

  final Widget child;

  /// See [PendingLastSetRestoration.retrieveLostData].
  final LastSetLostVideoData? retrieveLostData;

  @override
  Widget build(BuildContext context) => RootRestorationScope(
    restorationId: restorationReady ? 'exom' : null,
    child: PendingLastSetRestoration(
      retrieveLostData: retrieveLostData,
      child: child,
    ),
  );
}

/// Bounded state restoration for P-E3b-1: keeps only the last set of the
/// active exercise that is waiting for its video, one per account, so that it
/// survives Android destroying the activity (or the process) while the camera
/// or the gallery is open. Nothing else is restored: the router and the pages
/// are not (`MaterialApp.router` has no `restorationScopeId`), so the app
/// still starts where it always does and the page applies the entry when it
/// is reopened.
///
/// It must sit under a `RootRestorationScope` with an id and above the
/// `MaterialApp`. When an entry restored with the picker open has no video
/// yet, [retrieveLostData] is called right away (before any other picker can
/// clear its cache) and the first answer it has is kept in that entry,
/// unattributed: the page decides whether it belongs to the current account.
/// An answer that takes longer than [recoveryTimeout] counts as a lost video
/// (the set is kept); a late answer is ignored. An empty answer is not final:
/// once the app is in the foreground (the picker may still be open over the
/// recreated activity until then) the picker is asked again for at most
/// [lateResultWindow], since the plugin stores the clip off the main thread.
class PendingLastSetRestoration extends StatefulWidget {
  const PendingLastSetRestoration({
    super.key,
    required this.child,
    this.retrieveLostData,
    this.restorationId = 'pending_last_set',
    this.recoveryTimeout = const Duration(seconds: 5),
    this.lateResultWindow = const Duration(seconds: 5),
    this.lateResultPollInterval = const Duration(milliseconds: 250),
  });

  final Widget child;

  /// Defaults to `ImagePicker().retrieveLostData`; tests pass a fake.
  final LastSetLostVideoData? retrieveLostData;

  final String restorationId;

  /// Longest wait for [retrieveLostData].
  final Duration recoveryTimeout;

  /// When the picker had nothing yet for an entry restored with it open: how
  /// long, once the app is in the foreground, the picker is asked again
  /// (every [lateResultPollInterval]) before nothing counts as a cancel.
  final Duration lateResultWindow;

  /// See [lateResultWindow].
  final Duration lateResultPollInterval;

  /// The store above [context], or null when there is none.
  static PendingLastSetStore? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_PendingLastSetScope>()?.store;

  @override
  State<PendingLastSetRestoration> createState() =>
      _PendingLastSetRestorationState();
}

class _PendingLastSetRestorationState extends State<PendingLastSetRestoration>
    with RestorationMixin, WidgetsBindingObserver
    implements PendingLastSetStore {
  final RestorableStringN _entries = RestorableStringN(null);
  Future<void> _settled = Future<void>.value();
  bool _recovering = false;

  /// Completes with true when the app resumes, or with false on dispose.
  Completer<bool>? _resumed;

  @override
  String? get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    // The key of r1 ('entry') is kept: it holds a v1 or a v2 value.
    registerForRestoration(_entries, 'entry');
    if (_recovering) return;
    // Only one entry can have the picker open; the newest wins.
    final picking = entries.where((e) => e.picking && e.videoPath == null);
    if (picking.isNotEmpty) _settled = _recoverLostVideo(picking.last);
  }

  @override
  void dispose() {
    _stopWaitingForResume(false);
    _entries.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _stopWaitingForResume(true);
  }

  void _stopWaitingForResume(bool resumed) {
    final waiter = _resumed;
    if (waiter == null) return;
    _resumed = null;
    WidgetsBinding.instance.removeObserver(this);
    waiter.complete(resumed);
  }

  /// True once the app is in the foreground; false if this state is
  /// disposed first (Android destroyed the activity again).
  Future<bool> _untilResumed() {
    if (!mounted) return SynchronousFuture<bool>(false);
    if (SchedulerBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return SynchronousFuture<bool>(true);
    }
    final waiter = _resumed;
    if (waiter != null) return waiter.future;
    final next = Completer<bool>();
    _resumed = next;
    WidgetsBinding.instance.addObserver(this);
    return next.future;
  }

  /// Nothing once disposed: [_entries] cannot be read (nor written) then.
  @override
  List<PendingLastSetEntry> get entries => mounted
      ? PendingLastSetEntries.decode(_entries.value)
      : const <PendingLastSetEntry>[];

  @override
  PendingLastSetEntry? entryFor(String? ownerId, String environment) {
    for (final entry in entries) {
      if (entry.belongsTo(ownerId, environment)) return entry;
    }
    return null;
  }

  @override
  Future<void> get settled => _settled;

  void _set(List<PendingLastSetEntry> entries) {
    if (!mounted) return;
    _entries.value = PendingLastSetEntries.encode(entries);
    // Restoration data reaches the engine at the end of a frame; a change
    // made outside one (an async recovery, a dispose) must not wait for the
    // next unrelated frame.
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  List<PendingLastSetEntry> _closePickerOnOthers(
    List<PendingLastSetEntry> entries,
    PendingLastSetEntry open,
  ) => [
    for (final entry in entries)
      if (entry.picking && !entry.belongsTo(open.ownerId, open.environment))
        entry.copyWith(picking: false)
      else
        entry,
  ];

  @override
  void write(PendingLastSetEntry entry) {
    if (!mounted) return;
    final next = PendingLastSetEntries.upsert(entries, entry);
    _set(entry.picking ? _closePickerOnOthers(next, entry) : next);
  }

  @override
  void replace(PendingLastSetEntry expected, PendingLastSetEntry next) {
    if (!mounted || !next.belongsTo(expected.ownerId, expected.environment)) {
      return;
    }
    final current = entries;
    final index = current.indexOf(expected);
    if (index < 0) return;
    final updated = [...current]..[index] = next;
    _set(next.picking ? _closePickerOnOthers(updated, next) : updated);
  }

  @override
  void remove(PendingLastSetEntry entry) {
    if (!mounted) return;
    final current = entries;
    final next = [
      for (final other in current)
        if (!other.isSameSet(entry)) other,
    ];
    if (next.length != current.length) _set(next);
  }

  /// The picker's lost data; null for an error or no answer in time.
  Future<LostDataResponse?> _askLostVideo() async {
    try {
      return await (widget.retrieveLostData ??
              ImagePicker().retrieveLostData)()
          .timeout(widget.recoveryTimeout);
    } on Object {
      return null;
    }
  }

  static bool _nothingYet(LostDataResponse? response) =>
      response != null &&
      response.exception == null &&
      (response.isEmpty || response.file == null);

  Future<void> _recoverLostVideo(PendingLastSetEntry entry) async {
    _recovering = true;
    try {
      var response = await _askLostVideo();
      // Disposed meanwhile (Android destroyed the activity again): the new
      // store asks for itself; this one neither waits nor writes.
      if (!mounted) return;
      // An empty answer is not final while the picker may still deliver:
      // - D1 (r3): the activity can come back while the picker is still open
      //   over it (the gallery's photo picker is a sheet, so relaunching the
      //   app recreates the activity under it). The plugin only stores the
      //   clip when the picker closes, delivering its result to the new
      //   activity, which then resumes. Until the app resumes the entry keeps
      //   the picker open (a new destruction asks again).
      // - F1 (r4): with an opaque picker (the camera, or GET_CONTENT on older
      //   Android) the activity resumes right after the result arrives, but
      //   the plugin stores the clip off the main thread, so the first answer
      //   can come before it.
      // Either way, once in the foreground the picker is asked every
      // [PendingLastSetRestoration.lateResultPollInterval] until
      // [PendingLastSetRestoration.lateResultWindow] has passed.
      if (_nothingYet(response)) {
        if (SchedulerBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
          if (!await _untilResumed() || !mounted) return;
          response = await _askLostVideo();
          if (!mounted) return;
        }
        var waited = Duration.zero;
        while (_nothingYet(response) && waited < widget.lateResultWindow) {
          await Future<void>.delayed(widget.lateResultPollInterval);
          waited += widget.lateResultPollInterval;
          if (!mounted) return;
          response = await _askLostVideo();
          if (!mounted) return;
        }
      }
      if (response == null || response.exception != null) {
        // An error, an exception or no answer in time: the video is lost,
        // the set is kept.
        replace(entry, entry.copyWith(picking: false, videoLost: true));
        return;
      }
      final file = response.file;
      if (response.isEmpty || file == null) {
        // Nothing was picked (the camera or the gallery was cancelled): only
        // the set stays.
        replace(entry, entry.copyWith(picking: false));
        return;
      }
      if (response.type != RetrieveType.video ||
          !File(file.path).existsSync()) {
        replace(entry, entry.copyWith(picking: false, videoLost: true));
        return;
      }
      replace(entry, entry.copyWith(picking: false, videoPath: file.path));
    } finally {
      _recovering = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      _PendingLastSetScope(store: this, child: widget.child);
}

class _PendingLastSetScope extends InheritedWidget {
  const _PendingLastSetScope({required this.store, required super.child});

  final PendingLastSetStore store;

  @override
  bool updateShouldNotify(_PendingLastSetScope oldWidget) =>
      store != oldWidget.store;
}
