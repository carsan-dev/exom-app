// L5-E3b test support for the last-set video: a recording upload queue and a
// mock of the image picker method channel (the platform default in tests).
import 'dart:io';

import 'package:exom_app/features/feedback/services/feedback_upload_queue_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// One `enqueue` call with every field the page passes.
typedef EnqueueCall = ({
  String path,
  String? expectedSession,
  String contentType,
  String mediaType,
  String? notes,
  String? exerciseId,
  String? feedbackKind,
  String? trainingId,
  String? trainingExerciseId,
  String? assignmentDate,
  String? sessionId,
});

class RecordingVideoQueue extends Fake implements FeedbackUploadQueueService {
  final calls = <EnqueueCall>[];

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
    calls.add((
      path: file.path,
      expectedSession: expectedSession,
      contentType: contentType,
      mediaType: mediaType,
      notes: notes,
      exerciseId: exerciseId,
      feedbackKind: feedbackKind,
      trainingId: trainingId,
      trainingExerciseId: trainingExerciseId,
      assignmentDate: assignmentDate,
      sessionId: sessionId,
    ));
    return 'fb-${calls.length}';
  }
}

const _pickerChannel = MethodChannel('plugins.flutter.io/image_picker');

/// Answers `pickVideo` with [handler] (source 0 = camera, 1 = gallery);
/// records the requested sources in the returned list.
List<int> mockVideoPicker(
  WidgetTester tester,
  Future<String?> Function(int source) handler,
) {
  final sources = <int>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _pickerChannel,
    (call) async {
      if (call.method != 'pickVideo') return null;
      final source = (call.arguments as Map)['source'] as int;
      sources.add(source);
      return handler(source);
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _pickerChannel,
      null,
    ),
  );
  return sources;
}
