import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/trainings/presentation/widgets/exercise_video_preview.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppLocalizations> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: SizedBox(width: 320, height: 220, child: child)),
      ),
    ),
  );
  return AppLocalizations.of(tester.element(find.byType(Scaffold)));
}

void main() {
  testWidgets('without video nor thumbnail the name and the notice show once',
      (tester) async {
    final l10n = await _pump(
      tester,
      const ExerciseVideoPreview(title: 'Sentadilla búlgara'),
    );
    expect(find.text('Sentadilla búlgara'), findsOneWidget);
    expect(find.text(l10n.activeExerciseNoVideo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a broken thumbnail falls back without repeating the name',
      (tester) async {
    final l10n = await _pump(
      tester,
      const ExerciseVideoPreview(
        title: 'Peso muerto rumano',
        thumbnailUrl: 'not a url',
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Peso muerto rumano'), findsOneWidget);
    expect(find.text(l10n.activeExerciseNoVideo), findsOneWidget);
  });

  testWidgets('with a video the overlay shows the name once and the video tag',
      (tester) async {
    final l10n = await _pump(
      tester,
      ExerciseVideoPreview(
        title: 'Hip thrust',
        videoUrl: 'https://example.invalid/v.mp4',
        onTap: () {},
      ),
    );
    expect(find.text('Hip thrust'), findsOneWidget);
    expect(find.text(l10n.video), findsOneWidget);
  });

  testWidgets('with a video and no thumbnail only the play circle shows',
      (tester) async {
    // L3 review S2: the placeholder icon used to peek above the play circle.
    await _pump(
      tester,
      ExerciseVideoPreview(
        title: 'Hip thrust',
        videoUrl: 'https://example.invalid/v.mp4',
        onTap: () {},
      ),
    );
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center), findsNothing);
  });

  testWidgets('without an openable video the placeholder keeps its icon',
      (tester) async {
    await _pump(tester, const ExerciseVideoPreview(title: 'Hip thrust'));
    expect(find.byIcon(Icons.fitness_center), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

    // A video without a tap handler cannot be opened: same as no video.
    await _pump(
      tester,
      const ExerciseVideoPreview(
        title: 'Hip thrust',
        videoUrl: 'https://example.invalid/v.mp4',
      ),
    );
    expect(find.byIcon(Icons.fitness_center), findsOneWidget);
  });

  testWidgets('the video tag and the no-video notice are at least 13 px',
      (tester) async {
    final l10n = await _pump(
      tester,
      const ExerciseVideoPreview(title: 'Hip thrust'),
    );
    final notice = tester.widget<Text>(find.text(l10n.activeExerciseNoVideo));
    expect(notice.style?.fontSize, greaterThanOrEqualTo(13));

    await _pump(
      tester,
      ExerciseVideoPreview(
        title: 'Hip thrust',
        videoUrl: 'https://example.invalid/v.mp4',
        onTap: () {},
      ),
    );
    final tag = tester.widget<Text>(find.text(l10n.video));
    expect(tag.style?.fontSize, greaterThanOrEqualTo(13));
  });
}
