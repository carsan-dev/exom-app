import 'dart:async';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_upload_status.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../services/feedback_upload_queue_service_test.dart' as fixtures;

/// Queue whose notices and stored rows the test drives step by step.
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

  void emit(FeedbackUploadNotice notice, {String? status, String? claimedAt}) {
    final row = storage.queue.firstWhere((item) => item['id'] == notice.id);
    if (status != null) row['status'] = status;
    if (claimedAt != null) row['claimed_at'] = claimedAt;
    progress[notice.id] = notice;
    events.add(notice);
  }

  @override
  Future<void> dispose() async {
    await events.close();
    await super.dispose();
  }
}

const _first = '2026-11-21T10:00:00.000Z';
const _second = '2026-11-21T10:05:00.000Z';

FeedbackUploadNotice _processing() =>
    const FeedbackUploadNotice('a', FeedbackUploadNoticeKind.processing);

FeedbackUploadNotice _bytes(int sent) => FeedbackUploadNotice(
  'a',
  FeedbackUploadNoticeKind.uploading,
  sentBytes: sent,
  totalBytes: 38000,
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('es'));
  late _Queue queue;

  Future<void> pumpPanel(WidgetTester tester, Map<String, dynamic> row) async {
    queue = _Queue(fixtures.FakeFeedbackQueueStorage([row]));
    addTearDown(queue.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: FeedbackQueuePanel(queue: queue)),
      ),
    );
  }

  /// Title the row shows now: the first text of the upload status.
  String title(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(FeedbackUploadStatus),
          matching: find.byType(Text),
        ),
      )
      .first
      .data!;

  Future<String> step(
    WidgetTester tester,
    FeedbackUploadNotice notice, {
    String? status,
    String? claimedAt,
  }) async {
    queue.emit(notice, status: status, claimedAt: claimedAt);
    await tester.pump();
    return title(tester);
  }

  // D2: the managed transport reports «processing» while it checks for the
  // object before any byte is sent (lib/core/services/managed_upload.dart:254
  // → :139). Until the attempt sends bytes, that notice reads as preparing.
  testWidgets('processing never shows before sending in a fresh attempt', (
    tester,
  ) async {
    await pumpPanel(tester, {
      'id': 'a',
      'status': 'uploading',
      'claimed_at': _first,
      'attempts': 1,
    });
    final seen = [
      await step(
        tester,
        const FeedbackUploadNotice('a', FeedbackUploadNoticeKind.preparing),
      ),
      await step(tester, _processing()),
      await step(tester, _bytes(38000)),
      await step(tester, _processing()),
      await step(tester, _processing(), status: 'processing'),
    ];
    final sending = l10n.pendingUploadSendingKilobytes(100, '38,0', '38,0');
    expect(seen, [
      l10n.pendingUploadPreparingStatus,
      l10n.pendingUploadPreparingStatus,
      sending,
      l10n.feedbackUploadProcessingTitle,
      l10n.feedbackUploadProcessingTitle,
    ]);
  });

  testWidgets('a retry whose object is already on the server never reads '
      'confirmed before completed', (tester) async {
    await pumpPanel(tester, {
      'id': 'a',
      'status': 'queued',
      'claimed_at': _first,
      'attempts': 1,
      'upload_checkpoint': {'upload_id': 'one'},
    });
    final seen = [
      await step(
        tester,
        const FeedbackUploadNotice('a', FeedbackUploadNoticeKind.uploading),
        status: 'uploading',
        claimedAt: _second,
      ),
      await step(tester, _processing()),
      await step(tester, _processing(), status: 'processing'),
      await step(
        tester,
        const FeedbackUploadNotice('a', FeedbackUploadNoticeKind.completed),
        status: 'completed',
      ),
    ];
    expect(seen, [
      l10n.pendingUploadUploadingStatus,
      l10n.pendingUploadPreparingStatus,
      // The queue stored `processing`: the server has the bytes.
      l10n.feedbackUploadProcessingTitle,
      l10n.syncStatusConfirmed,
    ]);
  });

  testWidgets('a new attempt (another claimed_at) applies the rule again', (
    tester,
  ) async {
    await pumpPanel(tester, {
      'id': 'a',
      'status': 'uploading',
      'claimed_at': _first,
      'attempts': 1,
    });
    await step(tester, _bytes(20000));
    expect(
      await step(tester, _processing()),
      l10n.feedbackUploadProcessingTitle,
    );
    // The first attempt failed; the queue claims the upload again.
    final seen = [
      await step(
        tester,
        const FeedbackUploadNotice('a', FeedbackUploadNoticeKind.uploading),
        status: 'uploading',
        claimedAt: _second,
      ),
      await step(tester, _processing()),
      await step(tester, _bytes(38000)),
      await step(tester, _processing()),
    ];
    expect(seen, [
      l10n.pendingUploadUploadingStatus,
      l10n.pendingUploadPreparingStatus,
      l10n.pendingUploadSendingKilobytes(100, '38,0', '38,0'),
      l10n.feedbackUploadProcessingTitle,
    ]);
  });
}
