import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTagline.
  ///
  /// In es, this message translates to:
  /// **'Tu entrenador personal, siempre contigo'**
  String get appTagline;

  /// No description provided for @splashTagline.
  ///
  /// In es, this message translates to:
  /// **'Entrena. Come. Evoluciona.'**
  String get splashTagline;

  /// No description provided for @emailFieldLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get emailFieldLabel;

  /// No description provided for @emailValidationEmpty.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu correo electrónico'**
  String get emailValidationEmpty;

  /// No description provided for @emailValidationInvalid.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico no válido'**
  String get emailValidationInvalid;

  /// No description provided for @passwordFieldLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get passwordFieldLabel;

  /// No description provided for @passwordValidationEmpty.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu contraseña'**
  String get passwordValidationEmpty;

  /// No description provided for @passwordValidationLength.
  ///
  /// In es, this message translates to:
  /// **'La contraseña debe tener al menos 8 caracteres'**
  String get passwordValidationLength;

  /// No description provided for @forgotPasswordButton.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get forgotPasswordButton;

  /// No description provided for @emailFirstPrompt.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu email primero'**
  String get emailFirstPrompt;

  /// No description provided for @passwordResetEmailSent.
  ///
  /// In es, this message translates to:
  /// **'Email de recuperación enviado. Revisa tu bandeja de entrada.'**
  String get passwordResetEmailSent;

  /// No description provided for @passwordResetEmailFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo enviar el email. Verifica la dirección.'**
  String get passwordResetEmailFailed;

  /// No description provided for @loginButton.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get loginButton;

  /// No description provided for @continueWithDivider.
  ///
  /// In es, this message translates to:
  /// **'o continúa con'**
  String get continueWithDivider;

  /// No description provided for @continueWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Apple'**
  String get continueWithApple;

  /// No description provided for @linkSocialTitle.
  ///
  /// In es, this message translates to:
  /// **'Vincular acceso'**
  String get linkSocialTitle;

  /// No description provided for @linkSocialDescription.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una cuenta EXOM para {email}. Introduce tu contraseña actual para vincular también {provider} y poder iniciar sesión con ambos métodos.'**
  String linkSocialDescription(Object email, Object provider);

  /// No description provided for @linkSocialConfirmButton.
  ///
  /// In es, this message translates to:
  /// **'Vincular'**
  String get linkSocialConfirmButton;

  /// No description provided for @accountLockedTitle.
  ///
  /// In es, this message translates to:
  /// **'Cuenta bloqueada'**
  String get accountLockedTitle;

  /// No description provided for @accountLockedMessage.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta ha sido bloqueada temporalmente.\nContacta a tu entrenador para más información.'**
  String get accountLockedMessage;

  /// No description provided for @backToLoginButton.
  ///
  /// In es, this message translates to:
  /// **'Volver al inicio de sesión'**
  String get backToLoginButton;

  /// No description provided for @welcomeOnboarding.
  ///
  /// In es, this message translates to:
  /// **'¡Bienvenido\na EXOM!'**
  String get welcomeOnboarding;

  /// No description provided for @onboardingStepsMessage.
  ///
  /// In es, this message translates to:
  /// **'Sigue estos pasos para comenzar tu experiencia.'**
  String get onboardingStepsMessage;

  /// No description provided for @completeProfileTitle.
  ///
  /// In es, this message translates to:
  /// **'Completa tu perfil'**
  String get completeProfileTitle;

  /// No description provided for @completeProfileSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Añade tus datos para que el entrenador pueda personalizarte el plan.'**
  String get completeProfileSubtitle;

  /// No description provided for @waitForCoachTitle.
  ///
  /// In es, this message translates to:
  /// **'Espera a tu entrenador'**
  String get waitForCoachTitle;

  /// No description provided for @waitForCoachSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Te asignaremos un entrenador personal que diseñará tu rutina.'**
  String get waitForCoachSubtitle;

  /// No description provided for @startTransformationTitle.
  ///
  /// In es, this message translates to:
  /// **'Empieza tu transformación'**
  String get startTransformationTitle;

  /// No description provided for @startTransformationSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Sigue tu plan, registra tu progreso y alcanza tus objetivos.'**
  String get startTransformationSubtitle;

  /// No description provided for @completeProfileButton.
  ///
  /// In es, this message translates to:
  /// **'Completar perfil'**
  String get completeProfileButton;

  /// No description provided for @doItLaterButton.
  ///
  /// In es, this message translates to:
  /// **'Hacerlo más tarde'**
  String get doItLaterButton;

  /// No description provided for @pageNotFoundError.
  ///
  /// In es, this message translates to:
  /// **'Página no encontrada: {error}'**
  String pageNotFoundError(String error);

  /// No description provided for @userDefaultName.
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get userDefaultName;

  /// No description provided for @exomMemberLabel.
  ///
  /// In es, this message translates to:
  /// **'Miembro EXOM'**
  String get exomMemberLabel;

  /// No description provided for @profileMenuItem.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profileMenuItem;

  /// No description provided for @challengesMenuItem.
  ///
  /// In es, this message translates to:
  /// **'Retos'**
  String get challengesMenuItem;

  /// No description provided for @weeklyRecapMenuItem.
  ///
  /// In es, this message translates to:
  /// **'Recap Semanal'**
  String get weeklyRecapMenuItem;

  /// No description provided for @feedbackMenuItem.
  ///
  /// In es, this message translates to:
  /// **'Feedback'**
  String get feedbackMenuItem;

  /// No description provided for @settingsMenuItem.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsMenuItem;

  /// No description provided for @helpMenuItem.
  ///
  /// In es, this message translates to:
  /// **'Ayuda'**
  String get helpMenuItem;

  /// No description provided for @logOutMenuItem.
  ///
  /// In es, this message translates to:
  /// **'Cerrar Sesión'**
  String get logOutMenuItem;

  /// No description provided for @restDayTitle.
  ///
  /// In es, this message translates to:
  /// **'Día de descanso'**
  String get restDayTitle;

  /// No description provided for @restDayMessage.
  ///
  /// In es, this message translates to:
  /// **'No tienes entrenamiento asignado para hoy.\nAprovecha para recuperarte.'**
  String get restDayMessage;

  /// No description provided for @openCalendarButton.
  ///
  /// In es, this message translates to:
  /// **'Ver calendario'**
  String get openCalendarButton;

  /// No description provided for @todaysTrainingTitle.
  ///
  /// In es, this message translates to:
  /// **'Entrenamiento de hoy'**
  String get todaysTrainingTitle;

  /// No description provided for @trainingUntitledLabel.
  ///
  /// In es, this message translates to:
  /// **'Sin nombre'**
  String get trainingUntitledLabel;

  /// No description provided for @trainingCompletedLabel.
  ///
  /// In es, this message translates to:
  /// **'Completado'**
  String get trainingCompletedLabel;

  /// No description provided for @viewTrainingButton.
  ///
  /// In es, this message translates to:
  /// **'Ver entrenamiento'**
  String get viewTrainingButton;

  /// No description provided for @continueTrainingButton.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueTrainingButton;

  /// No description provided for @startTrainingButton.
  ///
  /// In es, this message translates to:
  /// **'Comenzar'**
  String get startTrainingButton;

  /// No description provided for @trainingStrength.
  ///
  /// In es, this message translates to:
  /// **'Fuerza'**
  String get trainingStrength;

  /// No description provided for @trainingMobility.
  ///
  /// In es, this message translates to:
  /// **'Flexibilidad'**
  String get trainingMobility;

  /// No description provided for @todaysDietTitle.
  ///
  /// In es, this message translates to:
  /// **'Dieta de hoy'**
  String get todaysDietTitle;

  /// No description provided for @nutritionPlanDefault.
  ///
  /// In es, this message translates to:
  /// **'Plan nutricional'**
  String get nutritionPlanDefault;

  /// No description provided for @nextMealLabel.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get nextMealLabel;

  /// No description provided for @nextMealButton.
  ///
  /// In es, this message translates to:
  /// **'Siguiente comida'**
  String get nextMealButton;

  /// No description provided for @viewFullDietButton.
  ///
  /// In es, this message translates to:
  /// **'Ver dieta completa'**
  String get viewFullDietButton;

  /// No description provided for @todayLabel.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get todayLabel;

  /// No description provided for @tomorrowLabel.
  ///
  /// In es, this message translates to:
  /// **'Mañana'**
  String get tomorrowLabel;

  /// No description provided for @dayAfterTomorrowLabel.
  ///
  /// In es, this message translates to:
  /// **'Pasado mañana'**
  String get dayAfterTomorrowLabel;

  /// No description provided for @yesterdayLabel.
  ///
  /// In es, this message translates to:
  /// **'Ayer'**
  String get yesterdayLabel;

  /// No description provided for @twoDaysAgoLabel.
  ///
  /// In es, this message translates to:
  /// **'Antes de ayer'**
  String get twoDaysAgoLabel;

  /// No description provided for @inDaysLabel.
  ///
  /// In es, this message translates to:
  /// **'En {diff} días'**
  String inDaysLabel(int diff);

  /// No description provided for @daysAgoLabel.
  ///
  /// In es, this message translates to:
  /// **'Hace {diff} días'**
  String daysAgoLabel(int diff);

  /// No description provided for @keepItUpSubtitle.
  ///
  /// In es, this message translates to:
  /// **'¡Sigue así!'**
  String get keepItUpSubtitle;

  /// No description provided for @sleepQualityGood.
  ///
  /// In es, this message translates to:
  /// **'Calidad buena'**
  String get sleepQualityGood;

  /// No description provided for @sleepQualityFair.
  ///
  /// In es, this message translates to:
  /// **'Calidad media'**
  String get sleepQualityFair;

  /// No description provided for @sleepQualityLow.
  ///
  /// In es, this message translates to:
  /// **'Poco sueño'**
  String get sleepQualityLow;

  /// No description provided for @allTrainingsSection.
  ///
  /// In es, this message translates to:
  /// **'Todos los entrenamientos'**
  String get allTrainingsSection;

  /// No description provided for @noTrainingsAvailable.
  ///
  /// In es, this message translates to:
  /// **'No hay entrenamientos disponibles'**
  String get noTrainingsAvailable;

  /// No description provided for @askCoachForPlan.
  ///
  /// In es, this message translates to:
  /// **'Contacta a tu entrenador para que te asigne un plan'**
  String get askCoachForPlan;

  /// No description provided for @noTrainingAssignedToday.
  ///
  /// In es, this message translates to:
  /// **'No hay entrenamiento asignado hoy'**
  String get noTrainingAssignedToday;

  /// No description provided for @noTrainingAssignedForDate.
  ///
  /// In es, this message translates to:
  /// **'No hay entrenamiento asignado para esa fecha'**
  String get noTrainingAssignedForDate;

  /// No description provided for @enjoyRestDay.
  ///
  /// In es, this message translates to:
  /// **'Disfruta tu día de descanso'**
  String get enjoyRestDay;

  /// No description provided for @noDietTodayMessage.
  ///
  /// In es, this message translates to:
  /// **'No tienes dieta asignada hoy'**
  String get noDietTodayMessage;

  /// No description provided for @noDietForDateMessage.
  ///
  /// In es, this message translates to:
  /// **'No tienes dieta asignada para esa fecha'**
  String get noDietForDateMessage;

  /// No description provided for @contactCoachForPlanMessage.
  ///
  /// In es, this message translates to:
  /// **'Contacta a tu entrenador para que te asigne un plan nutricional'**
  String get contactCoachForPlanMessage;

  /// No description provided for @contactCoachButton.
  ///
  /// In es, this message translates to:
  /// **'Contactar entrenador'**
  String get contactCoachButton;

  /// No description provided for @mealsOfTheDayLabel.
  ///
  /// In es, this message translates to:
  /// **'Comidas del día'**
  String get mealsOfTheDayLabel;

  /// No description provided for @todaysPlanLabel.
  ///
  /// In es, this message translates to:
  /// **'Plan de hoy'**
  String get todaysPlanLabel;

  /// No description provided for @planForLabel.
  ///
  /// In es, this message translates to:
  /// **'Plan de'**
  String get planForLabel;

  /// No description provided for @completedFeminine.
  ///
  /// In es, this message translates to:
  /// **'Completada'**
  String get completedFeminine;

  /// No description provided for @openPlan.
  ///
  /// In es, this message translates to:
  /// **'Ver plan'**
  String get openPlan;

  /// No description provided for @mealTypeBreakfast.
  ///
  /// In es, this message translates to:
  /// **'Desayuno'**
  String get mealTypeBreakfast;

  /// No description provided for @mealTypeLunch.
  ///
  /// In es, this message translates to:
  /// **'Almuerzo'**
  String get mealTypeLunch;

  /// No description provided for @mealTypeSnack.
  ///
  /// In es, this message translates to:
  /// **'Snack'**
  String get mealTypeSnack;

  /// No description provided for @mealTypeDinner.
  ///
  /// In es, this message translates to:
  /// **'Cena'**
  String get mealTypeDinner;

  /// No description provided for @richInLabel.
  ///
  /// In es, this message translates to:
  /// **'Rico en'**
  String get richInLabel;

  /// No description provided for @openRecipeButton.
  ///
  /// In es, this message translates to:
  /// **'Ver receta en Google'**
  String get openRecipeButton;

  /// No description provided for @recipeButton.
  ///
  /// In es, this message translates to:
  /// **'Receta'**
  String get recipeButton;

  /// No description provided for @mealCompletedButton.
  ///
  /// In es, this message translates to:
  /// **'Completada'**
  String get mealCompletedButton;

  /// No description provided for @completeButton.
  ///
  /// In es, this message translates to:
  /// **'Completar'**
  String get completeButton;

  /// No description provided for @markMealCompletedButton.
  ///
  /// In es, this message translates to:
  /// **'Marcar como completada'**
  String get markMealCompletedButton;

  /// No description provided for @markExerciseCompletedButton.
  ///
  /// In es, this message translates to:
  /// **'Marcar como completado'**
  String get markExerciseCompletedButton;

  /// No description provided for @exerciseCompletedButton.
  ///
  /// In es, this message translates to:
  /// **'Ejercicio completado'**
  String get exerciseCompletedButton;

  /// No description provided for @nutritionalInfoTitle.
  ///
  /// In es, this message translates to:
  /// **'Información nutricional'**
  String get nutritionalInfoTitle;

  /// No description provided for @caloriesLabel.
  ///
  /// In es, this message translates to:
  /// **'Calorías'**
  String get caloriesLabel;

  /// No description provided for @proteinLabel.
  ///
  /// In es, this message translates to:
  /// **'Proteína'**
  String get proteinLabel;

  /// No description provided for @carbsLabel.
  ///
  /// In es, this message translates to:
  /// **'Carbos'**
  String get carbsLabel;

  /// No description provided for @fatsLabel.
  ///
  /// In es, this message translates to:
  /// **'Grasas'**
  String get fatsLabel;

  /// No description provided for @ingredientsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ingredientes'**
  String get ingredientsTitle;

  /// No description provided for @calendarLoadError.
  ///
  /// In es, this message translates to:
  /// **'Error al cargar el calendario'**
  String get calendarLoadError;

  /// No description provided for @trainingsCompletedThisWeek.
  ///
  /// In es, this message translates to:
  /// **'entrenos completados esta semana'**
  String get trainingsCompletedThisWeek;

  /// No description provided for @mealsCompletedThisWeek.
  ///
  /// In es, this message translates to:
  /// **'comidas completadas esta semana'**
  String get mealsCompletedThisWeek;

  /// No description provided for @noActivityAssigned.
  ///
  /// In es, this message translates to:
  /// **'Sin actividad asignada'**
  String get noActivityAssigned;

  /// No description provided for @openDetail.
  ///
  /// In es, this message translates to:
  /// **'Ver detalle'**
  String get openDetail;

  /// No description provided for @goToMonthButton.
  ///
  /// In es, this message translates to:
  /// **'Ir al mes'**
  String get goToMonthButton;

  /// No description provided for @warmUp.
  ///
  /// In es, this message translates to:
  /// **'Calentamiento'**
  String get warmUp;

  /// No description provided for @cooldown.
  ///
  /// In es, this message translates to:
  /// **'Enfriamiento'**
  String get cooldown;

  /// No description provided for @addQuickNoteOptional.
  ///
  /// In es, this message translates to:
  /// **'Añadir nota rápida (Opcional)'**
  String get addQuickNoteOptional;

  /// No description provided for @completedExercisesLabel.
  ///
  /// In es, this message translates to:
  /// **'ejercicios completados'**
  String get completedExercisesLabel;

  /// No description provided for @workoutCompletedMessage.
  ///
  /// In es, this message translates to:
  /// **'¡Entrenamiento completado!'**
  String get workoutCompletedMessage;

  /// No description provided for @rest.
  ///
  /// In es, this message translates to:
  /// **'descanso'**
  String get rest;

  /// No description provided for @sets.
  ///
  /// In es, this message translates to:
  /// **'Series'**
  String get sets;

  /// No description provided for @repsOrTime.
  ///
  /// In es, this message translates to:
  /// **'Reps/Dur.'**
  String get repsOrTime;

  /// No description provided for @restLabel.
  ///
  /// In es, this message translates to:
  /// **'Descanso'**
  String get restLabel;

  /// No description provided for @exerciseMetadata.
  ///
  /// In es, this message translates to:
  /// **'{sets} series x {reps} · Descanso {rest}s'**
  String exerciseMetadata(int sets, String reps, int rest);

  /// No description provided for @description.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get description;

  /// No description provided for @explanation.
  ///
  /// In es, this message translates to:
  /// **'Explicación'**
  String get explanation;

  /// No description provided for @technique.
  ///
  /// In es, this message translates to:
  /// **'Técnica'**
  String get technique;

  /// No description provided for @commonMistakes.
  ///
  /// In es, this message translates to:
  /// **'Errores comunes'**
  String get commonMistakes;

  /// No description provided for @feedbackSentSuccessfully.
  ///
  /// In es, this message translates to:
  /// **'Feedback enviado correctamente'**
  String get feedbackSentSuccessfully;

  /// No description provided for @noFeedbackYet.
  ///
  /// In es, this message translates to:
  /// **'Aún no has enviado ningún feedback'**
  String get noFeedbackYet;

  /// No description provided for @sendFeedback.
  ///
  /// In es, this message translates to:
  /// **'Enviar feedback'**
  String get sendFeedback;

  /// No description provided for @fileUrlImageOrVideo.
  ///
  /// In es, this message translates to:
  /// **'URL del archivo (imagen o vídeo)'**
  String get fileUrlImageOrVideo;

  /// No description provided for @urlIsRequired.
  ///
  /// In es, this message translates to:
  /// **'La URL es obligatoria'**
  String get urlIsRequired;

  /// No description provided for @additionalNotesOptional.
  ///
  /// In es, this message translates to:
  /// **'Notas adicionales (opcional)'**
  String get additionalNotesOptional;

  /// No description provided for @challengesTitle.
  ///
  /// In es, this message translates to:
  /// **'Mis Retos'**
  String get challengesTitle;

  /// No description provided for @challengesSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Supera tus límites cada día'**
  String get challengesSubtitle;

  /// No description provided for @challengesLoadError.
  ///
  /// In es, this message translates to:
  /// **'Error al cargar los retos'**
  String get challengesLoadError;

  /// No description provided for @mainGoalSection.
  ///
  /// In es, this message translates to:
  /// **'Objetivo principal'**
  String get mainGoalSection;

  /// No description provided for @weeklyChallengesSection.
  ///
  /// In es, this message translates to:
  /// **'Retos semanales'**
  String get weeklyChallengesSection;

  /// No description provided for @unlockedAchievementsSection.
  ///
  /// In es, this message translates to:
  /// **'Logros desbloqueados'**
  String get unlockedAchievementsSection;

  /// No description provided for @viewAllButton.
  ///
  /// In es, this message translates to:
  /// **'Ver todos'**
  String get viewAllButton;

  /// No description provided for @achievementBoardTitle.
  ///
  /// In es, this message translates to:
  /// **'Todos los logros'**
  String get achievementBoardTitle;

  /// No description provided for @noActiveChallenges.
  ///
  /// In es, this message translates to:
  /// **'Sin retos activos'**
  String get noActiveChallenges;

  /// No description provided for @noActiveChallengesMessage.
  ///
  /// In es, this message translates to:
  /// **'Tu entrenador aún no te ha asignado retos. Empieza completando tus entrenamientos y comidas para desbloquear retos automáticos.'**
  String get noActiveChallengesMessage;

  /// No description provided for @lockedAchievementsHint.
  ///
  /// In es, this message translates to:
  /// **'Completa retos para desbloquear medallas'**
  String get lockedAchievementsHint;

  /// No description provided for @pendingChallengeLabel.
  ///
  /// In es, this message translates to:
  /// **'Reto pendiente'**
  String get pendingChallengeLabel;

  /// No description provided for @challengeDeadlineLabel.
  ///
  /// In es, this message translates to:
  /// **'Fecha límite'**
  String get challengeDeadlineLabel;

  /// No description provided for @challengeUntilLabel.
  ///
  /// In es, this message translates to:
  /// **'Hasta'**
  String get challengeUntilLabel;

  /// No description provided for @helpCenter.
  ///
  /// In es, this message translates to:
  /// **'Centro de ayuda'**
  String get helpCenter;

  /// No description provided for @helpCenterDescription.
  ///
  /// In es, this message translates to:
  /// **'Todo lo importante para usar EXOM en tu día a día: métricas, entrenamientos, dieta, modo offline y vías de contacto.'**
  String get helpCenterDescription;

  /// No description provided for @sendQuestionOrIssue.
  ///
  /// In es, this message translates to:
  /// **'Enviar duda o incidencia'**
  String get sendQuestionOrIssue;

  /// No description provided for @notificationsAndCache.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones y caché'**
  String get notificationsAndCache;

  /// No description provided for @supportAndLinks.
  ///
  /// In es, this message translates to:
  /// **'Soporte y enlaces'**
  String get supportAndLinks;

  /// No description provided for @supportCenter.
  ///
  /// In es, this message translates to:
  /// **'Centro de soporte'**
  String get supportCenter;

  /// No description provided for @supportCenterDescription.
  ///
  /// In es, this message translates to:
  /// **'Abre la página externa de soporte y contacto de EXOM.'**
  String get supportCenterDescription;

  /// No description provided for @couldNotOpenSupportPage.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la página de soporte.'**
  String get couldNotOpenSupportPage;

  /// No description provided for @emailSupportDescription.
  ///
  /// In es, this message translates to:
  /// **'Abre tu cliente de correo con un email a soporte@exom.app.'**
  String get emailSupportDescription;

  /// No description provided for @couldNotOpenMailApp.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la aplicación de correo.'**
  String get couldNotOpenMailApp;

  /// No description provided for @frequentlyAskedQuestions.
  ///
  /// In es, this message translates to:
  /// **'Preguntas frecuentes'**
  String get frequentlyAskedQuestions;

  /// No description provided for @creditsDescription.
  ///
  /// In es, this message translates to:
  /// **'Producto EXOM de valor añadido para clientes. Desarrollo principal por Carlos Sánchez Román, con app móvil en Flutter y backend en NestJS.'**
  String get creditsDescription;

  /// No description provided for @developer.
  ///
  /// In es, this message translates to:
  /// **'Desarrollador'**
  String get developer;

  /// No description provided for @couldNotOpenGithubProfile.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el perfil de GitHub.'**
  String get couldNotOpenGithubProfile;

  /// No description provided for @registerWeightMuscleAndMeasurements.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo registro mi peso, masa muscular y medidas?'**
  String get registerWeightMuscleAndMeasurements;

  /// No description provided for @registerWeightExplanation.
  ///
  /// In es, this message translates to:
  /// **'Ve a tu perfil y entra en \"Mis métricas\". Desde ahí puedes guardar peso, masa muscular, horas de sueño y medidas corporales. Si no tienes una medición directa de masa muscular, puedes usar la calculadora SEEN con edad, altura, sexo y pantorrilla para obtener una estimación.'**
  String get registerWeightExplanation;

  /// No description provided for @markWorkoutCompleted.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo marco un entrenamiento como completado?'**
  String get markWorkoutCompleted;

  /// No description provided for @markWorkoutExplanation.
  ///
  /// In es, this message translates to:
  /// **'Entra en el entrenamiento del día desde Home o desde Entrenamientos. Puedes marcar ejercicios uno a uno o completar la sesión completa desde el resumen final.'**
  String get markWorkoutExplanation;

  /// No description provided for @markMealCompleted.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo marco una comida como completada?'**
  String get markMealCompleted;

  /// No description provided for @markMealExplanation.
  ///
  /// In es, this message translates to:
  /// **'Abre la dieta del día, entra en la comida correspondiente y pulsa el botón de completado. El Home y el Calendario reflejará el avance real del día.'**
  String get markMealExplanation;

  /// No description provided for @useAppOffline.
  ///
  /// In es, this message translates to:
  /// **'¿Puedo usar la app sin conexión?'**
  String get useAppOffline;

  /// No description provided for @useAppOfflineExplanation.
  ///
  /// In es, this message translates to:
  /// **'Sí. La app conserva en caché el último Home, Perfil, Calendario, Dieta, Entreno y Métricas cargados. Sin conexión puedes consultar esos datos, aunque no se enviarán cambios al servidor.'**
  String get useAppOfflineExplanation;

  /// No description provided for @weeklyRecapPurpose.
  ///
  /// In es, this message translates to:
  /// **'¿Para qué sirve el ReCap semanal?'**
  String get weeklyRecapPurpose;

  /// No description provided for @weeklyRecapExplanation.
  ///
  /// In es, this message translates to:
  /// **'El ReCap te permite resumir tu semana para que tu entrenador entienda cómo has rendido, comido, descansado y qué sensaciones has tenido.'**
  String get weeklyRecapExplanation;

  /// No description provided for @contactCoachReportProblem.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo contacto con mi entrenador o reporto un problema?'**
  String get contactCoachReportProblem;

  /// No description provided for @contactCoachExplanation.
  ///
  /// In es, this message translates to:
  /// **'Usa la sección Feedback para enviar dudas, incidencias o material técnico. Es el canal principal dentro de la app para que tu entrenador o el equipo de soporte puedan darte seguimiento.'**
  String get contactCoachExplanation;

  /// No description provided for @profilePageTitle.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profilePageTitle;

  /// No description provided for @beginnerLevel.
  ///
  /// In es, this message translates to:
  /// **'Principiante'**
  String get beginnerLevel;

  /// No description provided for @intermediateLevel.
  ///
  /// In es, this message translates to:
  /// **'Intermedio'**
  String get intermediateLevel;

  /// No description provided for @advancedLevel.
  ///
  /// In es, this message translates to:
  /// **'Avanzado'**
  String get advancedLevel;

  /// No description provided for @loseWeightGoal.
  ///
  /// In es, this message translates to:
  /// **'Perder peso'**
  String get loseWeightGoal;

  /// No description provided for @gainMuscleGoal.
  ///
  /// In es, this message translates to:
  /// **'Ganar músculo'**
  String get gainMuscleGoal;

  /// No description provided for @maintainGoal.
  ///
  /// In es, this message translates to:
  /// **'Mantener'**
  String get maintainGoal;

  /// No description provided for @improveFitnessGoal.
  ///
  /// In es, this message translates to:
  /// **'Mejorar fitness'**
  String get improveFitnessGoal;

  /// No description provided for @updateWeightButton.
  ///
  /// In es, this message translates to:
  /// **'Actualizar peso'**
  String get updateWeightButton;

  /// No description provided for @updateMeasurementsButton.
  ///
  /// In es, this message translates to:
  /// **'Actualizar medidas'**
  String get updateMeasurementsButton;

  /// No description provided for @weeklyRecapButton.
  ///
  /// In es, this message translates to:
  /// **'ReCap semanal'**
  String get weeklyRecapButton;

  /// No description provided for @weightProgressTitle.
  ///
  /// In es, this message translates to:
  /// **'Progreso del peso'**
  String get weightProgressTitle;

  /// No description provided for @noDataYetMessage.
  ///
  /// In es, this message translates to:
  /// **'Sin datos todavía'**
  String get noDataYetMessage;

  /// No description provided for @logMetricsPrompt.
  ///
  /// In es, this message translates to:
  /// **'Registra tu peso y medidas para empezar\na ver tu evolución.'**
  String get logMetricsPrompt;

  /// No description provided for @logMetricsButton.
  ///
  /// In es, this message translates to:
  /// **'Registrar métricas'**
  String get logMetricsButton;

  /// No description provided for @muscleMassGoalTitle.
  ///
  /// In es, this message translates to:
  /// **'Objetivo de masa muscular'**
  String get muscleMassGoalTitle;

  /// No description provided for @muscleMassLabel.
  ///
  /// In es, this message translates to:
  /// **'Masa muscular'**
  String get muscleMassLabel;

  /// No description provided for @goalLabel.
  ///
  /// In es, this message translates to:
  /// **'Objetivo'**
  String get goalLabel;

  /// No description provided for @setYourGoal.
  ///
  /// In es, this message translates to:
  /// **'Define tu objetivo'**
  String get setYourGoal;

  /// No description provided for @latestMeasurementLabel.
  ///
  /// In es, this message translates to:
  /// **'Última medición'**
  String get latestMeasurementLabel;

  /// No description provided for @updateYourMetrics.
  ///
  /// In es, this message translates to:
  /// **'Actualiza tus métricas'**
  String get updateYourMetrics;

  /// No description provided for @currentCaption.
  ///
  /// In es, this message translates to:
  /// **'actual'**
  String get currentCaption;

  /// No description provided for @muscleGoalEmptyState.
  ///
  /// In es, this message translates to:
  /// **'Registra una medición directa o usa la estimación SEEN desde métricas para ver la evolución.'**
  String get muscleGoalEmptyState;

  /// No description provided for @logOrCalculateButton.
  ///
  /// In es, this message translates to:
  /// **'Registrar o calcular'**
  String get logOrCalculateButton;

  /// No description provided for @ofGoalPercentage.
  ///
  /// In es, this message translates to:
  /// **'del objetivo'**
  String get ofGoalPercentage;

  /// No description provided for @daysWithinGoal.
  ///
  /// In es, this message translates to:
  /// **'días dentro del objetivo'**
  String get daysWithinGoal;

  /// No description provided for @todayCaption.
  ///
  /// In es, this message translates to:
  /// **'hoy'**
  String get todayCaption;

  /// No description provided for @bodyDataTitle.
  ///
  /// In es, this message translates to:
  /// **'Datos corporales'**
  String get bodyDataTitle;

  /// No description provided for @lastUpdatedLabel.
  ///
  /// In es, this message translates to:
  /// **'Última actualización'**
  String get lastUpdatedLabel;

  /// No description provided for @syncedWithProfileAndMetrics.
  ///
  /// In es, this message translates to:
  /// **'Sincronizada con perfil y métricas'**
  String get syncedWithProfileAndMetrics;

  /// No description provided for @addHeightInMetrics.
  ///
  /// In es, this message translates to:
  /// **'Añádela en métricas para mejorar el seguimiento'**
  String get addHeightInMetrics;

  /// No description provided for @measurementsLabel.
  ///
  /// In es, this message translates to:
  /// **'Medidas'**
  String get measurementsLabel;

  /// No description provided for @noDataLabel.
  ///
  /// In es, this message translates to:
  /// **'Sin datos'**
  String get noDataLabel;

  /// No description provided for @updateMetricsButton.
  ///
  /// In es, this message translates to:
  /// **'Actualizar métricas'**
  String get updateMetricsButton;

  /// No description provided for @validHeightRequired.
  ///
  /// In es, this message translates to:
  /// **'Introduce una altura válida antes de guardar.'**
  String get validHeightRequired;

  /// No description provided for @validWeightRequired.
  ///
  /// In es, this message translates to:
  /// **'Introduce un peso válido antes de guardar.'**
  String get validWeightRequired;

  /// No description provided for @validSleepRequired.
  ///
  /// In es, this message translates to:
  /// **'Introduce las horas de sueño en formato numérico antes de guardar.'**
  String get validSleepRequired;

  /// No description provided for @validMuscleMassRequired.
  ///
  /// In es, this message translates to:
  /// **'Introduce una masa muscular válida antes de guardar.'**
  String get validMuscleMassRequired;

  /// No description provided for @measurementReviewTemplate.
  ///
  /// In es, this message translates to:
  /// **'Revisa la medida de {measurement} antes de guardar.'**
  String measurementReviewTemplate(String measurement);

  /// No description provided for @noChangesMessage.
  ///
  /// In es, this message translates to:
  /// **'No has modificado ninguna métrica para guardar.'**
  String get noChangesMessage;

  /// No description provided for @metricsPageTitle.
  ///
  /// In es, this message translates to:
  /// **'Actualizar métricas'**
  String get metricsPageTitle;

  /// No description provided for @recordDateTitle.
  ///
  /// In es, this message translates to:
  /// **'Fecha del registro'**
  String get recordDateTitle;

  /// No description provided for @recordDateDescription.
  ///
  /// In es, this message translates to:
  /// **'El registro se guardará para la fecha seleccionada. Así puedes apuntar métricas y sueño de días anteriores.'**
  String get recordDateDescription;

  /// No description provided for @heightSectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Altura'**
  String get heightSectionTitle;

  /// No description provided for @heightDescription.
  ///
  /// In es, this message translates to:
  /// **'La altura se guarda en tu histórico de métricas y también actualiza tu perfil para mantener coherencia con el cálculo SEEN.'**
  String get heightDescription;

  /// No description provided for @weightSectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Peso'**
  String get weightSectionTitle;

  /// No description provided for @manualEntryToggle.
  ///
  /// In es, this message translates to:
  /// **'Entrada manual'**
  String get manualEntryToggle;

  /// No description provided for @weightUpdateNote.
  ///
  /// In es, this message translates to:
  /// **'El peso solo se guarda si lo modificas en esta actualización.'**
  String get weightUpdateNote;

  /// No description provided for @muscleMassSectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Masa muscular'**
  String get muscleMassSectionTitle;

  /// No description provided for @muscleMassDescription.
  ///
  /// In es, this message translates to:
  /// **'Registra tu estimación actual para comparar tu evolución con el objetivo del perfil.'**
  String get muscleMassDescription;

  /// No description provided for @seenCalculatorTitle.
  ///
  /// In es, this message translates to:
  /// **'Calculadora SEEN'**
  String get seenCalculatorTitle;

  /// No description provided for @seenCalculatorDescription.
  ///
  /// In es, this message translates to:
  /// **'Si no tienes una medición directa, puedes usar una estimación basada en edad, altura, sexo y circunferencia de pantorrilla.'**
  String get seenCalculatorDescription;

  /// No description provided for @calculateEstimateButton.
  ///
  /// In es, this message translates to:
  /// **'Calcular estimación'**
  String get calculateEstimateButton;

  /// No description provided for @sleepHoursSectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Horas de sueño'**
  String get sleepHoursSectionTitle;

  /// No description provided for @sleepHoursDescription.
  ///
  /// In es, this message translates to:
  /// **'Indica cuántas horas dormiste en la noche correspondiente a esta fecha.'**
  String get sleepHoursDescription;

  /// No description provided for @sleepVeryLow.
  ///
  /// In es, this message translates to:
  /// **'Muy poco sueño'**
  String get sleepVeryLow;

  /// No description provided for @sleepInsufficient.
  ///
  /// In es, this message translates to:
  /// **'Sueño insuficiente'**
  String get sleepInsufficient;

  /// No description provided for @sleepOptimal.
  ///
  /// In es, this message translates to:
  /// **'Sueño óptimo'**
  String get sleepOptimal;

  /// No description provided for @sleepTooMuch.
  ///
  /// In es, this message translates to:
  /// **'Demasiado sueño'**
  String get sleepTooMuch;

  /// No description provided for @bodyMeasurementsTitle.
  ///
  /// In es, this message translates to:
  /// **'Medidas corporales'**
  String get bodyMeasurementsTitle;

  /// No description provided for @listViewToggle.
  ///
  /// In es, this message translates to:
  /// **'Lista'**
  String get listViewToggle;

  /// No description provided for @bodyViewToggle.
  ///
  /// In es, this message translates to:
  /// **'Cuerpo'**
  String get bodyViewToggle;

  /// No description provided for @frontViewLabel.
  ///
  /// In es, this message translates to:
  /// **'Frontal'**
  String get frontViewLabel;

  /// No description provided for @backViewLabel.
  ///
  /// In es, this message translates to:
  /// **'Posterior'**
  String get backViewLabel;

  /// No description provided for @saveMetricsButton.
  ///
  /// In es, this message translates to:
  /// **'Guardar métricas'**
  String get saveMetricsButton;

  /// No description provided for @quickSeenEstimate.
  ///
  /// In es, this message translates to:
  /// **'Estimación rápida SEEN'**
  String get quickSeenEstimate;

  /// No description provided for @seenFormulaDescription.
  ///
  /// In es, this message translates to:
  /// **'Usa la fórmula de la SEEN para estimar masa muscular esquelética a partir de edad, altura, sexo y pantorrilla.'**
  String get seenFormulaDescription;

  /// No description provided for @ageLabel.
  ///
  /// In es, this message translates to:
  /// **'Edad'**
  String get ageLabel;

  /// No description provided for @yearsLabel.
  ///
  /// In es, this message translates to:
  /// **'años'**
  String get yearsLabel;

  /// No description provided for @calfLabel.
  ///
  /// In es, this message translates to:
  /// **'Pantorrilla'**
  String get calfLabel;

  /// No description provided for @sexLabel.
  ///
  /// In es, this message translates to:
  /// **'Sexo'**
  String get sexLabel;

  /// No description provided for @maleOption.
  ///
  /// In es, this message translates to:
  /// **'Hombre'**
  String get maleOption;

  /// No description provided for @femaleOption.
  ///
  /// In es, this message translates to:
  /// **'Mujer'**
  String get femaleOption;

  /// No description provided for @invalidAgeError.
  ///
  /// In es, this message translates to:
  /// **'Introduce una edad válida.'**
  String get invalidAgeError;

  /// No description provided for @invalidHeightError.
  ///
  /// In es, this message translates to:
  /// **'Introduce una altura válida.'**
  String get invalidHeightError;

  /// No description provided for @invalidCalfError.
  ///
  /// In es, this message translates to:
  /// **'Introduce una circunferencia de pantorrilla válida.'**
  String get invalidCalfError;

  /// No description provided for @selectSexError.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un sexo para aplicar la fórmula SEEN.'**
  String get selectSexError;

  /// No description provided for @estimationFailedError.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido calcular una estimación válida con esos datos.'**
  String get estimationFailedError;

  /// No description provided for @calculateAndUseButton.
  ///
  /// In es, this message translates to:
  /// **'Calcular y usar'**
  String get calculateAndUseButton;

  /// No description provided for @metricsSuccessMessage.
  ///
  /// In es, this message translates to:
  /// **'Métricas guardadas correctamente'**
  String get metricsSuccessMessage;

  /// No description provided for @seenEstimateApplied.
  ///
  /// In es, this message translates to:
  /// **'Estimación SEEN aplicada: {estimate} (ASMI {asmi} kg/m²)'**
  String seenEstimateApplied(String estimate, String asmi);

  /// No description provided for @recapStartTitle.
  ///
  /// In es, this message translates to:
  /// **'Formulario ReCap semanal'**
  String get recapStartTitle;

  /// No description provided for @recapStartDescription.
  ///
  /// In es, this message translates to:
  /// **'Completa los cuatro pasos para que tu entrenador entienda cómo ha ido tu semana y pueda ajustar el plan.'**
  String get recapStartDescription;

  /// No description provided for @recapStartButton.
  ///
  /// In es, this message translates to:
  /// **'Comenzar'**
  String get recapStartButton;

  /// No description provided for @recapSendFormButton.
  ///
  /// In es, this message translates to:
  /// **'Enviar formulario'**
  String get recapSendFormButton;

  /// No description provided for @recapReviewAndSendButton.
  ///
  /// In es, this message translates to:
  /// **'Revisar y enviar'**
  String get recapReviewAndSendButton;

  /// No description provided for @recapImprovementTitle.
  ///
  /// In es, this message translates to:
  /// **'Ayúdanos a mejorar'**
  String get recapImprovementTitle;

  /// No description provided for @recapImprovementRatingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Valoraciones'**
  String get recapImprovementRatingsTitle;

  /// No description provided for @recapImprovementRatingsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Tu opinión nos ayuda a mejorar la experiencia y el acompañamiento.'**
  String get recapImprovementRatingsSubtitle;

  /// No description provided for @recapWhatCanWeImprove.
  ///
  /// In es, this message translates to:
  /// **'¿Qué podemos mejorar?'**
  String get recapWhatCanWeImprove;

  /// No description provided for @recapTellUsMore.
  ///
  /// In es, this message translates to:
  /// **'Cuéntanos más'**
  String get recapTellUsMore;

  /// No description provided for @recapSentSuccessfully.
  ///
  /// In es, this message translates to:
  /// **'Recap enviado correctamente'**
  String get recapSentSuccessfully;

  /// No description provided for @newRecap.
  ///
  /// In es, this message translates to:
  /// **'Nuevo recap'**
  String get newRecap;

  /// No description provided for @editRecap.
  ///
  /// In es, this message translates to:
  /// **'Editar recap'**
  String get editRecap;

  /// No description provided for @weeklyRecapTitle.
  ///
  /// In es, this message translates to:
  /// **'Recap semanal'**
  String get weeklyRecapTitle;

  /// No description provided for @recapTraining.
  ///
  /// In es, this message translates to:
  /// **'Entreno'**
  String get recapTraining;

  /// No description provided for @recapNutrition.
  ///
  /// In es, this message translates to:
  /// **'Nutrición'**
  String get recapNutrition;

  /// No description provided for @recapRecovery.
  ///
  /// In es, this message translates to:
  /// **'Recuperación'**
  String get recapRecovery;

  /// No description provided for @recapGeneral.
  ///
  /// In es, this message translates to:
  /// **'General'**
  String get recapGeneral;

  /// No description provided for @couldNotLoadRecap.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el recap'**
  String get couldNotLoadRecap;

  /// No description provided for @weekWithoutDates.
  ///
  /// In es, this message translates to:
  /// **'Semana sin fechas'**
  String get weekWithoutDates;

  /// No description provided for @notRatedFeminine.
  ///
  /// In es, this message translates to:
  /// **'No valorada'**
  String get notRatedFeminine;

  /// No description provided for @notRated.
  ///
  /// In es, this message translates to:
  /// **'No valorado'**
  String get notRated;

  /// No description provided for @noZonesSelected.
  ///
  /// In es, this message translates to:
  /// **'Sin zonas marcadas'**
  String get noZonesSelected;

  /// No description provided for @noAreasSelected.
  ///
  /// In es, this message translates to:
  /// **'Sin áreas seleccionadas'**
  String get noAreasSelected;

  /// No description provided for @youHaveNotSentAnyRecapYet.
  ///
  /// In es, this message translates to:
  /// **'Todavía no has enviado ningún recap'**
  String get youHaveNotSentAnyRecapYet;

  /// No description provided for @useThisSpaceToSummarizeYourWeek.
  ///
  /// In es, this message translates to:
  /// **'Usa este espacio para resumir tu semana y dar contexto útil a tu coach.'**
  String get useThisSpaceToSummarizeYourWeek;

  /// No description provided for @createMyFirstRecap.
  ///
  /// In es, this message translates to:
  /// **'Crear mi primer recap'**
  String get createMyFirstRecap;

  /// No description provided for @yourWeeklyHistory.
  ///
  /// In es, this message translates to:
  /// **'Tu histórico semanal'**
  String get yourWeeklyHistory;

  /// No description provided for @trackYourWeeksReviewPreviousRecaps.
  ///
  /// In es, this message translates to:
  /// **'Mantén trazabilidad de tus semanas, revisa recaps anteriores y continúa borradores pendientes.'**
  String get trackYourWeeksReviewPreviousRecaps;

  /// No description provided for @viewSummary.
  ///
  /// In es, this message translates to:
  /// **'Ver resumen'**
  String get viewSummary;

  /// No description provided for @trainingNotRated.
  ///
  /// In es, this message translates to:
  /// **'Entreno sin valorar'**
  String get trainingNotRated;

  /// No description provided for @nutritionNotRated.
  ///
  /// In es, this message translates to:
  /// **'Nutrición sin valorar'**
  String get nutritionNotRated;

  /// No description provided for @moodNotRated.
  ///
  /// In es, this message translates to:
  /// **'Ánimo sin valorar'**
  String get moodNotRated;

  /// No description provided for @completeTheFourBlocksAndSendYourWeeklySummary.
  ///
  /// In es, this message translates to:
  /// **'Completa los cuatro bloques y envía tu resumen semanal.'**
  String get completeTheFourBlocksAndSendYourWeeklySummary;

  /// No description provided for @sendRecap.
  ///
  /// In es, this message translates to:
  /// **'Enviar recap'**
  String get sendRecap;

  /// No description provided for @continueToNextStep.
  ///
  /// In es, this message translates to:
  /// **'Continuar al siguiente paso'**
  String get continueToNextStep;

  /// No description provided for @generalState.
  ///
  /// In es, this message translates to:
  /// **'Estado general'**
  String get generalState;

  /// No description provided for @yourMentalAndEmotionalContextAlsoMatters.
  ///
  /// In es, this message translates to:
  /// **'Tu contexto mental y emocional también cuenta.'**
  String get yourMentalAndEmotionalContextAlsoMatters;

  /// No description provided for @mainMood.
  ///
  /// In es, this message translates to:
  /// **'Ánimo predominante'**
  String get mainMood;

  /// No description provided for @howYouFeltMostOfTheWeek.
  ///
  /// In es, this message translates to:
  /// **'Cómo te has sentido la mayor parte de la semana.'**
  String get howYouFeltMostOfTheWeek;

  /// No description provided for @rateStressLevel.
  ///
  /// In es, this message translates to:
  /// **'Valorar nivel de estrés'**
  String get rateStressLevel;

  /// No description provided for @enableItIfYouWantToReportThePressureOrLoadOfTheWeek.
  ///
  /// In es, this message translates to:
  /// **'Actívalo si quieres reportar la presión o carga de la semana.'**
  String get enableItIfYouWantToReportThePressureOrLoadOfTheWeek;

  /// No description provided for @perceivedStress.
  ///
  /// In es, this message translates to:
  /// **'Estrés percibido'**
  String get perceivedStress;

  /// No description provided for @howMuchStressDidYouFeelThisWeek.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto estrés has sentido esta semana?'**
  String get howMuchStressDidYouFeelThisWeek;

  /// No description provided for @serviceFeedback.
  ///
  /// In es, this message translates to:
  /// **'Feedback sobre el servicio'**
  String get serviceFeedback;

  /// No description provided for @helpImproveTheExperienceAndSupport.
  ///
  /// In es, this message translates to:
  /// **'Ayuda a mejorar la experiencia y el acompañamiento.'**
  String get helpImproveTheExperienceAndSupport;

  /// No description provided for @rateTheApp.
  ///
  /// In es, this message translates to:
  /// **'Valora la app'**
  String get rateTheApp;

  /// No description provided for @yourOverallExperienceWithTheApp.
  ///
  /// In es, this message translates to:
  /// **'Tu experiencia general con la aplicación.'**
  String get yourOverallExperienceWithTheApp;

  /// No description provided for @rateTheService.
  ///
  /// In es, this message translates to:
  /// **'Valora el servicio'**
  String get rateTheService;

  /// No description provided for @howYouRateTheSupportReceivedThisWeek.
  ///
  /// In es, this message translates to:
  /// **'Cómo percibes el soporte recibido esta semana.'**
  String get howYouRateTheSupportReceivedThisWeek;

  /// No description provided for @selectThePointsWhereYouWantMoreSupport.
  ///
  /// In es, this message translates to:
  /// **'Selecciona los puntos donde quieres más apoyo.'**
  String get selectThePointsWhereYouWantMoreSupport;

  /// No description provided for @finalComments.
  ///
  /// In es, this message translates to:
  /// **'Comentarios finales'**
  String get finalComments;

  /// No description provided for @closeTheWeekWithWhatMattersForYourCoach.
  ///
  /// In es, this message translates to:
  /// **'Cierra la semana con lo más relevante para tu coach.'**
  String get closeTheWeekWithWhatMattersForYourCoach;

  /// No description provided for @shareAnyRelevantDetailFromYourWeek.
  ///
  /// In es, this message translates to:
  /// **'Comparte cualquier detalle relevante de tu semana.'**
  String get shareAnyRelevantDetailFromYourWeek;

  /// No description provided for @suggestionsOrImprovements.
  ///
  /// In es, this message translates to:
  /// **'Sugerencias o mejoras'**
  String get suggestionsOrImprovements;

  /// No description provided for @egIWouldLikeMoreContextInTheSessions.
  ///
  /// In es, this message translates to:
  /// **'Ej: me gustaría más contexto en las sesiones o una mejor guía para el fin de semana.'**
  String get egIWouldLikeMoreContextInTheSessions;

  /// No description provided for @loadAndFeelings.
  ///
  /// In es, this message translates to:
  /// **'Carga y sensaciones'**
  String get loadAndFeelings;

  /// No description provided for @tellUsHowYouFeltTrainingThisWeek.
  ///
  /// In es, this message translates to:
  /// **'Cuéntanos cómo te has sentido entrenando esta semana.'**
  String get tellUsHowYouFeltTrainingThisWeek;

  /// No description provided for @overallEffort.
  ///
  /// In es, this message translates to:
  /// **'Esfuerzo general'**
  String get overallEffort;

  /// No description provided for @howDidYouFeelWithTheTrainingLoad.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo te has sentido con la carga de entrenos?'**
  String get howDidYouFeelWithTheTrainingLoad;

  /// No description provided for @completedSessions.
  ///
  /// In es, this message translates to:
  /// **'Sesiones completadas'**
  String get completedSessions;

  /// No description provided for @howDoYouRateTheNumberOfSessions.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo valoras el número de sesiones?'**
  String get howDoYouRateTheNumberOfSessions;

  /// No description provided for @perceivedProgress.
  ///
  /// In es, this message translates to:
  /// **'Progreso percibido'**
  String get perceivedProgress;

  /// No description provided for @chooseTheProgressThatBestReflectsYourWeek.
  ///
  /// In es, this message translates to:
  /// **'Selecciona la evolución que mejor refleje tu semana.'**
  String get chooseTheProgressThatBestReflectsYourWeek;

  /// No description provided for @progressPerception.
  ///
  /// In es, this message translates to:
  /// **'Percepción de progreso'**
  String get progressPerception;

  /// No description provided for @yourOverallFeelingAboutThePlanProgress.
  ///
  /// In es, this message translates to:
  /// **'Tu sensación general sobre la evolución del plan.'**
  String get yourOverallFeelingAboutThePlanProgress;

  /// No description provided for @trainingNotes.
  ///
  /// In es, this message translates to:
  /// **'Notas de entreno'**
  String get trainingNotes;

  /// No description provided for @addContextSoYourCoachCanReviewYourWeekBetter.
  ///
  /// In es, this message translates to:
  /// **'Añade contexto para que el coach revise mejor tu semana.'**
  String get addContextSoYourCoachCanReviewYourWeekBetter;

  /// No description provided for @recapTrainingObservations.
  ///
  /// In es, this message translates to:
  /// **'Observaciones'**
  String get recapTrainingObservations;

  /// No description provided for @egItWasHardToKeepThePaceOnThursday.
  ///
  /// In es, this message translates to:
  /// **'Ej: me costó mantener el ritmo el jueves o noté mejor técnica en sentadilla.'**
  String get egItWasHardToKeepThePaceOnThursday;

  /// No description provided for @weekQuality.
  ///
  /// In es, this message translates to:
  /// **'Calidad de la semana'**
  String get weekQuality;

  /// No description provided for @rateHowYourNutritionWentTheseDays.
  ///
  /// In es, this message translates to:
  /// **'Valora cómo ha ido tu alimentación estos días.'**
  String get rateHowYourNutritionWentTheseDays;

  /// No description provided for @nutritionQuality.
  ///
  /// In es, this message translates to:
  /// **'Calidad nutricional'**
  String get nutritionQuality;

  /// No description provided for @yourOverallPerceptionOfThisWeeksNutrition.
  ///
  /// In es, this message translates to:
  /// **'Tu percepción general sobre la alimentación semanal.'**
  String get yourOverallPerceptionOfThisWeeksNutrition;

  /// No description provided for @mealQuality.
  ///
  /// In es, this message translates to:
  /// **'Calidad de comidas'**
  String get mealQuality;

  /// No description provided for @howDoYouRateYourNutritionThisWeek.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo valoras tu alimentación esta semana?'**
  String get howDoYouRateYourNutritionThisWeek;

  /// No description provided for @tellUsIfYouPaidAttentionToThisArea.
  ///
  /// In es, this message translates to:
  /// **'Indica si has prestado atención a este aspecto.'**
  String get tellUsIfYouPaidAttentionToThisArea;

  /// No description provided for @iWantToRateMyHydration.
  ///
  /// In es, this message translates to:
  /// **'Quiero valorar mi hidratación'**
  String get iWantToRateMyHydration;

  /// No description provided for @enableItIfYouWantToReportHowItWentDuringTheWeek.
  ///
  /// In es, this message translates to:
  /// **'Actívalo si quieres reportar cómo fue durante la semana.'**
  String get enableItIfYouWantToReportHowItWentDuringTheWeek;

  /// No description provided for @hydrationLevel.
  ///
  /// In es, this message translates to:
  /// **'Nivel de hidratación'**
  String get hydrationLevel;

  /// No description provided for @chooseTheOptionThatFitsYouBest.
  ///
  /// In es, this message translates to:
  /// **'Selecciona la opción que mejor encaje contigo.'**
  String get chooseTheOptionThatFitsYouBest;

  /// No description provided for @nutritionNotes.
  ///
  /// In es, this message translates to:
  /// **'Notas de alimentación'**
  String get nutritionNotes;

  /// No description provided for @addContextForIssuesCravingsOrDifficulties.
  ///
  /// In es, this message translates to:
  /// **'Deja contexto para incidencias, antojos o dificultades.'**
  String get addContextForIssuesCravingsOrDifficulties;

  /// No description provided for @egItWasHardToOrganizeBreakfasts.
  ///
  /// In es, this message translates to:
  /// **'Ej: me costó organizar desayunos o he mantenido mejor la estructura los fines de semana.'**
  String get egItWasHardToOrganizeBreakfasts;

  /// No description provided for @restAndRecovery.
  ///
  /// In es, this message translates to:
  /// **'Descanso y recuperación'**
  String get restAndRecovery;

  /// No description provided for @rateHowYourBodyRespondedThisWeek.
  ///
  /// In es, this message translates to:
  /// **'Evalúa cómo ha respondido tu cuerpo esta semana.'**
  String get rateHowYourBodyRespondedThisWeek;

  /// No description provided for @selectTheRangeThatRepeatedTheMost.
  ///
  /// In es, this message translates to:
  /// **'Selecciona el rango que más se repitió.'**
  String get selectTheRangeThatRepeatedTheMost;

  /// No description provided for @fatigueLevel.
  ///
  /// In es, this message translates to:
  /// **'Nivel de fatiga'**
  String get fatigueLevel;

  /// No description provided for @howYourOverallEnergyFelt.
  ///
  /// In es, this message translates to:
  /// **'Cómo te sentiste en energía general.'**
  String get howYourOverallEnergyFelt;

  /// No description provided for @discomfortOrTightness.
  ///
  /// In es, this message translates to:
  /// **'Molestias o cargas'**
  String get discomfortOrTightness;

  /// No description provided for @tapTheAreasThatFeltTheMostLoaded.
  ///
  /// In es, this message translates to:
  /// **'Toca las zonas que has sentido más cargadas.'**
  String get tapTheAreasThatFeltTheMostLoaded;

  /// No description provided for @areasWithPainOrTension.
  ///
  /// In es, this message translates to:
  /// **'Zonas con dolor o tensión'**
  String get areasWithPainOrTension;

  /// No description provided for @tapTheAffectedBodyAreas.
  ///
  /// In es, this message translates to:
  /// **'Pulsa sobre las zonas del cuerpo afectadas.'**
  String get tapTheAffectedBodyAreas;

  /// No description provided for @painIntensity.
  ///
  /// In es, this message translates to:
  /// **'Intensidad del dolor'**
  String get painIntensity;

  /// No description provided for @overallLevelOfDiscomfortFelt.
  ///
  /// In es, this message translates to:
  /// **'Nivel general de las molestias percibidas.'**
  String get overallLevelOfDiscomfortFelt;

  /// No description provided for @recoveryNotes.
  ///
  /// In es, this message translates to:
  /// **'Notas de recuperación'**
  String get recoveryNotes;

  /// No description provided for @addAnythingImportantToAdjustThePlan.
  ///
  /// In es, this message translates to:
  /// **'Añade lo que creas importante para ajustar el plan.'**
  String get addAnythingImportantToAdjustThePlan;

  /// No description provided for @egIStillHaveLowerBackTightness.
  ///
  /// In es, this message translates to:
  /// **'Ej: arrastro tensión lumbar o he dormido mejor desde que bajó el volumen de carga.'**
  String get egIStillHaveLowerBackTightness;

  /// No description provided for @appearanceSettingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get appearanceSettingsTitle;

  /// No description provided for @systemThemeOption.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get systemThemeOption;

  /// No description provided for @systemThemeDescription.
  ///
  /// In es, this message translates to:
  /// **'Sigue automáticamente el modo configurado en tu dispositivo'**
  String get systemThemeDescription;

  /// No description provided for @lightThemeOption.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get lightThemeOption;

  /// No description provided for @lightThemeDescription.
  ///
  /// In es, this message translates to:
  /// **'Activa una versión luminosa y cálida alineada con la paleta del producto'**
  String get lightThemeDescription;

  /// No description provided for @darkThemeOption.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get darkThemeOption;

  /// No description provided for @darkThemeDescription.
  ///
  /// In es, this message translates to:
  /// **'Mantiene la experiencia nocturna actual para reducir brillo y fatiga visual'**
  String get darkThemeDescription;

  /// No description provided for @accountSettingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get accountSettingsTitle;

  /// No description provided for @editProfileOption.
  ///
  /// In es, this message translates to:
  /// **'Editar perfil'**
  String get editProfileOption;

  /// No description provided for @editProfileDescription.
  ///
  /// In es, this message translates to:
  /// **'Foto, objetivo y datos visibles en tu ficha'**
  String get editProfileDescription;

  /// No description provided for @myMetricsOption.
  ///
  /// In es, this message translates to:
  /// **'Mis métricas'**
  String get myMetricsOption;

  /// No description provided for @myMetricsDescription.
  ///
  /// In es, this message translates to:
  /// **'Peso, masa muscular, sueño y medidas corporales'**
  String get myMetricsDescription;

  /// No description provided for @unitsSettingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Unidades'**
  String get unitsSettingsTitle;

  /// No description provided for @metricOption.
  ///
  /// In es, this message translates to:
  /// **'Métrico'**
  String get metricOption;

  /// No description provided for @metricDescription.
  ///
  /// In es, this message translates to:
  /// **'Usa kilos y centímetros en toda la app'**
  String get metricDescription;

  /// No description provided for @imperialDescription.
  ///
  /// In es, this message translates to:
  /// **'Usa libras e pulgadas, guardando en métrico internamente'**
  String get imperialDescription;

  /// No description provided for @languageSettingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get languageSettingsTitle;

  /// No description provided for @systemLanguageOption.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get systemLanguageOption;

  /// No description provided for @systemLanguageDescription.
  ///
  /// In es, this message translates to:
  /// **'Usa automáticamente el idioma configurado en tu dispositivo'**
  String get systemLanguageDescription;

  /// No description provided for @spanishLanguageDescription.
  ///
  /// In es, this message translates to:
  /// **'Interfaz principal en español.'**
  String get spanishLanguageDescription;

  /// No description provided for @englishLanguageDescription.
  ///
  /// In es, this message translates to:
  /// **'Interfaz principal en inglés.'**
  String get englishLanguageDescription;

  /// No description provided for @privacySettingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Privacidad'**
  String get privacySettingsTitle;

  /// No description provided for @privacyPolicyOption.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get privacyPolicyOption;

  /// No description provided for @privacyPolicyDescription.
  ///
  /// In es, this message translates to:
  /// **'Abre la política externa para revisar tratamiento de datos y privacidad.'**
  String get privacyPolicyDescription;

  /// No description provided for @supportContactOption.
  ///
  /// In es, this message translates to:
  /// **'Soporte y contacto'**
  String get supportContactOption;

  /// No description provided for @supportContactDescription.
  ///
  /// In es, this message translates to:
  /// **'Abre la página de soporte o escribe a soporte@exom.app.'**
  String get supportContactDescription;

  /// No description provided for @emailSupportOption.
  ///
  /// In es, this message translates to:
  /// **'Escribir a soporte'**
  String get emailSupportOption;

  /// No description provided for @emailSupportOptionDescription.
  ///
  /// In es, this message translates to:
  /// **'Prepara un email externo para soporte técnico.'**
  String get emailSupportOptionDescription;

  /// No description provided for @notificationsSettingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get notificationsSettingsTitle;

  /// No description provided for @pushNotificationsOption.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones push'**
  String get pushNotificationsOption;

  /// No description provided for @pushNotificationsDescription.
  ///
  /// In es, this message translates to:
  /// **'Avisos de entrenador, seguimiento y recordatorios'**
  String get pushNotificationsDescription;

  /// No description provided for @dataAndSupportTitle.
  ///
  /// In es, this message translates to:
  /// **'Datos y soporte'**
  String get dataAndSupportTitle;

  /// No description provided for @offlineModeOption.
  ///
  /// In es, this message translates to:
  /// **'Modo offline'**
  String get offlineModeOption;

  /// No description provided for @offlineModeDescription.
  ///
  /// In es, this message translates to:
  /// **'La app conserva el ultimo Home, Perfil, Calendario, Dieta y Entreno cargados'**
  String get offlineModeDescription;

  /// No description provided for @clearCacheOption.
  ///
  /// In es, this message translates to:
  /// **'Borrar caché local'**
  String get clearCacheOption;

  /// No description provided for @clearCacheDescription.
  ///
  /// In es, this message translates to:
  /// **'Elimina datos offline guardados en este dispositivo'**
  String get clearCacheDescription;

  /// No description provided for @sendFeedbackOption.
  ///
  /// In es, this message translates to:
  /// **'Enviar feedback'**
  String get sendFeedbackOption;

  /// No description provided for @sendFeedbackDescription.
  ///
  /// In es, this message translates to:
  /// **'Comparte dudas, incidencias o feedback técnico'**
  String get sendFeedbackDescription;

  /// No description provided for @helpAndFaqOption.
  ///
  /// In es, this message translates to:
  /// **'Ayuda y FAQ'**
  String get helpAndFaqOption;

  /// No description provided for @helpAndFaqDescription.
  ///
  /// In es, this message translates to:
  /// **'Preguntas frecuentes, uso offline y soporte'**
  String get helpAndFaqDescription;

  /// No description provided for @applicationSettingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Aplicación'**
  String get applicationSettingsTitle;

  /// No description provided for @versionOption.
  ///
  /// In es, this message translates to:
  /// **'Versión'**
  String get versionOption;

  /// No description provided for @versionDescription.
  ///
  /// In es, this message translates to:
  /// **'Build actual del cliente móvil'**
  String get versionDescription;

  /// No description provided for @recommendedUpdateTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva versión disponible'**
  String get recommendedUpdateTitle;

  /// No description provided for @recommendedUpdateMessage.
  ///
  /// In es, this message translates to:
  /// **'Hay una actualización recomendada de EXOM. Puedes seguir usando la app, pero te recomendamos instalar la última versión.'**
  String get recommendedUpdateMessage;

  /// No description provided for @requiredUpdateTitle.
  ///
  /// In es, this message translates to:
  /// **'Actualización necesaria'**
  String get requiredUpdateTitle;

  /// No description provided for @requiredUpdateMessage.
  ///
  /// In es, this message translates to:
  /// **'Tu versión de EXOM se ha quedado obsoleta. Actualiza la app para continuar.'**
  String get requiredUpdateMessage;

  /// No description provided for @creditsOption.
  ///
  /// In es, this message translates to:
  /// **'Créditos'**
  String get creditsOption;

  /// No description provided for @creditsOptionDescription.
  ///
  /// In es, this message translates to:
  /// **'Tecnología y stack del producto'**
  String get creditsOptionDescription;

  /// No description provided for @logOutButton.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get logOutButton;

  /// No description provided for @settingsPageTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsPageTitle;

  /// No description provided for @updateStoreNotOpenedError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la tienda de aplicaciones.'**
  String get updateStoreNotOpenedError;

  /// No description provided for @privacyPolicyNotOpenedError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la política de privacidad.'**
  String get privacyPolicyNotOpenedError;

  /// No description provided for @supportPageNotOpenedError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la página de soporte.'**
  String get supportPageNotOpenedError;

  /// No description provided for @mailAppNotOpenedError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la aplicación de correo.'**
  String get mailAppNotOpenedError;

  /// No description provided for @themeAppliedNotification.
  ///
  /// In es, this message translates to:
  /// **'Tema {themeLabel} aplicado'**
  String themeAppliedNotification(String themeLabel);

  /// No description provided for @unitsAppliedNotification.
  ///
  /// In es, this message translates to:
  /// **'Unidades {unitLabel} aplicadas'**
  String unitsAppliedNotification(String unitLabel);

  /// No description provided for @languageAppliedNotification.
  ///
  /// In es, this message translates to:
  /// **'Idioma {languageLabel} aplicado'**
  String languageAppliedNotification(String languageLabel);

  /// No description provided for @notificationsEnabledMessage.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones activadas para este dispositivo'**
  String get notificationsEnabledMessage;

  /// No description provided for @notificationsDisabledMessage.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones desactivadas en este dispositivo'**
  String get notificationsDisabledMessage;

  /// No description provided for @cacheDeletedMessage.
  ///
  /// In es, this message translates to:
  /// **'Caché offline borrada correctamente'**
  String get cacheDeletedMessage;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @previous.
  ///
  /// In es, this message translates to:
  /// **'Anterior'**
  String get previous;

  /// No description provided for @continueButton.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueButton;

  /// No description provided for @update.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get update;

  /// No description provided for @created.
  ///
  /// In es, this message translates to:
  /// **'Creado'**
  String get created;

  /// No description provided for @help.
  ///
  /// In es, this message translates to:
  /// **'Ayuda'**
  String get help;

  /// No description provided for @feedback.
  ///
  /// In es, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settings;

  /// No description provided for @history.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get history;

  /// No description provided for @image.
  ///
  /// In es, this message translates to:
  /// **'Imagen'**
  String get image;

  /// No description provided for @video.
  ///
  /// In es, this message translates to:
  /// **'Vídeo'**
  String get video;

  /// No description provided for @reviewed.
  ///
  /// In es, this message translates to:
  /// **'Revisado'**
  String get reviewed;

  /// No description provided for @pending.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get pending;

  /// No description provided for @today.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get today;

  /// No description provided for @weight.
  ///
  /// In es, this message translates to:
  /// **'Peso'**
  String get weight;

  /// No description provided for @height.
  ///
  /// In es, this message translates to:
  /// **'Altura'**
  String get height;

  /// No description provided for @streak.
  ///
  /// In es, this message translates to:
  /// **'Racha'**
  String get streak;

  /// No description provided for @days.
  ///
  /// In es, this message translates to:
  /// **'días'**
  String get days;

  /// No description provided for @hours.
  ///
  /// In es, this message translates to:
  /// **'horas'**
  String get hours;

  /// No description provided for @years.
  ///
  /// In es, this message translates to:
  /// **'años'**
  String get years;

  /// No description provided for @sleep.
  ///
  /// In es, this message translates to:
  /// **'Sueño'**
  String get sleep;

  /// No description provided for @progress.
  ///
  /// In es, this message translates to:
  /// **'Progreso'**
  String get progress;

  /// No description provided for @notes.
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get notes;

  /// No description provided for @meals.
  ///
  /// In es, this message translates to:
  /// **'Comidas'**
  String get meals;

  /// No description provided for @training.
  ///
  /// In es, this message translates to:
  /// **'Entrenamiento'**
  String get training;

  /// No description provided for @exercises.
  ///
  /// In es, this message translates to:
  /// **'Ejercicios'**
  String get exercises;

  /// No description provided for @nutrition.
  ///
  /// In es, this message translates to:
  /// **'Nutrición'**
  String get nutrition;

  /// No description provided for @recovery.
  ///
  /// In es, this message translates to:
  /// **'Recuperación'**
  String get recovery;

  /// No description provided for @general.
  ///
  /// In es, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @quality.
  ///
  /// In es, this message translates to:
  /// **'Calidad'**
  String get quality;

  /// No description provided for @hydration.
  ///
  /// In es, this message translates to:
  /// **'Hidratación'**
  String get hydration;

  /// No description provided for @mood.
  ///
  /// In es, this message translates to:
  /// **'Ánimo'**
  String get mood;

  /// No description provided for @stress.
  ///
  /// In es, this message translates to:
  /// **'Estrés'**
  String get stress;

  /// No description provided for @effort.
  ///
  /// In es, this message translates to:
  /// **'Esfuerzo'**
  String get effort;

  /// No description provided for @sessions.
  ///
  /// In es, this message translates to:
  /// **'Sesiones'**
  String get sessions;

  /// No description provided for @completed.
  ///
  /// In es, this message translates to:
  /// **'Completado'**
  String get completed;

  /// No description provided for @achievements.
  ///
  /// In es, this message translates to:
  /// **'Logros'**
  String get achievements;

  /// No description provided for @challenges.
  ///
  /// In es, this message translates to:
  /// **'Retos'**
  String get challenges;

  /// No description provided for @profile.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profile;

  /// No description provided for @calendar.
  ///
  /// In es, this message translates to:
  /// **'Calendario'**
  String get calendar;

  /// No description provided for @diets.
  ///
  /// In es, this message translates to:
  /// **'Dietas'**
  String get diets;

  /// No description provided for @restTimerTitle.
  ///
  /// In es, this message translates to:
  /// **'Descanso'**
  String get restTimerTitle;

  /// No description provided for @restTimerNextExercise.
  ///
  /// In es, this message translates to:
  /// **'Siguiente: {name}'**
  String restTimerNextExercise(String name);

  /// No description provided for @restTimerSkip.
  ///
  /// In es, this message translates to:
  /// **'Saltar'**
  String get restTimerSkip;

  /// No description provided for @weightInputTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Peso utilizado?'**
  String get weightInputTitle;

  /// No description provided for @weightInputHint.
  ///
  /// In es, this message translates to:
  /// **'ej. 20 (opcional)'**
  String get weightInputHint;

  /// No description provided for @weightInputSkip.
  ///
  /// In es, this message translates to:
  /// **'Omitir'**
  String get weightInputSkip;

  /// No description provided for @weightInputSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get weightInputSave;

  /// No description provided for @weightBadgeLabel.
  ///
  /// In es, this message translates to:
  /// **'{weight} kg'**
  String weightBadgeLabel(String weight);

  /// No description provided for @feedbackSelectImage.
  ///
  /// In es, this message translates to:
  /// **'Imagen'**
  String get feedbackSelectImage;

  /// No description provided for @feedbackSelectVideo.
  ///
  /// In es, this message translates to:
  /// **'Vídeo'**
  String get feedbackSelectVideo;

  /// No description provided for @feedbackFromCamera.
  ///
  /// In es, this message translates to:
  /// **'Desde cámara'**
  String get feedbackFromCamera;

  /// No description provided for @feedbackFromGallery.
  ///
  /// In es, this message translates to:
  /// **'Desde galería'**
  String get feedbackFromGallery;

  /// No description provided for @feedbackUploading.
  ///
  /// In es, this message translates to:
  /// **'Subiendo...'**
  String get feedbackUploading;

  /// No description provided for @feedbackSendFromExercise.
  ///
  /// In es, this message translates to:
  /// **'Enviar feedback'**
  String get feedbackSendFromExercise;

  /// No description provided for @errorNetwork.
  ///
  /// In es, this message translates to:
  /// **'Error de red'**
  String get errorNetwork;

  /// No description provided for @errorAccountLocked.
  ///
  /// In es, this message translates to:
  /// **'Cuenta bloqueada — contacta a tu entrenador'**
  String get errorAccountLocked;

  /// No description provided for @errorSessionExpired.
  ///
  /// In es, this message translates to:
  /// **'Sesión expirada. Inicia sesión nuevamente'**
  String get errorSessionExpired;

  /// No description provided for @errorForbidden.
  ///
  /// In es, this message translates to:
  /// **'No tienes permisos para realizar esta acción'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In es, this message translates to:
  /// **'Recurso no encontrado'**
  String get errorNotFound;

  /// No description provided for @errorServer.
  ///
  /// In es, this message translates to:
  /// **'Error del servidor. Inténtalo más tarde'**
  String get errorServer;

  /// No description provided for @retryButton.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retryButton;

  /// No description provided for @contactSupportButton.
  ///
  /// In es, this message translates to:
  /// **'Contactar soporte'**
  String get contactSupportButton;

  /// No description provided for @viewOfflineButton.
  ///
  /// In es, this message translates to:
  /// **'Ver offline'**
  String get viewOfflineButton;

  /// No description provided for @goToCalendarButton.
  ///
  /// In es, this message translates to:
  /// **'Ir al calendario'**
  String get goToCalendarButton;

  /// No description provided for @goHomeButton.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get goHomeButton;

  /// No description provided for @serverErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'Algo salió mal'**
  String get serverErrorTitle;

  /// No description provided for @serverErrorMessage.
  ///
  /// In es, this message translates to:
  /// **'El servidor no pudo procesar tu solicitud'**
  String get serverErrorMessage;

  /// No description provided for @serverErrorMessageWithCode.
  ///
  /// In es, this message translates to:
  /// **'Error {code}. El servidor no pudo procesar tu solicitud'**
  String serverErrorMessageWithCode(String code);

  /// No description provided for @noConnectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión a internet'**
  String get noConnectionTitle;

  /// No description provided for @noConnectionMessage.
  ///
  /// In es, this message translates to:
  /// **'Comprueba tu conexión e inténtalo de nuevo'**
  String get noConnectionMessage;

  /// No description provided for @notFoundTitle.
  ///
  /// In es, this message translates to:
  /// **'Contenido no disponible'**
  String get notFoundTitle;

  /// No description provided for @notFoundMessage.
  ///
  /// In es, this message translates to:
  /// **'No encontramos lo que buscas. Puede que haya sido eliminado o aún no está disponible'**
  String get notFoundMessage;

  /// No description provided for @selectedDateLabel.
  ///
  /// In es, this message translates to:
  /// **'la fecha seleccionada'**
  String get selectedDateLabel;

  /// No description provided for @measureNeck.
  ///
  /// In es, this message translates to:
  /// **'Cuello'**
  String get measureNeck;

  /// No description provided for @measureShoulders.
  ///
  /// In es, this message translates to:
  /// **'Hombros'**
  String get measureShoulders;

  /// No description provided for @measureChest.
  ///
  /// In es, this message translates to:
  /// **'Pecho'**
  String get measureChest;

  /// No description provided for @measureArm.
  ///
  /// In es, this message translates to:
  /// **'Brazo'**
  String get measureArm;

  /// No description provided for @measureForearm.
  ///
  /// In es, this message translates to:
  /// **'Antebrazo'**
  String get measureForearm;

  /// No description provided for @leftSideLabel.
  ///
  /// In es, this message translates to:
  /// **'Izquierda'**
  String get leftSideLabel;

  /// No description provided for @rightSideLabel.
  ///
  /// In es, this message translates to:
  /// **'Derecha'**
  String get rightSideLabel;

  /// No description provided for @leftSideShortLabel.
  ///
  /// In es, this message translates to:
  /// **'Izq.'**
  String get leftSideShortLabel;

  /// No description provided for @rightSideShortLabel.
  ///
  /// In es, this message translates to:
  /// **'Der.'**
  String get rightSideShortLabel;

  /// No description provided for @measureWaist.
  ///
  /// In es, this message translates to:
  /// **'Cintura'**
  String get measureWaist;

  /// No description provided for @measureHips.
  ///
  /// In es, this message translates to:
  /// **'Caderas'**
  String get measureHips;

  /// No description provided for @measureThigh.
  ///
  /// In es, this message translates to:
  /// **'Muslo'**
  String get measureThigh;

  /// No description provided for @measureCalf.
  ///
  /// In es, this message translates to:
  /// **'Gemelo'**
  String get measureCalf;

  /// No description provided for @noTrainingsAssigned.
  ///
  /// In es, this message translates to:
  /// **'No tienes entrenamientos asignados'**
  String get noTrainingsAssigned;

  /// No description provided for @noTrainingsAssignedSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Tu entrenador aún no te ha asignado un plan'**
  String get noTrainingsAssignedSubtitle;

  /// No description provided for @noActivitiesThisMonth.
  ///
  /// In es, this message translates to:
  /// **'Sin actividades este mes'**
  String get noActivitiesThisMonth;

  /// No description provided for @noActivitiesThisMonthSubtitle.
  ///
  /// In es, this message translates to:
  /// **'No hay entrenamientos ni dietas programados'**
  String get noActivitiesThisMonthSubtitle;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Bienvenido a EXOM!'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeDescription.
  ///
  /// In es, this message translates to:
  /// **'Configura tu perfil en unos pocos pasos para que tu entrenador pueda personalizar tu plan.'**
  String get onboardingWelcomeDescription;

  /// No description provided for @onboardingStartButton.
  ///
  /// In es, this message translates to:
  /// **'Empezar'**
  String get onboardingStartButton;

  /// No description provided for @onboardingDoItLaterButton.
  ///
  /// In es, this message translates to:
  /// **'Hacerlo después'**
  String get onboardingDoItLaterButton;

  /// No description provided for @onboardingBasicsTitle.
  ///
  /// In es, this message translates to:
  /// **'Datos básicos'**
  String get onboardingBasicsTitle;

  /// No description provided for @onboardingFirstNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get onboardingFirstNameLabel;

  /// No description provided for @onboardingLastNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Apellido'**
  String get onboardingLastNameLabel;

  /// No description provided for @onboardingBirthDateLabel.
  ///
  /// In es, this message translates to:
  /// **'Fecha de nacimiento'**
  String get onboardingBirthDateLabel;

  /// No description provided for @onboardingAvatarLabel.
  ///
  /// In es, this message translates to:
  /// **'Foto de perfil (opcional)'**
  String get onboardingAvatarLabel;

  /// No description provided for @onboardingBodyTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu cuerpo'**
  String get onboardingBodyTitle;

  /// No description provided for @onboardingHeightLabel.
  ///
  /// In es, this message translates to:
  /// **'Altura (cm)'**
  String get onboardingHeightLabel;

  /// No description provided for @onboardingWeightLabel.
  ///
  /// In es, this message translates to:
  /// **'Peso (kg)'**
  String get onboardingWeightLabel;

  /// No description provided for @onboardingGoalsTitle.
  ///
  /// In es, this message translates to:
  /// **'Tus objetivos'**
  String get onboardingGoalsTitle;

  /// No description provided for @onboardingLevelLabel.
  ///
  /// In es, this message translates to:
  /// **'Nivel'**
  String get onboardingLevelLabel;

  /// No description provided for @onboardingMainGoalLabel.
  ///
  /// In es, this message translates to:
  /// **'Objetivo principal'**
  String get onboardingMainGoalLabel;

  /// No description provided for @onboardingMuscleMassGoalLabel.
  ///
  /// In es, this message translates to:
  /// **'Meta de masa muscular (kg, opcional)'**
  String get onboardingMuscleMassGoalLabel;

  /// No description provided for @onboardingTargetCaloriesLabel.
  ///
  /// In es, this message translates to:
  /// **'Calorías objetivo (opcional)'**
  String get onboardingTargetCaloriesLabel;

  /// No description provided for @onboardingFirstNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu nombre'**
  String get onboardingFirstNameRequired;

  /// No description provided for @onboardingLastNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Introduce tu apellido'**
  String get onboardingLastNameRequired;

  /// No description provided for @onboardingCompleteProfileButton.
  ///
  /// In es, this message translates to:
  /// **'Completar perfil'**
  String get onboardingCompleteProfileButton;

  /// No description provided for @onboardingSummaryTitle.
  ///
  /// In es, this message translates to:
  /// **'Resumen'**
  String get onboardingSummaryTitle;

  /// No description provided for @onboardingConfirmButton.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get onboardingConfirmButton;

  /// No description provided for @onboardingEditButton.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get onboardingEditButton;

  /// No description provided for @onboardingProgressComplete.
  ///
  /// In es, this message translates to:
  /// **'Perfil {percent}% completo'**
  String onboardingProgressComplete(int percent);

  /// No description provided for @onboardingSkipButton.
  ///
  /// In es, this message translates to:
  /// **'Saltar'**
  String get onboardingSkipButton;

  /// No description provided for @onboardingNextButton.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get onboardingNextButton;

  /// No description provided for @onboardingSubmittingMessage.
  ///
  /// In es, this message translates to:
  /// **'Guardando tu perfil...'**
  String get onboardingSubmittingMessage;

  /// No description provided for @onboardingSuccessMessage.
  ///
  /// In es, this message translates to:
  /// **'¡Perfil completado!'**
  String get onboardingSuccessMessage;

  /// No description provided for @onboardingErrorMessage.
  ///
  /// In es, this message translates to:
  /// **'Error al guardar el perfil. Inténtalo de nuevo.'**
  String get onboardingErrorMessage;

  /// No description provided for @continueDraftRecap.
  ///
  /// In es, this message translates to:
  /// **'Continuar borrador'**
  String get continueDraftRecap;

  /// No description provided for @recapAlreadySubmittedThisWeek.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes un recap subido esta semana'**
  String get recapAlreadySubmittedThisWeek;

  /// No description provided for @tutorialPromptTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Quieres un tour rápido?'**
  String get tutorialPromptTitle;

  /// No description provided for @tutorialPromptDescription.
  ///
  /// In es, this message translates to:
  /// **'Te enseñamos las secciones principales de la app en unos segundos.'**
  String get tutorialPromptDescription;

  /// No description provided for @tutorialStartButton.
  ///
  /// In es, this message translates to:
  /// **'Empezar guía'**
  String get tutorialStartButton;

  /// No description provided for @tutorialSkipButton.
  ///
  /// In es, this message translates to:
  /// **'Omitir'**
  String get tutorialSkipButton;

  /// No description provided for @tutorialHomeTitle.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get tutorialHomeTitle;

  /// No description provided for @tutorialHomeDesc.
  ///
  /// In es, this message translates to:
  /// **'Tu panel diario. Consulta el entreno, dieta y estadísticas del día de un vistazo.'**
  String get tutorialHomeDesc;

  /// No description provided for @tutorialTrainingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Entrenamientos'**
  String get tutorialTrainingsTitle;

  /// No description provided for @tutorialTrainingsDesc.
  ///
  /// In es, this message translates to:
  /// **'Consulta y completa tus rutinas diarias. Marca cada ejercicio a medida que avanzas.'**
  String get tutorialTrainingsDesc;

  /// No description provided for @tutorialDietsTitle.
  ///
  /// In es, this message translates to:
  /// **'Dietas'**
  String get tutorialDietsTitle;

  /// No description provided for @tutorialDietsDesc.
  ///
  /// In es, this message translates to:
  /// **'Sigue tu plan de comidas personalizado. Marca las comidas a lo largo del día.'**
  String get tutorialDietsDesc;

  /// No description provided for @tutorialCalendarTitle.
  ///
  /// In es, this message translates to:
  /// **'Calendario'**
  String get tutorialCalendarTitle;

  /// No description provided for @tutorialCalendarDesc.
  ///
  /// In es, this message translates to:
  /// **'Consulta tu agenda completa. Revisa entrenos y comidas pasados y próximos.'**
  String get tutorialCalendarDesc;

  /// No description provided for @tutorialChallengesTitle.
  ///
  /// In es, this message translates to:
  /// **'Retos'**
  String get tutorialChallengesTitle;

  /// No description provided for @tutorialChallengesDesc.
  ///
  /// In es, this message translates to:
  /// **'Consigue logros y mantén tus rachas. Mantente motivado con objetivos.'**
  String get tutorialChallengesDesc;

  /// No description provided for @tutorialProfileTitle.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get tutorialProfileTitle;

  /// No description provided for @tutorialProfileDesc.
  ///
  /// In es, this message translates to:
  /// **'Pulsa el icono de persona en la barra superior para ver tu perfil, estadísticas y métricas corporales.'**
  String get tutorialProfileDesc;

  /// No description provided for @tutorialRecapTitle.
  ///
  /// In es, this message translates to:
  /// **'Recap semanal'**
  String get tutorialRecapTitle;

  /// No description provided for @tutorialRecapDesc.
  ///
  /// In es, this message translates to:
  /// **'Abre el menú (arriba a la derecha) para encontrar el recap semanal. Resume tu semana para tu entrenador.'**
  String get tutorialRecapDesc;

  /// No description provided for @tutorialFeedbackTitle.
  ///
  /// In es, this message translates to:
  /// **'Feedback'**
  String get tutorialFeedbackTitle;

  /// No description provided for @tutorialFeedbackDesc.
  ///
  /// In es, this message translates to:
  /// **'También en el menú. Envía dudas, incidencias o feedback directamente a tu entrenador.'**
  String get tutorialFeedbackDesc;

  /// No description provided for @tutorialNextButton.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get tutorialNextButton;

  /// No description provided for @tutorialDoneButton.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get tutorialDoneButton;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
