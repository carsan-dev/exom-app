import 'dart:async';

import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/features/feedback/presentation/pages/pending_uploads_page.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Queue extends Fake implements FeedbackUploadQueueService {
  final events = StreamController<FeedbackUploadNotice>.broadcast();
  final item = <String, dynamic>{
    'id': 'retained-operation', 'exercise_id': 'squat',
    'assignment_date': '2026-09-05', 'media_type': 'VIDEO',
    'status': 'failed', 'last_error': 'private technical diagnostic',
  };
  String? retried;
  String? discarded;
  bool retryThrows = false;
  bool retryNoop = false;
  bool discardRemoves = true;
  bool removed = false;
  @override
  Stream<FeedbackUploadNotice> get notices => events.stream;
  @override
  List<Map<String, dynamic>> get pendingItems => removed ? [] : [item];
  @override
  FeedbackUploadNotice? progressOf(String id) => null;
  @override
  Future<void> discard(String id) async {
    discarded = id;
    if (discardRemoves) removed = true;
  }

  @override
  Future<void> retry(String id) async {
    if (retryThrows) throw StateError('queue unavailable');
    if (retryNoop) return;
    retried = id;
    item['status'] = 'completed';
    item['last_error'] = null;
    events.add(FeedbackUploadNotice(id, FeedbackUploadNoticeKind.completed));
  }
}

class _Storage extends LocalStorage {
  String stamp = 'owner:1:test';
  @override
  String? get sessionStamp => stamp;
}

class _Sync extends Fake implements OfflineSyncService {
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  List<Map<String, dynamic>> get pendingActions => [];
}

class _SyncWithFailure extends _Sync {
  _SyncWithFailure({
    this.status = 'failed',
    this.lastError = 'progress_conflict_review_required',
    this.discardRemoves = true,
  });
  final String status;
  final String? lastError;
  final bool discardRemoves;
  String? retried;
  String? discarded;
  bool removed = false;
  @override
  List<Map<String, dynamic>> get pendingActions => removed
      ? []
      : [
          {
            'id': 'sync-1',
            'status': status,
            'last_error': lastError,
            'attempts': 2,
          },
        ];
  @override
  Future<void> retryAction(String id) async => retried = id;
  @override
  Future<void> discardAction(String id) async {
    discarded = id;
    if (discardRemoves) removed = true;
  }
}

/// COLA (A): a queued action that waits for a video.
class _SyncWaitingForVideo extends _SyncWithFailure {
  _SyncWaitingForVideo(this.wait) : super(status: 'queued', lastError: null);
  final ProgressFeedbackWait wait;
  @override
  ProgressFeedbackWait? feedbackWaitOf(Map<String, dynamic> action) =>
      action['id'] == 'sync-1' ? wait : null;
}

Future<({_Queue queue, AppLocalizations l10n})> _pump(
  WidgetTester tester, {
  required String locale,
  OfflineSyncService? sync,
  bool retryThrows = false,
  bool retryNoop = false,
  bool discardRemoves = true,
}) async {
  await sl.reset();
  final queue = _Queue()
    ..retryThrows = retryThrows
    ..retryNoop = retryNoop
    ..discardRemoves = discardRemoves;
  sl.registerSingleton<LocalStorage>(_Storage());
  sl.registerSingleton<FeedbackUploadQueueService>(queue);
  sl.registerSingleton<OfflineSyncService>(sync ?? _Sync());
  addTearDown(() async {
    await queue.events.close();
    await sl.reset();
  });
  await tester.pumpWidget(MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const PendingUploadsPage(),
  ));
  await tester.pumpAndSettle();
  return (
    queue: queue,
    l10n: AppLocalizations.of(tester.element(find.byType(PendingUploadsPage))),
  );
}


/// Queue with a fixed list of rows and per-row progress (L5-C1b).
class _ListQueue extends Fake implements FeedbackUploadQueueService {
  _ListQueue(this.items, {this.progress = const {}});
  final List<Map<String, dynamic>> items;
  final Map<String, FeedbackUploadNotice> progress;
  final events = StreamController<FeedbackUploadNotice>.broadcast();
  @override
  Stream<FeedbackUploadNotice> get notices => events.stream;
  @override
  List<Map<String, dynamic>> get pendingItems => items;
  @override
  FeedbackUploadNotice? progressOf(String id) => progress[id];
}

Future<AppLocalizations> _pumpList(
  WidgetTester tester, {
  required String locale,
  required List<Map<String, dynamic>> items,
  Map<String, FeedbackUploadNotice> progress = const {},
}) async {
  await sl.reset();
  final queue = _ListQueue(items, progress: progress);
  sl.registerSingleton<LocalStorage>(_Storage());
  sl.registerSingleton<FeedbackUploadQueueService>(queue);
  sl.registerSingleton<OfflineSyncService>(_Sync());
  addTearDown(() async {
    await queue.events.close();
    await sl.reset();
  });
  await tester.pumpWidget(MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const PendingUploadsPage(),
  ));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(PendingUploadsPage)));
}

Map<String, dynamic> _row(String id, String status) => {
      'id': id,
      'media_type': 'IMAGE',
      'status': status,
    };

const _retryKey = Key('pending-retry-retained-operation');
const _deleteKey = Key('pending-delete-retained-operation');
const _confirmKey = Key('pending-delete-confirm');

void main() {
  for (final locale in ['es', 'en']) {
    group('L5-C1 $locale', () {
      testWidgets('retry that throws shows the result in line, no SnackBar',
          (tester) async {
        final env = await _pump(tester, locale: locale, retryThrows: true);
        await tester.tap(find.byKey(_retryKey));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(find.text(env.l10n.pendingRetryFailed), findsOneWidget);
      });

      testWidgets('retry that goes through shows the result in line',
          (tester) async {
        final env = await _pump(tester, locale: locale);
        await tester.tap(find.byKey(_retryKey));
        await tester.pumpAndSettle();
        expect(env.queue.retried, 'retained-operation');
        expect(find.byType(SnackBar), findsNothing);
        expect(find.text(env.l10n.pendingRetryRequested), findsOneWidget);
      });

      testWidgets('delete confirmation is a sheet, not a dialog; confirm runs '
          'the same discard and shows the result in line', (tester) async {
        final env = await _pump(tester, locale: locale);
        await tester.tap(find.byKey(_deleteKey));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byKey(_confirmKey), findsOneWidget);
        expect(find.text(env.l10n.pendingUploadDeleteMessage), findsOneWidget);
        expect(env.queue.discarded, isNull);
        await tester.tap(find.byKey(_confirmKey));
        await tester.pumpAndSettle();
        expect(env.queue.discarded, 'retained-operation');
        expect(find.byKey(_confirmKey), findsNothing);
        expect(find.text(env.l10n.pendingDeleteDone), findsOneWidget);
      });

      testWidgets('retry that changes nothing does not claim anything', (
        tester,
      ) async {
        final env = await _pump(tester, locale: locale, retryNoop: true);
        await tester.tap(find.byKey(_retryKey));
        await tester.pumpAndSettle();
        expect(find.text(env.l10n.pendingRetryNotStarted), findsOneWidget);
        expect(find.text(env.l10n.pendingRetryRequested), findsNothing);
      });

      testWidgets('retry result disappears once the row moves on', (
        tester,
      ) async {
        final env = await _pump(tester, locale: locale);
        env.queue.item['status'] = 'queued';
        await tester.tap(find.byKey(_retryKey));
        await tester.pumpAndSettle();
        expect(find.text(env.l10n.pendingRetryRequested), findsOneWidget);
        env.queue.item['status'] = 'uploading';
        env.queue.events.add(
          const FeedbackUploadNotice(
            'retained-operation',
            FeedbackUploadNoticeKind.uploading,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(env.l10n.pendingRetryRequested), findsNothing);
      });

      testWidgets('discard that leaves the evidence is not reported as '
          'deleted', (tester) async {
        final env = await _pump(tester, locale: locale, discardRemoves: false);
        await tester.tap(find.byKey(_deleteKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_confirmKey));
        await tester.pumpAndSettle();
        expect(env.queue.discarded, 'retained-operation');
        expect(find.text(env.l10n.pendingDeleteDone), findsNothing);
        expect(find.text(env.l10n.pendingDeleteIncomplete), findsOneWidget);
      });

      testWidgets('a new action clears the previous result', (tester) async {
        final env = await _pump(tester, locale: locale, retryNoop: true);
        await tester.tap(find.byKey(_retryKey));
        await tester.pumpAndSettle();
        expect(find.text(env.l10n.pendingRetryNotStarted), findsOneWidget);
        await tester.ensureVisible(find.byKey(_deleteKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_deleteKey));
        await tester.pumpAndSettle();
        expect(find.text(env.l10n.pendingRetryNotStarted), findsNothing);
      });

      for (final wait in ProgressFeedbackWait.values) {
        testWidgets('queued sync action explains its video wait ($wait)',
            (tester) async {
          final env = await _pump(tester,
              locale: locale, sync: _SyncWaitingForVideo(wait));
          await tester.scrollUntilVisible(
            find.byKey(const Key('pending-delete-sync-1')),
            200,
          );
          final texts = {
            ProgressFeedbackWait.ownVideo: env.l10n.pendingSyncWaitsOwnVideo,
            ProgressFeedbackWait.behindVideo:
                env.l10n.pendingSyncWaitsBehindVideo,
            ProgressFeedbackWait.behindDayVideo:
                env.l10n.pendingSyncWaitsBehindDayVideo,
          };
          expect(texts.keys, ProgressFeedbackWait.values);
          expect(texts.values.toSet(), hasLength(texts.length));
          for (final MapEntry(:key, :value) in texts.entries) {
            expect(find.text(value),
                key == wait ? findsOneWidget : findsNothing);
          }
          expect(find.text(env.l10n.pendingSyncFailedStatus), findsNothing);
        });
      }

      testWidgets('queued sync action keeps its error line', (tester) async {
        final sync = _SyncWithFailure(
          status: 'queued',
          lastError: 'some_unknown_code',
        );
        final env = await _pump(tester, locale: locale, sync: sync);
        await tester.scrollUntilVisible(
          find.byKey(const Key('pending-delete-sync-1')),
          200,
        );
        expect(find.text(env.l10n.pendingSyncFailedStatus), findsOneWidget);
      });

      testWidgets('sync discard that leaves the action is not reported as '
          'deleted', (tester) async {
        final sync = _SyncWithFailure(discardRemoves: false);
        final env = await _pump(tester, locale: locale, sync: sync);
        await tester.scrollUntilVisible(
          find.byKey(const Key('pending-delete-sync-1')),
          200,
        );
        await tester.ensureVisible(
          find.byKey(const Key('pending-delete-sync-1')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('pending-delete-sync-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_confirmKey));
        await tester.pumpAndSettle();
        expect(sync.discarded, 'sync-1');
        expect(find.text(env.l10n.pendingSyncDeleteDone), findsNothing);
        expect(find.text(env.l10n.pendingDeleteIncomplete), findsOneWidget);
      });

      testWidgets('cancelling the delete sheet discards nothing',
          (tester) async {
        final env = await _pump(tester, locale: locale);
        await tester.tap(find.byKey(_deleteKey));
        await tester.pumpAndSettle();
        await tester.tap(find.text(env.l10n.cancel));
        await tester.pumpAndSettle();
        expect(env.queue.discarded, isNull);
        expect(find.byKey(_confirmKey), findsNothing);
        expect(find.text(env.l10n.pendingDeleteDone), findsNothing);
      });

      testWidgets('sync failure: retry and delete keep their calls and show '
          'the result in line', (tester) async {
        final sync = _SyncWithFailure();
        final env = await _pump(tester, locale: locale, sync: sync);
        await tester.scrollUntilVisible(
          find.byKey(const Key('pending-delete-sync-1')),
          200,
        );
        await tester.ensureVisible(
          find.byKey(const Key('pending-delete-sync-1')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('pending-retry-sync-1')), findsNothing,
            reason: 'conflict review: retry is not offered');
        expect(sync.retried, isNull);
        await tester.tap(find.byKey(const Key('pending-delete-sync-1')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text(env.l10n.pendingSyncDeleteMessage), findsOneWidget);
        await tester.tap(find.byKey(_confirmKey));
        await tester.pumpAndSettle();
        expect(sync.discarded, 'sync-1');
        expect(find.text(env.l10n.pendingSyncDeleteDone), findsOneWidget);
      });
    });
  }

  for (final locale in ['es', 'en']) {
  testWidgets('$locale identifies evidence, hides raw errors and refreshes same-operation retry', (tester) async {
    await sl.reset();
    final queue = _Queue();
    final storage = _Storage();
    sl.registerSingleton<LocalStorage>(storage);
    sl.registerSingleton<FeedbackUploadQueueService>(queue);
    sl.registerSingleton<OfflineSyncService>(_Sync());
    await tester.pumpWidget(MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PendingUploadsPage(),
    ));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(PendingUploadsPage)));
    // TEXTOS-2 O2: a row without a saved name never shows the identifier.
    expect(find.textContaining('squat'), findsNothing);
    expect(find.textContaining(l10n.pendingEvidenceExerciseGeneric), findsOneWidget);
    expect(find.textContaining('2026-09-05'), findsOneWidget);
    expect(find.textContaining('private technical diagnostic'), findsNothing);
    storage.stamp = 'other:2:test';
    await tester.tap(find.byKey(_retryKey));
    await tester.pumpAndSettle();
    expect(queue.retried, isNull, reason: 'stale account UI cannot retry under a new session');
    storage.stamp = 'owner:1:test';
    await tester.tap(find.byKey(_retryKey));
    await tester.pumpAndSettle();
    expect(queue.retried, 'retained-operation');
    expect(queue.item['id'], 'retained-operation');
    expect(find.byKey(_retryKey), findsNothing);
    expect(find.text(l10n.syncStatusConfirmed), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(queue.events.hasListener, isFalse);
    await queue.events.close();
    await sl.reset();
  });
  }

  for (final locale in ['es', 'en']) {
    group('L5-C1b $locale', () {
      testWidgets('header counts pending and failed apart, never confirmed', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(540, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final l10n = await _pumpList(tester, locale: locale, items: [
          _row('a', 'failed'),
          _row('b', 'completed'),
          _row('c', 'queued'),
        ]);
        expect(
          find.text(
            '${l10n.pendingUploadsCountSubtitle(1)} · '
            '${l10n.pendingUploadsErrorCount(1)}',
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.pendingUploadsHeroLabel(1)), findsOneWidget);
        expect(find.byKey(const ValueKey('pending-row-b')), findsOneWidget);
      });

      testWidgets('L5-D66: 1 confirmed + 1 failed reads only «con error»', (
        tester,
      ) async {
        final l10n = await _pumpList(tester, locale: locale, items: [
          {..._row('ok', 'completed'), 'attempts': 2},
          {..._row('bad', 'failed'), 'attempts': 1},
        ]);
        expect(find.text(l10n.pendingUploadsErrorCount(1)), findsWidgets);
        expect(find.text(l10n.pendingUploadsCountSubtitle(1)), findsNothing);
        expect(find.text(l10n.pendingUploadsNone), findsNothing);
      });

      testWidgets('L5-D66: confirmed rows sit under «Enviadas» with Eliminar', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(540, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final l10n = await _pumpList(tester, locale: locale, items: [
          {..._row('ok', 'completed'), 'attempts': 2},
          _row('bad', 'failed'),
        ]);
        final sent = find.text(l10n.pendingUploadsSectionSent.toUpperCase());
        final evidence = find.text(
          l10n.pendingUploadsSectionEvidence.toUpperCase(),
        );
        expect(sent, findsOneWidget);
        expect(evidence, findsOneWidget);
        final rows = find.byKey(const ValueKey('pending-row-ok'));
        expect(rows, findsOneWidget);
        expect(
          tester.getTopLeft(sent).dy,
          greaterThan(tester.getTopLeft(evidence).dy),
        );
        expect(
          tester.getTopLeft(rows).dy,
          greaterThan(tester.getTopLeft(sent).dy),
        );
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('pending-row-bad'))).dy,
          lessThan(tester.getTopLeft(sent).dy),
        );
        expect(find.byKey(const Key('pending-delete-ok')), findsOneWidget);
      });

      testWidgets('L5-D66: «Enviadas» is hidden without confirmed rows', (
        tester,
      ) async {
        final l10n = await _pumpList(tester, locale: locale, items: [
          _row('bad', 'failed'),
          _row('q', 'queued'),
        ]);
        expect(
          find.text(l10n.pendingUploadsSectionSent.toUpperCase()),
          findsNothing,
        );
        expect(
          find.text(l10n.pendingUploadsSectionEvidence.toUpperCase()),
          findsOneWidget,
        );
      });

      testWidgets('L5-D66: only confirmed rows leave no pending group', (
        tester,
      ) async {
        final l10n = await _pumpList(tester, locale: locale, items: [
          _row('ok', 'completed'),
        ]);
        expect(
          find.text(l10n.pendingUploadsSectionSent.toUpperCase()),
          findsOneWidget,
        );
        expect(
          find.text(l10n.pendingUploadsSectionEvidence.toUpperCase()),
          findsNothing,
        );
      });

      testWidgets('only completed rows: the summary says nothing is pending', (
        tester,
      ) async {
        final l10n = await _pumpList(tester, locale: locale, items: [
          _row('b', 'completed'),
        ]);
        expect(find.text(l10n.pendingUploadsNone), findsOneWidget);
        expect(find.text(l10n.pendingUploadsCountSubtitle(1)), findsNothing);
        expect(find.text('0'), findsOneWidget);
        expect(find.byKey(const ValueKey('pending-row-b')), findsOneWidget);
      });

      testWidgets('completed row reads «Confirmada» with a check in the text '
          'colour', (tester) async {
        final l10n = await _pumpList(tester, locale: locale, items: [
          _row('b', 'completed'),
        ]);
        expect(find.text(l10n.syncStatusConfirmed), findsOneWidget);
        expect(find.text(l10n.pendingUploadCompletedStatus), findsNothing);
        final row = find.byKey(const ValueKey('pending-row-b'));
        final label = tester.widget<Text>(
          find.descendant(of: row, matching: find.text(l10n.syncStatusConfirmed)),
        );
        final icon = tester.widget<Icon>(
          find.descendant(of: row, matching: find.byIcon(ExomIcons.check)),
        );
        expect(icon.color, label.style?.color);
      });

      testWidgets('small file sends in KB with the locale format', (
        tester,
      ) async {
        await _pumpList(tester, locale: locale, items: [
          _row('s', 'uploading'),
        ], progress: {
          's': const FeedbackUploadNotice(
            's',
            FeedbackUploadNoticeKind.uploading,
            sentBytes: 19000,
            totalBytes: 38000,
          ),
        });
        expect(
          find.text(
            locale == 'es'
                ? 'Enviando 50 % · 19,0 de 38,0 KB'
                : 'Sending 50% · 19.0 of 38.0 KB',
          ),
          findsOneWidget,
        );
      });

      testWidgets('sending without a total keeps the plain status', (
        tester,
      ) async {
        final l10n = await _pumpList(tester, locale: locale, items: [
          _row('s', 'uploading'),
        ], progress: {
          's': const FeedbackUploadNotice(
            's',
            FeedbackUploadNoticeKind.uploading,
            sentBytes: 19000,
            totalBytes: 0,
          ),
        });
        expect(find.text(l10n.pendingUploadUploadingStatus), findsOneWidget);
      });
    });
  }
  for (final locale in ['es', 'en']) {
    group('TEXTOS-2 O2 $locale', () {
      testWidgets('a plain exercise upload shows the saved name, not the id', (
        tester,
      ) async {
        final l10n = await _pumpList(tester, locale: locale, items: [
          {
            ..._row('named', 'queued'),
            'media_type': 'VIDEO',
            'exercise_id': '2a6cef58-3aeb-4b1a-8414-3f5154da8406',
            'exercise_name': 'Sentadilla',
          },
        ]);
        expect(
          find.textContaining(l10n.pendingEvidenceExercise('Sentadilla')),
          findsOneWidget,
        );
        expect(find.textContaining('2a6cef58'), findsNothing);
      });

      testWidgets('without a name it shows a generic label and no id', (
        tester,
      ) async {
        final l10n = await _pumpList(tester, locale: locale, items: [
          {
            ..._row('anon', 'queued'),
            'media_type': 'VIDEO',
            'exercise_id': '2a6cef58-3aeb-4b1a-8414-3f5154da8406',
          },
        ]);
        expect(
          find.textContaining(l10n.pendingEvidenceExerciseGeneric),
          findsOneWidget,
        );
        expect(find.textContaining('2a6cef58'), findsNothing);
      });
    });
  }

  for (final locale in ['es', 'en']) {
    testWidgets('TEXTOS-2 O4 $locale: the result strip never covers the last row actions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(540, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final l10n = await _pumpList(tester, locale: locale, items: [
        for (var i = 0; i < 6; i++)
          {..._row('r$i', 'failed'), 'media_type': 'VIDEO'},
      ]);
      await tester.dragUntilVisible(
        find.byKey(const Key('pending-retry-r5')),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pending-retry-r5')));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      final strip = find.text(l10n.pendingRetryFailed);
      expect(strip, findsOneWidget);
      await tester.dragUntilVisible(
        find.byKey(const Key('pending-delete-r5')),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      final stripTop = tester.getTopLeft(strip).dy;
      for (final key in ['pending-retry-r5', 'pending-delete-r5']) {
        final rect = tester.getRect(find.byKey(Key(key)));
        expect(rect.bottom, lessThanOrEqualTo(stripTop), reason: key);
        expect(rect.height, greaterThanOrEqualTo(48), reason: key);
      }
    });
  }
}
