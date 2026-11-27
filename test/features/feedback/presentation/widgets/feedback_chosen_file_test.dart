// L5-E3d-P1: the chosen file of the feedback form shows a 56 dp thumbnail, the
// kind («Vídeo · 0:12» / «Imagen») and «Quitar»; never the file name.
import 'dart:convert';
import 'dart:io';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/features/feedback/presentation/widgets/feedback_media_picker.dart';
import 'package:exom_app/features/trainings/presentation/widgets/local_video_thumbnail.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/android_nonlinear_text_scaler.dart';

class _FakePreview implements LocalVideoPreview {
  _FakePreview(this._duration);

  final Duration? _duration;

  @override
  Future<void> initialize() async {
    if (_duration == null) throw StateError('unreadable');
  }

  @override
  Duration get duration => _duration ?? Duration.zero;

  @override
  Size get size => const Size(90, 160);

  @override
  Widget buildFrame(BuildContext context) =>
      const ColoredBox(color: Color(0xFF446688));

  @override
  Future<void> dispose() async {}
}

// 1x1 PNG.
final List<int> _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

late Directory _tmp;

void main() {
  setUp(() {
    _tmp = Directory.systemTemp.createTempSync('feedback_chosen_file');
  });
  tearDown(() {
    debugLocalVideoPreviewFactoryOverride = null;
    // Windows may still hold the image file open for a moment: best effort.
    try {
      _tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // The OS cleans the temp directory.
    }
  });

  File write(String name, List<int> bytes) =>
      File('${_tmp.path}/$name')..writeAsBytesSync(bytes);

  Future<void> pump(
    WidgetTester tester,
    File file, {
    required bool video,
    VoidCallback? onClear,
    String locale = 'es',
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: AndroidNonlinearTextScaler(scale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: FeedbackMediaPicker(
                selectedFile: file,
                mediaType: video ? 'VIDEO' : 'IMAGE',
                videoOnly: video,
                isUploading: false,
                onMediaTypeChanged: (_) {},
                onFileSelected: (_) {},
                onClear: onClear ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  const thumb = Key('feedback-file-thumbnail');

  // «Imagen» is also the media-type chip of the form: look in the file row.
  Finder inRow(String text) => find.descendant(
    of: find.ancestor(of: find.byKey(thumb), matching: find.byType(Row)).first,
    matching: find.text(text),
  );

  testWidgets('video with duration: «Vídeo · 0:12», 56x56, no file name', (
    tester,
  ) async {
    debugLocalVideoPreviewFactoryOverride = (_) =>
        _FakePreview(const Duration(seconds: 12));
    await pump(tester, write('mi_clip_secreto.mp4', [0]), video: true);
    expect(find.text('Vídeo · 0:12', findRichText: true), findsOneWidget);
    expect(tester.getSize(find.byKey(thumb)), const Size(56, 56));
    expect(find.byType(LocalVideoThumbnail), findsOneWidget);
    expect(find.textContaining('mi_clip_secreto'), findsNothing);
    expect(find.textContaining('.mp4'), findsNothing);
    expect(find.text('Quitar'), findsOneWidget);
  });

  testWidgets('video without duration shows only «Vídeo»', (tester) async {
    debugLocalVideoPreviewFactoryOverride = (_) => _FakePreview(null);
    await pump(tester, write('a.mp4', [0]), video: true);
    expect(find.text('Vídeo'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
    expect(tester.getSize(find.byKey(thumb)), const Size(56, 56));
    expect(find.byIcon(ExomIcons.video), findsOneWidget);
  });

  testWidgets('image: «Imagen», 56x56 Image.file cover, no file name', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await pump(tester, write('foto_privada.png', _png), video: false);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(inRow('Imagen'), findsOneWidget);
    expect(tester.getSize(find.byKey(thumb)), const Size(56, 56));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.cover);
    expect(find.textContaining('foto_privada'), findsNothing);
    expect(find.byIcon(ExomIcons.image), findsNothing);
  });

  testWidgets('corrupt image falls back to the box with the image icon', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await pump(tester, write('rota.png', [1, 2, 3, 4]), video: false);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(thumb)), const Size(56, 56));
    expect(find.byIcon(ExomIcons.image), findsOneWidget);
    expect(inRow('Imagen'), findsOneWidget);
  });

  testWidgets('«Quitar» calls onClear and has a 48 dp target', (tester) async {
    debugLocalVideoPreviewFactoryOverride = (_) =>
        _FakePreview(const Duration(seconds: 12));
    var cleared = 0;
    await pump(
      tester,
      write('a.mp4', [0]),
      video: true,
      onClear: () => cleared++,
    );
    final size = tester.getSize(find.byType(ExomTextLink));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Quitar'));
    expect(cleared, 1);
  });

  testWidgets('semantics: row reads «Vídeo, 0:12»; «Quitar» is a button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    debugLocalVideoPreviewFactoryOverride = (_) =>
        _FakePreview(const Duration(seconds: 12));
    await pump(tester, write('a.mp4', [0]), video: true);
    expect(find.bySemanticsLabel('Vídeo, 0:12'), findsOneWidget);
    expect(find.bySemanticsLabel('Vídeo · 0:12'), findsNothing);
    expect(
      tester.getSemantics(find.text('Quitar')),
      isSemantics(label: 'Quitar', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  for (final locale in ['es', 'en']) {
    for (final video in [true, false]) {
      final kind = video ? 'video' : 'image';
      testWidgets('320 dp at 2.0x does not overflow ($locale, $kind)', (
        tester,
      ) async {
        debugLocalVideoPreviewFactoryOverride = (_) =>
            _FakePreview(const Duration(seconds: 3725));
        await tester.runAsync(() async {
          await pump(
            tester,
            write(video ? 'a.mp4' : 'a.png', video ? [0] : _png),
            video: video,
            locale: locale,
            width: 320,
            scale: 2,
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byKey(thumb)), const Size(56, 56));
      });
    }
  }
}
