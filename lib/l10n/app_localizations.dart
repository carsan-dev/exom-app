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

  /// No description provided for @trainingDiscardPending.
  ///
  /// In es, this message translates to:
  /// **'Descartar esta sesión pendiente'**
  String get trainingDiscardPending;

  /// No description provided for @trainingDiscardTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar esta sesión local?'**
  String get trainingDiscardTitle;

  /// No description provided for @trainingDiscardIdentity.
  ///
  /// In es, this message translates to:
  /// **'Entrenamiento: {name}\nFecha: {date}\nID de sesión: {id}'**
  String trainingDiscardIdentity(String name, String date, String id);

  /// No description provided for @trainingDiscardExplanation.
  ///
  /// In es, this message translates to:
  /// **'Solo se descartará esta sesión local pendiente. Su cierre pendiente, RPE y nota no se enviarán. Los ejercicios guardados en el servidor, las otras sesiones confirmadas y los datos no relacionados no se modificarán. Es un descarte lógico: los registros locales originales se conservan; no es un borrado físico permanente.'**
  String get trainingDiscardExplanation;

  /// No description provided for @trainingDiscardConfirm.
  ///
  /// In es, this message translates to:
  /// **'Descartar sesión local'**
  String get trainingDiscardConfirm;

  /// No description provided for @trainingDiscardSuccess.
  ///
  /// In es, this message translates to:
  /// **'Sesión local descartada. Las demás sesiones se conservan.'**
  String get trainingDiscardSuccess;

  /// No description provided for @trainingDiscardOwner.
  ///
  /// In es, this message translates to:
  /// **'No se puede descartar: ha cambiado la cuenta o la sesión. Vuelve a abrir la lista con la cuenta correspondiente.'**
  String get trainingDiscardOwner;

  /// No description provided for @trainingDiscardIdentityChanged.
  ///
  /// In es, this message translates to:
  /// **'No se puede descartar: esta sesión ya no está disponible o su identidad ha cambiado. Revisa la lista actualizada.'**
  String get trainingDiscardIdentityChanged;

  /// No description provided for @trainingDiscardUnknownOwner.
  ///
  /// In es, this message translates to:
  /// **'No se puede descartar: no se puede verificar a quién pertenecen los datos locales.'**
  String get trainingDiscardUnknownOwner;

  /// No description provided for @trainingDiscardConfirmed.
  ///
  /// In es, this message translates to:
  /// **'No se puede descartar: esta sesión ya está confirmada en el servidor.'**
  String get trainingDiscardConfirmed;

  /// No description provided for @trainingDiscardInFlight.
  ///
  /// In es, this message translates to:
  /// **'No se puede descartar mientras hay un envío en curso para esta sesión. Espera a que termine y revisa su estado.'**
  String get trainingDiscardInFlight;

  /// No description provided for @trainingDiscardDependencies.
  ///
  /// In es, this message translates to:
  /// **'No se puede descartar: hay ejercicios o evidencias pendientes de enviar vinculados a esta sesión. Se conservan para evitar pérdida de datos.'**
  String get trainingDiscardDependencies;

  /// No description provided for @trainingDiscardFailure.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el descarte local. Los datos se conservan. Revisa el estado antes de intentarlo de nuevo.'**
  String get trainingDiscardFailure;

  /// No description provided for @weeklyHunger.
  ///
  /// In es, this message translates to:
  /// **'Hambre semanal (opcional)'**
  String get weeklyHunger;

  /// No description provided for @weeklyHungerScale.
  ///
  /// In es, this message translates to:
  /// **'1 = nada de hambre · 10 = hambre extrema. Valora tu semana.'**
  String get weeklyHungerScale;

  /// No description provided for @weeklyEnergy.
  ///
  /// In es, this message translates to:
  /// **'Energía semanal (opcional)'**
  String get weeklyEnergy;

  /// No description provided for @weeklyEnergyScale.
  ///
  /// In es, this message translates to:
  /// **'1 = sin energía · 10 = mucha energía. Valora tu semana.'**
  String get weeklyEnergyScale;

  /// No description provided for @weeklyDigestion.
  ///
  /// In es, this message translates to:
  /// **'Digestión semanal (opcional)'**
  String get weeklyDigestion;

  /// No description provided for @weeklyDigestionScale.
  ///
  /// In es, this message translates to:
  /// **'1 = muy mala, muchas molestias · 10 = muy buena, sin molestias.'**
  String get weeklyDigestionScale;

  /// No description provided for @weeklyStressScale.
  ///
  /// In es, this message translates to:
  /// **'0 = sin estrés · 5 = estrés máximo. Escala histórica del recap.'**
  String get weeklyStressScale;

  /// No description provided for @optionalRatingNoData.
  ///
  /// In es, this message translates to:
  /// **'Sin dato'**
  String get optionalRatingNoData;

  /// No description provided for @appTagline.
  ///
  /// In es, this message translates to:
  /// **'Tu entrenador personal, siempre contigo'**
  String get appTagline;

  /// No description provided for @loginHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Tu plan.'**
  String get loginHeadlineFirst;

  /// No description provided for @loginHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'Siempre contigo.'**
  String get loginHeadlineSecond;

  /// No description provided for @loginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Tu entrenador crea tu cuenta al empezar. Entra con el correo que le diste.'**
  String get loginSubtitle;

  /// No description provided for @splashTagline.
  ///
  /// In es, this message translates to:
  /// **'Entrena. Come. Evoluciona.'**
  String get splashTagline;

  /// No description provided for @splashWelcomeFirst.
  ///
  /// In es, this message translates to:
  /// **'Vamos a por'**
  String get splashWelcomeFirst;

  /// No description provided for @splashWelcomeSecond.
  ///
  /// In es, this message translates to:
  /// **'tu cambio.'**
  String get splashWelcomeSecond;

  /// No description provided for @splashSlowStart.
  ///
  /// In es, this message translates to:
  /// **'Conectando…'**
  String get splashSlowStart;

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

  /// No description provided for @passwordShowTooltip.
  ///
  /// In es, this message translates to:
  /// **'Mostrar contraseña'**
  String get passwordShowTooltip;

  /// No description provided for @passwordHideTooltip.
  ///
  /// In es, this message translates to:
  /// **'Ocultar contraseña'**
  String get passwordHideTooltip;

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

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In es, this message translates to:
  /// **'Recupera tu contraseña'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Recupera'**
  String get forgotHeadlineFirst;

  /// No description provided for @forgotHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'tu contraseña.'**
  String get forgotHeadlineSecond;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Introduce el correo asociado a tu cuenta y te enviaremos un enlace para restablecerla.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @sendResetEmailButton.
  ///
  /// In es, this message translates to:
  /// **'Enviar enlace'**
  String get sendResetEmailButton;

  /// No description provided for @resetEmailSentTitle.
  ///
  /// In es, this message translates to:
  /// **'Email enviado'**
  String get resetEmailSentTitle;

  /// No description provided for @resetEmailSentFirst.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get resetEmailSentFirst;

  /// No description provided for @resetEmailSentSecond.
  ///
  /// In es, this message translates to:
  /// **'enviado.'**
  String get resetEmailSentSecond;

  /// No description provided for @resetEmailSentLinkTitle.
  ///
  /// In es, this message translates to:
  /// **'Enlace enviado'**
  String get resetEmailSentLinkTitle;

  /// No description provided for @resetEmailSentSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Hemos enviado un enlace a {email}. Revisa tu bandeja de entrada y la carpeta de correo no deseado.'**
  String resetEmailSentSubtitle(Object email);

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
  /// **'Ya existe una cuenta EXOM para {email}. Introduce tu contraseña actual para vincular este acceso.'**
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
  /// **'Tu cuenta ha sido bloqueada temporalmente.'**
  String get accountLockedMessage;

  /// No description provided for @accountLockedHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get accountLockedHeadlineFirst;

  /// No description provided for @accountLockedHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'bloqueada.'**
  String get accountLockedHeadlineSecond;

  /// No description provided for @accountLockedCoachAuthor.
  ///
  /// In es, this message translates to:
  /// **'Tu entrenador'**
  String get accountLockedCoachAuthor;

  /// No description provided for @accountLockedCoachMessage.
  ///
  /// In es, this message translates to:
  /// **'Contacta conmigo para más información.'**
  String get accountLockedCoachMessage;

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
  /// **'Recap semanal'**
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
  /// **'Cerrar sesión'**
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

  /// No description provided for @todaysTrainingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Entrenamientos de hoy'**
  String get todaysTrainingsTitle;

  /// No description provided for @assignedTrainingsCount.
  ///
  /// In es, this message translates to:
  /// **'{count} entrenamientos asignados'**
  String assignedTrainingsCount(int count);

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

  /// No description provided for @dietMealsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{{count} comida} other{{count} comidas}}'**
  String dietMealsCount(int count);

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

  /// No description provided for @dietMealsProgress.
  ///
  /// In es, this message translates to:
  /// **'{completed}/{total} {completed, plural, one{completada} other{completadas}}'**
  String dietMealsProgress(int completed, int total);

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

  /// No description provided for @mealMarkCompleteLabel.
  ///
  /// In es, this message translates to:
  /// **'Marcar {meal} como completada'**
  String mealMarkCompleteLabel(String meal);

  /// No description provided for @mealMarkUncompleteLabel.
  ///
  /// In es, this message translates to:
  /// **'Desmarcar {meal} como completada'**
  String mealMarkUncompleteLabel(String meal);

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

  /// No description provided for @remainingToConsumeLabel.
  ///
  /// In es, this message translates to:
  /// **'Por consumir'**
  String get remainingToConsumeLabel;

  /// No description provided for @remainingKcalLabel.
  ///
  /// In es, this message translates to:
  /// **'kcal restantes'**
  String get remainingKcalLabel;

  /// No description provided for @remainingTrainingMinutes.
  ///
  /// In es, this message translates to:
  /// **'≈ {minutes} min restantes'**
  String remainingTrainingMinutes(int minutes);

  /// No description provided for @remainingTrainingWork.
  ///
  /// In es, this message translates to:
  /// **'{exercises} ejercicios · {sets} series restantes'**
  String remainingTrainingWork(int exercises, int sets);

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

  /// No description provided for @yourTrainingNote.
  ///
  /// In es, this message translates to:
  /// **'Tu nota'**
  String get yourTrainingNote;

  /// No description provided for @historicalDayNoteUnattributed.
  ///
  /// In es, this message translates to:
  /// **'Nota histórica del día · Ejecución no identificada'**
  String get historicalDayNoteUnattributed;

  /// No description provided for @trainerReply.
  ///
  /// In es, this message translates to:
  /// **'Respuesta de tu entrenador'**
  String get trainerReply;

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

  /// No description provided for @challengesStreakHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Días'**
  String get challengesStreakHeadlineFirst;

  /// No description provided for @challengesStreakHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'seguidos.'**
  String get challengesStreakHeadlineSecond;

  /// No description provided for @challengesStreakEarlierDays.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{+{count} día anterior} other{+{count} días anteriores}}'**
  String challengesStreakEarlierDays(int count);

  /// No description provided for @challengesWeekHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Tu semana.'**
  String get challengesWeekHeadlineFirst;

  /// No description provided for @challengesWeekHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'También cuenta.'**
  String get challengesWeekHeadlineSecond;

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

  /// No description provided for @achievementLocked.
  ///
  /// In es, this message translates to:
  /// **'Bloqueado'**
  String get achievementLocked;

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

  /// No description provided for @noUnlockedAchievementsTitle.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes logros desbloqueados'**
  String get noUnlockedAchievementsTitle;

  /// No description provided for @noUnlockedAchievementsMessage.
  ///
  /// In es, this message translates to:
  /// **'Completa retos para desbloquear medallas. Puedes ver todos los logros disponibles.'**
  String get noUnlockedAchievementsMessage;

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
  /// **'Todo lo importante para usar EXOM en tu día a día: métricas, entrenamientos, dieta, modo sin conexión y vías de contacto.'**
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

  /// No description provided for @helpHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Tus dudas.'**
  String get helpHeadlineFirst;

  /// No description provided for @helpHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'Con tu entrenador.'**
  String get helpHeadlineSecond;

  /// No description provided for @helpCoachAuthor.
  ///
  /// In es, this message translates to:
  /// **'Tu entrenador'**
  String get helpCoachAuthor;

  /// No description provided for @helpCoachText.
  ///
  /// In es, this message translates to:
  /// **'Si no encuentras la respuesta, escríbeme.'**
  String get helpCoachText;

  /// No description provided for @helpOpensInBrowser.
  ///
  /// In es, this message translates to:
  /// **'Se abre en el navegador'**
  String get helpOpensInBrowser;

  /// No description provided for @helpOpensInMail.
  ///
  /// In es, this message translates to:
  /// **'Se abre en tu aplicación de correo'**
  String get helpOpensInMail;

  /// No description provided for @creditsDescription.
  ///
  /// In es, this message translates to:
  /// **'Producto EXOM de valor añadido para clientes. Desarrollo principal por Carlos Sánchez Román, con aplicación móvil en Flutter y servidor en NestJS.'**
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
  /// **'Entra en el entrenamiento del día desde Inicio o desde Entrenamientos. Puedes marcar ejercicios uno a uno o completar la sesión completa desde el resumen final.'**
  String get markWorkoutExplanation;

  /// No description provided for @markMealCompleted.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo marco una comida como completada?'**
  String get markMealCompleted;

  /// No description provided for @markMealExplanation.
  ///
  /// In es, this message translates to:
  /// **'Abre la dieta del día, entra en la comida correspondiente y pulsa el botón de completado. Inicio y Calendario reflejarán el avance real del día.'**
  String get markMealExplanation;

  /// No description provided for @useAppOffline.
  ///
  /// In es, this message translates to:
  /// **'¿Puedo usar la app sin conexión?'**
  String get useAppOffline;

  /// No description provided for @useAppOfflineExplanation.
  ///
  /// In es, this message translates to:
  /// **'Sí. La app conserva en caché los últimos datos cargados de Inicio, Perfil, Calendario, Dieta, Entreno y Métricas. Sin conexión puedes consultarlos, aunque no se enviarán cambios al servidor.'**
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

  /// No description provided for @profileFallbackUserName.
  ///
  /// In es, this message translates to:
  /// **'USUARIO EXOM'**
  String get profileFallbackUserName;

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
  /// **'Mejorar la condición física'**
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

  /// No description provided for @metricsFormSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Peso, altura, masa muscular, sueño y medidas'**
  String get metricsFormSubtitle;

  /// No description provided for @metricsWeightDecrease.
  ///
  /// In es, this message translates to:
  /// **'Restar {step}'**
  String metricsWeightDecrease(String step);

  /// No description provided for @metricsWeightIncrease.
  ///
  /// In es, this message translates to:
  /// **'Sumar {step}'**
  String metricsWeightIncrease(String step);

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

  /// No description provided for @metricsWeightTypeHint.
  ///
  /// In es, this message translates to:
  /// **'Toca la cifra para escribirla.'**
  String get metricsWeightTypeHint;

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
  /// **'Si no tienes una medición directa, puedes usar una estimación basada en edad, altura, sexo y circunferencia de pantorrilla. Fuente: calculadora SEEN, basada en Santos et al., JPEN 2019.'**
  String get seenCalculatorDescription;

  /// No description provided for @seenSourceLink.
  ///
  /// In es, this message translates to:
  /// **'Fuente: calculadora SEEN y artículo de referencia'**
  String get seenSourceLink;

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
  /// **'Usa la fórmula de la SEEN para estimar masa muscular esquelética apendicular a partir de edad, altura, sexo y pantorrilla. Fuente: Santos et al., JPEN 2019, referenciado por SEEN.'**
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
  /// **'Completa los cinco pasos para que tu entrenador entienda cómo ha ido tu semana y pueda ajustar el plan.'**
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
  /// **'Usa este espacio para resumir tu semana y dar contexto útil a tu entrenador.'**
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
  /// **'Completa los cinco pasos y envía tu resumen semanal.'**
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
  /// **'Cierra la semana con lo más relevante para tu entrenador.'**
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

  /// No description provided for @dailyActivity.
  ///
  /// In es, this message translates to:
  /// **'Actividad diaria'**
  String get dailyActivity;

  /// No description provided for @dailyActivityRecapDescription.
  ///
  /// In es, this message translates to:
  /// **'Añade el movimiento cotidiano para completar el contexto de la semana.'**
  String get dailyActivityRecapDescription;

  /// No description provided for @averageDailySteps.
  ///
  /// In es, this message translates to:
  /// **'Media diaria de pasos'**
  String get averageDailySteps;

  /// No description provided for @averageDailyStepsHelper.
  ///
  /// In es, this message translates to:
  /// **'Consulta la media de los últimos siete días en tu móvil o reloj.'**
  String get averageDailyStepsHelper;

  /// No description provided for @averageDailyStepsHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: 8500'**
  String get averageDailyStepsHint;

  /// No description provided for @stepsPerDay.
  ///
  /// In es, this message translates to:
  /// **'pasos/día'**
  String get stepsPerDay;

  /// No description provided for @averageDailyStepsRangeError.
  ///
  /// In es, this message translates to:
  /// **'Introduce un valor entre 0 y 200.000.'**
  String get averageDailyStepsRangeError;

  /// No description provided for @correctInvalidRecapFields.
  ///
  /// In es, this message translates to:
  /// **'Corrige los campos no válidos antes de guardar o enviar.'**
  String get correctInvalidRecapFields;

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
  /// **'Añade contexto para que el entrenador revise mejor tu semana.'**
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
  /// **'Usa libras y pulgadas, guardando en métrico internamente'**
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
  /// **'Abre la página de soporte de EXOM.'**
  String get supportContactDescription;

  /// No description provided for @emailSupportOption.
  ///
  /// In es, this message translates to:
  /// **'Escribir a soporte'**
  String get emailSupportOption;

  /// No description provided for @emailSupportOptionDescription.
  ///
  /// In es, this message translates to:
  /// **'Prepara un email externo para soporte.'**
  String get emailSupportOptionDescription;

  /// No description provided for @serviceSupportEmailOption.
  ///
  /// In es, this message translates to:
  /// **'Dudas del servicio'**
  String get serviceSupportEmailOption;

  /// No description provided for @serviceSupportEmailDescription.
  ///
  /// In es, this message translates to:
  /// **'Escribe a exom.method@gmail.com para altas, acceso y dudas de EXOM Method.'**
  String get serviceSupportEmailDescription;

  /// No description provided for @technicalSupportEmailOption.
  ///
  /// In es, this message translates to:
  /// **'Dudas técnicas'**
  String get technicalSupportEmailOption;

  /// No description provided for @technicalSupportEmailDescription.
  ///
  /// In es, this message translates to:
  /// **'Escribe a csroman.dev@gmail.com para errores de app, instalación o incidencias técnicas.'**
  String get technicalSupportEmailDescription;

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

  /// No description provided for @restTimerSoundOption.
  ///
  /// In es, this message translates to:
  /// **'Sonido al finalizar el descanso'**
  String get restTimerSoundOption;

  /// No description provided for @restTimerSoundDescription.
  ///
  /// In es, this message translates to:
  /// **'Reproduce un aviso al terminar el temporizador'**
  String get restTimerSoundDescription;

  /// No description provided for @dataAndSupportTitle.
  ///
  /// In es, this message translates to:
  /// **'Datos y soporte'**
  String get dataAndSupportTitle;

  /// No description provided for @offlineModeOption.
  ///
  /// In es, this message translates to:
  /// **'Modo sin conexión'**
  String get offlineModeOption;

  /// No description provided for @offlineModeDescription.
  ///
  /// In es, this message translates to:
  /// **'La app conserva los últimos datos cargados de Inicio, Perfil, Calendario, Dieta y Entreno'**
  String get offlineModeDescription;

  /// No description provided for @clearCacheOption.
  ///
  /// In es, this message translates to:
  /// **'Borrar caché local'**
  String get clearCacheOption;

  /// No description provided for @clearCacheDescription.
  ///
  /// In es, this message translates to:
  /// **'Elimina los datos sin conexión guardados en este dispositivo'**
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
  /// **'Ayuda y preguntas frecuentes'**
  String get helpAndFaqOption;

  /// No description provided for @helpAndFaqDescription.
  ///
  /// In es, this message translates to:
  /// **'Preguntas frecuentes, uso sin conexión y soporte'**
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
  /// **'Compilación actual del cliente móvil'**
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
  /// **'Tecnología y herramientas del producto'**
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

  /// No description provided for @updateStoreRetryHint.
  ///
  /// In es, this message translates to:
  /// **'Pulsa «Actualizar» para reintentar.'**
  String get updateStoreRetryHint;

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
  /// **'Caché sin conexión borrada correctamente'**
  String get cacheDeletedMessage;

  /// No description provided for @settingsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Tema, idioma, avisos y cuenta'**
  String get settingsSubtitle;

  /// No description provided for @settingsThemeLabel.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get settingsThemeLabel;

  /// No description provided for @settingsUnitsHint.
  ///
  /// In es, this message translates to:
  /// **'Métrico usa kilos y centímetros. Imperial usa libras y pulgadas.'**
  String get settingsUnitsHint;

  /// No description provided for @clearCacheSheetBody.
  ///
  /// In es, this message translates to:
  /// **'Se borrarán los datos guardados en este móvil para usar EXOM sin conexión. Volverán a descargarse cuando tengas conexión.'**
  String get clearCacheSheetBody;

  /// No description provided for @settingsPushEnableFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron activar las notificaciones push. Sigue desactivado.'**
  String get settingsPushEnableFailed;

  /// No description provided for @settingsPushDisableFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron desactivar las notificaciones push. Sigue activado.'**
  String get settingsPushDisableFailed;

  /// No description provided for @settingsSwitchEnableFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo activar. Sigue desactivado.'**
  String get settingsSwitchEnableFailed;

  /// No description provided for @settingsSwitchDisableFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo desactivar. Sigue activado.'**
  String get settingsSwitchDisableFailed;

  /// No description provided for @deleteAccountConfirmHelper.
  ///
  /// In es, this message translates to:
  /// **'El botón se activa cuando escribes {word}.'**
  String deleteAccountConfirmHelper(String word);

  /// No description provided for @clearCacheActiveWorkTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar la caché local?'**
  String get clearCacheActiveWorkTitle;

  /// No description provided for @clearCacheActiveWorkMessage.
  ///
  /// In es, this message translates to:
  /// **'Tienes un circuito sin terminar en este dispositivo. Si borras la caché, se perderá su progreso y no podrás retomarlo.'**
  String get clearCacheActiveWorkMessage;

  /// No description provided for @clearCacheConfirmButton.
  ///
  /// In es, this message translates to:
  /// **'Borrar caché'**
  String get clearCacheConfirmButton;

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

  /// No description provided for @completeSetButton.
  ///
  /// In es, this message translates to:
  /// **'Completar serie'**
  String get completeSetButton;

  /// No description provided for @exerciseCompleted.
  ///
  /// In es, this message translates to:
  /// **'¡Ejercicio completado!'**
  String get exerciseCompleted;

  /// No description provided for @exerciseSetProgress.
  ///
  /// In es, this message translates to:
  /// **'Serie {current} / {total}'**
  String exerciseSetProgress(int current, int total);

  /// No description provided for @startCircuitButton.
  ///
  /// In es, this message translates to:
  /// **'Comenzar circuito'**
  String get startCircuitButton;

  /// No description provided for @completeCircuitButton.
  ///
  /// In es, this message translates to:
  /// **'Circuito completado'**
  String get completeCircuitButton;

  /// No description provided for @markCircuitPendingButton.
  ///
  /// In es, this message translates to:
  /// **'Marcar circuito pendiente'**
  String get markCircuitPendingButton;

  /// No description provided for @circuitRoundRestTitle.
  ///
  /// In es, this message translates to:
  /// **'Descanso de ronda'**
  String get circuitRoundRestTitle;

  /// No description provided for @circuitRoundProgress.
  ///
  /// In es, this message translates to:
  /// **'Ronda {current} / {total}'**
  String circuitRoundProgress(int current, int total);

  /// No description provided for @circuitExerciseProgress.
  ///
  /// In es, this message translates to:
  /// **'Ejercicio {current} / {total}'**
  String circuitExerciseProgress(int current, int total);

  /// No description provided for @exerciseSeriesProgress.
  ///
  /// In es, this message translates to:
  /// **'{completed}/{total} series'**
  String exerciseSeriesProgress(int completed, int total);

  /// No description provided for @activeExerciseExecuting.
  ///
  /// In es, this message translates to:
  /// **'En ejecución'**
  String get activeExerciseExecuting;

  /// No description provided for @activeExerciseResting.
  ///
  /// In es, this message translates to:
  /// **'Descansando'**
  String get activeExerciseResting;

  /// No description provided for @activeExerciseLastWeight.
  ///
  /// In es, this message translates to:
  /// **'Último peso: {weight} kg'**
  String activeExerciseLastWeight(String weight);

  /// No description provided for @activeExerciseCloseTitle.
  ///
  /// In es, this message translates to:
  /// **'Salir del ejercicio'**
  String get activeExerciseCloseTitle;

  /// No description provided for @activeExerciseCloseMessage.
  ///
  /// In es, this message translates to:
  /// **'Has completado {completed} de {total} series. Podrás retomarlo después.'**
  String activeExerciseCloseMessage(int completed, int total);

  /// No description provided for @activeExerciseDiscardTitle.
  ///
  /// In es, this message translates to:
  /// **'Descartar progreso anterior'**
  String get activeExerciseDiscardTitle;

  /// No description provided for @activeExerciseDiscardMessage.
  ///
  /// In es, this message translates to:
  /// **'Hay un ejercicio activo guardado de otro entrenamiento. Si continúas, se descartará ese progreso local.'**
  String get activeExerciseDiscardMessage;

  /// No description provided for @activeExerciseDiscardAction.
  ///
  /// In es, this message translates to:
  /// **'Descartar y continuar'**
  String get activeExerciseDiscardAction;

  /// No description provided for @activeExerciseNoVideo.
  ///
  /// In es, this message translates to:
  /// **'Vídeo no disponible'**
  String get activeExerciseNoVideo;

  /// No description provided for @startExerciseButton.
  ///
  /// In es, this message translates to:
  /// **'Empezar ejercicio'**
  String get startExerciseButton;

  /// No description provided for @resumeExerciseButton.
  ///
  /// In es, this message translates to:
  /// **'Continuar ejercicio'**
  String get resumeExerciseButton;

  /// No description provided for @markExercisePendingButton.
  ///
  /// In es, this message translates to:
  /// **'Marcar como pendiente'**
  String get markExercisePendingButton;

  /// No description provided for @setPerformanceTitle.
  ///
  /// In es, this message translates to:
  /// **'Serie {setNumber}'**
  String setPerformanceTitle(int setNumber);

  /// No description provided for @setPerformancePrescription.
  ///
  /// In es, this message translates to:
  /// **'Objetivo: {prescription}'**
  String setPerformancePrescription(String prescription);

  /// No description provided for @setPerformancePrevious.
  ///
  /// In es, this message translates to:
  /// **'Anterior: {performance}'**
  String setPerformancePrevious(String performance);

  /// No description provided for @setPerformanceReps.
  ///
  /// In es, this message translates to:
  /// **'Repeticiones realizadas'**
  String get setPerformanceReps;

  /// No description provided for @setPerformanceSeconds.
  ///
  /// In es, this message translates to:
  /// **'Segundos realizados'**
  String get setPerformanceSeconds;

  /// No description provided for @setPerformanceWeightOptional.
  ///
  /// In es, this message translates to:
  /// **'Peso usado (opcional)'**
  String get setPerformanceWeightOptional;

  /// No description provided for @setPerformanceRirOptional.
  ///
  /// In es, this message translates to:
  /// **'RIR alcanzado (opcional)'**
  String get setPerformanceRirOptional;

  /// No description provided for @setPerformanceRepsError.
  ///
  /// In es, this message translates to:
  /// **'Introduce al menos 1 repetición'**
  String get setPerformanceRepsError;

  /// No description provided for @setPerformanceSecondsError.
  ///
  /// In es, this message translates to:
  /// **'Introduce al menos 1 segundo'**
  String get setPerformanceSecondsError;

  /// No description provided for @setPerformanceWeightError.
  ///
  /// In es, this message translates to:
  /// **'El peso no puede ser negativo'**
  String get setPerformanceWeightError;

  /// No description provided for @setPerformanceRirError.
  ///
  /// In es, this message translates to:
  /// **'El RIR debe ser un entero entre 0 y 10'**
  String get setPerformanceRirError;

  /// No description provided for @setPerformanceDataError.
  ///
  /// In es, this message translates to:
  /// **'Introduce repeticiones, segundos o peso'**
  String get setPerformanceDataError;

  /// No description provided for @completeWithoutTracking.
  ///
  /// In es, this message translates to:
  /// **'Completar sin registrar'**
  String get completeWithoutTracking;

  /// No description provided for @completeTrainingConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Completar todo el entrenamiento?'**
  String get completeTrainingConfirmTitle;

  /// No description provided for @completeTrainingConfirmMessage.
  ///
  /// In es, this message translates to:
  /// **'Se marcarán como completados todos los ejercicios pendientes. Esta acción respetará los registros y evidencias obligatorios.'**
  String get completeTrainingConfirmMessage;

  /// No description provided for @completeTrainingRpeLabel.
  ///
  /// In es, this message translates to:
  /// **'RPE (obligatorio, 1–10)'**
  String get completeTrainingRpeLabel;

  /// No description provided for @completeTrainingRpeExplanation.
  ///
  /// In es, this message translates to:
  /// **'El RPE indica cuánto esfuerzo sentiste al entrenar: 1 es muy fácil y 10 es tu máximo esfuerzo.'**
  String get completeTrainingRpeExplanation;

  /// No description provided for @completeTrainingConfirmAction.
  ///
  /// In es, this message translates to:
  /// **'Completar todo'**
  String get completeTrainingConfirmAction;

  /// No description provided for @completeTrainingTrackingRequired.
  ///
  /// In es, this message translates to:
  /// **'Registra el rendimiento obligatorio de todas las series antes de completar todo.'**
  String get completeTrainingTrackingRequired;

  /// No description provided for @completeTrainingSheetTitle.
  ///
  /// In es, this message translates to:
  /// **'Terminar sesión'**
  String get completeTrainingSheetTitle;

  /// No description provided for @completeTrainingSheetAction.
  ///
  /// In es, this message translates to:
  /// **'Terminar sesión'**
  String get completeTrainingSheetAction;

  /// No description provided for @completeTrainingRpeQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto te ha costado? (RPE)'**
  String get completeTrainingRpeQuestion;

  /// No description provided for @circuitExerciseRestTitle.
  ///
  /// In es, this message translates to:
  /// **'Descanso entre ejercicios'**
  String get circuitExerciseRestTitle;

  /// No description provided for @feedbackQueued.
  ///
  /// In es, this message translates to:
  /// **'Feedback en cola. Puedes seguir navegando mientras se sube.'**
  String get feedbackQueued;

  /// No description provided for @feedbackUploadFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo subir el feedback.'**
  String get feedbackUploadFailed;

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

  /// No description provided for @circuitFeedbackAction.
  ///
  /// In es, this message translates to:
  /// **'Enviar vídeos'**
  String get circuitFeedbackAction;

  /// No description provided for @circuitFeedbackTitle.
  ///
  /// In es, this message translates to:
  /// **'Vídeos del circuito'**
  String get circuitFeedbackTitle;

  /// No description provided for @circuitFeedbackDescription.
  ///
  /// In es, this message translates to:
  /// **'Añade un vídeo y una nota opcional a los ejercicios que quieras revisar.'**
  String get circuitFeedbackDescription;

  /// No description provided for @circuitFeedbackSendCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Enviar 1 vídeo} other{Enviar {count} vídeos}}'**
  String circuitFeedbackSendCount(int count);

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
  /// **'Ver sin conexión'**
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

  /// No description provided for @onboardingProfileIncomplete.
  ///
  /// In es, this message translates to:
  /// **'Perfil incompleto'**
  String get onboardingProfileIncomplete;

  /// No description provided for @onboardingProfileHalfDone.
  ///
  /// In es, this message translates to:
  /// **'Perfil a medias'**
  String get onboardingProfileHalfDone;

  /// No description provided for @onboardingProfileAlmostComplete.
  ///
  /// In es, this message translates to:
  /// **'Perfil casi completo'**
  String get onboardingProfileAlmostComplete;

  /// No description provided for @onboardingProfileComplete.
  ///
  /// In es, this message translates to:
  /// **'Perfil completo'**
  String get onboardingProfileComplete;

  /// No description provided for @onboardingProfileCompletionA11y.
  ///
  /// In es, this message translates to:
  /// **'{label}, {percent} %'**
  String onboardingProfileCompletionA11y(String label, int percent);

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

  /// No description provided for @onboardingWelcomeKicker.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido a EXOM'**
  String get onboardingWelcomeKicker;

  /// No description provided for @onboardingWelcomeHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Tu cambio.'**
  String get onboardingWelcomeHeadlineFirst;

  /// No description provided for @onboardingWelcomeHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'Con mi método.'**
  String get onboardingWelcomeHeadlineSecond;

  /// No description provided for @onboardingMethodOneTitle.
  ///
  /// In es, this message translates to:
  /// **'Parto de tu realidad.'**
  String get onboardingMethodOneTitle;

  /// No description provided for @onboardingMethodOneBody.
  ///
  /// In es, this message translates to:
  /// **'Antes de nada, tu punto de partida: cuéntame cómo eres y cómo es tu vida.'**
  String get onboardingMethodOneBody;

  /// No description provided for @onboardingMethodTwoTitle.
  ///
  /// In es, this message translates to:
  /// **'Sabes qué hacer.'**
  String get onboardingMethodTwoTitle;

  /// No description provided for @onboardingMethodTwoBody.
  ///
  /// In es, this message translates to:
  /// **'Con tu plan en la app, cada día sabes qué toca: tu entrenamiento, tu alimentación y tu evolución.'**
  String get onboardingMethodTwoBody;

  /// No description provided for @onboardingMethodThreeTitle.
  ///
  /// In es, this message translates to:
  /// **'Lo ajusto contigo.'**
  String get onboardingMethodThreeTitle;

  /// No description provided for @onboardingMethodThreeBody.
  ///
  /// In es, this message translates to:
  /// **'Reviso cómo vas y ajusto el plan contigo, según tu progreso.'**
  String get onboardingMethodThreeBody;

  /// No description provided for @onboardingWelcomeSteps.
  ///
  /// In es, this message translates to:
  /// **'Vamos a preparar tu perfil en cuatro pasos. Te llevará un minuto y podrás cambiarlo cuando quieras.'**
  String get onboardingWelcomeSteps;

  /// No description provided for @onboardingBasicsHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Datos básicos.'**
  String get onboardingBasicsHeadlineFirst;

  /// No description provided for @onboardingBasicsHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'Parto de tu realidad.'**
  String get onboardingBasicsHeadlineSecond;

  /// No description provided for @onboardingBodyHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Tu cuerpo.'**
  String get onboardingBodyHeadlineFirst;

  /// No description provided for @onboardingBodyHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'Tu punto de partida.'**
  String get onboardingBodyHeadlineSecond;

  /// No description provided for @onboardingGoalsHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Tus objetivos.'**
  String get onboardingGoalsHeadlineFirst;

  /// No description provided for @onboardingGoalsHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'Conmigo a tu lado.'**
  String get onboardingGoalsHeadlineSecond;

  /// No description provided for @onboardingSummaryHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Resumen.'**
  String get onboardingSummaryHeadlineFirst;

  /// No description provided for @onboardingSummaryHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'Vamos a por tu cambio.'**
  String get onboardingSummaryHeadlineSecond;

  /// No description provided for @onboardingTargetsLabel.
  ///
  /// In es, this message translates to:
  /// **'Metas'**
  String get onboardingTargetsLabel;

  /// No description provided for @onboardingNumeralHint.
  ///
  /// In es, this message translates to:
  /// **'Toca la cifra para escribirla. Los decimales llevan coma.'**
  String get onboardingNumeralHint;

  /// No description provided for @onboardingStepDecrease.
  ///
  /// In es, this message translates to:
  /// **'Restar {step}'**
  String onboardingStepDecrease(String step);

  /// No description provided for @onboardingStepIncrease.
  ///
  /// In es, this message translates to:
  /// **'Sumar {step}'**
  String onboardingStepIncrease(String step);

  /// No description provided for @onboardingNumberInvalid.
  ///
  /// In es, this message translates to:
  /// **'Introduce un número válido.'**
  String get onboardingNumberInvalid;

  /// No description provided for @onboardingNumberNotPositive.
  ///
  /// In es, this message translates to:
  /// **'Introduce un valor mayor que 0.'**
  String get onboardingNumberNotPositive;

  /// No description provided for @onboardingPreviousStep.
  ///
  /// In es, this message translates to:
  /// **'Paso anterior'**
  String get onboardingPreviousStep;

  /// No description provided for @onboardingSaveErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'Error al guardar el perfil.'**
  String get onboardingSaveErrorTitle;

  /// No description provided for @onboardingSaveErrorBody.
  ///
  /// In es, this message translates to:
  /// **'Inténtalo de nuevo; tus datos siguen aquí.'**
  String get onboardingSaveErrorBody;

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
  /// **'¿Quieres un recorrido rápido?'**
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

  /// No description provided for @promptDontShowAgain.
  ///
  /// In es, this message translates to:
  /// **'No volver a mostrar'**
  String get promptDontShowAgain;

  /// No description provided for @recapSundayPromptTitle.
  ///
  /// In es, this message translates to:
  /// **'Hoy toca tu recap'**
  String get recapSundayPromptTitle;

  /// No description provided for @recapSundayPromptBody.
  ///
  /// In es, this message translates to:
  /// **'Cuéntame cómo ha ido la semana. Son cinco pasos.'**
  String get recapSundayPromptBody;

  /// No description provided for @recapSundayPromptFill.
  ///
  /// In es, this message translates to:
  /// **'Rellenar recap'**
  String get recapSundayPromptFill;

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

  /// No description provided for @deleteAccountOption.
  ///
  /// In es, this message translates to:
  /// **'Eliminar cuenta'**
  String get deleteAccountOption;

  /// No description provided for @deleteAccountDescription.
  ///
  /// In es, this message translates to:
  /// **'Elimina permanentemente tu cuenta y todos tus datos'**
  String get deleteAccountDescription;

  /// No description provided for @deleteAccountDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar tu cuenta?'**
  String get deleteAccountDialogTitle;

  /// No description provided for @deleteAccountDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Esta acción es permanente y no se puede deshacer. Se eliminarán tu perfil, métricas, progreso, planes, feedback y archivos subidos.'**
  String get deleteAccountDialogBody;

  /// No description provided for @deleteAccountConfirmHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe ELIMINAR para confirmar'**
  String get deleteAccountConfirmHint;

  /// No description provided for @deleteAccountConfirmWord.
  ///
  /// In es, this message translates to:
  /// **'ELIMINAR'**
  String get deleteAccountConfirmWord;

  /// No description provided for @deleteAccountConfirmButton.
  ///
  /// In es, this message translates to:
  /// **'Eliminar cuenta'**
  String get deleteAccountConfirmButton;

  /// No description provided for @deleteAccountCancelButton.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get deleteAccountCancelButton;

  /// No description provided for @deleteAccountSuccessMessage.
  ///
  /// In es, this message translates to:
  /// **'Cuenta eliminada correctamente'**
  String get deleteAccountSuccessMessage;

  /// No description provided for @deleteAccountErrorMessage.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar la cuenta. Inténtalo de nuevo.'**
  String get deleteAccountErrorMessage;

  /// No description provided for @dangerZoneTitle.
  ///
  /// In es, this message translates to:
  /// **'Zona peligrosa'**
  String get dangerZoneTitle;

  /// No description provided for @notificationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get notificationsTitle;

  /// No description provided for @notificationsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No tienes notificaciones'**
  String get notificationsEmpty;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In es, this message translates to:
  /// **'Marcar todas'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsDeleteRead.
  ///
  /// In es, this message translates to:
  /// **'Eliminar leídas'**
  String get notificationsDeleteRead;

  /// No description provided for @notificationsDeleteReadDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar notificaciones leídas?'**
  String get notificationsDeleteReadDialogTitle;

  /// No description provided for @notificationsDeleteReadDialogBody.
  ///
  /// In es, this message translates to:
  /// **'Se eliminarán de forma permanente todas las notificaciones que ya has leído.'**
  String get notificationsDeleteReadDialogBody;

  /// No description provided for @notificationsDeleteReadConfirm.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get notificationsDeleteReadConfirm;

  /// No description provided for @exportWeeklyDietButton.
  ///
  /// In es, this message translates to:
  /// **'Exportar dieta semanal'**
  String get exportWeeklyDietButton;

  /// No description provided for @exportDietButton.
  ///
  /// In es, this message translates to:
  /// **'Exportar menú o lista de la compra'**
  String get exportDietButton;

  /// No description provided for @exportPeriodTitle.
  ///
  /// In es, this message translates to:
  /// **'Elige un periodo'**
  String get exportPeriodTitle;

  /// No description provided for @exportThisWeek.
  ///
  /// In es, this message translates to:
  /// **'Esta semana'**
  String get exportThisWeek;

  /// No description provided for @exportFullMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes completo'**
  String get exportFullMonth;

  /// No description provided for @exportMenu.
  ///
  /// In es, this message translates to:
  /// **'Menú'**
  String get exportMenu;

  /// No description provided for @dietPeriodEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay dietas asignadas en este periodo'**
  String get dietPeriodEmpty;

  /// No description provided for @monthlyDietPdfTitle.
  ///
  /// In es, this message translates to:
  /// **'Menú mensual'**
  String get monthlyDietPdfTitle;

  /// No description provided for @monthlyShoppingListPdfTitle.
  ///
  /// In es, this message translates to:
  /// **'Lista de la compra mensual'**
  String get monthlyShoppingListPdfTitle;

  /// No description provided for @monthlyShoppingListEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay ingredientes en las comidas de este mes'**
  String get monthlyShoppingListEmpty;

  /// No description provided for @weeklyDietPdfTitle.
  ///
  /// In es, this message translates to:
  /// **'Dieta semanal'**
  String get weeklyDietPdfTitle;

  /// No description provided for @weeklyDietNoDiet.
  ///
  /// In es, this message translates to:
  /// **'Sin dieta asignada'**
  String get weeklyDietNoDiet;

  /// No description provided for @weeklyDietIngredients.
  ///
  /// In es, this message translates to:
  /// **'Ingredientes'**
  String get weeklyDietIngredients;

  /// No description provided for @weeklyDietAlternatives.
  ///
  /// In es, this message translates to:
  /// **'Alternativa'**
  String get weeklyDietAlternatives;

  /// No description provided for @weeklyDietPreparing.
  ///
  /// In es, this message translates to:
  /// **'Preparando PDF…'**
  String get weeklyDietPreparing;

  /// No description provided for @weeklyDietEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay dietas asignadas esta semana'**
  String get weeklyDietEmpty;

  /// No description provided for @weeklyDietExportError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo generar el PDF. Inténtalo de nuevo.'**
  String get weeklyDietExportError;

  /// No description provided for @weeklyDietPrint.
  ///
  /// In es, this message translates to:
  /// **'Imprimir'**
  String get weeklyDietPrint;

  /// No description provided for @weeklyDietShare.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get weeklyDietShare;

  /// No description provided for @weeklyExportFormatTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Qué quieres exportar?'**
  String get weeklyExportFormatTitle;

  /// No description provided for @weeklyExportMenu.
  ///
  /// In es, this message translates to:
  /// **'Menú semanal'**
  String get weeklyExportMenu;

  /// No description provided for @weeklyExportShoppingList.
  ///
  /// In es, this message translates to:
  /// **'Lista de la compra'**
  String get weeklyExportShoppingList;

  /// No description provided for @weeklyVariantSelectorTitle.
  ///
  /// In es, this message translates to:
  /// **'Elegir alternativas'**
  String get weeklyVariantSelectorTitle;

  /// No description provided for @weeklyVariantMain.
  ///
  /// In es, this message translates to:
  /// **'Principal'**
  String get weeklyVariantMain;

  /// No description provided for @weeklyGenerateShoppingList.
  ///
  /// In es, this message translates to:
  /// **'Generar lista'**
  String get weeklyGenerateShoppingList;

  /// No description provided for @weeklyShoppingListPdfTitle.
  ///
  /// In es, this message translates to:
  /// **'Lista de la compra'**
  String get weeklyShoppingListPdfTitle;

  /// No description provided for @weeklyShoppingListEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay ingredientes en las comidas de esta semana'**
  String get weeklyShoppingListEmpty;

  /// No description provided for @shoppingListSetupFirst.
  ///
  /// In es, this message translates to:
  /// **'Elige tus'**
  String get shoppingListSetupFirst;

  /// No description provided for @shoppingListSetupSecond.
  ///
  /// In es, this message translates to:
  /// **'alternativas.'**
  String get shoppingListSetupSecond;

  /// No description provided for @shoppingListMealsWithOptions.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{comida} other{comidas}}'**
  String shoppingListMealsWithOptions(int count);

  /// No description provided for @shoppingListMealsWithOptionsFoot.
  ///
  /// In es, this message translates to:
  /// **'con alternativa'**
  String get shoppingListMealsWithOptionsFoot;

  /// No description provided for @shoppingListSetupNote.
  ///
  /// In es, this message translates to:
  /// **'La lista se genera con la opción elegida de cada comida.'**
  String get shoppingListSetupNote;

  /// No description provided for @shoppingListQuestion.
  ///
  /// In es, this message translates to:
  /// **'{day} · {meal}'**
  String shoppingListQuestion(String day, String meal);

  /// No description provided for @shoppingListWeekRange.
  ///
  /// In es, this message translates to:
  /// **'Semana del {start} al {end}'**
  String shoppingListWeekRange(String start, String end);

  /// No description provided for @shoppingListResultFirst.
  ///
  /// In es, this message translates to:
  /// **'Tu lista.'**
  String get shoppingListResultFirst;

  /// No description provided for @shoppingListResultSecondWeek.
  ///
  /// In es, this message translates to:
  /// **'Esta semana.'**
  String get shoppingListResultSecondWeek;

  /// No description provided for @shoppingListResultSecondMonth.
  ///
  /// In es, this message translates to:
  /// **'Este mes.'**
  String get shoppingListResultSecondMonth;

  /// No description provided for @shoppingListResultSecondWeekOf.
  ///
  /// In es, this message translates to:
  /// **'Semana del {start}.'**
  String shoppingListResultSecondWeekOf(String start);

  /// No description provided for @shoppingListProducts.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{producto} other{productos}}'**
  String shoppingListProducts(int count);

  /// No description provided for @shoppingListCheckedCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{{count} marcado} other{{count} marcados}}'**
  String shoppingListCheckedCount(int count);

  /// No description provided for @shoppingListShare.
  ///
  /// In es, this message translates to:
  /// **'Compartir lista'**
  String get shoppingListShare;

  /// No description provided for @ingredientToTaste.
  ///
  /// In es, this message translates to:
  /// **'al gusto'**
  String get ingredientToTaste;

  /// No description provided for @ingredientUnitG.
  ///
  /// In es, this message translates to:
  /// **'g'**
  String get ingredientUnitG;

  /// No description provided for @ingredientUnitMl.
  ///
  /// In es, this message translates to:
  /// **'ml'**
  String get ingredientUnitMl;

  /// No description provided for @ingredientUnitPiece.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{unidad} other{unidades}}'**
  String ingredientUnitPiece(num count);

  /// No description provided for @ingredientUnitTablespoon.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{cucharada} other{cucharadas}}'**
  String ingredientUnitTablespoon(num count);

  /// No description provided for @ingredientUnitTeaspoon.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{cucharadita} other{cucharaditas}}'**
  String ingredientUnitTeaspoon(num count);

  /// No description provided for @ingredientUnitHandful.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{puñado} other{puñados}}'**
  String ingredientUnitHandful(num count);

  /// No description provided for @ingredientUnitSlice.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{rebanada} other{rebanadas}}'**
  String ingredientUnitSlice(num count);

  /// No description provided for @ingredientUnitPalm.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{palma} other{palmas}}'**
  String ingredientUnitPalm(num count);

  /// No description provided for @ingredientUnitFist.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{puño} other{puños}}'**
  String ingredientUnitFist(num count);

  /// No description provided for @ingredientUnitLadle.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{cucharón} other{cucharones}}'**
  String ingredientUnitLadle(num count);

  /// No description provided for @ingredientUnitColdCutSlice.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{loncha} other{lonchas}}'**
  String ingredientUnitColdCutSlice(num count);

  /// No description provided for @ingredientUnitGlass.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{vaso} other{vasos}}'**
  String ingredientUnitGlass(num count);

  /// No description provided for @ingredientUnitCup.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{taza} other{tazas}}'**
  String ingredientUnitCup(num count);

  /// No description provided for @ingredientUnitBowl.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{bol} other{boles}}'**
  String ingredientUnitBowl(num count);

  /// No description provided for @ingredientUnitFinger.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{dedo} other{dedos}}'**
  String ingredientUnitFinger(num count);

  /// No description provided for @ingredientUnitPinch.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{pizca} other{pizcas}}'**
  String ingredientUnitPinch(num count);

  /// No description provided for @ingredientUnitServing.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{ración} other{raciones}}'**
  String ingredientUnitServing(num count);

  /// No description provided for @lastSetVideoReminderOption.
  ///
  /// In es, this message translates to:
  /// **'Recordatorio de vídeo de última serie'**
  String get lastSetVideoReminderOption;

  /// No description provided for @lastSetVideoReminderDescription.
  ///
  /// In es, this message translates to:
  /// **'Avisa antes de comenzar una última serie que requiere vídeo'**
  String get lastSetVideoReminderDescription;

  /// No description provided for @trainingSyncConflict.
  ///
  /// In es, this message translates to:
  /// **'Conflicto: requiere revisión'**
  String get trainingSyncConflict;

  /// No description provided for @trainingSyncReceiptMissing.
  ///
  /// In es, this message translates to:
  /// **'Falta la confirmación: reintenta la sincronización'**
  String get trainingSyncReceiptMissing;

  /// No description provided for @trainingSyncBlocked.
  ///
  /// In es, this message translates to:
  /// **'Sincronización bloqueada: una acción ha fallado'**
  String get trainingSyncBlocked;

  /// No description provided for @trainingSyncFailed.
  ///
  /// In es, this message translates to:
  /// **'La sincronización ha fallado: reinténtala'**
  String get trainingSyncFailed;

  /// No description provided for @trainingFeedbackMissing.
  ///
  /// In es, this message translates to:
  /// **'Falta la evidencia del feedback: requiere revisión'**
  String get trainingFeedbackMissing;

  /// No description provided for @trainingFeedbackFailed.
  ///
  /// In es, this message translates to:
  /// **'El feedback ha fallado: revisa la subida'**
  String get trainingFeedbackFailed;

  /// No description provided for @trainingFeedbackWaiting.
  ///
  /// In es, this message translates to:
  /// **'Esperando la confirmación del feedback'**
  String get trainingFeedbackWaiting;

  /// No description provided for @trainingPendingSync.
  ///
  /// In es, this message translates to:
  /// **'Pendiente de sincronización'**
  String get trainingPendingSync;

  /// No description provided for @trainingRetryCompletion.
  ///
  /// In es, this message translates to:
  /// **'Reintentar finalización'**
  String get trainingRetryCompletion;

  /// No description provided for @trainingPendingFinalizeNotice.
  ///
  /// In es, this message translates to:
  /// **'Tienes un entrenamiento pendiente de finalizar'**
  String get trainingPendingFinalizeNotice;

  /// No description provided for @trainingPendingFinalize.
  ///
  /// In es, this message translates to:
  /// **'Pendiente de finalizar'**
  String get trainingPendingFinalize;

  /// No description provided for @trainingContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar entrenando'**
  String get trainingContinue;

  /// No description provided for @trainingFinalize.
  ///
  /// In es, this message translates to:
  /// **'Finalizar'**
  String get trainingFinalize;

  /// No description provided for @trainingsContinueSessionButton.
  ///
  /// In es, this message translates to:
  /// **'Continuar sesión'**
  String get trainingsContinueSessionButton;

  /// No description provided for @trainingsRestDayFirst.
  ///
  /// In es, this message translates to:
  /// **'Día de'**
  String get trainingsRestDayFirst;

  /// No description provided for @trainingsRestDaySecond.
  ///
  /// In es, this message translates to:
  /// **'descanso.'**
  String get trainingsRestDaySecond;

  /// No description provided for @trainingsNoPlanFirst.
  ///
  /// In es, this message translates to:
  /// **'Sin plan.'**
  String get trainingsNoPlanFirst;

  /// No description provided for @trainingsNoPlanSecond.
  ///
  /// In es, this message translates to:
  /// **'Todavía.'**
  String get trainingsNoPlanSecond;

  /// No description provided for @trainingsHistoryPreviousMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes anterior'**
  String get trainingsHistoryPreviousMonth;

  /// No description provided for @trainingsHistoryNextMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes siguiente'**
  String get trainingsHistoryNextMonth;

  /// No description provided for @trainingsTodayHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Hoy sabes'**
  String get trainingsTodayHeadlineFirst;

  /// No description provided for @trainingsTodayHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'qué hacer.'**
  String get trainingsTodayHeadlineSecond;

  /// No description provided for @trainingsFigureMinutesApprox.
  ///
  /// In es, this message translates to:
  /// **'min aprox.'**
  String get trainingsFigureMinutesApprox;

  /// No description provided for @trainingsHistoryDone.
  ///
  /// In es, this message translates to:
  /// **'Hecha'**
  String get trainingsHistoryDone;

  /// No description provided for @trainingDraftRecoveryFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo recuperar el borrador. Los datos guardados siguen disponibles.'**
  String get trainingDraftRecoveryFailed;

  /// No description provided for @trainingLastSetVideoRequired.
  ///
  /// In es, this message translates to:
  /// **'Completa cada ejercicio y adjunta el vídeo de su última serie.'**
  String get trainingLastSetVideoRequired;

  /// No description provided for @pendingFeedbackError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo enviar el feedback. Tu evidencia se conserva; reintenta o revisa la subida.'**
  String get pendingFeedbackError;

  /// No description provided for @pendingEvidenceExercise.
  ///
  /// In es, this message translates to:
  /// **'Ejercicio: {exercise}'**
  String pendingEvidenceExercise(String exercise);

  /// No description provided for @pendingUploadsOption.
  ///
  /// In es, this message translates to:
  /// **'Subidas pendientes'**
  String get pendingUploadsOption;

  /// No description provided for @pendingUploadsDescription.
  ///
  /// In es, this message translates to:
  /// **'Revisa, reintenta o elimina evidencias que aún no se han sincronizado'**
  String get pendingUploadsDescription;

  /// No description provided for @pendingUploadsTitle.
  ///
  /// In es, this message translates to:
  /// **'Subidas pendientes'**
  String get pendingUploadsTitle;

  /// No description provided for @pendingUploadsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay subidas pendientes'**
  String get pendingUploadsEmpty;

  /// No description provided for @pendingUploadAttempts.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 intento} other{{count} intentos}}'**
  String pendingUploadAttempts(int count);

  /// No description provided for @pendingUploadDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get pendingUploadDelete;

  /// No description provided for @pendingUploadDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar esta evidencia?'**
  String get pendingUploadDeleteTitle;

  /// No description provided for @pendingUploadDeleteMessage.
  ///
  /// In es, this message translates to:
  /// **'También se eliminará la acción de progreso que depende de ella.'**
  String get pendingUploadDeleteMessage;

  /// No description provided for @pendingUploadRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get pendingUploadRetry;

  /// No description provided for @pendingUploadQueuedStatus.
  ///
  /// In es, this message translates to:
  /// **'En cola'**
  String get pendingUploadQueuedStatus;

  /// No description provided for @pendingUploadUploadingStatus.
  ///
  /// In es, this message translates to:
  /// **'Subiendo'**
  String get pendingUploadUploadingStatus;

  /// No description provided for @pendingUploadCompletedStatus.
  ///
  /// In es, this message translates to:
  /// **'Completada'**
  String get pendingUploadCompletedStatus;

  /// No description provided for @pendingUploadFailedStatus.
  ///
  /// In es, this message translates to:
  /// **'Fallida'**
  String get pendingUploadFailedStatus;

  /// No description provided for @lastSetReminderTitle.
  ///
  /// In es, this message translates to:
  /// **'Última serie'**
  String get lastSetReminderTitle;

  /// No description provided for @lastSetReminderMessage.
  ///
  /// In es, this message translates to:
  /// **'Necesitamos un vídeo de {exerciseName}. Puedes adjuntarlo ahora o al terminar el circuito.'**
  String lastSetReminderMessage(String exerciseName);

  /// No description provided for @doNotShowAgain.
  ///
  /// In es, this message translates to:
  /// **'No mostrar de nuevo'**
  String get doNotShowAgain;

  /// No description provided for @attachAtEnd.
  ///
  /// In es, this message translates to:
  /// **'Al terminar'**
  String get attachAtEnd;

  /// No description provided for @attachNow.
  ///
  /// In es, this message translates to:
  /// **'Adjuntar ahora'**
  String get attachNow;

  /// No description provided for @recordNow.
  ///
  /// In es, this message translates to:
  /// **'Grabar ahora'**
  String get recordNow;

  /// No description provided for @chooseFromGallery.
  ///
  /// In es, this message translates to:
  /// **'Elegir de la galería'**
  String get chooseFromGallery;

  /// No description provided for @requiredCircuitVideos.
  ///
  /// In es, this message translates to:
  /// **'{circuitName} · vídeos obligatorios'**
  String requiredCircuitVideos(String circuitName);

  /// No description provided for @setPerformanceMinutes.
  ///
  /// In es, this message translates to:
  /// **'Minutos'**
  String get setPerformanceMinutes;

  /// No description provided for @circuitSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el circuito. Tus datos siguen aquí; vuelve a intentarlo.'**
  String get circuitSaveError;

  /// No description provided for @mediaPickerPermissionTitle.
  ///
  /// In es, this message translates to:
  /// **'Permiso necesario'**
  String get mediaPickerPermissionTitle;

  /// No description provided for @mediaPickerPermissionMessage.
  ///
  /// In es, this message translates to:
  /// **'Da acceso a la cámara o a la galería desde Ajustes y vuelve a intentarlo.'**
  String get mediaPickerPermissionMessage;

  /// No description provided for @mediaPickerErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el archivo'**
  String get mediaPickerErrorTitle;

  /// No description provided for @mediaPickerErrorMessage.
  ///
  /// In es, this message translates to:
  /// **'Prueba de nuevo o elige un archivo de la galería.'**
  String get mediaPickerErrorMessage;

  /// No description provided for @mediaPickerFileMessage.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer o guardar el archivo. Comprueba el espacio disponible y vuelve a intentarlo.'**
  String get mediaPickerFileMessage;

  /// No description provided for @upcomingLastSetTitle.
  ///
  /// In es, this message translates to:
  /// **'Prepárate para grabar'**
  String get upcomingLastSetTitle;

  /// No description provided for @upcomingLastSetMessage.
  ///
  /// In es, this message translates to:
  /// **'La siguiente es la última serie. Necesitarás adjuntar su vídeo para completar el ejercicio.'**
  String get upcomingLastSetMessage;

  /// No description provided for @understood.
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get understood;

  /// No description provided for @attachLastSetVideo.
  ///
  /// In es, this message translates to:
  /// **'Adjunta el vídeo de tu última serie'**
  String get attachLastSetVideo;

  /// No description provided for @lastSetVideoRequiredDescription.
  ///
  /// In es, this message translates to:
  /// **'Es obligatorio para completar este ejercicio.'**
  String get lastSetVideoRequiredDescription;

  /// No description provided for @videoReadyTitle.
  ///
  /// In es, this message translates to:
  /// **'Vídeo preparado'**
  String get videoReadyTitle;

  /// No description provided for @optionalComment.
  ///
  /// In es, this message translates to:
  /// **'Comentario opcional'**
  String get optionalComment;

  /// No description provided for @changeVideo.
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get changeVideo;

  /// No description provided for @useVideo.
  ///
  /// In es, this message translates to:
  /// **'Usar vídeo'**
  String get useVideo;

  /// No description provided for @dietHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Histórico de dietas'**
  String get dietHistoryTitle;

  /// No description provided for @dietHistoryReadOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo lectura. Estas copias no cambian tu plan actual.'**
  String get dietHistoryReadOnly;

  /// No description provided for @dietHistoryEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay copias conservadas para esta fecha.'**
  String get dietHistoryEmpty;

  /// No description provided for @dietHistoryLegacy.
  ///
  /// In es, this message translates to:
  /// **'Contenido disponible al migrar; puede no reflejar ediciones anteriores.'**
  String get dietHistoryLegacy;

  /// No description provided for @dietHistoryMissing.
  ///
  /// In es, this message translates to:
  /// **'Hay comidas registradas sin detalle histórico conservado:'**
  String get dietHistoryMissing;

  /// No description provided for @dietHistoryLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el histórico. Cierra y vuelve a intentarlo.'**
  String get dietHistoryLoadError;

  /// No description provided for @pendingSyncFailuresTitle.
  ///
  /// In es, this message translates to:
  /// **'Acciones pendientes con error'**
  String get pendingSyncFailuresTitle;

  /// No description provided for @pendingSyncFailedStatus.
  ///
  /// In es, this message translates to:
  /// **'No se pudo sincronizar el progreso'**
  String get pendingSyncFailedStatus;

  /// No description provided for @pendingSyncDeleteMessage.
  ///
  /// In es, this message translates to:
  /// **'Se eliminará esta acción pendiente. El cambio local dejará de intentarse.'**
  String get pendingSyncDeleteMessage;

  /// No description provided for @feedbackOfflineMessage.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión a internet. Tus evidencias pendientes siguen guardadas.'**
  String get feedbackOfflineMessage;

  /// No description provided for @pendingUploadPreparingStatus.
  ///
  /// In es, this message translates to:
  /// **'Preparando archivo'**
  String get pendingUploadPreparingStatus;

  /// No description provided for @pendingUploadProcessingStatus.
  ///
  /// In es, this message translates to:
  /// **'Procesando'**
  String get pendingUploadProcessingStatus;

  /// No description provided for @pendingUploadLegacyRecovery.
  ///
  /// In es, this message translates to:
  /// **'Hay datos locales de una versión anterior sin propietario verificado. Se conservan sin enviar. Contacta con soporte para verificar su cuenta de origen y recuperarlos.'**
  String get pendingUploadLegacyRecovery;

  /// No description provided for @pendingSyncConflict.
  ///
  /// In es, this message translates to:
  /// **'Hay cambios en conflicto. Tus datos pendientes se conservan. Revisa el entrenamiento y descarta expresamente las acciones antiguas antes de registrar el cambio elegido.'**
  String get pendingSyncConflict;

  /// No description provided for @pendingUploadsCountSubtitle.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 pendiente} other{{count} pendientes}}'**
  String pendingUploadsCountSubtitle(int count);

  /// No description provided for @pendingUploadsErrorCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 con error} other{{count} con error}}'**
  String pendingUploadsErrorCount(int count);

  /// No description provided for @pendingUploadsNone.
  ///
  /// In es, this message translates to:
  /// **'Nada pendiente'**
  String get pendingUploadsNone;

  /// No description provided for @pendingUploadsKicker.
  ///
  /// In es, this message translates to:
  /// **'En este móvil'**
  String get pendingUploadsKicker;

  /// No description provided for @pendingUploadsHeroLabel.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{subida pendiente} other{subidas pendientes}}'**
  String pendingUploadsHeroLabel(int count);

  /// No description provided for @pendingUploadsSectionEvidence.
  ///
  /// In es, this message translates to:
  /// **'Evidencias'**
  String get pendingUploadsSectionEvidence;

  /// No description provided for @pendingUploadsEmptyFirst.
  ///
  /// In es, this message translates to:
  /// **'Todo al día.'**
  String get pendingUploadsEmptyFirst;

  /// No description provided for @pendingUploadsEmptySecond.
  ///
  /// In es, this message translates to:
  /// **'Sin subidas.'**
  String get pendingUploadsEmptySecond;

  /// No description provided for @pendingUploadsEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Cada archivo sigue en este móvil hasta que EXOM confirma que lo ha recibido.'**
  String get pendingUploadsEmptyBody;

  /// No description provided for @pendingMediaVideo.
  ///
  /// In es, this message translates to:
  /// **'Vídeo de feedback'**
  String get pendingMediaVideo;

  /// No description provided for @pendingMediaImage.
  ///
  /// In es, this message translates to:
  /// **'Imagen de feedback'**
  String get pendingMediaImage;

  /// No description provided for @pendingUploadSendingBytes.
  ///
  /// In es, this message translates to:
  /// **'Enviando {percent} % · {sent} de {total} MB'**
  String pendingUploadSendingBytes(int percent, String sent, String total);

  /// No description provided for @pendingUploadSendingKilobytes.
  ///
  /// In es, this message translates to:
  /// **'Enviando {percent} % · {sent} de {total} KB'**
  String pendingUploadSendingKilobytes(int percent, String sent, String total);

  /// No description provided for @pendingRetryFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo reintentar la subida. Tu evidencia se conserva.'**
  String get pendingRetryFailed;

  /// No description provided for @pendingRetryRequested.
  ///
  /// In es, this message translates to:
  /// **'Reintento solicitado.'**
  String get pendingRetryRequested;

  /// No description provided for @pendingRetryNotStarted.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar el reintento. Tus datos se conservan.'**
  String get pendingRetryNotStarted;

  /// No description provided for @pendingDeleteIncomplete.
  ///
  /// In es, this message translates to:
  /// **'No se completó la eliminación. Tus datos se conservan.'**
  String get pendingDeleteIncomplete;

  /// No description provided for @pendingDeleteDone.
  ///
  /// In es, this message translates to:
  /// **'Evidencia eliminada.'**
  String get pendingDeleteDone;

  /// No description provided for @pendingSyncDeleteDone.
  ///
  /// In es, this message translates to:
  /// **'Acción eliminada.'**
  String get pendingSyncDeleteDone;

  /// No description provided for @progressPhotosTitle.
  ///
  /// In es, this message translates to:
  /// **'Fotos de progreso'**
  String get progressPhotosTitle;

  /// No description provided for @progressPhotosEntry.
  ///
  /// In es, this message translates to:
  /// **'Fotos de progreso'**
  String get progressPhotosEntry;

  /// No description provided for @progressPhotosLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando fotos de progreso'**
  String get progressPhotosLoading;

  /// No description provided for @progressPhotosLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar las fotos de progreso'**
  String get progressPhotosLoadError;

  /// No description provided for @progressPhotosRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get progressPhotosRetry;

  /// No description provided for @progressPhotosRecoveryError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo recuperar la foto seleccionada. Selecciónala de nuevo.'**
  String get progressPhotosRecoveryError;

  /// No description provided for @progressPhotosEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay sesiones de fotos de progreso'**
  String get progressPhotosEmpty;

  /// No description provided for @progressPhotosNewSession.
  ///
  /// In es, this message translates to:
  /// **'Nueva sesión'**
  String get progressPhotosNewSession;

  /// No description provided for @progressPhotosCreateSession.
  ///
  /// In es, this message translates to:
  /// **'Crear sesión incompleta'**
  String get progressPhotosCreateSession;

  /// No description provided for @progressPhotosLoadMore.
  ///
  /// In es, this message translates to:
  /// **'Cargar más'**
  String get progressPhotosLoadMore;

  /// No description provided for @progressPhotosLoadingMore.
  ///
  /// In es, this message translates to:
  /// **'Cargando más…'**
  String get progressPhotosLoadingMore;

  /// No description provided for @progressPhotosChooseSource.
  ///
  /// In es, this message translates to:
  /// **'Elige el origen de la imagen'**
  String get progressPhotosChooseSource;

  /// No description provided for @progressPhotosCamera.
  ///
  /// In es, this message translates to:
  /// **'Cámara'**
  String get progressPhotosCamera;

  /// No description provided for @progressPhotosGallery.
  ///
  /// In es, this message translates to:
  /// **'Galería'**
  String get progressPhotosGallery;

  /// No description provided for @progressPhotosFront.
  ///
  /// In es, this message translates to:
  /// **'Frontal'**
  String get progressPhotosFront;

  /// No description provided for @progressPhotosLeft.
  ///
  /// In es, this message translates to:
  /// **'Lateral izquierda'**
  String get progressPhotosLeft;

  /// No description provided for @progressPhotosRight.
  ///
  /// In es, this message translates to:
  /// **'Lateral derecha'**
  String get progressPhotosRight;

  /// No description provided for @progressPhotosBack.
  ///
  /// In es, this message translates to:
  /// **'Espalda'**
  String get progressPhotosBack;

  /// No description provided for @progressPhotosComplete.
  ///
  /// In es, this message translates to:
  /// **'Completa'**
  String get progressPhotosComplete;

  /// No description provided for @progressPhotosIncomplete.
  ///
  /// In es, this message translates to:
  /// **'Sesión incompleta'**
  String get progressPhotosIncomplete;

  /// No description provided for @progressPhotosMissing.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get progressPhotosMissing;

  /// No description provided for @progressPhotosAdd.
  ///
  /// In es, this message translates to:
  /// **'Añadir {view}'**
  String progressPhotosAdd(String view);

  /// No description provided for @progressPhotosReplace.
  ///
  /// In es, this message translates to:
  /// **'Sustituir {view}'**
  String progressPhotosReplace(String view);

  /// Short visible label of the add-photo button on a progress photo tile; the full progressPhotosAdd text is its accessible label and tooltip.
  ///
  /// In es, this message translates to:
  /// **'Añadir'**
  String get progressPhotosAddShort;

  /// Short visible label of the replace-photo button on a progress photo tile; the full progressPhotosReplace text is its accessible label and tooltip.
  ///
  /// In es, this message translates to:
  /// **'Sustituir'**
  String get progressPhotosReplaceShort;

  /// No description provided for @progressPhotosReplaceTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Sustituir la foto activa?'**
  String get progressPhotosReplaceTitle;

  /// No description provided for @progressPhotosReplaceMessage.
  ///
  /// In es, this message translates to:
  /// **'La foto activa {view} solo se sustituirá si sigue siendo la actual.'**
  String progressPhotosReplaceMessage(String view);

  /// No description provided for @progressPhotosReplaceConfirm.
  ///
  /// In es, this message translates to:
  /// **'Sustituir'**
  String get progressPhotosReplaceConfirm;

  /// No description provided for @progressPhotosPending.
  ///
  /// In es, this message translates to:
  /// **'Subida pendiente'**
  String get progressPhotosPending;

  /// No description provided for @progressPhotosSynchronizing.
  ///
  /// In es, this message translates to:
  /// **'Sincronizando'**
  String get progressPhotosSynchronizing;

  /// No description provided for @progressPhotosConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Confirmada'**
  String get progressPhotosConfirmed;

  /// No description provided for @progressPhotosConfirmedCleanup.
  ///
  /// In es, this message translates to:
  /// **'Confirmada; limpiando la copia local'**
  String get progressPhotosConfirmedCleanup;

  /// No description provided for @progressPhotosFailed.
  ///
  /// In es, this message translates to:
  /// **'Falló la subida; se conserva la foto local'**
  String get progressPhotosFailed;

  /// No description provided for @progressPhotosConflict.
  ///
  /// In es, this message translates to:
  /// **'La sustitución requiere revisión; se conserva la foto local'**
  String get progressPhotosConflict;

  /// No description provided for @progressPhotosEnlarge.
  ///
  /// In es, this message translates to:
  /// **'Ampliar {view}'**
  String progressPhotosEnlarge(String view);

  /// No description provided for @progressPhotosCloseImage.
  ///
  /// In es, this message translates to:
  /// **'Cerrar imagen'**
  String get progressPhotosCloseImage;

  /// No description provided for @progressPhotosCreateError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear la sesión de fotos'**
  String get progressPhotosCreateError;

  /// No description provided for @progressPhotosRefresh.
  ///
  /// In es, this message translates to:
  /// **'Actualizar fotos de progreso'**
  String get progressPhotosRefresh;

  /// No description provided for @progressPhotosReviewReplacement.
  ///
  /// In es, this message translates to:
  /// **'Revisar sustitución'**
  String get progressPhotosReviewReplacement;

  /// No description provided for @progressPhotosRebaseTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Usar la foto activa actual?'**
  String get progressPhotosRebaseTitle;

  /// No description provided for @progressPhotosRebaseMessage.
  ///
  /// In es, this message translates to:
  /// **'La foto local conservada sustituirá la foto activa actual solo si sigue siendo la actual. No se creará una nueva subida.'**
  String get progressPhotosRebaseMessage;

  /// No description provided for @progressPhotosRebaseConfirm.
  ///
  /// In es, this message translates to:
  /// **'Reasignar sustitución'**
  String get progressPhotosRebaseConfirm;

  /// No description provided for @progressPhotosDiscard.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get progressPhotosDiscard;

  /// No description provided for @progressPhotosDiscardTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar la foto local conservada?'**
  String get progressPhotosDiscardTitle;

  /// No description provided for @progressPhotosDiscardMessage.
  ///
  /// In es, this message translates to:
  /// **'Se elimina permanentemente la foto local conservada y se detiene su subida. Esta acción no se puede deshacer.'**
  String get progressPhotosDiscardMessage;

  /// No description provided for @progressPhotosDiscardConfirm.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get progressPhotosDiscardConfirm;

  /// No description provided for @progressPhotosHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Mira atrás.'**
  String get progressPhotosHeadlineFirst;

  /// No description provided for @progressPhotosHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'Sigue adelante.'**
  String get progressPhotosHeadlineSecond;

  /// Line under the progress photos title with the date of the newest session, formatted with the active locale.
  ///
  /// In es, this message translates to:
  /// **'Última sesión: {date}'**
  String progressPhotosLastSession(String date);

  /// No description provided for @progressPhotosEmptyFirst.
  ///
  /// In es, this message translates to:
  /// **'Sin fotos.'**
  String get progressPhotosEmptyFirst;

  /// No description provided for @progressPhotosEmptySecond.
  ///
  /// In es, this message translates to:
  /// **'Todavía.'**
  String get progressPhotosEmptySecond;

  /// Accessible label of the short «Retry» link of a failed progress photo upload; view is the lowercase view name.
  ///
  /// In es, this message translates to:
  /// **'Reintentar foto {view}'**
  String progressPhotosRetryView(String view);

  /// Accessible label of the short «Discard» link of a failed progress photo upload; view is the lowercase view name.
  ///
  /// In es, this message translates to:
  /// **'Descartar foto {view}'**
  String progressPhotosDiscardView(String view);

  /// Kicker of the image source sheet: the progress photo view and the session date.
  ///
  /// In es, this message translates to:
  /// **'{view} · {date}'**
  String progressPhotosSourceKicker(String view, String date);

  /// No description provided for @executionPrepareTitle.
  ///
  /// In es, this message translates to:
  /// **'Prepárate'**
  String get executionPrepareTitle;

  /// No description provided for @executionPrepareBody.
  ///
  /// In es, this message translates to:
  /// **'El tiempo del ejercicio empieza al terminar la cuenta atrás.'**
  String get executionPrepareBody;

  /// No description provided for @executionPrepareCountdown.
  ///
  /// In es, this message translates to:
  /// **'Empieza en {seconds} segundos'**
  String executionPrepareCountdown(int seconds);

  /// No description provided for @executionPrepareCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get executionPrepareCancel;

  /// No description provided for @inputExample.
  ///
  /// In es, this message translates to:
  /// **'P. ej.: {value}'**
  String inputExample(String value);

  /// No description provided for @activeCircuitContextMissing.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el circuito. Vuelve al entrenamiento e inténtalo de nuevo.'**
  String get activeCircuitContextMissing;

  /// No description provided for @activeExerciseContextMissing.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el ejercicio. Vuelve al entrenamiento e inténtalo de nuevo.'**
  String get activeExerciseContextMissing;

  /// No description provided for @selectTrainingExecution.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una sesión de entrenamiento'**
  String get selectTrainingExecution;

  /// No description provided for @recoverSavedExerciseDraft.
  ///
  /// In es, this message translates to:
  /// **'Recuperar el borrador del ejercicio'**
  String get recoverSavedExerciseDraft;

  /// No description provided for @restoreSavedSetsNewExecution.
  ///
  /// In es, this message translates to:
  /// **'Recupera las series guardadas en una sesión nueva'**
  String get restoreSavedSetsNewExecution;

  /// No description provided for @newTrainingExecution.
  ///
  /// In es, this message translates to:
  /// **'Nueva sesión'**
  String get newTrainingExecution;

  /// No description provided for @quarantinedWorkoutNotice.
  ///
  /// In es, this message translates to:
  /// **'En este dispositivo se conservan datos de un entrenamiento cuya cuenta o fecha se desconoce. No se pueden recuperar automáticamente. Contacta con soporte para recuperarlos.'**
  String get quarantinedWorkoutNotice;

  /// No description provided for @notificationChannelName.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones de EXOM'**
  String get notificationChannelName;

  /// No description provided for @bootstrapErrorMessage.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar la app. Inténtalo de nuevo.'**
  String get bootstrapErrorMessage;

  /// No description provided for @errorRequestFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar la solicitud. Inténtalo de nuevo.'**
  String get errorRequestFailed;

  /// No description provided for @errorBadRequest.
  ///
  /// In es, this message translates to:
  /// **'Los datos enviados no son válidos. Revísalos e inténtalo de nuevo.'**
  String get errorBadRequest;

  /// No description provided for @errorConflict.
  ///
  /// In es, this message translates to:
  /// **'Los datos han cambiado desde otro lugar. Actualiza e inténtalo de nuevo.'**
  String get errorConflict;

  /// No description provided for @errorRateLimited.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos. Espera un momento e inténtalo de nuevo.'**
  String get errorRateLimited;

  /// No description provided for @errorSyncConflictReview.
  ///
  /// In es, this message translates to:
  /// **'Hay cambios en conflicto que requieren tu revisión antes de sincronizar.'**
  String get errorSyncConflictReview;

  /// No description provided for @errorSyncVersionConflict.
  ///
  /// In es, this message translates to:
  /// **'Tu progreso se modificó en otro dispositivo. Revisa los datos antes de continuar.'**
  String get errorSyncVersionConflict;

  /// No description provided for @errorSyncHistoryAmbiguous.
  ///
  /// In es, this message translates to:
  /// **'No se pudo determinar a qué entrenamiento pertenece este progreso. Tus datos se conservan para revisarlos.'**
  String get errorSyncHistoryAmbiguous;

  /// No description provided for @errorSyncReceiptMissing.
  ///
  /// In es, this message translates to:
  /// **'El servidor no confirmó el guardado. Tus datos se conservan; vuelve a intentarlo.'**
  String get errorSyncReceiptMissing;

  /// No description provided for @errorFeedbackDiscarded.
  ///
  /// In es, this message translates to:
  /// **'El material adjunto se descartó antes de enviarse.'**
  String get errorFeedbackDiscarded;

  /// No description provided for @errorSyncFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo sincronizar. Tus datos se conservan en este dispositivo.'**
  String get errorSyncFailed;

  /// No description provided for @errorCompressionCancelled.
  ///
  /// In es, this message translates to:
  /// **'La preparación del archivo se canceló.'**
  String get errorCompressionCancelled;

  /// No description provided for @errorCompressionInvalidInput.
  ///
  /// In es, this message translates to:
  /// **'El archivo seleccionado no se puede procesar.'**
  String get errorCompressionInvalidInput;

  /// No description provided for @errorCompressionTimeout.
  ///
  /// In es, this message translates to:
  /// **'La preparación del archivo tardó demasiado. Inténtalo de nuevo.'**
  String get errorCompressionTimeout;

  /// No description provided for @errorCompressionBusy.
  ///
  /// In es, this message translates to:
  /// **'Ya se está preparando otro archivo. Espera a que termine.'**
  String get errorCompressionBusy;

  /// No description provided for @errorCompressionFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo preparar el archivo. Inténtalo de nuevo.'**
  String get errorCompressionFailed;

  /// No description provided for @errorUploadExpired.
  ///
  /// In es, this message translates to:
  /// **'La subida caducó. Vuelve a intentarlo.'**
  String get errorUploadExpired;

  /// No description provided for @errorUploadObjectMissing.
  ///
  /// In es, this message translates to:
  /// **'El archivo no llegó al servidor. Vuelve a subirlo.'**
  String get errorUploadObjectMissing;

  /// No description provided for @errorUploadSessionChanged.
  ///
  /// In es, this message translates to:
  /// **'La cuenta cambió durante la subida. Inicia sesión con la cuenta original para continuar.'**
  String get errorUploadSessionChanged;

  /// No description provided for @errorUploadOperationConflict.
  ///
  /// In es, this message translates to:
  /// **'Hay otra subida en curso para este elemento. Inténtalo más tarde.'**
  String get errorUploadOperationConflict;

  /// No description provided for @authOperationError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar la operación de la cuenta. Vuelve a intentarlo.'**
  String get authOperationError;

  /// No description provided for @authUserDisabled.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta ha sido dada de baja por un administrador. Contacta con tu entrenador.'**
  String get authUserDisabled;

  /// No description provided for @authCredentialAlreadyInUse.
  ///
  /// In es, this message translates to:
  /// **'Este acceso social ya está vinculado a otra cuenta. Inicia sesión con tu método original e inténtalo de nuevo.'**
  String get authCredentialAlreadyInUse;

  /// No description provided for @authNoCurrentUser.
  ///
  /// In es, this message translates to:
  /// **'No hemos podido mantener tu sesión para completar la vinculación. Vuelve a intentarlo.'**
  String get authNoCurrentUser;

  /// No description provided for @authInvalidCredential.
  ///
  /// In es, this message translates to:
  /// **'La credencial social ha caducado. Repite el proceso de vinculación.'**
  String get authInvalidCredential;

  /// No description provided for @homeLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el resumen. Vuelve a intentarlo.'**
  String get homeLoadError;

  /// No description provided for @metricsSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron guardar las medidas. Vuelve a intentarlo.'**
  String get metricsSaveError;

  /// No description provided for @feedbackOperationError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar la operación. Vuelve a intentarlo.'**
  String get feedbackOperationError;

  /// No description provided for @notificationsLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar las notificaciones. Inténtalo de nuevo.'**
  String get notificationsLoadError;

  /// No description provided for @profileOperationError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar la operación del perfil. Inténtalo de nuevo.'**
  String get profileOperationError;

  /// No description provided for @profileHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Mira atrás.'**
  String get profileHeadlineFirst;

  /// No description provided for @profileHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'Sigue adelante.'**
  String get profileHeadlineSecond;

  /// No description provided for @profileStreakDays.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Racha de 1 día} other{Racha de {count} días}}'**
  String profileStreakDays(int count);

  /// No description provided for @profileChangePhotoA11y.
  ///
  /// In es, this message translates to:
  /// **'Cambiar foto de perfil'**
  String get profileChangePhotoA11y;

  /// No description provided for @profileAvatarSending.
  ///
  /// In es, this message translates to:
  /// **'Enviando foto de perfil'**
  String get profileAvatarSending;

  /// No description provided for @profileWeightSince.
  ///
  /// In es, this message translates to:
  /// **'desde {value}'**
  String profileWeightSince(String value);

  /// No description provided for @profileGoalShare.
  ///
  /// In es, this message translates to:
  /// **'{percent} del objetivo'**
  String profileGoalShare(String percent);

  /// No description provided for @profileGoalValue.
  ///
  /// In es, this message translates to:
  /// **'Objetivo: {value}'**
  String profileGoalValue(String value);

  /// No description provided for @profileIndexMetrics.
  ///
  /// In es, this message translates to:
  /// **'Actualizar peso y medidas'**
  String get profileIndexMetrics;

  /// No description provided for @profileEmptyFirst.
  ///
  /// In es, this message translates to:
  /// **'Sin datos'**
  String get profileEmptyFirst;

  /// No description provided for @profileEmptySecond.
  ///
  /// In es, this message translates to:
  /// **'todavía.'**
  String get profileEmptySecond;

  /// No description provided for @profileMeasurementsUpdated.
  ///
  /// In es, this message translates to:
  /// **'Medidas · última actualización {date}'**
  String profileMeasurementsUpdated(String date);

  /// No description provided for @profileGoalSheetFirst.
  ///
  /// In es, this message translates to:
  /// **'Objetivo'**
  String get profileGoalSheetFirst;

  /// No description provided for @profileGoalSheetSecond.
  ///
  /// In es, this message translates to:
  /// **'de masa muscular'**
  String get profileGoalSheetSecond;

  /// No description provided for @profileGoalLatest.
  ///
  /// In es, this message translates to:
  /// **'Última medición: {value}'**
  String profileGoalLatest(String value);

  /// No description provided for @profileGoalDecrease.
  ///
  /// In es, this message translates to:
  /// **'Restar {step}'**
  String profileGoalDecrease(String step);

  /// No description provided for @profileGoalIncrease.
  ///
  /// In es, this message translates to:
  /// **'Sumar {step}'**
  String profileGoalIncrease(String step);

  /// No description provided for @profileGoalInvalid.
  ///
  /// In es, this message translates to:
  /// **'Introduce un objetivo mayor que 0.'**
  String get profileGoalInvalid;

  /// No description provided for @profileGoalEditA11y.
  ///
  /// In es, this message translates to:
  /// **'Editar objetivo de masa muscular'**
  String get profileGoalEditA11y;

  /// No description provided for @profileHoursUnit.
  ///
  /// In es, this message translates to:
  /// **'h'**
  String get profileHoursUnit;

  /// No description provided for @recapSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el resumen semanal. Inténtalo de nuevo.'**
  String get recapSaveError;

  /// No description provided for @recapLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar los resúmenes semanales. Inténtalo de nuevo.'**
  String get recapLoadError;

  /// No description provided for @recapDetailLoadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el resumen semanal. Inténtalo de nuevo.'**
  String get recapDetailLoadError;

  /// No description provided for @activeExerciseSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron guardar los datos del ejercicio. Inténtalo de nuevo.'**
  String get activeExerciseSaveError;

  /// No description provided for @trainingProgressSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el progreso del entrenamiento. Inténtalo de nuevo.'**
  String get trainingProgressSaveError;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In es, this message translates to:
  /// **'Alertas y recordatorios importantes de EXOM'**
  String get notificationChannelDescription;

  /// No description provided for @optionsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{{count} opción} other{{count} opciones}}'**
  String optionsCount(int count);

  /// No description provided for @chooseAnOption.
  ///
  /// In es, this message translates to:
  /// **'Elige una opción'**
  String get chooseAnOption;

  /// No description provided for @streakDaysLabel.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{días de racha} =1{día de racha} other{días de racha}}'**
  String streakDaysLabel(int count);

  /// No description provided for @recapDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Detalle del recap'**
  String get recapDetailTitle;

  /// No description provided for @recapDetailHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Mira atrás.'**
  String get recapDetailHeadlineFirst;

  /// No description provided for @recapDetailHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'Sigue adelante.'**
  String get recapDetailHeadlineSecond;

  /// No description provided for @recapReviewedOn.
  ///
  /// In es, this message translates to:
  /// **'Revisado el {date}'**
  String recapReviewedOn(String date);

  /// No description provided for @recapNewCoachComment.
  ///
  /// In es, this message translates to:
  /// **'Nuevo comentario de tu entrenador'**
  String get recapNewCoachComment;

  /// No description provided for @recapCoachCommentTitle.
  ///
  /// In es, this message translates to:
  /// **'Comentario de tu entrenador'**
  String get recapCoachCommentTitle;

  /// No description provided for @recapBadgeNew.
  ///
  /// In es, this message translates to:
  /// **'Nuevo'**
  String get recapBadgeNew;

  /// No description provided for @recapFeedbackSentOn.
  ///
  /// In es, this message translates to:
  /// **'Enviado el {date}'**
  String recapFeedbackSentOn(String date);

  /// No description provided for @recapFeedbackPendingRead.
  ///
  /// In es, this message translates to:
  /// **'Pendiente de lectura'**
  String get recapFeedbackPendingRead;

  /// No description provided for @recapFeedbackReadOn.
  ///
  /// In es, this message translates to:
  /// **'Leído el {date}'**
  String recapFeedbackReadOn(String date);

  /// No description provided for @todayWithLabel.
  ///
  /// In es, this message translates to:
  /// **'Hoy: {label}'**
  String todayWithLabel(String label);

  /// No description provided for @errorTitle.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get errorTitle;

  /// No description provided for @completeLastSetOpenExercise.
  ///
  /// In es, this message translates to:
  /// **'Abre el ejercicio para completar la última serie y adjuntar su vídeo.'**
  String get completeLastSetOpenExercise;

  /// No description provided for @circuitSummary.
  ///
  /// In es, this message translates to:
  /// **'{rounds, plural, one{{rounds} ronda} other{{rounds} rondas}} · {exerciseCount, plural, one{{exerciseCount} ejercicio} other{{exerciseCount} ejercicios}}'**
  String circuitSummary(int rounds, int exerciseCount);

  /// No description provided for @registeredSetsToday.
  ///
  /// In es, this message translates to:
  /// **'Series registradas hoy'**
  String get registeredSetsToday;

  /// No description provided for @editData.
  ///
  /// In es, this message translates to:
  /// **'Editar datos'**
  String get editData;

  /// No description provided for @timerFinished.
  ///
  /// In es, this message translates to:
  /// **'Tiempo finalizado'**
  String get timerFinished;

  /// No description provided for @timerNowAction.
  ///
  /// In es, this message translates to:
  /// **'Ahora: {action}'**
  String timerNowAction(String action);

  /// No description provided for @timerLogSetWhenDone.
  ///
  /// In es, this message translates to:
  /// **'Registra la serie cuando termines.'**
  String get timerLogSetWhenDone;

  /// No description provided for @timerSegmentRemaining.
  ///
  /// In es, this message translates to:
  /// **'Tramo: {segment} · Total restante: {total}'**
  String timerSegmentRemaining(String segment, String total);

  /// No description provided for @timerNextAction.
  ///
  /// In es, this message translates to:
  /// **'Siguiente: {action}'**
  String timerNextAction(String action);

  /// No description provided for @timerRunning.
  ///
  /// In es, this message translates to:
  /// **'En marcha'**
  String get timerRunning;

  /// No description provided for @timerPaused.
  ///
  /// In es, this message translates to:
  /// **'En pausa'**
  String get timerPaused;

  /// No description provided for @timerReady.
  ///
  /// In es, this message translates to:
  /// **'Preparado'**
  String get timerReady;

  /// No description provided for @timerPause.
  ///
  /// In es, this message translates to:
  /// **'Pausar'**
  String get timerPause;

  /// No description provided for @timerResume.
  ///
  /// In es, this message translates to:
  /// **'Reanudar'**
  String get timerResume;

  /// No description provided for @timerStart.
  ///
  /// In es, this message translates to:
  /// **'Iniciar tiempo'**
  String get timerStart;

  /// No description provided for @timerReset.
  ///
  /// In es, this message translates to:
  /// **'Reiniciar tiempo'**
  String get timerReset;

  /// No description provided for @streakMsgStart.
  ///
  /// In es, this message translates to:
  /// **'¡Empieza tu racha hoy!'**
  String get streakMsgStart;

  /// No description provided for @streakMsgFirstDay.
  ///
  /// In es, this message translates to:
  /// **'¡Primer día completado! Sigue así'**
  String get streakMsgFirstDay;

  /// No description provided for @streakMsgGoingWell.
  ///
  /// In es, this message translates to:
  /// **'¡Vas muy bien! No lo detengas'**
  String get streakMsgGoingWell;

  /// No description provided for @streakMsgWeek.
  ///
  /// In es, this message translates to:
  /// **'¡Una semana seguida! Increíble'**
  String get streakMsgWeek;

  /// No description provided for @streakMsgMachine.
  ///
  /// In es, this message translates to:
  /// **'¡Eres una máquina! Más de {days} días'**
  String streakMsgMachine(int days);

  /// No description provided for @streakMsgLegend.
  ///
  /// In es, this message translates to:
  /// **'¡Leyenda viva! {days} días de racha'**
  String streakMsgLegend(int days);

  /// No description provided for @recapSignInRequired.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para ver el recap.'**
  String get recapSignInRequired;

  /// No description provided for @authMissingEmailForLink.
  ///
  /// In es, this message translates to:
  /// **'No hemos podido identificar el correo de esta cuenta {provider}. Inicia sesión con tu método actual y vuelve a intentarlo.'**
  String authMissingEmailForLink(String provider);

  /// No description provided for @authLinkRequestExpired.
  ///
  /// In es, this message translates to:
  /// **'La solicitud de vinculación ha caducado. Vuelve a intentarlo.'**
  String get authLinkRequestExpired;

  /// No description provided for @activeExerciseOtherExecution.
  ///
  /// In es, this message translates to:
  /// **'Hay un entrenamiento guardado que pertenece a otra sesión. Elige cuál conservar antes de continuar.'**
  String get activeExerciseOtherExecution;

  /// No description provided for @navTabChallengesA11y.
  ///
  /// In es, this message translates to:
  /// **'Retos'**
  String get navTabChallengesA11y;

  /// No description provided for @navTabTrainingsA11y.
  ///
  /// In es, this message translates to:
  /// **'Entrenar'**
  String get navTabTrainingsA11y;

  /// No description provided for @navTabHomeA11y.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navTabHomeA11y;

  /// No description provided for @navTabDietsA11y.
  ///
  /// In es, this message translates to:
  /// **'Dietas'**
  String get navTabDietsA11y;

  /// No description provided for @navTabCalendarA11y.
  ///
  /// In es, this message translates to:
  /// **'Calendario'**
  String get navTabCalendarA11y;

  /// No description provided for @navTabChallengesLabel.
  ///
  /// In es, this message translates to:
  /// **'Retos'**
  String get navTabChallengesLabel;

  /// No description provided for @navTabTrainingsLabel.
  ///
  /// In es, this message translates to:
  /// **'Entrenar'**
  String get navTabTrainingsLabel;

  /// No description provided for @navTabHomeLabel.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navTabHomeLabel;

  /// No description provided for @navTabDietsLabel.
  ///
  /// In es, this message translates to:
  /// **'Dietas'**
  String get navTabDietsLabel;

  /// No description provided for @navTabCalendarLabel.
  ///
  /// In es, this message translates to:
  /// **'Calendario'**
  String get navTabCalendarLabel;

  /// No description provided for @shellMenuTooltip.
  ///
  /// In es, this message translates to:
  /// **'Menú'**
  String get shellMenuTooltip;

  /// No description provided for @syncStatusSavedOnDevice.
  ///
  /// In es, this message translates to:
  /// **'Guardada en este móvil'**
  String get syncStatusSavedOnDevice;

  /// No description provided for @syncStatusPending.
  ///
  /// In es, this message translates to:
  /// **'Pendiente de sincronizar'**
  String get syncStatusPending;

  /// No description provided for @syncStatusSending.
  ///
  /// In es, this message translates to:
  /// **'Enviando'**
  String get syncStatusSending;

  /// No description provided for @syncStatusConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Confirmada'**
  String get syncStatusConfirmed;

  /// No description provided for @syncStatusFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo sincronizar'**
  String get syncStatusFailed;

  /// No description provided for @buttonBusyA11y.
  ///
  /// In es, this message translates to:
  /// **'En curso'**
  String get buttonBusyA11y;

  /// No description provided for @sheetBarrierA11y.
  ///
  /// In es, this message translates to:
  /// **'Cerrar hoja'**
  String get sheetBarrierA11y;

  /// No description provided for @noticeUnreadA11y.
  ///
  /// In es, this message translates to:
  /// **'No leído'**
  String get noticeUnreadA11y;

  /// No description provided for @homeStartSessionButton.
  ///
  /// In es, this message translates to:
  /// **'Empezar sesión'**
  String get homeStartSessionButton;

  /// No description provided for @homeContinueSessionButton.
  ///
  /// In es, this message translates to:
  /// **'Continuar sesión'**
  String get homeContinueSessionButton;

  /// No description provided for @homeSessionDone.
  ///
  /// In es, this message translates to:
  /// **'Hecha'**
  String get homeSessionDone;

  /// No description provided for @homeRestDayTitle.
  ///
  /// In es, this message translates to:
  /// **'Descanso'**
  String get homeRestDayTitle;

  /// No description provided for @homeRestDayToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy no tienes entrenamiento asignado.'**
  String get homeRestDayToday;

  /// No description provided for @homeRestDayOther.
  ///
  /// In es, this message translates to:
  /// **'Este día no tienes entrenamiento asignado.'**
  String get homeRestDayOther;

  /// No description provided for @homeFactSessions.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 sesión} other{{count} sesiones}}'**
  String homeFactSessions(int count);

  /// No description provided for @homeFactExercises.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 ejercicio} other{{count} ejercicios}}'**
  String homeFactExercises(int count);

  /// No description provided for @homeFactExercisesProgress.
  ///
  /// In es, this message translates to:
  /// **'{total, plural, =1{{done} de 1 ejercicio} other{{done} de {total} ejercicios}}'**
  String homeFactExercisesProgress(int done, int total);

  /// No description provided for @homeFactDuration.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min aprox.'**
  String homeFactDuration(int minutes);

  /// No description provided for @homeFactSets.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 serie} other{{count} series}}'**
  String homeFactSets(int count);

  /// No description provided for @homeProgramWeek.
  ///
  /// In es, this message translates to:
  /// **'semana {week}'**
  String homeProgramWeek(int week);

  /// No description provided for @homeProgramWeekDay.
  ///
  /// In es, this message translates to:
  /// **'semana {week}, día {day}'**
  String homeProgramWeekDay(int week, int day);

  /// No description provided for @homeMealsDone.
  ///
  /// In es, this message translates to:
  /// **'{total, plural, =1{{done} de 1 comida hecha} other{{done} de {total} comidas hechas}}'**
  String homeMealsDone(int done, int total);

  /// No description provided for @homeRemainingKcal.
  ///
  /// In es, this message translates to:
  /// **'{kcal} kcal restantes'**
  String homeRemainingKcal(String kcal);

  /// No description provided for @homeStreakRow.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Sin racha activa} =1{Racha de 1 día} other{Racha de {count} días}}'**
  String homeStreakRow(int count);

  /// No description provided for @homeWeekDayToday.
  ///
  /// In es, this message translates to:
  /// **'{day}, hoy'**
  String homeWeekDayToday(String day);

  /// No description provided for @homeWeekDayDone.
  ///
  /// In es, this message translates to:
  /// **'{day}, sesión hecha'**
  String homeWeekDayDone(String day);

  /// No description provided for @homeWeekDayPending.
  ///
  /// In es, this message translates to:
  /// **'{day}, sesión pendiente'**
  String homeWeekDayPending(String day);

  /// No description provided for @homeWeekDayMissed.
  ///
  /// In es, this message translates to:
  /// **'{day}, sesión no hecha'**
  String homeWeekDayMissed(String day);

  /// No description provided for @trainingDetailExercises.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 ejercicio} other{{count} ejercicios}}'**
  String trainingDetailExercises(int count);

  /// No description provided for @trainingDetailSets.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 serie} other{{count} series}}'**
  String trainingDetailSets(int count);

  /// No description provided for @trainingDetailDuration.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min aprox.'**
  String trainingDetailDuration(int minutes);

  /// No description provided for @trainingDetailPrescription.
  ///
  /// In es, this message translates to:
  /// **'{sets} × {prescription} · descanso {rest} s'**
  String trainingDetailPrescription(int sets, String prescription, int rest);

  /// No description provided for @trainingDetailPrevious.
  ///
  /// In es, this message translates to:
  /// **'Anterior {value}'**
  String trainingDetailPrevious(String value);

  /// No description provided for @trainingDetailReps.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 rep.} other{{count} reps.}}'**
  String trainingDetailReps(int count);

  /// No description provided for @trainingDetailSetsProgress.
  ///
  /// In es, this message translates to:
  /// **'{total, plural, =1{{done} de 1 serie} other{{done} de {total} series}}'**
  String trainingDetailSetsProgress(int done, int total);

  /// No description provided for @trainingDetailToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy {value}'**
  String trainingDetailToday(String value);

  /// No description provided for @trainingDetailNextAction.
  ///
  /// In es, this message translates to:
  /// **'Siguiente: {name}'**
  String trainingDetailNextAction(String name);

  /// No description provided for @trainingDetailCompletionSavedPending.
  ///
  /// In es, this message translates to:
  /// **'Guardada en este móvil · pendiente de sincronizar'**
  String get trainingDetailCompletionSavedPending;

  /// No description provided for @trainingDetailExercisesDone.
  ///
  /// In es, this message translates to:
  /// **'{total, plural, =1{{done} de 1 hecho} other{{done} de {total} hechos}}'**
  String trainingDetailExercisesDone(int done, int total);

  /// No description provided for @trainingDetailProgressKicker.
  ///
  /// In es, this message translates to:
  /// **'Progreso de la sesión'**
  String get trainingDetailProgressKicker;

  /// No description provided for @trainingDetailSetsDoneOf.
  ///
  /// In es, this message translates to:
  /// **'{done} de {total}'**
  String trainingDetailSetsDoneOf(int done, int total);

  /// No description provided for @trainingDetailSetsDoneLabel.
  ///
  /// In es, this message translates to:
  /// **'series hechas'**
  String get trainingDetailSetsDoneLabel;

  /// No description provided for @activeExerciseCloseA11y.
  ///
  /// In es, this message translates to:
  /// **'Cerrar ejercicio'**
  String get activeExerciseCloseA11y;

  /// No description provided for @activeExercisePosition.
  ///
  /// In es, this message translates to:
  /// **'Ejercicio {current} de {total}'**
  String activeExercisePosition(int current, int total);

  /// No description provided for @activeExerciseSetOf.
  ///
  /// In es, this message translates to:
  /// **'Serie {current} de {total}'**
  String activeExerciseSetOf(int current, int total);

  /// No description provided for @activeExerciseUnitReps.
  ///
  /// In es, this message translates to:
  /// **'reps'**
  String get activeExerciseUnitReps;

  /// No description provided for @activeExerciseUnitSeconds.
  ///
  /// In es, this message translates to:
  /// **'s'**
  String get activeExerciseUnitSeconds;

  /// No description provided for @activeExerciseUnitMinutes.
  ///
  /// In es, this message translates to:
  /// **'min'**
  String get activeExerciseUnitMinutes;

  /// No description provided for @activeExerciseRir.
  ///
  /// In es, this message translates to:
  /// **'RIR {rir}'**
  String activeExerciseRir(int rir);

  /// No description provided for @activeExerciseTargetA11y.
  ///
  /// In es, this message translates to:
  /// **'Objetivo: {target}'**
  String activeExerciseTargetA11y(String target);

  /// No description provided for @activeExerciseYourWeight.
  ///
  /// In es, this message translates to:
  /// **'Tu peso: {weight}'**
  String activeExerciseYourWeight(String weight);

  /// No description provided for @activeExerciseNoPrevious.
  ///
  /// In es, this message translates to:
  /// **'Sin datos anteriores'**
  String get activeExerciseNoPrevious;

  /// No description provided for @activeExerciseRestAfter.
  ///
  /// In es, this message translates to:
  /// **'Descanso después: {seconds} s'**
  String activeExerciseRestAfter(int seconds);

  /// No description provided for @activeExerciseSetsA11y.
  ///
  /// In es, this message translates to:
  /// **'Series del ejercicio'**
  String get activeExerciseSetsA11y;

  /// No description provided for @activeExerciseSetNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora'**
  String get activeExerciseSetNow;

  /// No description provided for @activeExerciseSetDone.
  ///
  /// In es, this message translates to:
  /// **'Hecha'**
  String get activeExerciseSetDone;

  /// No description provided for @activeExerciseSetChipDoneA11y.
  ///
  /// In es, this message translates to:
  /// **'Serie {setNumber}: {value}, guardada en este móvil'**
  String activeExerciseSetChipDoneA11y(int setNumber, String value);

  /// No description provided for @activeExerciseSetChipNowA11y.
  ///
  /// In es, this message translates to:
  /// **'Serie {setNumber}, ahora'**
  String activeExerciseSetChipNowA11y(int setNumber);

  /// No description provided for @activeExerciseSetChipNextA11y.
  ///
  /// In es, this message translates to:
  /// **'Serie {setNumber}, {value}'**
  String activeExerciseSetChipNextA11y(int setNumber, String value);

  /// No description provided for @activeExerciseSetSavedStatus.
  ///
  /// In es, this message translates to:
  /// **'Serie {setNumber} · {status}'**
  String activeExerciseSetSavedStatus(int setNumber, String status);

  /// No description provided for @activeExerciseTechniqueButton.
  ///
  /// In es, this message translates to:
  /// **'Ver técnica'**
  String get activeExerciseTechniqueButton;

  /// No description provided for @activeExerciseLogSetButton.
  ///
  /// In es, this message translates to:
  /// **'Registrar serie'**
  String get activeExerciseLogSetButton;

  /// No description provided for @activeExerciseRestNext.
  ///
  /// In es, this message translates to:
  /// **'Siguiente: Serie {setNumber} · {target}'**
  String activeExerciseRestNext(int setNumber, String target);

  /// No description provided for @activeExerciseRestNextWithWeight.
  ///
  /// In es, this message translates to:
  /// **'Siguiente: Serie {setNumber} · {target} · tu peso {weight}'**
  String activeExerciseRestNextWithWeight(
    int setNumber,
    String target,
    String weight,
  );

  /// No description provided for @activeExerciseRestExtend.
  ///
  /// In es, this message translates to:
  /// **'+{seconds} s'**
  String activeExerciseRestExtend(int seconds);

  /// No description provided for @activeExerciseRestSkip.
  ///
  /// In es, this message translates to:
  /// **'Saltar descanso'**
  String get activeExerciseRestSkip;

  /// No description provided for @activeExerciseRestRemainingA11y.
  ///
  /// In es, this message translates to:
  /// **'Descanso, quedan {time}'**
  String activeExerciseRestRemainingA11y(String time);

  /// No description provided for @activeExerciseRestTenSecondsA11y.
  ///
  /// In es, this message translates to:
  /// **'Quedan 10 segundos de descanso'**
  String get activeExerciseRestTenSecondsA11y;

  /// No description provided for @activeExerciseRestFinishedA11y.
  ///
  /// In es, this message translates to:
  /// **'Descanso terminado'**
  String get activeExerciseRestFinishedA11y;

  /// No description provided for @setSheetObjective.
  ///
  /// In es, this message translates to:
  /// **'Objetivo {objective}'**
  String setSheetObjective(String objective);

  /// No description provided for @setSheetObjectiveWithPrevious.
  ///
  /// In es, this message translates to:
  /// **'Objetivo {objective} — Anterior {previous}'**
  String setSheetObjectiveWithPrevious(String objective, String previous);

  /// No description provided for @setSheetSameAsPrevious.
  ///
  /// In es, this message translates to:
  /// **'Igual que la anterior · {value}'**
  String setSheetSameAsPrevious(String value);

  /// No description provided for @setSheetRepsLabel.
  ///
  /// In es, this message translates to:
  /// **'Repeticiones'**
  String get setSheetRepsLabel;

  /// No description provided for @setSheetSecondsLabel.
  ///
  /// In es, this message translates to:
  /// **'Segundos'**
  String get setSheetSecondsLabel;

  /// No description provided for @setSheetWeightLabel.
  ///
  /// In es, this message translates to:
  /// **'Peso'**
  String get setSheetWeightLabel;

  /// No description provided for @setSheetWeightKgA11y.
  ///
  /// In es, this message translates to:
  /// **'Peso en kilos'**
  String get setSheetWeightKgA11y;

  /// No description provided for @setSheetWeightLbA11y.
  ///
  /// In es, this message translates to:
  /// **'Peso en libras'**
  String get setSheetWeightLbA11y;

  /// No description provided for @setSheetWeightHint.
  ///
  /// In es, this message translates to:
  /// **'pasos de {step} · toca la cifra para escribir'**
  String setSheetWeightHint(String step);

  /// No description provided for @setSheetRirLabel.
  ///
  /// In es, this message translates to:
  /// **'RIR'**
  String get setSheetRirLabel;

  /// No description provided for @setSheetRirChipA11y.
  ///
  /// In es, this message translates to:
  /// **'RIR {value}'**
  String setSheetRirChipA11y(int value);

  /// No description provided for @setSheetRirFivePlusA11y.
  ///
  /// In es, this message translates to:
  /// **'RIR 5 o más'**
  String get setSheetRirFivePlusA11y;

  /// No description provided for @setSheetRepsDecrement.
  ///
  /// In es, this message translates to:
  /// **'Una repetición menos'**
  String get setSheetRepsDecrement;

  /// No description provided for @setSheetRepsIncrement.
  ///
  /// In es, this message translates to:
  /// **'Una repetición más'**
  String get setSheetRepsIncrement;

  /// No description provided for @setSheetSecondsDecrement.
  ///
  /// In es, this message translates to:
  /// **'{step} segundos menos'**
  String setSheetSecondsDecrement(int step);

  /// No description provided for @setSheetSecondsIncrement.
  ///
  /// In es, this message translates to:
  /// **'{step} segundos más'**
  String setSheetSecondsIncrement(int step);

  /// No description provided for @setSheetMinutesDecrement.
  ///
  /// In es, this message translates to:
  /// **'Un minuto menos'**
  String get setSheetMinutesDecrement;

  /// No description provided for @setSheetMinutesIncrement.
  ///
  /// In es, this message translates to:
  /// **'Un minuto más'**
  String get setSheetMinutesIncrement;

  /// No description provided for @setSheetWeightDecrement.
  ///
  /// In es, this message translates to:
  /// **'Restar {step}'**
  String setSheetWeightDecrement(String step);

  /// No description provided for @setSheetWeightIncrement.
  ///
  /// In es, this message translates to:
  /// **'Sumar {step}'**
  String setSheetWeightIncrement(String step);

  /// No description provided for @setSheetSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar serie'**
  String get setSheetSave;

  /// No description provided for @setInputNotANumber.
  ///
  /// In es, this message translates to:
  /// **'No entiendo «{value}». Escribe un número, por ejemplo {example}'**
  String setInputNotANumber(String value, String example);

  /// No description provided for @setInputWeightAmbiguous.
  ///
  /// In es, this message translates to:
  /// **'«{value}» es ambiguo. Usa una sola coma decimal, por ejemplo {example}'**
  String setInputWeightAmbiguous(String value, String example);

  /// No description provided for @setInputTooManyDecimals.
  ///
  /// In es, this message translates to:
  /// **'Como máximo dos decimales, por ejemplo {example}'**
  String setInputTooManyDecimals(String example);

  /// No description provided for @setInputNotInteger.
  ///
  /// In es, this message translates to:
  /// **'Tiene que ser un número entero, por ejemplo {example}'**
  String setInputNotInteger(String example);

  /// No description provided for @setInputAboveMax.
  ///
  /// In es, this message translates to:
  /// **'Máximo {max}'**
  String setInputAboveMax(String max);

  /// No description provided for @circuitCloseA11y.
  ///
  /// In es, this message translates to:
  /// **'Cerrar circuito'**
  String get circuitCloseA11y;

  /// No description provided for @circuitRoundOf.
  ///
  /// In es, this message translates to:
  /// **'Ronda {current} de {total}'**
  String circuitRoundOf(int current, int total);

  /// No description provided for @exomStepOf.
  ///
  /// In es, this message translates to:
  /// **'Paso {step} de {total}'**
  String exomStepOf(int step, int total);

  /// No description provided for @exomChartSummary.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Sin datos} =1{1 punto, último valor {last}} other{{count} puntos, último valor {last}}}'**
  String exomChartSummary(int count, String last);

  /// No description provided for @circuitThisRound.
  ///
  /// In es, this message translates to:
  /// **'Esta ronda'**
  String get circuitThisRound;

  /// No description provided for @circuitNotLogged.
  ///
  /// In es, this message translates to:
  /// **'Sin registrar'**
  String get circuitNotLogged;

  /// No description provided for @circuitRowDoneA11y.
  ///
  /// In es, this message translates to:
  /// **'{name}: {value}, guardada en este móvil'**
  String circuitRowDoneA11y(String name, String value);

  /// No description provided for @circuitRowNotLoggedA11y.
  ///
  /// In es, this message translates to:
  /// **'{name}: sin registrar'**
  String circuitRowNotLoggedA11y(String name);

  /// No description provided for @circuitRowNowA11y.
  ///
  /// In es, this message translates to:
  /// **'{name}: ahora'**
  String circuitRowNowA11y(String name);

  /// No description provided for @circuitRowNowWithTargetA11y.
  ///
  /// In es, this message translates to:
  /// **'{name}: ahora, {target}'**
  String circuitRowNowWithTargetA11y(String name, String target);

  /// No description provided for @circuitRowNextA11y.
  ///
  /// In es, this message translates to:
  /// **'{name}: después, {target}'**
  String circuitRowNextA11y(String name, String target);

  /// No description provided for @circuitRowLaterA11y.
  ///
  /// In es, this message translates to:
  /// **'{name}: después'**
  String circuitRowLaterA11y(String name);

  /// No description provided for @circuitRoundRestAfter.
  ///
  /// In es, this message translates to:
  /// **'Descanso de ronda después: {seconds} s'**
  String circuitRoundRestAfter(int seconds);

  /// No description provided for @circuitEndsAfter.
  ///
  /// In es, this message translates to:
  /// **'Al terminar: fin del circuito'**
  String get circuitEndsAfter;

  /// No description provided for @circuitFinalRestTitle.
  ///
  /// In es, this message translates to:
  /// **'Último descanso'**
  String get circuitFinalRestTitle;

  /// No description provided for @circuitRoundDone.
  ///
  /// In es, this message translates to:
  /// **'Ronda {round} hecha'**
  String circuitRoundDone(int round);

  /// No description provided for @circuitNextExercise.
  ///
  /// In es, this message translates to:
  /// **'Siguiente: {name} · {target}'**
  String circuitNextExercise(String name, String target);

  /// No description provided for @circuitNextExerciseWithWeight.
  ///
  /// In es, this message translates to:
  /// **'Siguiente: {name} · {target} · tu peso {weight}'**
  String circuitNextExerciseWithWeight(
    String name,
    String target,
    String weight,
  );

  /// No description provided for @circuitNextRound.
  ///
  /// In es, this message translates to:
  /// **'Siguiente: Ronda {round} · {name}'**
  String circuitNextRound(int round, String name);

  /// No description provided for @circuitAfterRestEnd.
  ///
  /// In es, this message translates to:
  /// **'Después: fin del circuito'**
  String get circuitAfterRestEnd;

  /// No description provided for @circuitFinishButton.
  ///
  /// In es, this message translates to:
  /// **'Terminar circuito'**
  String get circuitFinishButton;

  /// No description provided for @circuitReadyTitle.
  ///
  /// In es, this message translates to:
  /// **'Todas las rondas hechas'**
  String get circuitReadyTitle;

  /// No description provided for @circuitSheetTitle.
  ///
  /// In es, this message translates to:
  /// **'{name} · Ronda {round}'**
  String circuitSheetTitle(String name, int round);

  /// No description provided for @circuitSavedStatus.
  ///
  /// In es, this message translates to:
  /// **'{name}, ronda {round} · {status}'**
  String circuitSavedStatus(String name, int round, String status);

  /// No description provided for @circuitStepExercise.
  ///
  /// In es, this message translates to:
  /// **'{name}.'**
  String circuitStepExercise(String name);

  /// No description provided for @circuitStepPosition.
  ///
  /// In es, this message translates to:
  /// **'Ejercicio {current} de {total}.'**
  String circuitStepPosition(int current, int total);

  /// No description provided for @circuitTargetLabel.
  ///
  /// In es, this message translates to:
  /// **'Objetivo'**
  String get circuitTargetLabel;

  /// No description provided for @circuitTargetLabelWithRir.
  ///
  /// In es, this message translates to:
  /// **'Objetivo · RIR {rir}'**
  String circuitTargetLabelWithRir(int rir);

  /// No description provided for @exerciseLastTimeLabel.
  ///
  /// In es, this message translates to:
  /// **'Última vez'**
  String get exerciseLastTimeLabel;

  /// No description provided for @circuitRoundLogged.
  ///
  /// In es, this message translates to:
  /// **'{total, plural, =1{{done} de 1 registrado} other{{done} de {total} registrados}}'**
  String circuitRoundLogged(int done, int total);

  /// No description provided for @circuitRowLater.
  ///
  /// In es, this message translates to:
  /// **'Después'**
  String get circuitRowLater;

  /// No description provided for @progressTitle.
  ///
  /// In es, this message translates to:
  /// **'Progreso'**
  String get progressTitle;

  /// No description provided for @progressSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Peso, medidas y fotos'**
  String get progressSubtitle;

  /// No description provided for @progressHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Mira atrás.'**
  String get progressHeadlineFirst;

  /// No description provided for @progressHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'Sigue adelante.'**
  String get progressHeadlineSecond;

  /// No description provided for @progressLatestMeasures.
  ///
  /// In es, this message translates to:
  /// **'Últimas medidas'**
  String get progressLatestMeasures;

  /// No description provided for @progressAddMeasure.
  ///
  /// In es, this message translates to:
  /// **'Añadir medida'**
  String get progressAddMeasure;

  /// No description provided for @progressOnDate.
  ///
  /// In es, this message translates to:
  /// **'el {date}'**
  String progressOnDate(String date);

  /// No description provided for @progressDeltaLess.
  ///
  /// In es, this message translates to:
  /// **'{amount} menos en {period}'**
  String progressDeltaLess(String amount, String period);

  /// No description provided for @progressDeltaMore.
  ///
  /// In es, this message translates to:
  /// **'{amount} más en {period}'**
  String progressDeltaMore(String amount, String period);

  /// No description provided for @progressDeltaSame.
  ///
  /// In es, this message translates to:
  /// **'Sin cambios en {period}'**
  String progressDeltaSame(String period);

  /// No description provided for @progressPeriodWeeks.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 semana} other{{count} semanas}}'**
  String progressPeriodWeeks(int count);

  /// No description provided for @progressPeriodDays.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 día} other{{count} días}}'**
  String progressPeriodDays(int count);

  /// No description provided for @progressChartSemantics.
  ///
  /// In es, this message translates to:
  /// **'Peso del {from} al {to}: de {start} a {end}'**
  String progressChartSemantics(
    String from,
    String to,
    String start,
    String end,
  );

  /// No description provided for @progressChartEmpty.
  ///
  /// In es, this message translates to:
  /// **'Registra al menos dos pesos para ver la gráfica.'**
  String get progressChartEmpty;

  /// No description provided for @progressWeightEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no has registrado tu peso.'**
  String get progressWeightEmpty;

  /// No description provided for @progressMeasuresEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay medidas registradas.'**
  String get progressMeasuresEmpty;

  /// No description provided for @progressMeasureSide.
  ///
  /// In es, this message translates to:
  /// **'{measure} · {side}'**
  String progressMeasureSide(String measure, String side);

  /// No description provided for @progressLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando tu progreso'**
  String get progressLoading;

  /// No description provided for @progressHistoryError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar tu progreso.'**
  String get progressHistoryError;

  /// No description provided for @progressHistoryOffline.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Conéctate para ver tu progreso.'**
  String get progressHistoryOffline;

  /// No description provided for @progressCachedBanner.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión · datos guardados'**
  String get progressCachedBanner;

  /// No description provided for @progressLatestUnavailableOffline.
  ///
  /// In es, this message translates to:
  /// **'Las medidas de tu último registro no están disponibles sin conexión.'**
  String get progressLatestUnavailableOffline;

  /// No description provided for @progressLatestUnavailableError.
  ///
  /// In es, this message translates to:
  /// **'No se han podido cargar las medidas de tu último registro.'**
  String get progressLatestUnavailableError;

  /// No description provided for @noticesScreenTitle.
  ///
  /// In es, this message translates to:
  /// **'Avisos'**
  String get noticesScreenTitle;

  /// No description provided for @noticesEmptyFirst.
  ///
  /// In es, this message translates to:
  /// **'Todo'**
  String get noticesEmptyFirst;

  /// No description provided for @noticesEmptySecond.
  ///
  /// In es, this message translates to:
  /// **'al día.'**
  String get noticesEmptySecond;

  /// No description provided for @noticeTimeNow.
  ///
  /// In es, this message translates to:
  /// **'ahora'**
  String get noticeTimeNow;

  /// No description provided for @noticeTimeMinutes.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min'**
  String noticeTimeMinutes(int minutes);

  /// No description provided for @noticeTimeHours.
  ///
  /// In es, this message translates to:
  /// **'{hours} h'**
  String noticeTimeHours(int hours);

  /// No description provided for @noticeTimeDays.
  ///
  /// In es, this message translates to:
  /// **'{days} d'**
  String noticeTimeDays(int days);

  /// No description provided for @noticesUnreadHero.
  ///
  /// In es, this message translates to:
  /// **'sin leer'**
  String get noticesUnreadHero;

  /// No description provided for @noticesAllCaughtUp.
  ///
  /// In es, this message translates to:
  /// **'Todo al día'**
  String get noticesAllCaughtUp;

  /// No description provided for @noticesGroupToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get noticesGroupToday;

  /// No description provided for @noticesGroupThisWeek.
  ///
  /// In es, this message translates to:
  /// **'Esta semana'**
  String get noticesGroupThisWeek;

  /// No description provided for @noticesGroupEarlier.
  ///
  /// In es, this message translates to:
  /// **'Anteriores'**
  String get noticesGroupEarlier;

  /// No description provided for @videoPlayerPause.
  ///
  /// In es, this message translates to:
  /// **'Pausar'**
  String get videoPlayerPause;

  /// No description provided for @videoPlayerPlay.
  ///
  /// In es, this message translates to:
  /// **'Reproducir'**
  String get videoPlayerPlay;

  /// No description provided for @videoPlayerProgress.
  ///
  /// In es, this message translates to:
  /// **'Progreso del vídeo'**
  String get videoPlayerProgress;

  /// No description provided for @videoPlayerRewind5.
  ///
  /// In es, this message translates to:
  /// **'Retroceder 5 s'**
  String get videoPlayerRewind5;

  /// No description provided for @videoPlayerForward5.
  ///
  /// In es, this message translates to:
  /// **'Avanzar 5 s'**
  String get videoPlayerForward5;

  /// No description provided for @calendarMonthTitleLabel.
  ///
  /// In es, this message translates to:
  /// **'{month}, elegir mes y año'**
  String calendarMonthTitleLabel(String month);

  /// No description provided for @calendarHeroTrainingFirst.
  ///
  /// In es, this message translates to:
  /// **'Tu mes,'**
  String get calendarHeroTrainingFirst;

  /// No description provided for @calendarHeroTrainingSecond.
  ///
  /// In es, this message translates to:
  /// **'organizado.'**
  String get calendarHeroTrainingSecond;

  /// No description provided for @calendarHeroTrainingFoot.
  ///
  /// In es, this message translates to:
  /// **'sesiones hechas'**
  String get calendarHeroTrainingFoot;

  /// No description provided for @calendarHeroDietFirst.
  ///
  /// In es, this message translates to:
  /// **'Tu comida.'**
  String get calendarHeroDietFirst;

  /// No description provided for @calendarHeroDietSecond.
  ///
  /// In es, this message translates to:
  /// **'Sin improvisar.'**
  String get calendarHeroDietSecond;

  /// No description provided for @calendarHeroDietFoot.
  ///
  /// In es, this message translates to:
  /// **'comidas esta semana'**
  String get calendarHeroDietFoot;

  /// No description provided for @calendarHeroNoSessions.
  ///
  /// In es, this message translates to:
  /// **'sesiones'**
  String get calendarHeroNoSessions;

  /// No description provided for @calendarHeroNoSessionsFoot.
  ///
  /// In es, this message translates to:
  /// **'{year} · sin sesiones programadas'**
  String calendarHeroNoSessionsFoot(String year);

  /// No description provided for @calendarWeekTrainings.
  ///
  /// In es, this message translates to:
  /// **'{done} de {total} entrenos esta semana'**
  String calendarWeekTrainings(String done, String total);

  /// No description provided for @calendarEmptyMonthFirst.
  ///
  /// In es, this message translates to:
  /// **'Sin actividades'**
  String get calendarEmptyMonthFirst;

  /// No description provided for @calendarEmptyMonthSecond.
  ///
  /// In es, this message translates to:
  /// **'este mes.'**
  String get calendarEmptyMonthSecond;

  /// No description provided for @calendarOfflineFirst.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión.'**
  String get calendarOfflineFirst;

  /// No description provided for @calendarOfflineSecond.
  ///
  /// In es, this message translates to:
  /// **'No se ha perdido nada.'**
  String get calendarOfflineSecond;

  /// No description provided for @calendarOfflineMessage.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. No se ha podido cargar el calendario.'**
  String get calendarOfflineMessage;

  /// No description provided for @calendarRestDayFacts.
  ///
  /// In es, this message translates to:
  /// **'Sin entrenamiento asignado.'**
  String get calendarRestDayFacts;

  /// No description provided for @calendarActiveChallengesToday.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{{figure} reto activo hoy} other{{figure} retos activos hoy}}'**
  String calendarActiveChallengesToday(int count, String figure);

  /// No description provided for @calendarDayWithChallenge.
  ///
  /// In es, this message translates to:
  /// **'{day}, con reto'**
  String calendarDayWithChallenge(String day);

  /// No description provided for @calendarDayDietDone.
  ///
  /// In es, this message translates to:
  /// **'{day}, dieta completada'**
  String calendarDayDietDone(String day);

  /// No description provided for @calendarDayDietPending.
  ///
  /// In es, this message translates to:
  /// **'{day}, dieta pendiente'**
  String calendarDayDietPending(String day);

  /// No description provided for @calendarDayDietMissed.
  ///
  /// In es, this message translates to:
  /// **'{day}, dieta sin completar'**
  String calendarDayDietMissed(String day);

  /// No description provided for @calendarMonthPickerKicker.
  ///
  /// In es, this message translates to:
  /// **'Elige mes y año'**
  String get calendarMonthPickerKicker;

  /// No description provided for @calendarPreviousYear.
  ///
  /// In es, this message translates to:
  /// **'Año anterior'**
  String get calendarPreviousYear;

  /// No description provided for @calendarNextYear.
  ///
  /// In es, this message translates to:
  /// **'Año siguiente'**
  String get calendarNextYear;

  /// No description provided for @calendarExportPeriodKicker.
  ///
  /// In es, this message translates to:
  /// **'Dietas · calendario'**
  String get calendarExportPeriodKicker;

  /// No description provided for @calendarExportPeriodFirst.
  ///
  /// In es, this message translates to:
  /// **'Elige'**
  String get calendarExportPeriodFirst;

  /// No description provided for @calendarExportPeriodSecond.
  ///
  /// In es, this message translates to:
  /// **'un periodo'**
  String get calendarExportPeriodSecond;

  /// No description provided for @calendarExportFormatFirst.
  ///
  /// In es, this message translates to:
  /// **'¿Qué quieres'**
  String get calendarExportFormatFirst;

  /// No description provided for @calendarExportFormatSecond.
  ///
  /// In es, this message translates to:
  /// **'exportar?'**
  String get calendarExportFormatSecond;

  /// No description provided for @dietHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Tu comida.'**
  String get dietHeadlineFirst;

  /// No description provided for @dietHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'Sin improvisar.'**
  String get dietHeadlineSecond;

  /// No description provided for @dietEmptyHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Sin plan.'**
  String get dietEmptyHeadlineFirst;

  /// No description provided for @dietEmptyHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'Por ahora.'**
  String get dietEmptyHeadlineSecond;

  /// No description provided for @dietLeftKicker.
  ///
  /// In es, this message translates to:
  /// **'Te quedan'**
  String get dietLeftKicker;

  /// No description provided for @dietOfTotalKcal.
  ///
  /// In es, this message translates to:
  /// **'de {total} kcal'**
  String dietOfTotalKcal(int total);

  /// No description provided for @mealOptionsLabel.
  ///
  /// In es, this message translates to:
  /// **'Opciones'**
  String get mealOptionsLabel;

  /// No description provided for @mealDoneStatus.
  ///
  /// In es, this message translates to:
  /// **'Hecha'**
  String get mealDoneStatus;

  /// No description provided for @feedbackUploadPreparingBody.
  ///
  /// In es, this message translates to:
  /// **'Se guarda en este móvil antes de enviarse.'**
  String get feedbackUploadPreparingBody;

  /// No description provided for @feedbackUploadProcessingTitle.
  ///
  /// In es, this message translates to:
  /// **'Enviado · procesando en EXOM'**
  String get feedbackUploadProcessingTitle;

  /// No description provided for @feedbackUploadProcessingBody.
  ///
  /// In es, this message translates to:
  /// **'Aún no está confirmada. Puedes cerrar la app.'**
  String get feedbackUploadProcessingBody;

  /// No description provided for @feedbackUploadConfirmedBody.
  ///
  /// In es, this message translates to:
  /// **'Tu entrenador ya puede revisarlo.'**
  String get feedbackUploadConfirmedBody;

  /// No description provided for @feedbackUploadFailedTitle.
  ///
  /// In es, this message translates to:
  /// **'No se pudo enviar.'**
  String get feedbackUploadFailedTitle;

  /// No description provided for @feedbackUploadKeptBody.
  ///
  /// In es, this message translates to:
  /// **'Tu evidencia se conserva en este móvil.'**
  String get feedbackUploadKeptBody;

  /// No description provided for @feedbackUploadOfflineBody.
  ///
  /// In es, this message translates to:
  /// **'Se enviará cuando vuelva la conexión.'**
  String get feedbackUploadOfflineBody;

  /// No description provided for @feedbackEmptyFirst.
  ///
  /// In es, this message translates to:
  /// **'Sin feedback.'**
  String get feedbackEmptyFirst;

  /// No description provided for @feedbackEmptySecond.
  ///
  /// In es, this message translates to:
  /// **'Todavía.'**
  String get feedbackEmptySecond;

  /// No description provided for @feedbackQuestionType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de evidencia'**
  String get feedbackQuestionType;

  /// No description provided for @feedbackQuestionFile.
  ///
  /// In es, this message translates to:
  /// **'Archivo'**
  String get feedbackQuestionFile;

  /// No description provided for @feedbackChooseFile.
  ///
  /// In es, this message translates to:
  /// **'Elegir archivo'**
  String get feedbackChooseFile;

  /// No description provided for @feedbackRemoveFile.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get feedbackRemoveFile;

  /// No description provided for @recapListHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Tu semana.'**
  String get recapListHeadlineFirst;

  /// No description provided for @recapListHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'También cuenta.'**
  String get recapListHeadlineSecond;

  /// No description provided for @recapListWeekSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Semana del {start} al {end}'**
  String recapListWeekSubtitle(String start, String end);

  /// No description provided for @recapListNewCommentsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{comentario nuevo de tu entrenador} other{comentarios nuevos de tu entrenador}}'**
  String recapListNewCommentsCount(int count);

  /// No description provided for @recapListNotRated.
  ///
  /// In es, this message translates to:
  /// **'Sin valorar'**
  String get recapListNotRated;

  /// No description provided for @coachNameMoi.
  ///
  /// In es, this message translates to:
  /// **'Moi'**
  String get coachNameMoi;

  /// No description provided for @recapListEmptyHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Sin recaps.'**
  String get recapListEmptyHeadlineFirst;

  /// No description provided for @recapListEmptyHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'Todavía.'**
  String get recapListEmptyHeadlineSecond;

  /// No description provided for @recapListEmptyCoachText.
  ///
  /// In es, this message translates to:
  /// **'Cuéntame cómo ha ido tu semana en cinco pasos.'**
  String get recapListEmptyCoachText;

  /// No description provided for @recapListErrorHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Algo ha fallado'**
  String get recapListErrorHeadlineFirst;

  /// No description provided for @recapListErrorHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'con el recap.'**
  String get recapListErrorHeadlineSecond;

  /// No description provided for @recapStepKicker.
  ///
  /// In es, this message translates to:
  /// **'Recap semanal · paso {step} de {total}'**
  String recapStepKicker(int step, int total);

  /// No description provided for @recapStepTrainingFirst.
  ///
  /// In es, this message translates to:
  /// **'Entreno.'**
  String get recapStepTrainingFirst;

  /// No description provided for @recapStepTrainingSecond.
  ///
  /// In es, this message translates to:
  /// **'Cómo ha ido.'**
  String get recapStepTrainingSecond;

  /// No description provided for @recapStepNutritionFirst.
  ///
  /// In es, this message translates to:
  /// **'Nutrición.'**
  String get recapStepNutritionFirst;

  /// No description provided for @recapStepNutritionSecond.
  ///
  /// In es, this message translates to:
  /// **'Tu semana cuenta.'**
  String get recapStepNutritionSecond;

  /// No description provided for @recapStepRecoveryFirst.
  ///
  /// In es, this message translates to:
  /// **'Recuperación.'**
  String get recapStepRecoveryFirst;

  /// No description provided for @recapStepRecoverySecond.
  ///
  /// In es, this message translates to:
  /// **'Cómo estás.'**
  String get recapStepRecoverySecond;

  /// No description provided for @recapStepGeneralFirst.
  ///
  /// In es, this message translates to:
  /// **'General.'**
  String get recapStepGeneralFirst;

  /// No description provided for @recapStepGeneralSecond.
  ///
  /// In es, this message translates to:
  /// **'Cómo te sientes.'**
  String get recapStepGeneralSecond;

  /// No description provided for @recapStepImprovementFirst.
  ///
  /// In es, this message translates to:
  /// **'Mejora.'**
  String get recapStepImprovementFirst;

  /// No description provided for @recapStepImprovementSecond.
  ///
  /// In es, this message translates to:
  /// **'Tu opinión cuenta.'**
  String get recapStepImprovementSecond;

  /// No description provided for @recapStepTrainingCoach.
  ///
  /// In es, this message translates to:
  /// **'Dime cómo han ido tus entrenos esta semana.'**
  String get recapStepTrainingCoach;

  /// No description provided for @recapStepNutritionCoach.
  ///
  /// In es, this message translates to:
  /// **'Cuéntame cómo has comido esta semana.'**
  String get recapStepNutritionCoach;

  /// No description provided for @recapStepRecoveryCoach.
  ///
  /// In es, this message translates to:
  /// **'Dime cómo has descansado y si has notado alguna molestia.'**
  String get recapStepRecoveryCoach;

  /// No description provided for @recapStepGeneralCoach.
  ///
  /// In es, this message translates to:
  /// **'Cuéntame cómo te has sentido en general esta semana.'**
  String get recapStepGeneralCoach;

  /// No description provided for @recapStepImprovementCoach.
  ///
  /// In es, this message translates to:
  /// **'Dime qué mejorarías del servicio y de la app.'**
  String get recapStepImprovementCoach;

  /// No description provided for @recapStartHeadlineFirst.
  ///
  /// In es, this message translates to:
  /// **'Tu semana.'**
  String get recapStartHeadlineFirst;

  /// No description provided for @recapStartHeadlineSecond.
  ///
  /// In es, this message translates to:
  /// **'En cinco pasos.'**
  String get recapStartHeadlineSecond;

  /// No description provided for @recapSaveDraft.
  ///
  /// In es, this message translates to:
  /// **'Guardar borrador'**
  String get recapSaveDraft;

  /// No description provided for @recapNextStep.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get recapNextStep;

  /// No description provided for @recapZonesCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{{count} zona} other{{count} zonas}}'**
  String recapZonesCount(int count);

  /// No description provided for @recapZonesMore.
  ///
  /// In es, this message translates to:
  /// **'+{count} más'**
  String recapZonesMore(int count);

  /// No description provided for @recapZonesNone.
  ///
  /// In es, this message translates to:
  /// **'Sin zonas marcadas'**
  String get recapZonesNone;

  /// No description provided for @recapZonesSemantics.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{{count} zona} other{{count} zonas}}: {zones}'**
  String recapZonesSemantics(int count, String zones);

  /// No description provided for @recapImprovement.
  ///
  /// In es, this message translates to:
  /// **'Mejora'**
  String get recapImprovement;

  /// No description provided for @recapSentKicker.
  ///
  /// In es, this message translates to:
  /// **'Cinco pasos completados'**
  String get recapSentKicker;

  /// No description provided for @recapSentTitleFirst.
  ///
  /// In es, this message translates to:
  /// **'Recap'**
  String get recapSentTitleFirst;

  /// No description provided for @recapSentTitleSecond.
  ///
  /// In es, this message translates to:
  /// **'enviado.'**
  String get recapSentTitleSecond;

  /// No description provided for @recapSentCoach.
  ///
  /// In es, this message translates to:
  /// **'Gracias por contármelo. Lo reviso y te dejo mi comentario en tu recap.'**
  String get recapSentCoach;

  /// No description provided for @recapBackToRecaps.
  ///
  /// In es, this message translates to:
  /// **'Volver a recaps'**
  String get recapBackToRecaps;

  /// No description provided for @recapSentClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get recapSentClose;

  /// No description provided for @trainingMilestoneTitle.
  ///
  /// In es, this message translates to:
  /// **'Sesión hecha.'**
  String get trainingMilestoneTitle;

  /// No description provided for @trainingMilestoneName.
  ///
  /// In es, this message translates to:
  /// **'{name}.'**
  String trainingMilestoneName(String name);

  /// No description provided for @trainingMilestoneBackHome.
  ///
  /// In es, this message translates to:
  /// **'Volver a Inicio'**
  String get trainingMilestoneBackHome;
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
