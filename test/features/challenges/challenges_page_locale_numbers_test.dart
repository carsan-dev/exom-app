// L4-I6 / L5-D5: the figures of the challenge cards go through the active
// locale. The owner decided no thousands separator (2026-11-20), so the
// visible result is the plain integer in es and en. The bloc and the use cases
// are the real ones; the repository is a fake.
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
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

ChallengeEntity _challenge(
  String id, {
  required String type,
  required double current,
  required double target,
  required String unit,
}) => ChallengeEntity(
  id: id,
  challengeId: 'c-$id',
  currentValue: current,
  isCompleted: false,
  assignedAt: DateTime(2026, 11, 16),
  title: 'Reto $id',
  description: '',
  type: type,
  targetValue: target,
  unit: unit,
  isManual: false,
);

class _Repository extends Fake implements ChallengesRepository {
  @override
  Future<List<ChallengeEntity>> getMyChallenges() async => [
    _challenge(
      'goal',
      type: 'MAIN_GOAL',
      current: 1234,
      target: 12345.5,
      unit: 'kcal',
    ),
    _challenge(
      'weekly',
      type: 'WEEKLY',
      current: 1234,
      target: 5000,
      unit: 'pasos',
    ),
    _challenge(
      'small',
      type: 'WEEKLY',
      current: 68.4,
      target: 100,
      unit: 'min',
    ),
  ];

  @override
  Future<List<AchievementEntity>> getMyAchievements() async => const [];

  @override
  Future<List<AchievementEntity>> getAchievementCatalog() async => const [];

  @override
  Future<int> getMyStreakDays() async => 3;
}

Future<void> _mount(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final getIt = GetIt.I;
  await getIt.reset();
  addTearDown(getIt.reset);
  final repository = _Repository();
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
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: ChallengesPage()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  for (final locale in const [Locale('es'), Locale('en')]) {
    testWidgets('progress figures without grouping, ${locale.languageCode}', (
      tester,
    ) async {
      await _mount(tester, locale);
      // Main goal card: current / target.
      expect(find.text('1234 / 12346 kcal'), findsOneWidget);
      // Weekly card: current/target.
      expect(find.text('1234/5000 pasos'), findsOneWidget);
      expect(find.text('68/100 min'), findsOneWidget);
      expect(find.textContaining('1.234'), findsNothing);
      expect(find.textContaining('1,234'), findsNothing);
    });
  }
}
