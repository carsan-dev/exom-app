// Shared scene of the L5-C2 «Feedback» tests: a feedback page for one exercise
// (or a circuit) with one evidence sending (62 % of 13.5 MB) and a history with
// a reviewed item answered by the coach and a pending one; fakes for the queue
// and the repository; and a pump with a router so sheets can be closed by a
// location change (CC 11).
import 'dart:async';
import 'dart:io';

import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';
import 'package:exom_app/features/feedback/domain/usecases/create_feedback_usecase.dart';
import 'package:exom_app/features/feedback/domain/usecases/get_my_feedback_usecase.dart';
import 'package:exom_app/features/feedback/domain/usecases/upload_feedback_media_usecase.dart';
import 'package:exom_app/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:exom_app/features/feedback/presentation/pages/feedback_page.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;
import '../../services/feedback_upload_queue_service_test.dart' as fixtures;
import 'feedback_progress_visibility_test.dart' as screen;

class SceneFeedbackQueue extends Fake implements FeedbackUploadQueueService {
  SceneFeedbackQueue(this.items, {this.enqueueError});

  final List<Map<String, dynamic>> items;
  final Object? enqueueError;
  final events = StreamController<FeedbackUploadNotice>.broadcast();
  final enqueued = <String?>[];

  @override
  Stream<FeedbackUploadNotice> get notices => events.stream;
  @override
  List<Map<String, dynamic>> get pendingItems => items;
  @override
  bool get hasUnattributedData => false;
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
  Future<void> retry(String id) async {}
  @override
  Future<String> enqueue({
    required File file,
    String? expectedSession,
    required String contentType,
    required String mediaType,
    String? notes,
    String? exerciseId,
    String? feedbackKind,
    String? trainingId,
    String? trainingExerciseId,
    String? assignmentDate,
    String? sessionId,
    String? exerciseName,
  }) async {
    final error = enqueueError;
    if (error != null) throw error;
    enqueued.add(exerciseId);
    return 'queued-${enqueued.length}';
  }
}

class SceneRepository extends fixtures.FakeFeedbackRepository {
  SceneRepository(this.history, {this.historyError});

  final List<FeedbackEntity> history;
  final Object? historyError;

  @override
  Future<List<FeedbackEntity>> getMyFeedback() async {
    final error = historyError;
    if (error != null) throw error;
    return history;
  }
}

List<Map<String, dynamic>> sceneUploads() => [
  {'id': 'sending', 'media_type': 'VIDEO', 'status': 'uploading'},
];

List<FeedbackEntity> sceneHistory() => [
  FeedbackEntity(
    id: 'f1',
    mediaType: 'VIDEO',
    mediaUrl: null,
    notes: 'Rodilla estable, la última serie se me hizo larga.',
    adminResponse:
        'Buena profundidad y control en la bajada. Sube el tronco un poco '
        'antes en la última repetición.',
    status: 'REVIEWED',
    createdAt: DateTime(2026, 11, 18, 19, 42),
    exerciseName: 'Sentadilla búlgara',
  ),
  FeedbackEntity(
    id: 'f2',
    mediaType: 'IMAGE',
    mediaUrl: null,
    notes: 'Foto de la posición de la espalda al inicio.',
    status: 'PENDING',
    createdAt: DateTime(2026, 11, 16, 18, 10),
    exerciseName: 'Remo con barra',
  ),
];

const sceneExercise = FeedbackPageArgs.exercise(
  FeedbackExerciseTarget(
    key: 'te-1',
    exerciseId: 'exercise-1',
    exerciseName: 'Sentadilla búlgara',
  ),
);

const sceneCircuit = FeedbackPageArgs.circuit(
  circuitName: 'Circuito A',
  circuitExercises: [
    FeedbackExerciseTarget(
      key: 'te-a',
      exerciseId: 'exercise-a',
      exerciseName: 'Sentadilla goblet',
    ),
    FeedbackExerciseTarget(
      key: 'te-b',
      exerciseId: 'exercise-b',
      exerciseName: 'Zancada atrás',
    ),
  ],
);

Future<GoRouter> pumpFeedbackScene(
  WidgetTester tester, {
  FeedbackPageArgs? args = sceneExercise,
  List<Map<String, dynamic>>? uploads,
  List<FeedbackEntity>? history,
  Object? historyError,
  Object? enqueueError,
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('es'),
}) async {
  await loadRedesignFonts();
  await sl.reset();
  final storage = screen.ScreenStorage([]);
  final queue = SceneFeedbackQueue(
    uploads ?? sceneUploads(),
    enqueueError: enqueueError,
  );
  final repository = SceneRepository(
    history ?? sceneHistory(),
    historyError: historyError,
  );
  sl.registerSingleton<LocalStorage>(storage);
  sl.registerSingleton<FeedbackUploadQueueService>(queue);
  sl.registerFactory<FeedbackBloc>(
    () => FeedbackBloc(
      getMyFeedbackUseCase: GetMyFeedbackUseCase(repository),
      createFeedbackUseCase: CreateFeedbackUseCase(repository),
      uploadFeedbackMediaUseCase: UploadFeedbackMediaUseCase(repository),
      uploadNotices: queue.notices,
      localStorage: storage,
    ),
  );
  addTearDown(() async {
    await queue.events.close();
    await sl.reset();
  });
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => GlassDecoration.brightness = Brightness.dark);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => FeedbackPage(args: args),
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
        GlassDecoration.brightness = Theme.of(context).brightness;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            disableAnimations: true,
          ),
          child: child!,
        );
      },
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
