// L5-E3d: «Vídeo preparado» of the last-set video sheet shows the first frame
// and the duration of the chosen clip (replaces E3b decision 5 / D15 for this
// case). Fake preview: local_video_preview_fake.dart.
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/features/trainings/presentation/widgets/local_video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'local_video_preview_fake.dart';

final Finder _frame = find.byKey(const Key('fake-video-frame'));
final Finder _thumb = find.byType(LocalVideoThumbnail);

Finder _line(String text) => find.text(text, findRichText: true);

void main() {
  testWidgets('the chosen clip shows its frame in the box and its duration '
      'on the set line', (tester) async {
    final factory = FakePreviewFactory();
    await pumpLastSetVideoSheet(tester, factory: factory);
    await tester.pumpAndSettle();
    expect(_thumb, findsOneWidget);
    expect(tester.getSize(_thumb), const Size(56, 56));
    expect(_frame, findsOneWidget);
    expect(factory.created.single.file.path, 'clip-a.mp4');
    expect(_line('Serie 4 · 8 × 62,5 kg · 0:42'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the duration uses tabular figures', (tester) async {
    final factory = FakePreviewFactory();
    await pumpLastSetVideoSheet(tester, factory: factory);
    await tester.pumpAndSettle();
    final rich = tester.widget<RichText>(
      find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText() == 'Serie 4 · 8 × 62,5 kg · 0:42',
      ),
    );
    TextStyle? durationStyle;
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == '0:42') durationStyle = span.style;
      return true;
    });
    expect(
      durationStyle?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('without a set label the line shows only the duration', (
    tester,
  ) async {
    final factory = FakePreviewFactory();
    await pumpLastSetVideoSheet(tester, factory: factory, setLabel: null);
    await tester.pumpAndSettle();
    expect(_line('0:42'), findsOneWidget);
  });

  testWidgets('while the clip opens: icon box and no duration', (
    tester,
  ) async {
    final factory = FakePreviewFactory(gated: true);
    await pumpLastSetVideoSheet(tester, factory: factory);
    expect(find.byIcon(ExomIcons.video), findsOneWidget);
    expect(_frame, findsNothing);
    expect(_line('Serie 4 · 8 × 62,5 kg'), findsOneWidget);
    expect(find.textContaining('0:42', findRichText: true), findsNothing);
    factory.release();
    await tester.pumpAndSettle();
    expect(_line('Serie 4 · 8 × 62,5 kg · 0:42'), findsOneWidget);
  });

  testWidgets('a set label ending in a period drops it before the duration '
      '(O1)', (tester) async {
    final factory = FakePreviewFactory(
      gated: true,
      duration: const Duration(seconds: 7),
    );
    await pumpLastSetVideoSheet(
      tester,
      factory: factory,
      setLabel: 'Serie 4 · 10 reps.',
    );
    // Without a duration the label stays exactly as given.
    expect(_line('Serie 4 · 10 reps.'), findsOneWidget);
    factory.release();
    await tester.pumpAndSettle();
    expect(_line('Serie 4 · 10 reps · 0:07'), findsOneWidget);
    expect(find.textContaining('reps. ·', findRichText: true), findsNothing);
  });

  testWidgets('an unreadable clip keeps the icon box and adds nothing to the '
      'line', (tester) async {
    final factory = FakePreviewFactory(fails: true);
    await pumpLastSetVideoSheet(tester, factory: factory);
    await tester.pumpAndSettle();
    expect(find.byIcon(ExomIcons.video), findsOneWidget);
    expect(_frame, findsNothing);
    expect(_line('Serie 4 · 8 × 62,5 kg'), findsOneWidget);
    expect(find.textContaining('·  ', findRichText: true), findsNothing);
    expect(find.textContaining('0:42', findRichText: true), findsNothing);
  });

  testWidgets('«Vídeo preparado» reads the duration when there is one', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final factory = FakePreviewFactory(gated: true);
    await pumpLastSetVideoSheet(tester, factory: factory);
    expect(find.bySemanticsLabel('Vídeo preparado'), findsOneWidget);
    factory.release();
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Vídeo preparado, duración 0:42'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(kFakeFrameLabel), findsNothing);
    handle.dispose();
  });

  testWidgets('English: duration on the line and in the label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final factory = FakePreviewFactory(
      duration: const Duration(hours: 1, minutes: 2, seconds: 3),
    );
    await pumpLastSetVideoSheet(
      tester,
      factory: factory,
      locale: const Locale('en'),
      setLabel: 'Set 4 · 8 × 62.5 kg',
    );
    await tester.pumpAndSettle();
    expect(_line('Set 4 · 8 × 62.5 kg · 1:02:03'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Video ready, duration 1:02:03'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('«Cancelar» during initialize releases the preview', (
    tester,
  ) async {
    final factory = FakePreviewFactory(gated: true);
    final result = await pumpLastSetVideoSheet(tester, factory: factory);
    await tester.tap(find.byKey(const Key('last-set-video-cancel')));
    await tester.pumpAndSettle();
    expect(result.value, isNull);
    expect(factory.created.single.disposed, isTrue);
    factory.release();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing after initialize («Usar vídeo») releases the preview', (
    tester,
  ) async {
    final factory = FakePreviewFactory();
    final result = await pumpLastSetVideoSheet(tester, factory: factory);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('last-set-video-use')));
    await tester.pumpAndSettle();
    expect(result.value, isNotNull);
    expect(factory.created.single.disposed, isTrue);
  });

  testWidgets('«Cambiar» releases the preview; the next clip gets a new one '
      'and its own duration, never two alive', (tester) async {
    final factory = FakePreviewFactory();
    await pumpLastSetVideoSheet(tester, factory: factory);
    await tester.pumpAndSettle();
    expect(_line('Serie 4 · 8 × 62,5 kg · 0:42'), findsOneWidget);

    await tester.tap(find.byKey(const Key('last-set-video-change')));
    await tester.pumpAndSettle();
    expect(_thumb, findsNothing);
    expect(factory.created.single.disposed, isTrue);

    factory
      ..duration = const Duration(seconds: 7)
      ..gated = true;
    await pickFromGallery(tester);
    expect(factory.created, hasLength(2));
    expect(factory.created.last.file.path, 'clip-1.mp4');
    // The old duration is gone while the new clip opens.
    expect(_line('Serie 4 · 8 × 62,5 kg'), findsOneWidget);
    factory.release();
    await tester.pumpAndSettle();
    expect(_line('Serie 4 · 8 × 62,5 kg · 0:07'), findsOneWidget);
    expect(factory.maxAlive, 1);
    expect(factory.alive, 1);
  });

  testWidgets('«Cambiar» then a new clip: the new player opens only after '
      'the old one is released (r2)', (tester) async {
    final factory = FakePreviewFactory(slowDispose: true);
    await pumpLastSetVideoSheet(tester, factory: factory);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('last-set-video-change')));
    await tester.pumpAndSettle();
    expect(factory.created.single.disposeCalled, isTrue);
    await pickFromGallery(tester);
    expect(_thumb, findsOneWidget);
    expect(factory.created, hasLength(1));
    expect(find.byIcon(ExomIcons.video), findsOneWidget);
    factory.finishDisposals();
    await tester.pumpAndSettle();
    expect(factory.created, hasLength(2));
    expect(factory.maxAlive, 1);
    expect(_line('Serie 4 · 8 × 62,5 kg · 0:42'), findsOneWidget);
  });
}
