import 'dart:async';

import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
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
    expect(find.textContaining('squat'), findsOneWidget);
    expect(find.textContaining('2026-09-05'), findsOneWidget);
    expect(find.textContaining('private technical diagnostic'), findsNothing);
    final l10n = AppLocalizations.of(tester.element(find.byType(PendingUploadsPage)));
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
    expect(find.text(l10n.pendingUploadCompletedStatus), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(queue.events.hasListener, isFalse);
    await queue.events.close();
    await sl.reset();
  });
  }
}
