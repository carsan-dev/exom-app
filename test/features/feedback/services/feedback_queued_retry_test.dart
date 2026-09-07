import 'dart:io';
import 'package:dio/dio.dart';
import 'package:exom_app/core/services/offline_sync_service.dart';
import 'package:exom_app/features/feedback/presentation/pages/pending_uploads_page.dart';
import 'package:exom_app/injection_container.dart';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_upload_status.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_upload_queue_service_test.dart' as fixtures;

void main() {
  test(
    'manual retry keeps automatic backoff after another recoverable failure',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'exom-retry-backoff-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File(
        '${directory.path}/evidence.mp4',
      ).writeAsBytes([1]);
      final storage = fixtures.FakeFeedbackQueueStorage([
        {
          'id': 'same-operation',
          'file_path': file.path,
          'content_type': 'video/mp4',
          'media_type': 'VIDEO',
          'status': 'queued',
          'attempts': 4,
          'next_attempt_at': DateTime.now()
              .add(const Duration(hours: 1))
              .toIso8601String(),
        },
      ]);
      final repository = fixtures.FakeFeedbackRepository(
        uploadError: DioException(
          requestOptions: RequestOptions(path: '/uploads/sessions'),
          type: DioExceptionType.connectionError,
        ),
      );
      final service = FeedbackUploadQueueService(
        repository,
        storage,
        fixtures.FakeOfflineSyncService(storage),
        isAuthenticated: () => true,
      );
      addTearDown(service.dispose);
      await service.retry('same-operation');
      await service.processQueue();
      expect(repository.uploadCalls, 1);
      expect(repository.createCalls, 0);
      expect(storage.queue.single['status'], 'queued');
      expect(
        DateTime.parse(
          storage.queue.single['next_attempt_at'] as String,
        ).isAfter(DateTime.now()),
        isTrue,
      );
      expect(await file.exists(), isTrue);
    },
  );

  test(
    'manual retry bypasses backoff without duplicating an in-flight upload',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'exom-queued-retry-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File(
        '${directory.path}/evidence.mp4',
      ).writeAsBytes([1]);
      final storage = fixtures.FakeFeedbackQueueStorage([
        {
          'id': 'stable-operation',
          'file_path': file.path,
          'content_type': 'video/mp4',
          'media_type': 'VIDEO',
          'status': 'queued',
          'attempts': 4,
          'next_attempt_at': DateTime.now()
              .add(const Duration(hours: 1))
              .toIso8601String(),
          'upload_checkpoint': {'generation': 2},
        },
      ]);
      final repository = fixtures.BlockingFeedbackRepository();
      final service = FeedbackUploadQueueService(
        repository,
        storage,
        fixtures.FakeOfflineSyncService(storage),
        isAuthenticated: () => true,
      );
      addTearDown(service.dispose);
      await service.processQueue();
      expect(repository.uploadCalls, 0);
      final retry = service.retry('stable-operation');
      await fixtures.waitUntil(() => repository.uploadCalls == 1);
      final secondRetry = service.retry('stable-operation');
      await Future<void>.delayed(Duration.zero);
      expect(storage.queue.single['status'], 'uploading');
      expect(repository.uploadCalls, 1);
      repository.releaseFirstUpload.complete();
      await Future.wait([retry, secondRetry]);
      expect(storage.queue.single['id'], 'stable-operation');
      expect(storage.queue.single['upload_checkpoint'], {'generation': 2});
      expect(storage.queue.single['status'], 'completed');
      expect(repository.createCalls, 1);
    },
  );

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'pending uploads page exposes queued retry in ${theme.brightness}',
      (tester) async {
        final storage = _PanelStorage([
          {'id': 'pending', 'status': 'queued', 'attempts': 4},
        ]);
        final offline = fixtures.FakeOfflineSyncService(storage);
        final queue = FeedbackUploadQueueService(
          fixtures.FakeFeedbackRepository(),
          storage,
          offline,
          isAuthenticated: () => false,
        );
        sl.registerSingleton<FeedbackUploadQueueService>(queue);
        sl.registerSingleton<OfflineSyncService>(offline);
        addTearDown(() async {
          await sl.reset();
          await queue.dispose();
          await offline.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PendingUploadsPage(),
          ),
        );
        final retry = find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Reintentar',
        );
        expect(retry.hitTestable(), findsOneWidget);
        expect(
          tester.widget<IconButton>(retry).color,
          theme.colorScheme.primary,
        );
        await tester.runAsync(() async {
          await tester.tap(retry);
          await fixtures.waitUntil(() => queue.progressOf('pending') != null);
        });
        await tester.pump();
        expect(storage.queue.single['status'], 'queued');
      },
    );

    testWidgets(
      'queued retry is accessible and preserves auth pause in ${theme.brightness}',
      (tester) async {
        final storage = _PanelStorage([
          {
            'id': 'pending',
            'status': 'queued',
            'attempts': 4,
            'next_attempt_at': DateTime.now()
                .add(const Duration(hours: 1))
                .toIso8601String(),
          },
        ]);
        final repository = fixtures.FakeFeedbackRepository();
        final service = FeedbackUploadQueueService(
          repository,
          storage,
          fixtures.FakeOfflineSyncService(storage),
          isAuthenticated: () => false,
        );
        addTearDown(service.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: FeedbackQueuePanel(queue: service)),
          ),
        );
        expect(find.text('Reintentar').hitTestable(), findsOneWidget);
        final button = tester.widget<TextButton>(find.byType(TextButton));
        expect(
          button.style!.foregroundColor!.resolve({}),
          theme.colorScheme.primary,
        );
        await tester.runAsync(() async {
          await tester.tap(find.text('Reintentar'));
          await fixtures.waitUntil(() => service.progressOf('pending') != null);
        });
        await tester.pump();
        expect(repository.uploadCalls, 0);
        expect(storage.queue.single['id'], 'pending');
        expect(storage.queue.single['status'], 'queued');
        expect(
          service.progressOf('pending')?.kind,
          FeedbackUploadNoticeKind.queued,
        );
      },
    );
  }
}

class _PanelStorage extends fixtures.FakeFeedbackQueueStorage {
  _PanelStorage(super.queue);
  @override
  bool get hasUnattributedData => false;
  @override
  List<Map<String, dynamic>> getPendingSyncActions() => [];
}
