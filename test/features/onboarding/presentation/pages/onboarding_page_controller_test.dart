import 'dart:async';
import 'dart:io';

import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:exom_app/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:exom_app/features/profile/domain/entities/profile_entity.dart';
import 'package:exom_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:exom_app/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:exom_app/features/profile/domain/usecases/upload_avatar_usecase.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ProfileRepository implements ProfileRepository {
  final pending = Completer<ProfileEntity>();
  final pendingUpdate = Completer<ProfileEntity>();

  @override
  Future<ProfileEntity> getProfile() => pending.future;

  @override
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data) =>
      pendingUpdate.future;

  @override
  Future<ProfileEntity> uploadAvatar(File file) async =>
      throw StateError('Avatar upload not used');
}

class _ProbeBloc extends OnboardingBloc {
  _ProbeBloc(_ProfileRepository repository)
    : super(
        getProfile: GetProfileUseCase(repository),
        updateProfile: UpdateProfileUseCase(repository),
        uploadAvatar: UploadAvatarUseCase(repository),
        localStorage: LocalStorage(),
      );

  void restoreAt(int page) => emit(
    OnboardingStepActive(
      currentStep: page,
      totalSteps: 5,
      accumulatedData: const {},
    ),
  );

  void detachPages() => emit(const OnboardingSubmitting());
}

Future<(_ProfileRepository, _ProbeBloc)> _mount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = _ProfileRepository();
  final bloc = _ProbeBloc(repository);
  sl.registerFactory<OnboardingBloc>(() => bloc);
  addTearDown(sl.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const OnboardingPage(),
    ),
  );
  await tester.pump();
  _expectNoSteps();
  return (repository, bloc);
}

// The contract is the navigation between steps driven by the page's
// controller, not a given widget. Until round 4 the steps lived in a
// PageView and these tests read its PageController; since round 5 (owner:
// the steps overlap as in the sketch) the page stacks the steps itself and
// keeps each one mounted, so the tests read which step is on screen through
// the keys of the page (OnboardingPage.stepKey). Same steps, same values and
// the same detached state while saving («Guardando»).

/// Step on screen once a change has settled: exactly one step is painted
/// (the others are offstage or not mounted).
int _page(WidgetTester tester) {
  final painted = [
    for (var i = 0; i < 5; i++)
      if (find
          .descendant(
            of: find.byKey(OnboardingPage.stepKey(i)),
            matching: find.byKey(const Key('onboarding-step-transition')),
          )
          .evaluate()
          .isNotEmpty)
        i,
  ];
  expect(painted, hasLength(1), reason: 'steps painted: $painted');
  return painted.single;
}

/// The steps are not mounted (before the profile, or while saving).
void _expectNoSteps() {
  for (var i = 0; i < 5; i++) {
    expect(
      find.byKey(OnboardingPage.stepKey(i), skipOffstage: false),
      findsNothing,
    );
  }
}

void main() {
  testWidgets('initial async profile attaches pages before navigation', (
    tester,
  ) async {
    final (repository, _) = await _mount(tester);
    repository.pending.complete(const ProfileEntity(id: 'synthetic'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(_page(tester), 0);
  });

  testWidgets('reattachment honors requested nonzero page', (tester) async {
    final (_, bloc) = await _mount(tester);
    bloc.restoreAt(3);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(_page(tester), 3);
    bloc.detachPages();
    // A state emitted by the bloc reaches the page on a microtask: the first
    // pump flushes it and schedules the page's rebuild, the second paints it.
    // The step change (M9) leaves no frame scheduled of its own, so there is
    // no earlier frame that would have painted it.
    await tester.pump();
    await tester.pump();
    _expectNoSteps();
    bloc.restoreAt(1);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(_page(tester), 1);
  });

  testWidgets('submit error restores summary after pages were detached', (
    tester,
  ) async {
    final (repository, bloc) = await _mount(tester);
    repository.pending.complete(const ProfileEntity(id: 'synthetic'));
    await tester.pump();
    bloc.add(const OnboardingStepSelected(4));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_page(tester), 4);
    bloc.add(const OnboardingSubmitted());
    // Same as above: the event, the state and the rebuild need two frames.
    await tester.pump();
    await tester.pump();
    _expectNoSteps();
    repository.pendingUpdate.completeError(StateError('Synthetic submit failure'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(_page(tester), 4);
    // L5-D2 (D14-3/8): the save error is shown inline above «Confirmar»
    // instead of an ephemeral SnackBar.
    expect(find.byKey(const Key('onboarding-save-error')), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('rapid targets keep latest page and disposal stays safe', (
    tester,
  ) async {
    final (repository, bloc) = await _mount(tester);
    repository.pending.complete(const ProfileEntity(id: 'synthetic'));
    await tester.pump();
    bloc.restoreAt(1);
    bloc.restoreAt(3);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_page(tester), 3);
    bloc.restoreAt(2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
