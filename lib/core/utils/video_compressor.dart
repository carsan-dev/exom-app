import 'dart:io';
import 'dart:typed_data';
import 'package:video_compress/video_compress.dart';

class VideoCompressor {
  static Future<File> compress(File file) async {
    final info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
    );

    if (info == null || info.file == null) return file;
    return info.file!;
  }

  static Future<File?> generateThumbnail(File file) async {
    final Uint8List? thumbnail = await VideoCompress.getByteThumbnail(
      file.path,
      quality: 75,
      position: -1, // default position
    );

    if (thumbnail == null) return null;

    final dir = file.parent;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final thumbFile = File('${dir.path}/thumb_$timestamp.jpg');
    await thumbFile.writeAsBytes(thumbnail);
    return thumbFile;
  }
}
