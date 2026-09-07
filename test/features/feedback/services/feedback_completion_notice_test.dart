import 'dart:async';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_upload_status.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_upload_queue_service_test.dart' as fixtures;

class _Queue extends FeedbackUploadQueueService {
  _Queue(this.storage)
    : super(
        fixtures.FakeFeedbackRepository(),
        storage,
        fixtures.FakeOfflineSyncService(storage),
        isAuthenticated: () => false,
      );
  final fixtures.FakeFeedbackQueueStorage storage;
  final events = StreamController<FeedbackUploadNotice>.broadcast();
  final progress = <String, FeedbackUploadNotice>{};
  @override
  bool get hasUnattributedData => false;
  @override
  Stream<FeedbackUploadNotice> get notices => events.stream;
  @override
  FeedbackUploadNotice? progressOf(String id) => progress[id];
  void complete() {
    storage.queue.first['status'] = 'completed';
    const notice = FeedbackUploadNotice(
      'finished',
      FeedbackUploadNoticeKind.completed,
    );
    progress[notice.id] = notice;
    events.add(notice);
  }

  @override
  Future<void> dispose() async {
    await events.close();
    await super.dispose();
  }
}

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'completion disappears without losing receipt or pending work in ${theme.brightness}',
      (tester) async {
        final storage = fixtures.FakeFeedbackQueueStorage([
          {'id': 'finished', 'status': 'processing', 'cleanup_pending': true},
          {'id': 'pending', 'status': 'queued'},
        ]);
        final queue = _Queue(storage);
        addTearDown(queue.dispose);
        Widget screen() => MaterialApp(
          theme: theme,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FeedbackQueuePanel(queue: queue)),
        );
        await tester.pumpWidget(screen());
        queue.complete();
        await tester.pump();
        expect(find.text('Completada'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('Completada'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('Completada'), findsNothing);
        expect(find.byType(FeedbackUploadStatus), findsOneWidget);
        expect(storage.queue.first, {
          'id': 'finished',
          'status': 'completed',
          'cleanup_pending': true,
        });
        queue.complete(); // Repeated confirmation must not revive the banner.
        await tester.pump();
        expect(find.text('Completada'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(screen());
        expect(find.text('Completada'), findsNothing);
        expect(find.byType(FeedbackUploadStatus), findsOneWidget);
      },
    );
  }
}
