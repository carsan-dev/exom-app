// L5-F4 «Hoja de técnica» (docs/plans/rediseno-app-l5-contrato-v2.md; sketch
// f-resto.html, frames f4-video and f4-texto): the sheet opened with
// showExerciseTechniqueSheet, as the active exercise and the circuit open it.
// The opening from both pages is covered in their redesign tests.
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/trainings/presentation/widgets/exercise_technique_sheet.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../core/widgets/exom_component_harness.dart';
import '../../../../golden/redesign_scenes.dart' show loadRedesignFonts;

const techniqueSheetSections = <TechniqueSection>[
  (
    title: 'Técnica',
    text:
        'Pie adelantado en el suelo, el de atrás apoyado en el banco. Baja en '
        'vertical hasta que la rodilla de atrás casi toque el suelo.',
  ),
  (
    title: 'Errores comunes',
    text:
        'Dejar que la rodilla delantera se vaya hacia dentro. Inclinar el '
        'tronco hacia delante al subir.',
  ),
  (
    title: 'Explicación',
    text:
        'Trabaja sobre todo la pierna adelantada. Empieza sin carga hasta '
        'dominar el equilibrio.',
  ),
];

/// Pumps a page with a button that opens the technique sheet and opens it.
/// Returns how many times the video was asked for.
Future<ValueNotifier<int>> pumpTechniqueSheet(
  WidgetTester tester, {
  bool hasVideo = true,
  List<TechniqueSection> sections = techniqueSheetSections,
  String exerciseName = 'Sentadilla búlgara',
  Brightness brightness = Brightness.dark,
  TextScaler textScaler = TextScaler.noScaling,
  Size size = const Size(390, 844),
  Locale locale = const Locale('es'),
}) async {
  await loadRedesignFonts();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final videoTaps = ValueNotifier<int>(0);
  addTearDown(videoTaps.dispose);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const Key('open-technique'),
              onPressed: () => showExerciseTechniqueSheet(
                context,
                exerciseName: exerciseName,
                hasVideo: hasVideo,
                videoUrl: hasVideo ? 'https://example.com/v.mp4' : null,
                thumbnailUrl: null,
                onOpenVideo: () => videoTaps.value++,
                sections: sections,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-technique')));
  await tester.pumpAndSettle();
  return videoTaps;
}

Finder _inPanel(Finder finder) =>
    find.descendant(of: find.byKey(const Key('exom-sheet-panel')), matching: finder);

void main() {
  testWidgets('with video: preview at full bleed, square play of 56, «Vídeo» '
      'under it, then the three texts numbered 01-03', (tester) async {
    final taps = await pumpTechniqueSheet(tester);
    expectNoOverflow(tester);
    final video = find.byKey(const Key('technique-sheet-video'));
    final panel = tester.getRect(find.byKey(const Key('exom-sheet-panel')));
    final rect = tester.getRect(video);
    // Full bleed: the preview spans the panel inside its 1 px outline.
    expect(rect.left, lessThanOrEqualTo(panel.left + 1));
    expect(rect.right, greaterThanOrEqualTo(panel.right - 1));
    expect(rect.height, 200);
    expect(tester.getSize(find.byKey(const Key('technique-sheet-play'))),
        const Size(56, 56));
    final caption = _inPanel(find.text('Vídeo'));
    expect(caption, findsOneWidget);
    expect(tester.getTopLeft(caption).dy, greaterThan(rect.bottom));
    for (final n in const ['01', '02', '03']) {
      expect(_inPanel(find.text(n)), findsOneWidget);
    }
    expect(tester.getTopLeft(_inPanel(find.text('01'))).dy,
        greaterThan(tester.getBottomLeft(caption).dy));
    await tester.tap(video);
    expect(taps.value, 1);
  });

  testWidgets('without video the sheet starts with the texts', (tester) async {
    await pumpTechniqueSheet(tester, hasVideo: false);
    expectNoOverflow(tester);
    expect(find.byKey(const Key('technique-sheet-video')), findsNothing);
    expect(_inPanel(find.text('Vídeo')), findsNothing);
    final name = _inPanel(find.text('Sentadilla búlgara'));
    final first = _inPanel(find.text('01'));
    // Header, then the first numbered text 18 px under it (no video between).
    final gap = tester.getTopLeft(first).dy - tester.getBottomLeft(name).dy;
    expect(gap, lessThan(30));
  });

  testWidgets('only the present texts are numbered, in order', (tester) async {
    await pumpTechniqueSheet(
      tester,
      hasVideo: false,
      sections: [techniqueSheetSections[0], techniqueSheetSections[2]],
    );
    expect(_inPanel(find.text('01')), findsOneWidget);
    expect(_inPanel(find.text('02')), findsOneWidget);
    expect(_inPanel(find.text('03')), findsNothing);
    expect(_inPanel(find.text('Errores comunes')), findsNothing);
    final two = tester.getCenter(_inPanel(find.text('02'))).dy;
    final explanation = tester.getCenter(_inPanel(find.text('Explicación'))).dy;
    expect((two - explanation).abs(), lessThan(4));
  });

  testWidgets('«Cerrar» is the l10n copy, sits in the pinned footer and '
      'closes the sheet', (tester) async {
    await pumpTechniqueSheet(tester);
    final close = find.byKey(const Key('technique-sheet-close'));
    expect(
      find.descendant(
        of: find.byKey(const Key('exom-sheet-actions')),
        matching: close,
      ),
      findsOneWidget,
    );
    expect(find.descendant(of: close, matching: find.text('Cerrar')),
        findsOneWidget);
    await expectTapTargetGuidelines(tester);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exom-sheet-panel')), findsNothing);
  });

  testWidgets('«Close» in English', (tester) async {
    await pumpTechniqueSheet(tester, locale: const Locale('en'));
    expect(
      find.descendant(
        of: find.byKey(const Key('technique-sheet-close')),
        matching: find.text('Close'),
      ),
      findsOneWidget,
    );
  });

  for (final hasVideo in const [false, true]) {
    testWidgets('at 320 dp and 160 % the sheet scrolls and «Cerrar» stays '
        'fixed (${hasVideo ? 'with' : 'without'} video)', (tester) async {
      await pumpTechniqueSheet(
        tester,
        hasVideo: hasVideo,
        size: const Size(320, 568),
        textScaler: const TextScaler.linear(1.6),
      );
      expectNoOverflow(tester);
      final scrollable = find
          .descendant(
            of: find.byKey(const Key('exom-sheet-panel')),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));
      final close = find.byKey(const Key('technique-sheet-close'));
      final before = tester.getRect(close);
      expect(before.bottom, lessThanOrEqualTo(568));
      expect(close.hitTestable(), findsOneWidget);
      for (var i = 0; i < 10; i++) {
        await tester.drag(scrollable, const Offset(0, -200));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
      expect(position.pixels, position.maxScrollExtent);
      expect(tester.getRect(close), before);
      expect(close.hitTestable(), findsOneWidget);
      // The last text ends above the pinned footer.
      final last = find.textContaining('dominar el equilibrio');
      expect(
        tester.getBottomLeft(last).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byKey(const Key('exom-sheet-actions'))).dy,
        ),
      );
      expect(find.byKey(const Key('exom-sheet-panel')), findsOneWidget);
    });
  }
}
