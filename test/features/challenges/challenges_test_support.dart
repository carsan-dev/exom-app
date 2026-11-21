// Shared fixture of the L5-B2 «Retos» page tests: a fake repository with the
// realistic data of the sketch (B4), the real bloc and use cases, and a host
// with a router, both themes, locale and text scaler. Not a test file: it has
// no `main` and is only imported.
import 'dart:async';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/challenges/domain/entities/achievement_entity.dart';
import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';
import 'package:exom_app/features/challenges/domain/repositories/challenges_repository.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_achievement_catalog_usecase.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_my_achievements_usecase.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_my_challenges_usecase.dart';
import 'package:exom_app/features/challenges/domain/usecases/get_my_streak_usecase.dart';
import 'package:exom_app/features/challenges/domain/usecases/update_challenge_progress_usecase.dart';
import 'package:exom_app/features/challenges/presentation/bloc/challenges_bloc.dart';
import 'package:exom_app/features/challenges/presentation/pages/challenges_page.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/wcag_contrast.dart';
import '../../golden/redesign_scenes.dart' show loadRedesignFonts;

ChallengeEntity challengeFixture(
  String id, {
  required String title,
  required String type,
  required double current,
  required double target,
  required String unit,
  bool completed = false,
  String description = '',
  DateTime? deadline,
}) => ChallengeEntity(
  id: id,
  challengeId: 'c-$id',
  currentValue: current,
  isCompleted: completed,
  assignedAt: DateTime(2026, 11, 16),
  title: title,
  description: description,
  type: type,
  targetValue: target,
  unit: unit,
  isManual: false,
  deadline: deadline,
);

/// Main goal of the sketch: 34 of 50 km (68 %).
final ChallengeEntity kMainGoal = challengeFixture(
  'goal',
  title: '50 km de carrera en noviembre',
  description: 'Suma kilómetros de carrera durante el mes.',
  type: 'MAIN_GOAL',
  current: 34,
  target: 50,
  unit: 'km',
  deadline: DateTime(2026, 11, 30),
);

/// Weekly challenges: 75 %, 71 % and one completed.
final List<ChallengeEntity> kWeekly = [
  challengeFixture(
    'w1',
    title: 'Entrenar cuatro días',
    type: 'WEEKLY',
    current: 3,
    target: 4,
    unit: 'entrenos',
    deadline: DateTime(2026, 11, 22),
  ),
  challengeFixture(
    'w2',
    title: 'Registrar todas las comidas',
    type: 'WEEKLY',
    current: 5,
    target: 7,
    unit: 'días',
  ),
  challengeFixture(
    'w3',
    title: 'Pesarte el lunes',
    type: 'WEEKLY',
    current: 1,
    target: 1,
    unit: 'pesaje',
    completed: true,
  ),
];

const List<AchievementEntity> kUnlocked = [
  AchievementEntity(id: 'a1', name: 'Primer entreno', description: 'Uno.'),
  AchievementEntity(id: 'a2', name: 'Racha de 7 días', description: 'Siete.'),
  AchievementEntity(id: 'a3', name: '10 sesiones', description: 'Diez.'),
];

const List<AchievementEntity> kCatalog = [
  ...kUnlocked,
  AchievementEntity(id: 'a4', name: '50 sesiones', description: 'Cincuenta.'),
  AchievementEntity(
    id: 'a5',
    name: 'Racha de 30 días',
    description: 'Treinta.',
  ),
];

class FakeChallengesRepository extends Fake implements ChallengesRepository {
  FakeChallengesRepository({
    List<ChallengeEntity>? challenges,
    this.achievements = kUnlocked,
    this.catalog = kCatalog,
    this.streakDays = 12,
  }) : challenges = challenges ?? [kMainGoal, ...kWeekly];

  List<ChallengeEntity> challenges;
  List<AchievementEntity> achievements;
  List<AchievementEntity> catalog;
  int streakDays;
  bool failLoad = false;

  /// Number of times the challenges were requested (load and refresh).
  int loads = 0;
  Completer<void>? gate;

  Future<void> _wait() async {
    final pending = gate;
    if (pending != null) await pending.future;
    if (failLoad) throw StateError('load failed');
  }

  @override
  Future<List<ChallengeEntity>> getMyChallenges() async {
    loads++;
    await _wait();
    return challenges;
  }

  @override
  Future<List<AchievementEntity>> getMyAchievements() async => achievements;

  @override
  Future<List<AchievementEntity>> getAchievementCatalog() async => catalog;

  @override
  Future<int> getMyStreakDays() async => streakDays;
}

/// Host of the page: router with `/` (the page) and `/other`, both themes.
class ChallengesHost extends StatelessWidget {
  const ChallengesHost({
    super.key,
    required this.router,
    this.mode = ThemeMode.dark,
    this.locale = const Locale('es'),
    this.textScaler = TextScaler.noScaling,
    this.disableAnimations = true,
  });

  final GoRouter router;
  final ThemeMode mode;
  final Locale locale;
  final TextScaler textScaler;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: mode,
    locale: locale,
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: textScaler, disableAnimations: disableAnimations),
      child: app!,
    ),
  );
}

GoRouter challengesRouter() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => const Scaffold(body: ChallengesPage()),
    ),
    GoRoute(
      path: '/other',
      builder: (context, _) => const Scaffold(body: Text('Otra')),
    ),
  ],
);

/// Mounts the page with [repository] and returns its router.
Future<GoRouter> pumpChallengesPage(
  WidgetTester tester,
  FakeChallengesRepository repository, {
  double width = 390,
  double height = 2400,
  ThemeMode mode = ThemeMode.dark,
  Locale locale = const Locale('es'),
  TextScaler textScaler = TextScaler.noScaling,
  bool settle = true,
}) async {
  await loadRedesignFonts();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final getIt = GetIt.I;
  await getIt.reset();
  addTearDown(getIt.reset);
  getIt.registerFactory<ChallengesBloc>(
    () => ChallengesBloc(
      getMyChallengesUseCase: GetMyChallengesUseCase(repository),
      updateChallengeProgressUseCase: UpdateChallengeProgressUseCase(
        repository,
      ),
      getAchievementCatalogUseCase: GetAchievementCatalogUseCase(repository),
      getMyAchievementsUseCase: GetMyAchievementsUseCase(repository),
      getMyStreakUseCase: GetMyStreakUseCase(repository),
    ),
  );
  final router = challengesRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChallengesHost(
      router: router,
      mode: mode,
      locale: locale,
      textScaler: textScaler,
    ),
  );
  if (settle) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
  return router;
}

String _plain(Widget widget) {
  if (widget is Text) {
    return widget.data ?? widget.textSpan?.toPlainText() ?? '';
  }
  return '';
}

/// Finds a [Text] whose text equals [text] ignoring case (the redesign paints
/// some titles upper case).
Finder findTextCi(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is Text && _plain(widget).toLowerCase() == text.toLowerCase(),
  description: 'Text "$text" (any case)',
);

/// Opens the «all achievements» sheet through its trigger («Ver todos»).
Future<void> openAchievementsBoard(WidgetTester tester, String label) async {
  final trigger = findTextCi(label);
  if (trigger.evaluate().isEmpty) {
    // Short surfaces build the list lazily: scroll until it exists.
    await tester.scrollUntilVisible(
      trigger,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(trigger);
  await tester.pump();
  await tester.tap(trigger);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Fails when a word of any painted paragraph is split across two lines.
void expectNoBrokenWords(WidgetTester tester) {
  final words = RegExp(r'[^\s]+');
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    if (!paragraph.hasSize || !paragraph.attached) continue;
    final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
    for (final match in words.allMatches(text)) {
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: match.start, extentOffset: match.end),
      );
      if (boxes.length < 2) continue;
      // Boxes of one line overlap vertically (runs of different sizes, as a
      // figure and its unit, have different tops but share the line).
      final lowestTop = boxes.map((b) => b.top).reduce((a, b) => a > b ? a : b);
      final highestBottom = boxes
          .map((b) => b.bottom)
          .reduce((a, b) => a < b ? a : b);
      expect(
        lowestTop < highestBottom,
        isTrue,
        reason: 'word "${match.group(0)}" of "$text" is split across lines',
      );
    }
  }
}

/// Achievements with real, long descriptions (the wording of the catalog), as
/// the API sends them: the first three are unlocked. The long words
/// («entrenamientos», «consecutive») are what splits a name in a narrow tile.
List<AchievementEntity> realisticCatalog(Locale locale) =>
    locale.languageCode == 'es'
    ? const [
        AchievementEntity(
          id: 'a1',
          name: 'Primer entreno',
          description: 'Completa tu primer entrenamiento asignado',
        ),
        AchievementEntity(
          id: 'a2',
          name: 'Racha de 7 días',
          description:
              'Completa entrenamientos consecutivos durante una semana',
        ),
        AchievementEntity(
          id: 'a3',
          name: '10 sesiones',
          description: 'Registra diez entrenamientos completados',
        ),
        AchievementEntity(
          id: 'a4',
          name: '50 sesiones',
          description: 'Acumula cincuenta entrenamientos completados',
        ),
        AchievementEntity(
          id: 'a5',
          name: 'Racha de 30 días',
          description:
              'Mantén entrenamientos consecutivos durante treinta días',
        ),
      ]
    : const [
        AchievementEntity(
          id: 'a1',
          name: 'First workout',
          description: 'Complete your first assigned workout',
        ),
        AchievementEntity(
          id: 'a2',
          name: '7-day streak',
          description: 'Complete consecutive workouts for a whole week',
        ),
        AchievementEntity(
          id: 'a3',
          name: '10 sessions',
          description: 'Log ten completed workouts',
        ),
        AchievementEntity(
          id: 'a4',
          name: '50 sessions',
          description: 'Accumulate fifty completed workouts',
        ),
        AchievementEntity(
          id: 'a5',
          name: '30-day streak',
          description: 'Keep up consecutive workouts for thirty days',
        ),
      ];

/// Repository whose achievements are [realisticCatalog] (3 unlocked of 5).
FakeChallengesRepository realisticRepository(Locale locale) {
  final catalog = realisticCatalog(locale);
  return FakeChallengesRepository(
    achievements: catalog.take(3).toList(),
    catalog: catalog,
  );
}

void _collectRuns(
  InlineSpan span,
  TextStyle inherited,
  List<(String, TextStyle)> out,
) {
  if (span is! TextSpan) return;
  final style = inherited.merge(span.style);
  final text = span.text;
  if (text != null && text.trim().isNotEmpty) out.add((text, style));
  for (final child in span.children ?? const <InlineSpan>[]) {
    _collectRuns(child, style, out);
  }
}

/// Opaque colour behind [element]: the nearest ancestor that paints one (a
/// decorated box, a colored box or a material), else [fallback].
Color _backgroundOf(Element element, Color fallback) {
  Color? found;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    Color? color;
    if (widget is DecoratedBox) {
      final decoration = widget.decoration;
      if (decoration is BoxDecoration) color = decoration.color;
    } else if (widget is ColoredBox) {
      color = widget.color;
    } else if (widget is Material) {
      color = widget.color;
    }
    if (color != null && color.a == 1) {
      found = color;
      return false;
    }
    return true;
  });
  return found ?? fallback;
}

/// Contrast of every painted run of text under [scope], by identity (not by
/// semantics nor by screen position): the colour of the text against the
/// colour painted behind it, [fallback] where nothing paints one. AA: 4.5, or
/// 3.0 for large text. Icon glyphs are skipped. Fails when [scope] holds no
/// text, so an empty finder never passes.
void expectParagraphContrast(
  WidgetTester tester,
  Finder scope, {
  required Color fallback,
}) {
  final paragraphs = find
      .descendant(of: scope, matching: find.byType(RichText))
      .evaluate();
  var checked = 0;
  final failures = <String>[];
  for (final element in paragraphs) {
    final render = element.renderObject;
    if (render is! RenderParagraph || !render.attached || !render.hasSize) {
      continue;
    }
    final background = _backgroundOf(element, fallback);
    final runs = <(String, TextStyle)>[];
    _collectRuns(render.text, const TextStyle(), runs);
    for (final (text, style) in runs) {
      if (style.fontFamily == 'MaterialIcons') continue;
      final color = style.color;
      if (color == null) {
        failures.add('"$text": no text colour');
        continue;
      }
      final ink = Color.alphaBlend(color, background);
      final size = render.textScaler.scale(style.fontSize ?? 14);
      final needed = wcagAaMinimum(size, style.fontWeight);
      final ratio = contrastRatio(ink, background);
      checked++;
      if (ratio < needed) {
        failures.add(
          '"$text": ${ratio.toStringAsFixed(2)} < $needed '
          '(${hexRgb(ink)} on ${hexRgb(background)}, ${size.toStringAsFixed(1)} px)',
        );
      }
    }
  }
  expect(checked, greaterThan(0), reason: 'no text found under the scope');
  expect(failures, isEmpty, reason: 'low contrast text');
}
