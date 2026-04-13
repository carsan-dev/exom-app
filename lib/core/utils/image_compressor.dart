import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressor {
  static Future<File> compress(
    File file, {
    int maxWidth = 1200,
    int maxHeight = 1200,
    int quality = 80,
  }) async {
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

  static Future<File> compressAvatar(File file) {
    return compress(file, maxWidth: 400, maxHeight: 400, quality: 75);
  }
}
