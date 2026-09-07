import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'feedback_upload_queue_service_test.dart' as fixtures;

class _InterruptedRepository extends fixtures.FakeFeedbackRepository {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<ManagedFeedbackUpload> uploadMedia(
    File file,
    String type, {
    FeedbackUploadContext? context,
  }) async {
    if (uploadCalls == 0) {
      uploadCalls++;
      started.complete();
      await release.future;
      throw DioException(
        requestOptions: RequestOptions(path: '/uploads/sessions'),
        type: DioExceptionType.connectionError,
      );
    }
    return super.uploadMedia(file, type, context: context);
  }
}

void main() {
  late Directory dir;
  late File file;
  late StreamController<bool> connectivity;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('exom-reconnect-');
    file = await File('${dir.path}/evidence.mp4').writeAsBytes([1]);
    connectivity = StreamController<bool>();
  });
  tearDown(() async {
    await connectivity.close();
    await dir.delete(recursive: true);
  });
  Map<String, dynamic> entry(
    String id,
    String error, {
    String status = 'queued',
  }) => {
    'id': id,
    'file_path': file.path,
    'content_type': 'video/mp4',
    'media_type': 'VIDEO',
    'status': status,
    'attempts': 4,
    'last_error': error,
    'next_attempt_at': DateTime.now()
        .add(const Duration(hours: 1))
        .toIso8601String(),
    'upload_checkpoint': {'generation': 2},
  };

  test(
    'reconnection sends retained network failure automatically without overriding server backoff',
    () async {
      final storage = fixtures.FakeFeedbackQueueStorage([
        entry('network', 'network_connectionError_0'),
        entry('limited', 'network_badResponse_429'),
        entry('server', 'network_badResponse_503'),
        entry('invalid', 'upload_request_failed', status: 'failed'),
      ]);
      final repository = fixtures.FakeFeedbackRepository();
      final service = FeedbackUploadQueueService(
        repository,
        storage,
        fixtures.FakeOfflineSyncService(storage),
        isAuthenticated: () => true,
        connectivityChanges: connectivity.stream,
      );
      addTearDown(service.dispose);
      await service.init();
      expect(repository.uploadCalls, 0);
      connectivity.add(false);
      connectivity.add(true);
      await fixtures.waitUntil(
        () => storage.queue.first['status'] == 'completed',
      );
      expect(repository.uploadCalls, 1);
      expect(repository.createCalls, 1);
      expect(storage.queue.first['id'], 'network');
      expect(storage.queue.first['upload_checkpoint'], {'generation': 2});
      expect(storage.queue.skip(1).map((row) => row['status']), [
        'queued',
        'queued',
        'failed',
      ]);
    },
  );

  test('reconnection during an in-flight failure is not lost', () async {
    final storage = fixtures.FakeFeedbackQueueStorage([
      entry('in-flight', 'network_connectionError_0')
        ..remove('next_attempt_at'),
    ]);
    final repository = _InterruptedRepository();
    final service = FeedbackUploadQueueService(
      repository,
      storage,
      fixtures.FakeOfflineSyncService(storage),
      isAuthenticated: () => true,
      connectivityChanges: connectivity.stream,
    );
    addTearDown(service.dispose);
    final initialization = service.init();
    await repository.started.future;
    connectivity.add(false);
    connectivity.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(repository.uploadCalls, 1);
    repository.release.complete();
    await initialization;
    await fixtures.waitUntil(
      () => storage.queue.single['status'] == 'completed',
    );
    expect(repository.uploadCalls, 2);
    expect(repository.createCalls, 1);
    expect(storage.queue.single['id'], 'in-flight');
  });

  test('duplicate connected events do not bypass backoff repeatedly', () async {
    final storage = fixtures.FakeFeedbackQueueStorage([
      entry('network', 'network_connectionError_0'),
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
      connectivityChanges: connectivity.stream,
    );
    addTearDown(service.dispose);
    await service.init();
    connectivity.add(true);
    await fixtures.waitUntil(
      () =>
          repository.uploadCalls == 1 &&
          storage.queue.single['status'] == 'queued',
    );
    connectivity.add(true);
    connectivity.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await service.processQueue();
    expect(repository.uploadCalls, 1);
    expect(await file.exists(), isTrue);
  });

  test('reconnection never grants authorization', () async {
    final storage = fixtures.FakeFeedbackQueueStorage([
      entry('paused', 'network_receiveTimeout_0'),
    ]);
    final repository = fixtures.FakeFeedbackRepository();
    var authenticated = false;
    final service = FeedbackUploadQueueService(
      repository,
      storage,
      fixtures.FakeOfflineSyncService(storage),
      isAuthenticated: () => authenticated,
      connectivityChanges: connectivity.stream,
    );
    addTearDown(service.dispose);
    await service.init();
    connectivity.add(true);
    await fixtures.waitUntil(
      () => !storage.queue.single.containsKey('next_attempt_at'),
    );
    expect(repository.uploadCalls, 0);
    expect(await file.exists(), isTrue);
    authenticated = true;
    await service.processQueue();
    expect(repository.createCalls, 1);
  });
}
