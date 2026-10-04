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
  @override
  Stream<FeedbackUploadNotice> get notices => events.stream;
  @override
  List<Map<String, dynamic>> get pendingItems => [item];
  @override
  FeedbackUploadNotice? progressOf(String id) => null;
  @override
  Future<void> retry(String id) async {
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

void main() {
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
    await tester.tap(find.byTooltip(l10n.pendingUploadRetry));
    await tester.pumpAndSettle();
    expect(queue.retried, isNull, reason: 'stale account UI cannot retry under a new session');
    storage.stamp = 'owner:1:test';
    await tester.tap(find.byTooltip(l10n.pendingUploadRetry));
    await tester.pumpAndSettle();
    expect(queue.retried, 'retained-operation');
    expect(queue.item['id'], 'retained-operation');
    expect(find.byTooltip(l10n.pendingUploadRetry), findsNothing);
    expect(find.text(l10n.pendingUploadCompletedStatus), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(queue.events.hasListener, isFalse);
    await queue.events.close();
    await sl.reset();
  });
  }
}
