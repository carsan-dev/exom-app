import 'dart:async';
import 'dart:io';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/features/feedback/domain/entities/feedback_entity.dart';
import 'package:exom_app/features/feedback/domain/usecases/create_feedback_usecase.dart';
import 'package:exom_app/features/feedback/domain/usecases/get_my_feedback_usecase.dart';
import 'package:exom_app/features/feedback/domain/usecases/upload_feedback_media_usecase.dart';
import 'package:exom_app/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:exom_app/features/feedback/presentation/pages/feedback_page.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_media_picker.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../services/feedback_upload_queue_service_test.dart' as fixtures;
import 'feedback_progress_visibility_test.dart' as screen;

class _Repository extends fixtures.FakeFeedbackRepository {
  final requests = <Completer<List<FeedbackEntity>>>[];
  final requestSessions = <String?>[];

  @override
  Future<List<FeedbackEntity>> getMyFeedback() {
    final request = Completer<List<FeedbackEntity>>();
    requests.add(request);
    requestSessions.add(LocalStorage.requestSessionKey);
    return request.future;
  }
}

FeedbackEntity _item(String id) => FeedbackEntity(
  id: id,
  mediaType: 'VIDEO',
  mediaUrl: null,
  notes: id,
  status: 'PENDING',
  createdAt: DateTime.utc(2026, 11, 4),
);

FeedbackBloc _bloc(
  _Repository repository, {
  Stream<FeedbackUploadNotice> notices = const Stream.empty(),
  LocalStorage? storage,
}) => FeedbackBloc(
  getMyFeedbackUseCase: GetMyFeedbackUseCase(repository),
  createFeedbackUseCase: CreateFeedbackUseCase(repository),
  uploadFeedbackMediaUseCase: UploadFeedbackMediaUseCase(repository),
  uploadNotices: notices,
  localStorage: storage ?? LocalStorage(),
);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  testWidgets(
    'confirmed durable upload refreshes history and preserves new draft',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('exom-history-'),
      ))!;
      addTearDown(() => directory.delete(recursive: true));
      final evidence = (await tester.runAsync(
        () => File('${directory.path}/finished.mp4').writeAsBytes([0]),
      ))!;
      final repository = _Repository();
      final storage = screen.ScreenStorage([
        {
          'id': 'finished',
          'file_path': evidence.path,
          'content_type': 'video/mp4',
          'media_type': 'VIDEO',
          'status': 'queued',
          'attempts': 0,
        },
      ]);
      final offline = fixtures.FakeOfflineSyncService(storage);
      final queue = FeedbackUploadQueueService(
        repository,
        storage,
        offline,
        isAuthenticated: () => true,
      );
      sl.registerSingleton<FeedbackUploadQueueService>(queue);
      sl.registerFactory<FeedbackBloc>(
        () => _bloc(repository, notices: queue.notices, storage: storage),
      );
      addTearDown(() async {
        await sl.reset();
        await queue.dispose();
        await offline.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FeedbackPage(),
        ),
      );
      await tester.pump();
      repository.requests.single.complete([_item('previous history')]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final draft = File('${directory.path}/new-draft.mp4');
      tester.widget<FeedbackMediaPicker>(find.byType(FeedbackMediaPicker))
        ..onMediaTypeChanged('VIDEO')
        ..onFileSelected(draft);
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), 'new unsent notes');
      final formState = tester.state(find.byType(TextFormField));

      // Real durable queue must confirm createFeedback, not only finish its bytes.
      await tester.runAsync(queue.processQueue);
      await tester.pump();
      expect(storage.queue.single['status'], 'completed');
      expect(repository.createCalls, 1);
      expect(repository.requests, hasLength(2));
      expect(find.text('previous history'), findsOneWidget);
      expect(tester.state(find.byType(TextFormField)), same(formState));
      expect(
        tester
            .widget<FeedbackMediaPicker>(find.byType(FeedbackMediaPicker))
            .selectedFile,
        draft,
      );
      expect(find.text('new unsent notes'), findsOneWidget);

      repository.requests.last.complete([_item('confirmed history')]);
      await tester.pump();
      expect(find.text('confirmed history'), findsOneWidget);
      expect(find.text('previous history'), findsNothing);
      expect(tester.state(find.byType(TextFormField)), same(formState));
      expect(
        tester
            .widget<FeedbackMediaPicker>(find.byType(FeedbackMediaPicker))
            .selectedFile,
        draft,
      );
      expect(find.text('new unsent notes'), findsOneWidget);

      final secondEvidence = (await tester.runAsync(
        () => File('${directory.path}/second.mp4').writeAsBytes([1]),
      ))!;
      storage.queue.add({
        'id': 'second',
        'file_path': secondEvidence.path,
        'content_type': 'video/mp4',
        'media_type': 'VIDEO',
        'status': 'queued',
        'attempts': 0,
      });
      await tester.runAsync(queue.processQueue);
      await tester.pump();
      expect(repository.requests, hasLength(3));
      repository.requests.last.completeError(StateError('history failed'));
      await tester.pump();
      expect(find.text('confirmed history'), findsOneWidget);
      expect(tester.state(find.byType(TextFormField)), same(formState));
      expect(
        tester
            .widget<FeedbackMediaPicker>(find.byType(FeedbackMediaPicker))
            .selectedFile,
        draft,
      );
      expect(find.text('new unsent notes'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('older initial history cannot overwrite newer manual history', () async {
    final repository = _Repository();
    final bloc = _bloc(repository);
    addTearDown(bloc.close);
    bloc.add(const FeedbackLoadRequested());
    await _flush();
    bloc.add(const FeedbackLoadRequested());
    await _flush();
    repository.requests.last.complete([_item('new')]);
    await _flush();
    repository.requests.first.complete([_item('old')]);
    await _flush();
    expect((bloc.state as FeedbackLoaded).items.single.id, 'new');
  });

  group('completion subscription', () {
    late _Repository repository;
    late StreamController<FeedbackUploadNotice> notices;
    late FeedbackBloc bloc;

    setUp(() {
      repository = _Repository();
      notices = StreamController<FeedbackUploadNotice>.broadcast();
      bloc = _bloc(repository, notices: notices.stream);
    });
    tearDown(() async {
      await bloc.close();
      await notices.close();
    });

    test(
      'only confirmed completion fetches; keeps loaded state while pending',
      () async {
        bloc.add(const FeedbackLoadRequested());
        await _flush();
        repository.requests.single.complete([_item('previous')]);
        await _flush();
        final loaded = bloc.state;
        for (final kind in FeedbackUploadNoticeKind.values) {
          if (kind != FeedbackUploadNoticeKind.completed) {
            notices.add(
              FeedbackUploadNotice(
                'pending',
                kind,
                sentBytes: 100,
                totalBytes: 100,
              ),
            );
          }
        }
        await _flush();
        expect(repository.requests, hasLength(1));
        notices.add(
          const FeedbackUploadNotice(
            'finished',
            FeedbackUploadNoticeKind.completed,
          ),
        );
        await _flush();
        expect(repository.requests, hasLength(2));
        expect(bloc.state, same(loaded));
        repository.requests.last.complete([_item('confirmed')]);
        await _flush();
        expect((bloc.state as FeedbackLoaded).items.single.id, 'confirmed');
      },
    );

    for (final failOldRequest in [false, true]) {
      test(
        'latest completion wins over initial/older refresh; old error=$failOldRequest',
        () async {
          bloc.add(const FeedbackLoadRequested());
          await _flush();
          notices.add(
            const FeedbackUploadNotice(
              'first',
              FeedbackUploadNoticeKind.completed,
            ),
          );
          await _flush();
          notices.add(
            const FeedbackUploadNotice(
              'second',
              FeedbackUploadNoticeKind.completed,
            ),
          );
          await _flush();
          expect(repository.requests, hasLength(3));
          repository.requests.last.complete([_item('latest')]);
          await _flush();
          if (failOldRequest) {
            repository.requests[1].completeError(
              StateError('outdated failure'),
            );
          } else {
            repository.requests[1].complete([_item('outdated')]);
          }
          repository.requests.first.complete([_item('initial')]);
          await _flush();
          expect(bloc.state, isNot(isA<FeedbackError>()));
          expect((bloc.state as FeedbackLoaded).items.single.id, 'latest');
        },
      );
    }

    test(
      'close cancels notices and ignores in-flight history results',
      () async {
        final states = <FeedbackState>[];
        final subscription = bloc.stream.listen(states.add);
        bloc.add(const FeedbackLoadRequested());
        await _flush();
        expect(notices.hasListener, isTrue);
        final closing = bloc.close();
        notices.add(
          const FeedbackUploadNotice(
            'late',
            FeedbackUploadNoticeKind.completed,
          ),
        );
        repository.requests.single.complete([_item('late')]);
        await closing;
        await _flush();
        expect(notices.hasListener, isFalse);
        expect(repository.requests, hasLength(1));
        expect(states.whereType<FeedbackLoaded>(), isEmpty);
        await subscription.cancel();
      },
    );
  });

  for (final next in <LocalAuthSession?>[
    const LocalAuthSession(uid: 'other-owner'),
    const LocalAuthSession(uid: 'owner', generation: 1),
    null,
  ]) {
    test(
      'session change to ${next?.uid}:${next?.generation} rejects requests/results',
      () async {
        LocalAuthSession? session = const LocalAuthSession(uid: 'owner');
        final storage = LocalStorage(currentSession: () => session);
        final repository = _Repository();
        final notices = StreamController<FeedbackUploadNotice>.broadcast();
        final bloc = _bloc(
          repository,
          notices: notices.stream,
          storage: storage,
        );
        addTearDown(() async {
          await bloc.close();
          await notices.close();
        });
        bloc.add(const FeedbackLoadRequested());
        await _flush();
        expect(repository.requestSessions, ['owner:0']);
        session = next;
        notices.add(
          const FeedbackUploadNotice(
            'foreign',
            FeedbackUploadNoticeKind.completed,
          ),
        );
        bloc.add(const FeedbackLoadRequested());
        await _flush();
        repository.requests.single.complete([_item('old owner')]);
        await _flush();
        expect(repository.requests, hasLength(1));
        expect(bloc.state, isA<FeedbackLoading>());
      },
    );
  }
}
