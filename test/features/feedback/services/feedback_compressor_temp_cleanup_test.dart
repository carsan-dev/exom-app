import 'dart:io';

import 'package:dio/dio.dart';
import 'package:exom_app/core/api/api_client.dart';
import 'package:exom_app/features/feedback/data/datasources/feedback_remote_datasource.dart';
import 'package:exom_app/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The upload is already verified remotely, so the transport confirms it
/// right after preparation without a byte transfer.
ApiClient _confirmingApi() {
  final api = ApiClient(useAuth: false, baseUrl: 'https://api.exom.test');
  api.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/uploads/sessions') {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'upload_id': 'one',
                'upload_url': 'https://storage.exom.test/one',
              },
            ),
          );
        } else {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'file_url': 'r2://one'},
            ),
          );
        }
      },
    ),
  );
  return api;
}

void main() {
  late Directory dir;
  late Directory cache;
  late File source;
  late String preparedPath;
  late File compressorOutput;
  late List<Map<String, dynamic>> checkpoints;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('exom-compress-temp-');
    cache = await Directory('${dir.path}/video_compression').create();
    source = await File(
      '${dir.path}/evidence.mp4',
    ).writeAsBytes(List.filled(16384, 1));
    preparedPath = '${source.path}.prepared.mp4';
    compressorOutput = File('${cache.path}/native-output.mp4');
    checkpoints = [];
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  Future<File> compress(File _, String _) =>
      compressorOutput.writeAsBytes(List.filled(8192, 2));

  FeedbackUploadContext context({
    Map<String, dynamic> checkpoint = const {},
    bool Function()? isCurrent,
  }) => FeedbackUploadContext(
    operationId: 'stable',
    checkpoint: checkpoint,
    saveCheckpoint: (value) async => checkpoints.add(value),
    isCurrent: isCurrent ?? () => true,
  );

  test('successful prepare deletes the compressor output only', () async {
    final source0 = FeedbackRemoteDataSourceImpl(
      _confirmingApi(),
      prepareFile: compress,
    );

    final result = await source0.uploadMedia(
      source,
      'video/mp4',
      context: context(),
    );

    expect(result.uploadId, 'one');
    expect(await compressorOutput.exists(), isFalse);
    expect(await source.exists(), isTrue);
    expect(await File(preparedPath).length(), 8192);
    expect(checkpoints.last['prepared_path'], preparedPath);
  });

  test(
    'session change after compression still deletes the compressor output',
    () async {
      var current = true;
      final source0 = FeedbackRemoteDataSourceImpl(
        _confirmingApi(),
        prepareFile: (file, type) async {
          final output = await compress(file, type);
          current = false;
          return output;
        },
      );

      await expectLater(
        source0.uploadMedia(
          source,
          'video/mp4',
          context: context(isCurrent: () => current),
        ),
        throwsA(isA<DioException>()),
      );

      expect(await compressorOutput.exists(), isFalse);
      expect(await source.exists(), isTrue);
      expect(await File(preparedPath).exists(), isFalse);
    },
  );

  test(
    'session change after the prepared copy keeps the prepared file',
    () async {
      final source0 = FeedbackRemoteDataSourceImpl(
        _confirmingApi(),
        prepareFile: compress,
      );

      await expectLater(
        source0.uploadMedia(
          source,
          'video/mp4',
          // Becomes stale exactly once the prepared copy has been written.
          context: context(isCurrent: () => !File(preparedPath).existsSync()),
        ),
        throwsA(isA<DioException>()),
      );

      expect(await compressorOutput.exists(), isFalse);
      expect(await source.exists(), isTrue);
      expect(await File(preparedPath).length(), 8192);
    },
  );

  test('a compressor returning the source never deletes it', () async {
    final deleted = <String>[];
    final source0 = FeedbackRemoteDataSourceImpl(
      _confirmingApi(),
      prepareFile: (file, _) async => file,
      deleteTemporaryFile: (file) async => deleted.add(file.path),
    );

    await source0.uploadMedia(source, 'video/mp4', context: context());

    expect(deleted, isEmpty);
    expect(await source.length(), 16384);
    expect(checkpoints.last['prepared_path'], source.path);
  });

  test(
    'a compressor output already at the prepared path is not deleted',
    () async {
      final deleted = <String>[];
      final source0 = FeedbackRemoteDataSourceImpl(
        _confirmingApi(),
        prepareFile: (_, _) =>
            File(preparedPath).writeAsBytes(List.filled(8192, 3)),
        deleteTemporaryFile: (file) async => deleted.add(file.path),
      );

      await source0.uploadMedia(source, 'video/mp4', context: context());

      expect(deleted, isEmpty);
      expect(await File(preparedPath).length(), 8192);
      expect(await source.exists(), isTrue);
    },
  );

  test('compressor output deletion failure does not fail the upload', () async {
    final attempted = <String>[];
    final source0 = FeedbackRemoteDataSourceImpl(
      _confirmingApi(),
      prepareFile: compress,
      deleteTemporaryFile: (file) async {
        attempted.add(file.path);
        throw FileSystemException('locked', file.path);
      },
    );

    final result = await source0.uploadMedia(
      source,
      'video/mp4',
      context: context(),
    );

    expect(result.fileUrl, 'r2://one');
    expect(attempted, [compressorOutput.path]);
    expect(await source.exists(), isTrue);
    expect(await File(preparedPath).length(), 8192);
    expect(checkpoints.last['phase'], 'completion_confirmed');
  });

  test(
    'resume with an existing prepared file neither compresses nor deletes',
    () async {
      final prepared = await File(
        preparedPath,
      ).writeAsBytes(List.filled(8192, 4));
      final deleted = <String>[];
      final source0 = FeedbackRemoteDataSourceImpl(
        _confirmingApi(),
        prepareFile: (_, _) async => throw StateError('must not prepare'),
        deleteTemporaryFile: (file) async => deleted.add(file.path),
      );

      await source0.uploadMedia(
        source,
        'video/mp4',
        context: context(
          checkpoint: {
            'prepared_path': preparedPath,
            'prepared_content_type': 'video/mp4',
            'prepared_bytes': 8192,
          },
        ),
      );

      expect(deleted, isEmpty);
      expect(await prepared.length(), 8192);
      expect(await source.exists(), isTrue);
      expect(checkpoints.last['phase'], 'completion_confirmed');
    },
  );
}
