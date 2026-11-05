import 'dart:io';
import 'package:exom_app/core/utils/feedback_preparation_files.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressor {
  static Future<File> compress(
    File file, {
    int maxWidth = 1200,
    int maxHeight = 1200,
    int quality = 75,
  }) async {
    await FeedbackPreparationFiles.rejectSource(file);
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final targetPath = '${dir.path}/compressed_$timestamp.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      minWidth: maxWidth,
      minHeight: maxHeight,
      quality: quality,
      format: CompressFormat.jpeg,
    );

    if (result == null) return file;
    return File(result.path);
  }

  /// Android's file-return callback can precede its final stream close. Keep
  /// native code off the reserved file; only this awaited Dart write owns it.
  static Future<File> compressToPreparation(File file, File target) async {
    await FeedbackPreparationFiles.rejectSource(file);
    final bytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 1200,
      minHeight: 1200,
      quality: 75,
      format: CompressFormat.jpeg,
    );
    if (bytes == null) return file;
    await target.create(exclusive: true);
    return target.writeAsBytes(bytes, flush: true);
  }

  static Future<File> compressAvatar(File file) {
    return compress(file, maxWidth: 400, maxHeight: 400, quality: 75);
  }
}
