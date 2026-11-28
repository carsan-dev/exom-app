// Shared scene of the L5-C1 «Subidas pendientes» tests: one evidence sending
// (62 % of 13.5 MB), one failed, and one failed offline-sync action under
// conflict review; fakes for the queue and the sync service; and a pump with
// a router so the sheet can be closed by a location change (CC 11).
import 'dart:async';

import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/feedback/presentation/pages/pending_uploads_page.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;

class SceneQueue extends Fake implements FeedbackUploadQueueService {
  SceneQueue(this.items);

  final List<Map<String, dynamic>> items;
  final events = StreamController<FeedbackUploadNotice>.broadcast();
  String? discarded;

  @override
  Stream<FeedbackUploadNotice> get notices => events.stream;
  @override
  List<Map<String, dynamic>> get pendingItems => items;
  @override
  FeedbackUploadNotice? progressOf(String id) => id == 'sending'
      ? const FeedbackUploadNotice(
          'sending',
          FeedbackUploadNoticeKind.uploading,
          sentBytes: 8400000,
          totalBytes: 13500000,
        )
      : null;
  @override
  Future<void> discard(String id) async => discarded = id;
}

class SceneSync extends Fake implements OfflineSyncService {
  SceneSync(this.actions);

  final List<Map<String, dynamic>> actions;
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  List<Map<String, dynamic>> get pendingActions => actions;
}

class SceneStorage extends LocalStorage {
  @override
  String? get sessionStamp => 'owner:1:test';
}

List<Map<String, dynamic>> sceneItems() => [
  {
    'id': 'sending',
    'media_type': 'VIDEO',
    'status': 'uploading',
    'attempts': 1,
    'exercise_name': 'Peso muerto rumano',
    'assignment_date': '2026-11-18',
  },
  {
    'id': 'failed',
    'media_type': 'VIDEO',
    'status': 'failed',
    'attempts': 3,
    'last_error': 'technical diagnostic',
    'exercise_name': 'Sentadilla búlgara',
    'assignment_date': '2026-11-18',
  },
];

List<Map<String, dynamic>> sceneSyncFailures() => [
  {
    'id': 'sync-1',
    'status': 'failed',
    'attempts': 2,
    'last_error': 'progress_conflict_review_required',
  },
];

Future<GoRouter> pumpScene(
  WidgetTester tester, {
  List<Map<String, dynamic>>? items,
  List<Map<String, dynamic>>? syncFailures,
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  Locale locale = const Locale('es'),
  bool disableAnimations = true,
}) async {
  await loadRedesignFonts();
  await sl.reset();
  final queue = SceneQueue(items ?? sceneItems());
  sl.registerSingleton<LocalStorage>(SceneStorage());
  sl.registerSingleton<FeedbackUploadQueueService>(queue);
  sl.registerSingleton<OfflineSyncService>(
    SceneSync(syncFailures ?? sceneSyncFailures()),
  );
  addTearDown(() async {
    await queue.events.close();
    await sl.reset();
  });
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const PendingUploadsPage(),
      ),
      GoRoute(
        path: '/other',
        builder: (context, state) => const Scaffold(body: Text('Otra')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        );
      },
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
