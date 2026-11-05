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
  expect(find.byType(PageView), findsNothing);
  return (repository, bloc);
}

PageController _controller(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!;

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
    expect(_controller(tester).page, 0);
  });

  testWidgets('reattachment honors requested nonzero page', (tester) async {
    final (_, bloc) = await _mount(tester);
    bloc.restoreAt(3);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(_controller(tester).page, 3);
    bloc.detachPages();
    await tester.pump();
    expect(find.byType(PageView), findsNothing);
    bloc.restoreAt(1);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(_controller(tester).page, 1);
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
    expect(_controller(tester).page, 4);
    bloc.add(const OnboardingSubmitted());
    await tester.pump();
    expect(find.byType(PageView), findsNothing);
    repository.pendingUpdate.completeError(StateError('Synthetic submit failure'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(_controller(tester).page, 4);
    expect(find.byType(SnackBar), findsOneWidget);
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
    expect(_controller(tester).page, 3);
    bloc.restoreAt(2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
