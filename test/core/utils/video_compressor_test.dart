import 'dart:convert';
import 'dart:io';

import 'package:exom_app/core/utils/video_compressor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('com.exommethod.exom/video_compression');
  const legacy = MethodChannel('video_compress');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late File source;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exom-video-test-');
    source = await File('${directory.path}/source.mov').writeAsBytes([1, 2, 3]);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(legacy, (_) async => null);
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(native, null);
    messenger.setMockMethodCallHandler(legacy, null);
    await directory.delete(recursive: true);
  });

  test(
    'Android returns app-owned prepared MP4 and preserves original',
    () async {
      final output = await File(
        '${directory.path}/normalized.mp4',
      ).writeAsBytes([4]);
      messenger.setMockMethodCallHandler(native, (call) async {
        expect(call.method, 'compress');
        expect(call.arguments, {'path': source.path});
        return output.path;
      });
      expect((await VideoCompressor.compress(source)).path, output.path);
      expect(await source.readAsBytes(), [1, 2, 3]);
    },
  );

  for (final output in <String?>[null, '', '   ']) {
    test(
      'Android rejects invalid output $output without original fallback',
      () async {
        messenger.setMockMethodCallHandler(native, (_) async => output);
        await expectLater(
          VideoCompressor.compress(source),
          throwsA(isA<PlatformException>()),
        );
        expect(await source.readAsBytes(), [1, 2, 3]);
      },
    );
  }

  for (final code in [
    'compression_failed',
    'compression_busy',
    'compression_cancelled',
  ]) {
    test('Android propagates $code and preserves original', () async {
      messenger.setMockMethodCallHandler(
        native,
        (_) async => throw PlatformException(code: code),
      );
      await expectLater(
        VideoCompressor.compress(source),
        throwsA(
          isA<PlatformException>().having((error) => error.code, 'code', code),
        ),
      );
      expect(await source.readAsBytes(), [1, 2, 3]);
    });
  }

  test('Android missing channel never falls back to original', () async {
    await expectLater(
      VideoCompressor.compress(source),
      throwsA(isA<MissingPluginException>()),
    );
    expect(await source.readAsBytes(), [1, 2, 3]);
  });

  test('iOS keeps legacy quality/audio/original contract', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final output = await File('${directory.path}/ios.mp4').writeAsBytes([4]);
    messenger.setMockMethodCallHandler(
      native,
      (_) async => fail('Android channel used on iOS'),
    );
    messenger.setMockMethodCallHandler(legacy, (call) async {
      expect(call.method, 'compressVideo');
      expect(call.arguments['quality'], 6);
      expect(call.arguments['deleteOrigin'], false);
      expect(call.arguments['includeAudio'], true);
      return jsonEncode({'path': output.path});
    });
    expect((await VideoCompressor.compress(source)).path, output.path);
    expect(await source.readAsBytes(), [1, 2, 3]);
  });

  test('iOS retains historical null fallback', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect((await VideoCompressor.compress(source)).path, source.path);
  });

  test('thumbnail remains on legacy channel', () async {
    messenger.setMockMethodCallHandler(legacy, (call) async {
      expect(call.method, 'getByteThumbnail');
      expect(call.arguments, {
        'path': source.path,
        'quality': 75,
        'position': -1,
      });
      return Uint8List.fromList([7, 8]);
    });
    expect(
      await (await VideoCompressor.generateThumbnail(source))!.readAsBytes(),
      [7, 8],
    );
  });
}
