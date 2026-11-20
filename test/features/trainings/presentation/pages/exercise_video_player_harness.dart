// Shared by the L5-A2 tests and golden: a [VideoPlayerController] that needs
// no platform video, and a helper that pumps the player page on it.
import 'package:exom_app/features/trainings/presentation/pages/exercise_video_player_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/widgets/exom_component_harness.dart';

class FakeVideoController extends VideoPlayerController {
  FakeVideoController({this.videoSize = const Size(1280, 720)})
    : super.networkUrl(Uri.parse('https://video.example.test/clip.mp4'));

  /// Size of the fake clip (16:9 by default; 720x1280 is a vertical clip).
  final Size videoSize;

  final List<String> calls = <String>[];

  @override
  Future<void> initialize() async {
    value = VideoPlayerValue(
      duration: const Duration(seconds: 38),
      size: videoSize,
      position: const Duration(seconds: 12),
      isInitialized: true,
    );
  }

  @override
  Future<void> play() async {
    calls.add('play');
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    calls.add('seek:${position.inSeconds}');
    value = value.copyWith(position: position);
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    calls.add('speed:$speed');
    value = value.copyWith(playbackSpeed: speed);
  }
}

Future<FakeVideoController> pumpPlayer(
  WidgetTester tester, {
  Brightness brightness = Brightness.dark,
  bool accessibleNavigation = false,
  bool disableAnimations = false,
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  Locale locale = const Locale('es'),
  String title = 'Sentadilla búlgara',
  Size videoSize = const Size(1280, 720),
}) async {
  final controller = FakeVideoController(videoSize: videoSize);
  await pumpComponent(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(accessibleNavigation: accessibleNavigation),
        child: ExerciseVideoPlayerPage(
          title: title,
          videoUri: Uri.parse('https://video.example.test/clip.mp4'),
          controllerFactory: (_) => controller,
        ),
      ),
    ),
    brightness: brightness,
    width: width,
    height: height,
    textScale: textScale,
    disableAnimations: disableAnimations,
    locale: locale,
    wrapInScaffold: false,
  );
  // initialize() + play() resolve in microtasks.
  await tester.pump();
  await tester.pump();
  return controller;
}
