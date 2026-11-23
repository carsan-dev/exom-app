// Shared harness of the L5-D2 onboarding tests: a step widget alone inside a
// scaffold, or the whole OnboardingPage with a fake profile repository behind
// `sl`, always with the real theme, fonts and localizations.
import 'dart:async';
import 'dart:io';

import 'package:exom_app/core/storage/local_storage.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/widgets/exom_numeral_stepper.dart';
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

import '../../../golden/redesign_scenes.dart' show loadRedesignFonts;

/// Wraps [child] in the app theme, localizations and a [MediaQuery] with the
/// given text scaler, motion preference and keyboard inset.
Widget onboardingHarness(
  Widget child, {
  Locale locale = const Locale('es'),
  Brightness brightness = Brightness.dark,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
  double keyboardInset = 0,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, app) {
      GlassDecoration.brightness = Theme.of(context).brightness;
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          textScaler: textScaler,
          disableAnimations: disableAnimations,
          viewInsets: media.viewInsets.copyWith(bottom: keyboardInset),
        ),
        child: app!,
      );
    },
    home: child,
  );
}

/// Sets a [width] x [height] logical surface for the test.
void setOnboardingSurface(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => GlassDecoration.brightness = Brightness.dark);
}

/// Pumps a single onboarding step inside a scaffold body.
Future<void> pumpOnboardingStep(
  WidgetTester tester,
  Widget step, {
  Locale locale = const Locale('es'),
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = true,
  double keyboardInset = 0,
}) async {
  await loadRedesignFonts();
  setOnboardingSurface(tester, width: width, height: height);
  await tester.pumpWidget(
    onboardingHarness(
      Scaffold(body: SafeArea(child: step)),
      locale: locale,
      brightness: brightness,
      textScaler: textScaler,
      disableAnimations: disableAnimations,
      keyboardInset: keyboardInset,
    ),
  );
  await tester.pump();
}

/// Taps the numeral of the stepper with [stepperKey] and types [text].
Future<void> typeIntoStepper(
  WidgetTester tester,
  String stepperKey,
  String text,
) async {
  final stepper = find.byKey(Key(stepperKey));
  final numeral = find.descendant(
    of: stepper,
    matching: find.byKey(ExomNumeralStepper.valueKey),
  );
  await tester.ensureVisible(numeral);
  await tester.tap(numeral);
  await tester.pump();
  await tester.enterText(
    find.descendant(
      of: stepper,
      matching: find.byKey(ExomNumeralStepper.fieldKey),
    ),
    text,
  );
  await tester.pump();
}

/// Taps the widget with [key] after scrolling it into view.
Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

/// Rich-text aware finder for a figure painted with spans.
Finder findFigure(String text) => find.textContaining(text, findRichText: true);

/// Profile repository double: the profile is returned at once, every update
/// is recorded and fails while [failUpdates] is true; with [holdUpdates] the
/// update stays pending until [releaseUpdate].
class FakeOnboardingRepository implements ProfileRepository {
  FakeOnboardingRepository({
    this.profile = const ProfileEntity(
      id: 'synthetic',
      firstName: 'Lucía',
      lastName: 'Martín',
    ),
  });

  final ProfileEntity profile;
  final List<Map<String, dynamic>> updates = [];
  bool failUpdates = false;
  bool holdUpdates = false;
  Completer<ProfileEntity>? _held;

  void releaseUpdate() {
    _held?.completeError(StateError('Synthetic update failure'));
    _held = null;
  }

  @override
  Future<ProfileEntity> getProfile() async => profile;

  @override
  Future<ProfileEntity> updateProfile(Map<String, dynamic> data) {
    updates.add(Map<String, dynamic>.of(data));
    if (holdUpdates) {
      final held = Completer<ProfileEntity>();
      _held = held;
      return held.future;
    }
    if (failUpdates) {
      return Future.error(StateError('Synthetic update failure'));
    }
    return Future.value(profile);
  }

  @override
  Future<ProfileEntity> uploadAvatar(File file) async =>
      throw StateError('Avatar upload not used');
}

/// Pumps the whole [OnboardingPage] with a real [OnboardingBloc] over
/// [repository].
Future<OnboardingBloc> pumpOnboardingPage(
  WidgetTester tester,
  FakeOnboardingRepository repository, {
  Locale locale = const Locale('es'),
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = true,
  double keyboardInset = 0,
}) async {
  await loadRedesignFonts();
  setOnboardingSurface(tester, width: width, height: height);
  final bloc = OnboardingBloc(
    getProfile: GetProfileUseCase(repository),
    updateProfile: UpdateProfileUseCase(repository),
    uploadAvatar: UploadAvatarUseCase(repository),
    localStorage: LocalStorage(),
  );
  sl.registerFactory<OnboardingBloc>(() => bloc);
  addTearDown(sl.reset);
  await tester.pumpWidget(
    onboardingHarness(
      const OnboardingPage(),
      locale: locale,
      brightness: brightness,
      textScaler: textScaler,
      disableAnimations: disableAnimations,
      keyboardInset: keyboardInset,
    ),
  );
  await settleOnboarding(tester);
  return bloc;
}

/// Lets the bloc, the post-frame page jump and the M9 step change finish:
/// the step that leaves (100 ms), then the entrance (240 ms) and the rule
/// (300 ms). Each phase starts on the frame after the previous one ends, so
/// every phase gets a frame and a pump longer than itself.
Future<void> settleOnboarding(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  for (var phase = 0; phase < 2; phase++) {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }
}
