// Shared scene of the L5-F1 «Fotos de progreso» tests and goldens
// (docs/plans/rediseno-app-l5-contrato-v2.md, L5-F1; sketch f-resto.html
// frames f1-lista, f1-origen, f1-visor, f1-vacio and f1-carga-error).
//
// The page runs on the real theme and bundled fonts, under a GoRouter (so an
// EXOM sheet can be closed by a location change, CC 11), with the fakes of
// progress_photos_page_test.dart. Not a test file: it has no `main`.
import 'dart:async';
import 'dart:io';

import 'package:exom_app/features/progress_photos/domain/entities/progress_photo.dart';
import 'package:exom_app/features/progress_photos/presentation/pages/progress_photos_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/widgets/exom_component_harness.dart' show themeFor;
import '../../golden/redesign_scenes.dart' show loadRedesignFonts;
import 'progress_photos_page_test.dart'
    show FakeQueue, FakeRepository, pending, photo, sessionFor;

/// Sketch f1-lista: session 01 (18 Nov 2026) with a confirmed front photo
/// and three views in upload states (synchronizing, failed, pending); session
/// 02 (4 Nov 2026) with three photos and the back view missing; one more page.
FakeRepository listRepository() {
  final repository = FakeRepository();
  final sessions = [
    sessionFor('s1', '2026-11-18', photos: [photo('s1-front', 'FRONT')]),
    sessionFor(
      's2',
      '2026-11-04',
      photos: [
        photo('s2-front', 'FRONT'),
        photo('s2-left', 'LEFT'),
        photo('s2-right', 'RIGHT'),
      ],
    ),
  ];
  repository
    ..history = sessions
    ..histories[1] = ProgressPhotoHistory(
      sessions: sessions,
      total: 3,
      page: 1,
      limit: 20,
      totalPages: 2,
    );
  return repository;
}

FakeQueue listQueue() => FakeQueue()
  ..items = [
    pending('q-front', 's1', 'FRONT', 'completed'),
    pending('q-left', 's1', 'LEFT', 'processing'),
    pending(
      'q-right',
      's1',
      'RIGHT',
      'failed',
      error: 'progress_photo_network_connectionError_0',
    ),
    pending('q-back', 's1', 'BACK', 'queued'),
  ];

/// Pumps [ProgressPhotosPage] at [width] x [height] (device pixel ratio 1).
/// Returns the router so a test can change the location.
Future<GoRouter> pumpPhotosScene(
  WidgetTester tester, {
  FakeRepository? repository,
  FakeQueue? queue,
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  TextScaler? textScaler,
  Locale locale = const Locale('es'),
  bool disableAnimations = true,
  Future<XFile?> Function(ImageSource source)? picker,
  bool settle = true,
}) async {
  await loadRedesignFonts();
  final cacheDirectory = Directory.systemTemp.createTempSync(
    'progress-photos-scene-',
  );
  // The image cache manager resolves its directories on first use; tests
  // have no path_provider plugin.
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    pathProvider,
    (call) async => cacheDirectory.path,
  );
  addTearDown(() {
    messenger.setMockMethodCallHandler(pathProvider, null);
    try {
      cacheDirectory.deleteSync(recursive: true);
    } on FileSystemException {
      // Best effort: the cache manager may still hold the directory.
    }
  });
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final page = ProgressPhotosPage(
    repository: repository ?? listRepository(),
    queue: queue ?? listQueue(),
    sessionStamp: () => 'account-a:1',
    pickImage: picker ?? (_) async => null,
    retrieveLostData: () async => LostDataResponse.empty(),
    queuePollInterval: null,
  );
  final router = GoRouter(
    initialLocation: '/photos',
    routes: [
      GoRoute(path: '/photos', builder: (context, state) => page),
      GoRoute(
        path: '/other',
        builder: (context, state) => const Scaffold(body: Text('other')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: themeFor(brightness),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, app) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler ?? TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: app!,
        );
      },
    ),
  );
  await tester.pump();
  if (settle) await tester.pump(const Duration(milliseconds: 300));
  return router;
}

/// A repository whose first history request never completes (loading).
FakeRepository loadingRepository() =>
    FakeRepository()..pendingHistory = Completer<ProgressPhotoHistory>();

/// A repository whose history requests fail (load error, also offline).
class ErrorRepository extends FakeRepository {
  @override
  Future<ProgressPhotoHistory> getHistory({int page = 1, int limit = 20}) {
    requestedPages.add(page);
    return Future<ProgressPhotoHistory>.error(StateError('offline'));
  }
}
