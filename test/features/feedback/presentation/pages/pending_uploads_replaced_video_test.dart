// FB1 r2 (review F2): «Subidas pendientes» decides whether a last-set video
// can be deleted by asking whether queued progress waits for it. A queued
// action may still name a video that this one replaced (a circuit snapshot
// restored after the replacement, or the window between the replacement and
// its redirect). Such an action waits for the replacement too, so the
// replacement must not offer «Eliminar». Real LocalStorage, OfflineSyncService
// and FeedbackUploadQueueService over in-memory Hive boxes.
import 'dart:io';
import 'dart:typed_data';

import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:exom_app/features/feedback/presentation/pages/pending_uploads_page.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/features/trainings/data/models/active_workout_hive_model.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

const _date = '2026-09-05';

class _Repository extends Fake implements FeedbackRepository {}

void main() {
  late LocalStorage storage;
  late OfflineSyncService sync;
  late FeedbackUploadQueueService queue;

  setUp(() async {
    // In-memory boxes: file IO never completes under the widget test clock.
    Hive.init(Directory.systemTemp.path);
    if (!Hive.isAdapterRegistered(ActiveWorkoutHiveModel.typeId)) {
      Hive.registerAdapter(ActiveWorkoutHiveModelAdapter());
    }
    await Hive.openBox('auth_box', bytes: Uint8List(0));
    await Hive.openBox('cache_box', bytes: Uint8List(0));
    await Hive.openBox('settings_box', bytes: Uint8List(0));
    await Hive.openBox<ActiveWorkoutHiveModel>(
      'active_workout_box',
      bytes: Uint8List(0),
    );
    const session = LocalAuthSession(uid: 'owner-a', generation: 1);
    storage = LocalStorage(currentSession: () => session);
    sync = OfflineSyncService(
      ApiClient(useAuth: false),
      storage,
      isAuthenticated: () => false,
      authenticationChanges: const Stream<bool>.empty(),
      connectivityChanges: const Stream<bool>.empty(),
    );
    queue = FeedbackUploadQueueService(
      _Repository(),
      storage,
      sync,
      isAuthenticated: () => false,
      applicationSupportDirectory: () async => Directory.systemTemp,
      connectivityChanges: const Stream<bool>.empty(),
    );
    await sl.reset();
    sl.registerSingleton<LocalStorage>(storage);
    sl.registerSingleton<OfflineSyncService>(sync);
    sl.registerSingleton<FeedbackUploadQueueService>(queue);
  });

  tearDown(() async {
    await sl.reset();
    await queue.dispose();
    await sync.dispose();
    await Hive.close();
  });

  /// A last-set video row of this owner. [replacedBy] makes it the
  /// tombstone a replacement leaves behind.
  Map<String, dynamic> video(
    String id, {
    String status = 'queued',
    String? replacedBy,
    String? replaces,
  }) => {
    'id': id,
    ...storage.queueIdentity,
    'media_type': 'VIDEO',
    'feedback_kind': 'LAST_SET',
    'training_id': 'training-1',
    'training_exercise_id': 'te-1',
    'exercise_id': 'ex-1',
    'exercise_name': 'Remo con barra',
    'file_path': '${Directory.systemTemp.path}/missing-$id.mp4',
    'status': status,
    'attempts': 0,
    if (status == 'failed') 'last_error': 'file_missing',
    if (replacedBy == null) ...{
      'assignment_date': _date,
      'training_session_id': 'execution-1',
    } else ...{
      'replaced_by': replacedBy,
      'dismissed': true,
      'discard_requested': true,
      'discard_cleanup_complete': true,
    },
    'replaces_feedback_id': ?replaces,
  };

  Map<String, dynamic> exerciseCompletion(String feedbackId) => {
    'id': 'circuit-op',
    ...storage.queueIdentity,
    'type': 'mark_exercise_completed',
    'training_exercise_id': 'te-1',
    'training_id': 'training-1',
    'training_session_id': 'execution-1',
    'date': _date,
    'status': 'queued',
    'attempts': 0,
    'last_set_feedback_client_upload_id': feedbackId,
  };

  Future<void> seed(
    WidgetTester tester, {
    required List<Map<String, dynamic>> uploads,
    List<Map<String, dynamic>> actions = const [],
  }) async {
    await tester.runAsync(() async {
      await storage.saveFeedbackUploadQueue(uploads);
      await storage.savePendingSyncActions(actions);
    });
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PendingUploadsPage(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a replacement keeps no «Eliminar» while an action still names '
      'the video it replaced', (tester) async {
    await seed(tester, uploads: [
      video('a', status: 'superseded', replacedBy: 'b'),
      video('b', replaces: 'a'),
    ], actions: [exerciseCompletion('a')]);
    await pump(tester);
    expect(find.byKey(const ValueKey('pending-row-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('pending-row-a')), findsNothing);
    expect(find.byKey(const Key('pending-delete-b')), findsNothing);
  });

  testWidgets('through a chain (A→B→C) the last video is the one the action '
      'waits for: it offers «Volver a grabar», not «Eliminar»', (tester) async {
    await seed(tester, uploads: [
      video('a', status: 'superseded', replacedBy: 'b'),
      video('b', status: 'superseded', replacedBy: 'c', replaces: 'a'),
      video('c', status: 'failed', replaces: 'b'),
    ], actions: [exerciseCompletion('a')]);
    await pump(tester);
    expect(find.byKey(const Key('pending-delete-c')), findsNothing);
    expect(find.byKey(const Key('pending-rerecord-c')), findsOneWidget);
  });

  testWidgets('without an action waiting for it the replacement keeps '
      '«Eliminar»', (tester) async {
    await seed(tester, uploads: [
      video('a', status: 'superseded', replacedBy: 'b'),
      video('b', replaces: 'a'),
    ]);
    await pump(tester);
    expect(find.byKey(const Key('pending-delete-b')), findsOneWidget);
  });

  testWidgets('a replacement cycle in a damaged queue does not hang the page',
      (tester) async {
    await seed(tester, uploads: [
      video('a', status: 'superseded', replacedBy: 'b'),
      video('b', status: 'superseded', replacedBy: 'a'),
      video('x'),
    ], actions: [exerciseCompletion('a')]);
    await pump(tester);
    expect(find.byKey(const Key('pending-delete-x')), findsOneWidget);
  });
}
