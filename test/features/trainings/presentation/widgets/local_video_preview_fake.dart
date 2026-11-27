// Shared by the L5-E3d tests and goldens: a [LocalVideoPreview] that needs no
// platform video, a factory that records every preview it creates, and a
// helper that opens the last-set video sheet on them and picks a clip.
// Not a test file: it has no `main` and is only imported.
import 'dart:async';
import 'dart:io';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/features/trainings/presentation/widgets/last_set_video_sheet.dart';
import 'package:exom_app/features/trainings/presentation/widgets/local_video_thumbnail.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;

/// Semantics label of the fake frame: the thumbnail must exclude it.
const String kFakeFrameLabel = 'fake video frame';

class FakeLocalVideoPreview implements LocalVideoPreview {
  FakeLocalVideoPreview(
    this.file, {
    required this.gate,
    required this.fails,
    this.disposeGate,
    this.disposeThrowsSync = false,
    required Duration duration,
    required Size size,
  }) : _duration = duration,
       _size = size;

  final File file;

  /// When not null, `initialize` waits for it (a slow or hung decoder).
  final Completer<void>? gate;
  final bool fails;

  /// When not null, `dispose` finishes only when it completes (a native
  /// player that takes a moment to release).
  final Completer<void>? disposeGate;

  /// When true, `dispose` throws before returning a future.
  final bool disposeThrowsSync;
  final Duration _duration;
  final Size _size;

  bool initializeCalled = false;
  bool initialized = false;

  /// `dispose` was called.
  bool disposeCalled = false;

  /// `dispose` finished: the player no longer exists.
  bool disposed = false;

  @override
  Future<void> initialize() async {
    initializeCalled = true;
    final pending = gate;
    if (pending != null) await pending.future;
    if (fails) throw StateError('unreadable clip');
    initialized = true;
  }

  @override
  Duration get duration => _duration;

  @override
  Size get size => _size;

  @override
  Widget buildFrame(BuildContext context) => Semantics(
    label: kFakeFrameLabel,
    child: const DecoratedBox(
      key: Key('fake-video-frame'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2F3B48), Color(0xFF8A7656), Color(0xFF1C2229)],
          stops: [0, 0.55, 1],
        ),
      ),
    ),
  );

  @override
  Future<void> dispose() {
    disposeCalled = true;
    if (disposeThrowsSync) {
      disposed = true;
      throw StateError('dispose failed synchronously');
    }
    final pending = disposeGate;
    if (pending == null) {
      disposed = true;
      return Future<void>.value();
    }
    return pending.future.then((_) => disposed = true);
  }
}

/// Records every preview and the most that were alive at once.
class FakePreviewFactory {
  FakePreviewFactory({
    this.duration = const Duration(seconds: 42),
    this.size = const Size(720, 1280),
    this.fails = false,
    this.gated = false,
    this.slowDispose = false,
    this.disposeThrowsSync = false,
  });

  Duration duration;
  Size size;
  bool fails;

  /// When true each preview waits for its own gate (see [release]).
  bool gated;

  /// When true each `dispose` waits for [finishDisposals].
  bool slowDispose;

  /// When true each `dispose` throws synchronously.
  bool disposeThrowsSync;

  final List<FakeLocalVideoPreview> created = <FakeLocalVideoPreview>[];
  int maxAlive = 0;

  int get alive => created.where((p) => !p.disposed).length;

  LocalVideoPreview call(File file) {
    final preview = FakeLocalVideoPreview(
      file,
      gate: gated ? Completer<void>() : null,
      fails: fails,
      disposeGate: slowDispose ? Completer<void>() : null,
      disposeThrowsSync: disposeThrowsSync,
      duration: duration,
      size: size,
    );
    created.add(preview);
    if (alive > maxAlive) maxAlive = alive;
    return preview;
  }

  /// Lets the last gated preview finish `initialize`.
  void release() => created.last.gate?.complete();

  /// Lets every pending slow `dispose` finish.
  void finishDisposals() {
    for (final preview in created) {
      final gate = preview.disposeGate;
      if (preview.disposeCalled && gate != null && !gate.isCompleted) {
        gate.complete();
      }
    }
  }
}

/// Opens [LastSetVideoSheet] through `showExomSheet` and, when [pick] is
/// true, chooses a clip from the gallery so the sheet shows «Vídeo
/// preparado». Returns the slot that receives the sheet's result.
Future<ValueNotifier<Object?>> pumpLastSetVideoSheet(
  WidgetTester tester, {
  required FakePreviewFactory factory,
  bool pick = true,
  String? setLabel = 'Serie 4 · 8 × 62,5 kg',
  Brightness brightness = Brightness.dark,
  TextScaler textScaler = TextScaler.noScaling,
  Size size = const Size(390, 844),
  Locale locale = const Locale('es'),
  bool disableAnimations = false,
  String path = 'clip-a.mp4',
}) async {
  debugResetLocalVideoDisposals();
  await loadRedesignFonts();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final result = ValueNotifier<Object?>('open');
  addTearDown(result.dispose);
  var picks = 0;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScaler,
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const Key('open-last-set-video'),
              onPressed: () async {
                result.value = await showExomSheet<LastSetVideoChoice>(
                  context: context,
                  builder: (_) => LastSetVideoSheet(
                    kicker: 'Sentadilla búlgara · serie 4',
                    setLabel: setLabel,
                    // Each pick returns a new file, like a new recording.
                    pickVideo: (_) async {
                      final n = picks++;
                      return File(n == 0 ? path : 'clip-$n.mp4');
                    },
                    previewFactory: factory.call,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-last-set-video')));
  await tester.pumpAndSettle();
  if (pick) await pickFromGallery(tester);
  return result;
}

/// Taps «Elegir de la galería» and lets the fake picker answer.
Future<void> pickFromGallery(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('last-set-video-gallery')));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}
