// L5-E3d: first frame and duration of the video the user has just recorded or
// chosen, in «Vídeo preparado» of the last-set video sheet. The thumbnail runs
// on a fake preview (local_video_preview_fake.dart); the real one wraps
// `VideoPlayerController.file`.
import 'dart:io';

import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/features/trainings/presentation/widgets/local_video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/exom_component_harness.dart';
import 'local_video_preview_fake.dart';

final Finder _frame = find.byKey(const Key('fake-video-frame'));
final Finder _icon = find.byIcon(ExomIcons.video);

Future<List<Duration>> _pumpThumbnail(
  WidgetTester tester,
  FakePreviewFactory factory, {
  String path = 'clip-a.mp4',
  bool disableAnimations = false,
}) async {
  debugResetLocalVideoDisposals();
  final durations = <Duration>[];
  await pumpComponent(
    tester,
    Center(
      child: LocalVideoThumbnail(
        key: const Key('thumb'),
        file: File(path),
        previewFactory: factory.call,
        onDuration: durations.add,
      ),
    ),
    disableAnimations: disableAnimations,
  );
  return durations;
}

double _frameOpacity(WidgetTester tester) {
  final opacities = tester
      .widgetList<Opacity>(
        find.ancestor(of: _frame, matching: find.byType(Opacity)),
      )
      .map((o) => o.opacity);
  final fades = tester
      .widgetList<FadeTransition>(
        find.ancestor(of: _frame, matching: find.byType(FadeTransition)),
      )
      .map((f) => f.opacity.value);
  return [...opacities, ...fades].fold<double>(1, (a, b) => a * b);
}

void main() {
  group('formatClipDuration', () {
    test('m:ss under an hour, h:mm:ss from an hour', () {
      expect(formatClipDuration(const Duration(seconds: 42)), '0:42');
      expect(formatClipDuration(const Duration(seconds: 5)), '0:05');
      expect(formatClipDuration(const Duration(minutes: 1, seconds: 5)), '1:05');
      expect(
        formatClipDuration(const Duration(minutes: 59, seconds: 59)),
        '59:59',
      );
      expect(
        formatClipDuration(const Duration(hours: 1, minutes: 1, seconds: 2)),
        '1:01:02',
      );
      expect(
        formatClipDuration(const Duration(seconds: 42, milliseconds: 900)),
        '0:42',
      );
    });

    test('a clip shorter than a second shows 0:01, not 0:00 (r2)', () {
      expect(formatClipDuration(const Duration(milliseconds: 1)), '0:01');
      expect(formatClipDuration(const Duration(milliseconds: 400)), '0:01');
      expect(formatClipDuration(const Duration(milliseconds: 999)), '0:01');
      expect(formatClipDuration(const Duration(seconds: 1)), '0:01');
      expect(formatClipDuration(const Duration(milliseconds: 1500)), '0:01');
      expect(formatClipDuration(Duration.zero), '0:00');
    });
  });

  group('LocalVideoThumbnail', () {
    testWidgets('shows the current icon box while the preview initializes', (
      tester,
    ) async {
      final factory = FakePreviewFactory(gated: true);
      final durations = await _pumpThumbnail(tester, factory);
      expect(factory.created, hasLength(1));
      expect(factory.created.single.initializeCalled, isTrue);
      expect(_icon, findsOneWidget);
      expect(_frame, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.getSize(find.byKey(const Key('thumb'))), const Size(56, 56));
      expect(durations, isEmpty);
      factory.release();
      await tester.pumpAndSettle();
    });

    testWidgets('shows the first frame, cropped to the 56 dp box, once '
        'initialized, and reports the duration', (tester) async {
      final factory = FakePreviewFactory();
      final durations = await _pumpThumbnail(tester, factory);
      await tester.pumpAndSettle();
      expect(_frame, findsOneWidget);
      final box = tester.getRect(find.byKey(const Key('thumb')));
      expect(box.size, const Size(56, 56));
      final fitted = tester.widget<FittedBox>(
        find.ancestor(of: _frame, matching: find.byType(FittedBox)),
      );
      expect(fitted.fit, BoxFit.cover);
      // The frame keeps the clip's own size inside the FittedBox.
      expect(tester.getSize(_frame), const Size(720, 1280));
      expect(_frameOpacity(tester), 1);
      expect(durations, [const Duration(seconds: 42)]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fades the frame in within 150 ms', (tester) async {
      final factory = FakePreviewFactory(gated: true);
      await _pumpThumbnail(tester, factory);
      factory.release();
      await tester.pump();
      await tester.pump();
      expect(_frame, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      final mid = _frameOpacity(tester);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      await tester.pump(const Duration(milliseconds: 90));
      expect(_frameOpacity(tester), 1);
    });

    testWidgets('with reduced motion the frame appears without a fade', (
      tester,
    ) async {
      final factory = FakePreviewFactory(gated: true);
      await _pumpThumbnail(tester, factory, disableAnimations: true);
      factory.release();
      await tester.pump();
      await tester.pump();
      expect(_frame, findsOneWidget);
      expect(_frameOpacity(tester), 1);
    });

    testWidgets('keeps the icon box and reports no duration when '
        'initialize fails, and releases the preview', (tester) async {
      final factory = FakePreviewFactory(fails: true);
      final durations = await _pumpThumbnail(tester, factory);
      await tester.pumpAndSettle();
      expect(_icon, findsOneWidget);
      expect(_frame, findsNothing);
      expect(durations, isEmpty);
      expect(factory.created.single.disposed, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('gives up after the timeout: icon box, preview released, a '
        'late initialize is ignored', (tester) async {
      final factory = FakePreviewFactory(gated: true);
      final durations = await _pumpThumbnail(tester, factory);
      await tester.pump(kLocalVideoPreviewTimeout + const Duration(seconds: 1));
      expect(factory.created.single.disposed, isTrue);
      factory.release();
      await tester.pumpAndSettle();
      expect(_icon, findsOneWidget);
      expect(_frame, findsNothing);
      expect(durations, isEmpty);
    });

    testWidgets('a clip without a picture keeps the icon box but reports its '
        'duration', (tester) async {
      final factory = FakePreviewFactory(size: Size.zero);
      final durations = await _pumpThumbnail(tester, factory);
      await tester.pumpAndSettle();
      expect(_icon, findsOneWidget);
      expect(_frame, findsNothing);
      expect(durations, [const Duration(seconds: 42)]);
    });

    testWidgets('unmounting during initialize releases the preview and the '
        'late result is ignored', (tester) async {
      final factory = FakePreviewFactory(gated: true);
      final durations = await _pumpThumbnail(tester, factory);
      await tester.pumpWidget(const SizedBox());
      expect(factory.created.single.disposed, isTrue);
      factory.release();
      await tester.pump();
      await tester.pump();
      expect(durations, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unmounting after initialize releases the preview', (
      tester,
    ) async {
      final factory = FakePreviewFactory();
      await _pumpThumbnail(tester, factory);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(factory.created.single.disposed, isTrue);
    });

    testWidgets('a new file releases the previous preview before opening the '
        'next one', (tester) async {
      final factory = FakePreviewFactory(gated: true);
      final durations = <Duration>[];
      Widget thumb(String path) => Center(
        child: LocalVideoThumbnail(
          key: const Key('thumb'),
          file: File(path),
          previewFactory: factory.call,
          onDuration: durations.add,
        ),
      );
      Widget app(String path) => MaterialApp(home: Scaffold(body: thumb(path)));
      await tester.pumpWidget(app('clip-a.mp4'));
      // Same tree, new file: didUpdateWidget, not a remount.
      await tester.pumpWidget(app('clip-b.mp4'));
      expect(factory.created, hasLength(2));
      expect(factory.created.first.disposed, isTrue);
      expect(factory.created.last.file.path, 'clip-b.mp4');
      expect(factory.maxAlive, 1);
      expect(factory.alive, 1);
      factory.release();
      await tester.pumpAndSettle();
      expect(durations, [const Duration(seconds: 42)]);
    });

    Widget app(FakePreviewFactory factory, String path) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: LocalVideoThumbnail(
            key: const Key('thumb'),
            file: File(path),
            previewFactory: factory.call,
          ),
        ),
      ),
    );

    testWidgets('a new file opens only after the previous player is '
        'released; the icon box shows meanwhile (r2)', (tester) async {
      debugResetLocalVideoDisposals();
      final factory = FakePreviewFactory(slowDispose: true);
      await tester.pumpWidget(app(factory, 'clip-a.mp4'));
      await tester.pumpAndSettle();
      expect(_frame, findsOneWidget);
      await tester.pumpWidget(app(factory, 'clip-b.mp4'));
      await tester.pump();
      expect(factory.created.first.disposeCalled, isTrue);
      expect(factory.created, hasLength(1));
      expect(_icon, findsOneWidget);
      expect(_frame, findsNothing);
      factory.finishDisposals();
      await tester.pumpAndSettle();
      expect(factory.created, hasLength(2));
      expect(factory.created.last.file.path, 'clip-b.mp4');
      expect(factory.maxAlive, 1);
      expect(_frame, findsOneWidget);
    });

    testWidgets('a remounted thumbnail also waits for the previous release '
        '(r2)', (tester) async {
      debugResetLocalVideoDisposals();
      final factory = FakePreviewFactory(slowDispose: true);
      await tester.pumpWidget(app(factory, 'clip-a.mp4'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(factory, 'clip-b.mp4'));
      await tester.pump();
      expect(factory.created, hasLength(1));
      factory.finishDisposals();
      await tester.pumpAndSettle();
      expect(factory.created, hasLength(2));
      expect(factory.maxAlive, 1);
    });

    testWidgets('a release that never finishes delays the next clip at most '
        'kLocalVideoDisposeWait (r2)', (tester) async {
      debugResetLocalVideoDisposals();
      final factory = FakePreviewFactory(slowDispose: true);
      await tester.pumpWidget(app(factory, 'clip-a.mp4'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(factory, 'clip-b.mp4'));
      await tester.pump();
      expect(factory.created, hasLength(1));
      await tester.pump(kLocalVideoDisposeWait + const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(factory.created, hasLength(2));
      expect(_frame, findsOneWidget);
      factory.finishDisposals();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a dispose that throws synchronously is contained (r2)', (
      tester,
    ) async {
      debugResetLocalVideoDisposals();
      final factory = FakePreviewFactory(disposeThrowsSync: true);
      await tester.pumpWidget(app(factory, 'clip-a.mp4'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(factory, 'clip-b.mp4'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(factory.created, hasLength(2));
      expect(_frame, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      expect(factory.created.last.disposeCalled, isTrue);
    });

    testWidgets('the thumbnail is decorative: no semantics of the frame', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final factory = FakePreviewFactory();
      await _pumpThumbnail(tester, factory);
      await tester.pumpAndSettle();
      expect(_frame, findsOneWidget);
      expect(find.bySemanticsLabel(kFakeFrameLabel), findsNothing);
      handle.dispose();
    });
  });

  test('pages without their own factory use the test override when set', () {
    final factory = FakePreviewFactory();
    debugLocalVideoPreviewFactoryOverride = factory.call;
    addTearDown(() => debugLocalVideoPreviewFactoryOverride = null);
    final preview = createPlayerLocalVideoPreview(File('clip-z.mp4'));
    expect(preview, same(factory.created.single));
    expect(factory.created.single.file.path, 'clip-z.mp4');
  });
}
