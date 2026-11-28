import 'package:exom_app/core/auth/auth_token_provider.dart';
import 'package:exom_app/core/prompts/automatic_prompt_coordinator.dart';
import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/domain/repositories/recap_repository.dart';
import 'package:exom_app/features/recap/domain/usecases/get_my_recaps_usecase.dart';
import 'package:exom_app/injection_container.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/onboarding_harness.dart';
import 'automatic_prompt_fakes.dart';

class _Recaps extends Fake implements RecapRepository {
  int calls = 0;

  @override
  Future<List<RecapEntity>> getMyRecaps() async {
    calls++;
    return const [];
  }
}

const _sessionA = LocalAuthSession(uid: 'uid-A', email: 'a@exom.test');

/// The coordinator MainShell resolves from `sl`: one per process, wired to
/// LocalStorage (settings box) and GetMyRecapsUseCase.
void main() {
  setUp(() async => sl.reset());
  tearDown(() async => sl.reset());

  test('registered as a lazy singleton over LocalStorage and the recap use '
      'case', () async {
    final directory = await openInMemorySettingsBox();
    addTearDown(() => closeSettingsBox(directory));
    final storage = LocalStorage(currentSession: () => _sessionA);
    final recaps = _Recaps();
    sl.registerSingleton<LocalStorage>(storage);
    sl.registerSingleton(GetMyRecapsUseCase(recaps));

    registerAutomaticPromptCoordinator(clock: () => sunday);

    final coordinator = sl<AutomaticPromptCoordinator>();
    expect(identical(coordinator, sl<AutomaticPromptCoordinator>()), isTrue);
    expect(
      await coordinator.nextPrompt(
        uid: 'uid-A',
        email: 'a@exom.test',
        tutorialDue: false,
      ),
      AutomaticPrompt.recapSunday,
    );
    expect(recaps.calls, 1);
    expect(
      storage.recapSundayPromptLastFor(uid: 'uid-A', email: 'a@exom.test'),
      '2026-11-22',
    );
  });
}
