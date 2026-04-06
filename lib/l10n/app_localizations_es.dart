// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTagline => 'Tu entrenador personal, siempre contigo';

  @override
  String get emailFieldLabel => 'Correo electrónico';

  @override
  String get emailValidationEmpty => 'Introduce tu correo electrónico';

  @override
  String get emailValidationInvalid => 'Correo electrónico no válido';

  @override
  String get passwordFieldLabel => 'Contraseña';

  @override
  String get passwordValidationEmpty => 'Introduce tu contraseña';

  @override
  String get passwordValidationLength =>
      'La contraseña debe tener al menos 8 caracteres';

  @override
  String get forgotPasswordButton => '¿Olvidaste tu contraseña?';

  @override
  String get emailFirstPrompt => 'Introduce tu email primero';

  @override
  String get passwordResetEmailSent =>
      'Email de recuperación enviado. Revisa tu bandeja de entrada.';

  @override
  String get passwordResetEmailFailed =>
      'No se pudo enviar el email. Verifica la dirección.';

  @override
  String get loginButton => 'Iniciar sesión';

  @override
  String get continueWithDivider => 'o continúa con';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get continueWithApple => 'Continuar con Apple';

  @override
  String get accountLockedTitle => 'Cuenta bloqueada';

  @override
  String get accountLockedMessage =>
      'Tu cuenta ha sido bloqueada temporalmente.\nContacta a tu entrenador para más información.';

  @override
  String get backToLoginButton => 'Volver al inicio de sesión';

  @override
  String get trialRegisterButton => 'Probar gratis 14 días';

  @override
  String get trialHeaderTitle => '14 días gratis';

  @override
  String get trialHeaderSubtitle => 'Prueba EXOM sin compromiso';

  @override
  String get trialFormName => 'Nombre';

  @override
  String get trialFormLastName => 'Apellidos';

  @override
  String get trialFormEmail => 'Email';

  @override
  String get trialFormPassword => 'Contraseña';

  @override
  String get trialCreateAccountButton => 'Crear cuenta de prueba';

  @override
  String get trialNoAccountPrompt => '¿No tienes cuenta?';

  @override
  String get welcomeOnboarding => '¡Bienvenido\na EXOM!';

  @override
  String get onboardingStepsMessage =>
      'Sigue estos pasos para comenzar tu experiencia.';

  @override
  String get completeProfileTitle => 'Completa tu perfil';

  @override
  String get completeProfileSubtitle =>
      'Añade tus datos para que el entrenador pueda personalizarte el plan.';

  @override
  String get waitForCoachTitle => 'Espera a tu entrenador';

  @override
  String get waitForCoachSubtitle =>
      'Te asignaremos un entrenador personal que diseñará tu rutina.';

  @override
  String get startTransformationTitle => 'Empieza tu transformación';

  @override
  String get startTransformationSubtitle =>
      'Sigue tu plan, registra tu progreso y alcanza tus objetivos.';

  @override
  String get completeProfileButton => 'Completar perfil';

  @override
  String get doItLaterButton => 'Hacerlo más tarde';

  @override
  String pageNotFoundError(String error) {
    return 'Página no encontrada: $error';
  }

  @override
  String get userDefaultName => 'Usuario';

  @override
  String get exomMemberLabel => 'Miembro EXOM';

  @override
  String get profileMenuItem => 'Perfil';

  @override
  String get challengesMenuItem => 'Retos';

  @override
  String get weeklyRecapMenuItem => 'Recap Semanal';

  @override
  String get feedbackMenuItem => 'Feedback';

  @override
  String get settingsMenuItem => 'Ajustes';

  @override
  String get helpMenuItem => 'Ayuda';

  @override
  String get logOutMenuItem => 'Cerrar Sesión';

  @override
  String get restDayTitle => 'Día de descanso';

  @override
  String get restDayMessage =>
      'No tienes entrenamiento asignado para hoy.\nAprovecha para recuperarte.';

  @override
  String get openCalendarButton => 'Ver calendario';

  @override
  String get todaysTrainingTitle => 'Entrenamiento de hoy';

  @override
  String get trainingUntitledLabel => 'Sin nombre';

  @override
  String get trainingCompletedLabel => 'Completado';

  @override
  String get viewTrainingButton => 'Ver entrenamiento';

  @override
  String get continueTrainingButton => 'Continuar';

  @override
  String get startTrainingButton => 'Comenzar';

  @override
  String get trainingStrength => 'Fuerza';

  @override
  String get trainingMobility => 'Flexibilidad';

  @override
  String get todaysDietTitle => 'Dieta de hoy';

  @override
  String get nutritionPlanDefault => 'Plan nutricional';

  @override
  String get nextMealLabel => 'Siguiente';

  @override
  String get nextMealButton => 'Siguiente comida';

  @override
  String get viewFullDietButton => 'Ver dieta completa';

  @override
  String get todayLabel => 'Hoy';

  @override
  String get tomorrowLabel => 'Mañana';

  @override
  String get dayAfterTomorrowLabel => 'Pasado mañana';

  @override
  String get yesterdayLabel => 'Ayer';

  @override
  String get twoDaysAgoLabel => 'Antes de ayer';

  @override
  String inDaysLabel(int diff) {
    return 'En $diff días';
  }

  @override
  String daysAgoLabel(int diff) {
    return 'Hace $diff días';
  }

  @override
  String get keepItUpSubtitle => '¡Sigue así!';

  @override
  String get sleepQualityGood => 'Calidad buena';

  @override
  String get sleepQualityFair => 'Calidad media';

  @override
  String get sleepQualityLow => 'Poco sueño';

  @override
  String get allTrainingsSection => 'Todos los entrenamientos';

  @override
  String get noTrainingsAvailable => 'No hay entrenamientos disponibles';

  @override
  String get askCoachForPlan =>
      'Contacta a tu entrenador para que te asigne un plan';

  @override
  String get noTrainingAssignedToday => 'No hay entrenamiento asignado hoy';

  @override
  String get noTrainingAssignedForDate =>
      'No hay entrenamiento asignado para esa fecha';

  @override
  String get enjoyRestDay => 'Disfruta tu día de descanso';

  @override
  String get noDietTodayMessage => 'No tienes dieta asignada hoy';

  @override
  String get noDietForDateMessage => 'No tienes dieta asignada para esa fecha';

  @override
  String get contactCoachForPlanMessage =>
      'Contacta a tu entrenador para que te asigne un plan nutricional';

  @override
  String get contactCoachButton => 'Contactar entrenador';

  @override
  String get mealsOfTheDayLabel => 'Comidas del día';

  @override
  String get todaysPlanLabel => 'Plan de hoy';

  @override
  String get planForLabel => 'Plan de';

  @override
  String get completedFeminine => 'Completada';

  @override
  String get openPlan => 'Ver plan';

  @override
  String get mealTypeBreakfast => 'Desayuno';

  @override
  String get mealTypeLunch => 'Almuerzo';

  @override
  String get mealTypeSnack => 'Snack';

  @override
  String get mealTypeDinner => 'Cena';

  @override
  String get richInLabel => 'Rico en';

  @override
  String get openRecipeButton => 'Ver receta en Google';

  @override
  String get recipeButton => 'Receta';

  @override
  String get mealCompletedButton => 'Completada';

  @override
  String get completeButton => 'Completar';

  @override
  String get markMealCompletedButton => 'Marcar como completada';

  @override
  String get markExerciseCompletedButton => 'Marcar como completado';

  @override
  String get exerciseCompletedButton => 'Ejercicio completado';

  @override
  String get nutritionalInfoTitle => 'Información nutricional';

  @override
  String get caloriesLabel => 'Calorías';

  @override
  String get proteinLabel => 'Proteína';

  @override
  String get carbsLabel => 'Carbos';

  @override
  String get fatsLabel => 'Grasas';

  @override
  String get ingredientsTitle => 'Ingredientes';

  @override
  String get calendarLoadError => 'Error al cargar el calendario';

  @override
  String get trainingsCompletedThisWeek => 'entrenos completados esta semana';

  @override
  String get mealsCompletedThisWeek => 'comidas completadas esta semana';

  @override
  String get noActivityAssigned => 'Sin actividad asignada';

  @override
  String get openDetail => 'Ver detalle';

  @override
  String get goToMonthButton => 'Ir al mes';

  @override
  String get warmUp => 'Calentamiento';

  @override
  String get cooldown => 'Enfriamiento';

  @override
  String get addQuickNoteOptional => 'Añadir nota rápida (Opcional)';

  @override
  String get completedExercisesLabel => 'ejercicios completados';

  @override
  String get workoutCompletedMessage => '¡Entrenamiento completado!';

  @override
  String get rest => 'descanso';

  @override
  String get sets => 'Series';

  @override
  String get repsOrTime => 'Reps/Dur.';

  @override
  String get restLabel => 'Descanso';

  @override
  String exerciseMetadata(int sets, String reps, int rest) {
    return '$sets series x $reps · Descanso ${rest}s';
  }

  @override
  String get description => 'Descripción';

  @override
  String get explanation => 'Explicación';

  @override
  String get technique => 'Técnica';

  @override
  String get commonMistakes => 'Errores comunes';

  @override
  String get feedbackSentSuccessfully => 'Feedback enviado correctamente';

  @override
  String get noFeedbackYet => 'Aún no has enviado ningún feedback';

  @override
  String get sendFeedback => 'Enviar feedback';

  @override
  String get fileUrlImageOrVideo => 'URL del archivo (imagen o vídeo)';

  @override
  String get urlIsRequired => 'La URL es obligatoria';

  @override
  String get additionalNotesOptional => 'Notas adicionales (opcional)';

  @override
  String get challengesTitle => 'Mis Retos';

  @override
  String get challengesSubtitle => 'Supera tus límites cada día';

  @override
  String get challengesLoadError => 'Error al cargar los retos';

  @override
  String get mainGoalSection => 'Objetivo principal';

  @override
  String get weeklyChallengesSection => 'Retos semanales';

  @override
  String get unlockedAchievementsSection => 'Logros desbloqueados';

  @override
  String get noActiveChallenges => 'Sin retos activos';

  @override
  String get noActiveChallengesMessage =>
      'Tu entrenador aún no te ha asignado retos. Empieza completando tus entrenamientos y comidas para desbloquear retos automáticos.';

  @override
  String get lockedAchievementsHint =>
      'Completa retos para desbloquear medallas';

  @override
  String get pendingChallengeLabel => 'Reto pendiente';

  @override
  String get challengeDeadlineLabel => 'Fecha límite';

  @override
  String get challengeUntilLabel => 'Hasta';

  @override
  String get helpCenter => 'Centro de ayuda';

  @override
  String get helpCenterDescription =>
      'Todo lo importante para usar EXOM en tu día a día: métricas, entrenamientos, dieta, modo offline y vías de contacto.';

  @override
  String get sendQuestionOrIssue => 'Enviar duda o incidencia';

  @override
  String get notificationsAndCache => 'Notificaciones y caché';

  @override
  String get supportAndLinks => 'Soporte y enlaces';

  @override
  String get supportCenter => 'Centro de soporte';

  @override
  String get supportCenterDescription =>
      'Abre la página externa de soporte y contacto de EXOM.';

  @override
  String get couldNotOpenSupportPage =>
      'No se pudo abrir la página de soporte.';

  @override
  String get emailSupportDescription =>
      'Abre tu cliente de correo con un email a soporte@exom.app.';

  @override
  String get couldNotOpenMailApp => 'No se pudo abrir la aplicación de correo.';

  @override
  String get frequentlyAskedQuestions => 'Preguntas frecuentes';

  @override
  String get creditsDescription =>
      'Producto EXOM de valor añadido para clientes. Desarrollo principal por Carlos Sánchez Román, con app móvil en Flutter y backend en NestJS.';

  @override
  String get developer => 'Desarrollador';

  @override
  String get couldNotOpenGithubProfile =>
      'No se pudo abrir el perfil de GitHub.';

  @override
  String get registerWeightMuscleAndMeasurements =>
      '¿Cómo registro mi peso, masa muscular y medidas?';

  @override
  String get registerWeightExplanation =>
      'Ve a tu perfil y entra en \"Mis métricas\". Desde ahí puedes guardar peso, masa muscular, horas de sueño y medidas corporales. Si no tienes una medición directa de masa muscular, puedes usar la calculadora SEEN con edad, altura, sexo y pantorrilla para obtener una estimación.';

  @override
  String get markWorkoutCompleted =>
      '¿Cómo marco un entrenamiento como completado?';

  @override
  String get markWorkoutExplanation =>
      'Entra en el entrenamiento del día desde Home o desde Entrenamientos. Puedes marcar ejercicios uno a uno o completar la sesión completa desde el resumen final.';

  @override
  String get markMealCompleted => '¿Cómo marco una comida como completada?';

  @override
  String get markMealExplanation =>
      'Abre la dieta del día, entra en la comida correspondiente y pulsa el botón de completado. El Home y el Calendario reflejará el avance real del día.';

  @override
  String get useAppOffline => '¿Puedo usar la app sin conexión?';

  @override
  String get useAppOfflineExplanation =>
      'Sí. La app conserva en caché el último Home, Perfil, Calendario, Dieta, Entreno y Métricas cargados. Sin conexión puedes consultar esos datos, aunque no se enviarán cambios al servidor.';

  @override
  String get weeklyRecapPurpose => '¿Para qué sirve el ReCap semanal?';

  @override
  String get weeklyRecapExplanation =>
      'El ReCap te permite resumir tu semana para que tu entrenador entienda cómo has rendido, comido, descansado y qué sensaciones has tenido.';

  @override
  String get contactCoachReportProblem =>
      '¿Cómo contacto con mi entrenador o reporto un problema?';

  @override
  String get contactCoachExplanation =>
      'Usa la sección Feedback para enviar dudas, incidencias o material técnico. Es el canal principal dentro de la app para que tu entrenador o el equipo de soporte puedan darte seguimiento.';

  @override
  String get profilePageTitle => 'Perfil';

  @override
  String get beginnerLevel => 'Principiante';

  @override
  String get intermediateLevel => 'Intermedio';

  @override
  String get advancedLevel => 'Avanzado';

  @override
  String get loseWeightGoal => 'Perder peso';

  @override
  String get gainMuscleGoal => 'Ganar músculo';

  @override
  String get maintainGoal => 'Mantener';

  @override
  String get improveFitnessGoal => 'Mejorar fitness';

  @override
  String get updateWeightButton => 'Actualizar peso';

  @override
  String get updateMeasurementsButton => 'Actualizar medidas';

  @override
  String get weeklyRecapButton => 'ReCap semanal';

  @override
  String get weightProgressTitle => 'Progreso del peso';

  @override
  String get noDataYetMessage => 'Sin datos todavía';

  @override
  String get logMetricsPrompt =>
      'Registra tu peso y medidas para empezar\na ver tu evolución.';

  @override
  String get logMetricsButton => 'Registrar métricas';

  @override
  String get muscleMassGoalTitle => 'Objetivo de masa muscular';

  @override
  String get muscleMassLabel => 'Masa muscular';

  @override
  String get goalLabel => 'Objetivo';

  @override
  String get setYourGoal => 'Define tu objetivo';

  @override
  String get latestMeasurementLabel => 'Última medición';

  @override
  String get updateYourMetrics => 'Actualiza tus métricas';

  @override
  String get currentCaption => 'actual';

  @override
  String get muscleGoalEmptyState =>
      'Registra una medición directa o usa la estimación SEEN desde métricas para ver la evolución.';

  @override
  String get logOrCalculateButton => 'Registrar o calcular';

  @override
  String get ofGoalPercentage => 'del objetivo';

  @override
  String get daysWithinGoal => 'días dentro del objetivo';

  @override
  String get todayCaption => 'hoy';

  @override
  String get bodyDataTitle => 'Datos corporales';

  @override
  String get lastUpdatedLabel => 'Última actualización';

  @override
  String get syncedWithProfileAndMetrics =>
      'Sincronizada con perfil y métricas';

  @override
  String get addHeightInMetrics =>
      'Añádela en métricas para mejorar el seguimiento';

  @override
  String get measurementsLabel => 'Medidas';

  @override
  String get noDataLabel => 'Sin datos';

  @override
  String get updateMetricsButton => 'Actualizar métricas';

  @override
  String get validHeightRequired =>
      'Introduce una altura válida antes de guardar.';

  @override
  String get validWeightRequired =>
      'Introduce un peso válido antes de guardar.';

  @override
  String get validSleepRequired =>
      'Introduce las horas de sueño en formato numérico antes de guardar.';

  @override
  String get validMuscleMassRequired =>
      'Introduce una masa muscular válida antes de guardar.';

  @override
  String measurementReviewTemplate(String measurement) {
    return 'Revisa la medida de $measurement antes de guardar.';
  }

  @override
  String get noChangesMessage =>
      'No has modificado ninguna métrica para guardar.';

  @override
  String get metricsPageTitle => 'Actualizar métricas';

  @override
  String get recordDateTitle => 'Fecha del registro';

  @override
  String get recordDateDescription =>
      'El registro se guardará para la fecha seleccionada. Así puedes apuntar métricas y sueño de días anteriores.';

  @override
  String get heightSectionTitle => 'Altura';

  @override
  String get heightDescription =>
      'La altura se guarda en tu histórico de métricas y también actualiza tu perfil para mantener coherencia con el cálculo SEEN.';

  @override
  String get weightSectionTitle => 'Peso';

  @override
  String get manualEntryToggle => 'Entrada manual';

  @override
  String get weightUpdateNote =>
      'El peso solo se guarda si lo modificas en esta actualización.';

  @override
  String get muscleMassSectionTitle => 'Masa muscular';

  @override
  String get muscleMassDescription =>
      'Registra tu estimación actual para comparar tu evolución con el objetivo del perfil.';

  @override
  String get seenCalculatorTitle => 'Calculadora SEEN';

  @override
  String get seenCalculatorDescription =>
      'Si no tienes una medición directa, puedes usar una estimación basada en edad, altura, sexo y circunferencia de pantorrilla.';

  @override
  String get calculateEstimateButton => 'Calcular estimación';

  @override
  String get sleepHoursSectionTitle => 'Horas de sueño';

  @override
  String get sleepHoursDescription =>
      'Indica cuántas horas dormiste en la noche correspondiente a esta fecha.';

  @override
  String get sleepVeryLow => 'Muy poco sueño';

  @override
  String get sleepInsufficient => 'Sueño insuficiente';

  @override
  String get sleepOptimal => 'Sueño óptimo';

  @override
  String get sleepTooMuch => 'Demasiado sueño';

  @override
  String get bodyMeasurementsTitle => 'Medidas corporales';

  @override
  String get listViewToggle => 'Lista';

  @override
  String get bodyViewToggle => 'Cuerpo';

  @override
  String get frontViewLabel => 'Frontal';

  @override
  String get backViewLabel => 'Posterior';

  @override
  String get saveMetricsButton => 'Guardar métricas';

  @override
  String get quickSeenEstimate => 'Estimación rápida SEEN';

  @override
  String get seenFormulaDescription =>
      'Usa la fórmula de la SEEN para estimar masa muscular esquelética a partir de edad, altura, sexo y pantorrilla.';

  @override
  String get ageLabel => 'Edad';

  @override
  String get yearsLabel => 'años';

  @override
  String get calfLabel => 'Pantorrilla';

  @override
  String get sexLabel => 'Sexo';

  @override
  String get maleOption => 'Hombre';

  @override
  String get femaleOption => 'Mujer';

  @override
  String get invalidAgeError => 'Introduce una edad válida.';

  @override
  String get invalidHeightError => 'Introduce una altura válida.';

  @override
  String get invalidCalfError =>
      'Introduce una circunferencia de pantorrilla válida.';

  @override
  String get selectSexError =>
      'Selecciona un sexo para aplicar la fórmula SEEN.';

  @override
  String get estimationFailedError =>
      'No se ha podido calcular una estimación válida con esos datos.';

  @override
  String get calculateAndUseButton => 'Calcular y usar';

  @override
  String get metricsSuccessMessage => 'Métricas guardadas correctamente';

  @override
  String seenEstimateApplied(String estimate, String asmi) {
    return 'Estimación SEEN aplicada: $estimate (ASMI $asmi kg/m²)';
  }

  @override
  String get recapStartTitle => 'Formulario ReCap semanal';

  @override
  String get recapStartDescription =>
      'Completa los cuatro pasos para que tu entrenador entienda cómo ha ido tu semana y pueda ajustar el plan.';

  @override
  String get recapStartButton => 'Comenzar';

  @override
  String get recapSendFormButton => 'Enviar formulario';

  @override
  String get recapReviewAndSendButton => 'Revisar y enviar';

  @override
  String get recapImprovementTitle => 'Ayúdanos a mejorar';

  @override
  String get recapImprovementRatingsTitle => 'Valoraciones';

  @override
  String get recapImprovementRatingsSubtitle =>
      'Tu opinión nos ayuda a mejorar la experiencia y el acompañamiento.';

  @override
  String get recapWhatCanWeImprove => '¿Qué podemos mejorar?';

  @override
  String get recapTellUsMore => 'Cuéntanos más';

  @override
  String get recapSentSuccessfully => 'Recap enviado correctamente';

  @override
  String get newRecap => 'Nuevo recap';

  @override
  String get editRecap => 'Editar recap';

  @override
  String get weeklyRecapTitle => 'Recap semanal';

  @override
  String get recapTraining => 'Entreno';

  @override
  String get recapNutrition => 'Nutrición';

  @override
  String get recapRecovery => 'Recuperación';

  @override
  String get recapGeneral => 'General';

  @override
  String get couldNotLoadRecap => 'No se pudo cargar el recap';

  @override
  String get weekWithoutDates => 'Semana sin fechas';

  @override
  String get notRatedFeminine => 'No valorada';

  @override
  String get notRated => 'No valorado';

  @override
  String get noZonesSelected => 'Sin zonas marcadas';

  @override
  String get noAreasSelected => 'Sin áreas seleccionadas';

  @override
  String get youHaveNotSentAnyRecapYet => 'Todavía no has enviado ningún recap';

  @override
  String get useThisSpaceToSummarizeYourWeek =>
      'Usa este espacio para resumir tu semana y dar contexto útil a tu coach.';

  @override
  String get createMyFirstRecap => 'Crear mi primer recap';

  @override
  String get yourWeeklyHistory => 'Tu histórico semanal';

  @override
  String get trackYourWeeksReviewPreviousRecaps =>
      'Mantén trazabilidad de tus semanas, revisa recaps anteriores y continúa borradores pendientes.';

  @override
  String get viewSummary => 'Ver resumen';

  @override
  String get trainingNotRated => 'Entreno sin valorar';

  @override
  String get nutritionNotRated => 'Nutrición sin valorar';

  @override
  String get moodNotRated => 'Ánimo sin valorar';

  @override
  String get completeTheFourBlocksAndSendYourWeeklySummary =>
      'Completa los cuatro bloques y envía tu resumen semanal.';

  @override
  String get sendRecap => 'Enviar recap';

  @override
  String get continueToNextStep => 'Continuar al siguiente paso';

  @override
  String get generalState => 'Estado general';

  @override
  String get yourMentalAndEmotionalContextAlsoMatters =>
      'Tu contexto mental y emocional también cuenta.';

  @override
  String get mainMood => 'Ánimo predominante';

  @override
  String get howYouFeltMostOfTheWeek =>
      'Cómo te has sentido la mayor parte de la semana.';

  @override
  String get rateStressLevel => 'Valorar nivel de estrés';

  @override
  String get enableItIfYouWantToReportThePressureOrLoadOfTheWeek =>
      'Actívalo si quieres reportar la presión o carga de la semana.';

  @override
  String get perceivedStress => 'Estrés percibido';

  @override
  String get howMuchStressDidYouFeelThisWeek =>
      '¿Cuánto estrés has sentido esta semana?';

  @override
  String get serviceFeedback => 'Feedback sobre el servicio';

  @override
  String get helpImproveTheExperienceAndSupport =>
      'Ayuda a mejorar la experiencia y el acompañamiento.';

  @override
  String get rateTheApp => 'Valora la app';

  @override
  String get yourOverallExperienceWithTheApp =>
      'Tu experiencia general con la aplicación.';

  @override
  String get rateTheService => 'Valora el servicio';

  @override
  String get howYouRateTheSupportReceivedThisWeek =>
      'Cómo percibes el soporte recibido esta semana.';

  @override
  String get selectThePointsWhereYouWantMoreSupport =>
      'Selecciona los puntos donde quieres más apoyo.';

  @override
  String get finalComments => 'Comentarios finales';

  @override
  String get closeTheWeekWithWhatMattersForYourCoach =>
      'Cierra la semana con lo más relevante para tu coach.';

  @override
  String get shareAnyRelevantDetailFromYourWeek =>
      'Comparte cualquier detalle relevante de tu semana.';

  @override
  String get suggestionsOrImprovements => 'Sugerencias o mejoras';

  @override
  String get egIWouldLikeMoreContextInTheSessions =>
      'Ej: me gustaría más contexto en las sesiones o una mejor guía para el fin de semana.';

  @override
  String get loadAndFeelings => 'Carga y sensaciones';

  @override
  String get tellUsHowYouFeltTrainingThisWeek =>
      'Cuéntanos cómo te has sentido entrenando esta semana.';

  @override
  String get overallEffort => 'Esfuerzo general';

  @override
  String get howDidYouFeelWithTheTrainingLoad =>
      '¿Cómo te has sentido con la carga de entrenos?';

  @override
  String get completedSessions => 'Sesiones completadas';

  @override
  String get howDoYouRateTheNumberOfSessions =>
      '¿Cómo valoras el número de sesiones?';

  @override
  String get perceivedProgress => 'Progreso percibido';

  @override
  String get chooseTheProgressThatBestReflectsYourWeek =>
      'Selecciona la evolución que mejor refleje tu semana.';

  @override
  String get progressPerception => 'Percepción de progreso';

  @override
  String get yourOverallFeelingAboutThePlanProgress =>
      'Tu sensación general sobre la evolución del plan.';

  @override
  String get trainingNotes => 'Notas de entreno';

  @override
  String get addContextSoYourCoachCanReviewYourWeekBetter =>
      'Añade contexto para que el coach revise mejor tu semana.';

  @override
  String get recapTrainingObservations => 'Observaciones';

  @override
  String get egItWasHardToKeepThePaceOnThursday =>
      'Ej: me costó mantener el ritmo el jueves o noté mejor técnica en sentadilla.';

  @override
  String get weekQuality => 'Calidad de la semana';

  @override
  String get rateHowYourNutritionWentTheseDays =>
      'Valora cómo ha ido tu alimentación estos días.';

  @override
  String get nutritionQuality => 'Calidad nutricional';

  @override
  String get yourOverallPerceptionOfThisWeeksNutrition =>
      'Tu percepción general sobre la alimentación semanal.';

  @override
  String get mealQuality => 'Calidad de comidas';

  @override
  String get howDoYouRateYourNutritionThisWeek =>
      '¿Cómo valoras tu alimentación esta semana?';

  @override
  String get tellUsIfYouPaidAttentionToThisArea =>
      'Indica si has prestado atención a este aspecto.';

  @override
  String get iWantToRateMyHydration => 'Quiero valorar mi hidratación';

  @override
  String get enableItIfYouWantToReportHowItWentDuringTheWeek =>
      'Actívalo si quieres reportar cómo fue durante la semana.';

  @override
  String get hydrationLevel => 'Nivel de hidratación';

  @override
  String get chooseTheOptionThatFitsYouBest =>
      'Selecciona la opción que mejor encaje contigo.';

  @override
  String get nutritionNotes => 'Notas de alimentación';

  @override
  String get addContextForIssuesCravingsOrDifficulties =>
      'Deja contexto para incidencias, antojos o dificultades.';

  @override
  String get egItWasHardToOrganizeBreakfasts =>
      'Ej: me costó organizar desayunos o he mantenido mejor la estructura los fines de semana.';

  @override
  String get restAndRecovery => 'Descanso y recuperación';

  @override
  String get rateHowYourBodyRespondedThisWeek =>
      'Evalúa cómo ha respondido tu cuerpo esta semana.';

  @override
  String get selectTheRangeThatRepeatedTheMost =>
      'Selecciona el rango que más se repitió.';

  @override
  String get fatigueLevel => 'Nivel de fatiga';

  @override
  String get howYourOverallEnergyFelt => 'Cómo te sentiste en energía general.';

  @override
  String get discomfortOrTightness => 'Molestias o cargas';

  @override
  String get tapTheAreasThatFeltTheMostLoaded =>
      'Toca las zonas que has sentido más cargadas.';

  @override
  String get areasWithPainOrTension => 'Zonas con dolor o tensión';

  @override
  String get tapTheAffectedBodyAreas =>
      'Pulsa sobre las zonas del cuerpo afectadas.';

  @override
  String get painIntensity => 'Intensidad del dolor';

  @override
  String get overallLevelOfDiscomfortFelt =>
      'Nivel general de las molestias percibidas.';

  @override
  String get recoveryNotes => 'Notas de recuperación';

  @override
  String get addAnythingImportantToAdjustThePlan =>
      'Añade lo que creas importante para ajustar el plan.';

  @override
  String get egIStillHaveLowerBackTightness =>
      'Ej: arrastro tensión lumbar o he dormido mejor desde que bajó el volumen de carga.';

  @override
  String get appearanceSettingsTitle => 'Apariencia';

  @override
  String get systemThemeOption => 'Sistema';

  @override
  String get systemThemeDescription =>
      'Sigue automáticamente el modo configurado en tu dispositivo';

  @override
  String get lightThemeOption => 'Claro';

  @override
  String get lightThemeDescription =>
      'Activa una versión luminosa y cálida alineada con la paleta del producto';

  @override
  String get darkThemeOption => 'Oscuro';

  @override
  String get darkThemeDescription =>
      'Mantiene la experiencia nocturna actual para reducir brillo y fatiga visual';

  @override
  String get accountSettingsTitle => 'Cuenta';

  @override
  String get editProfileOption => 'Editar perfil';

  @override
  String get editProfileDescription =>
      'Foto, objetivo y datos visibles en tu ficha';

  @override
  String get myMetricsOption => 'Mis métricas';

  @override
  String get myMetricsDescription =>
      'Peso, masa muscular, sueño y medidas corporales';

  @override
  String get unitsSettingsTitle => 'Unidades';

  @override
  String get metricOption => 'Métrico';

  @override
  String get metricDescription => 'Usa kilos y centímetros en toda la app';

  @override
  String get imperialDescription =>
      'Usa libras e pulgadas, guardando en métrico internamente';

  @override
  String get languageSettingsTitle => 'Idioma';

  @override
  String get systemLanguageOption => 'Sistema';

  @override
  String get systemLanguageDescription =>
      'Usa automáticamente el idioma configurado en tu dispositivo';

  @override
  String get spanishLanguageDescription => 'Interfaz principal en español.';

  @override
  String get englishLanguageDescription => 'Interfaz principal en inglés.';

  @override
  String get privacySettingsTitle => 'Privacidad';

  @override
  String get privacyPolicyOption => 'Política de privacidad';

  @override
  String get privacyPolicyDescription =>
      'Abre la política externa para revisar tratamiento de datos y privacidad.';

  @override
  String get supportContactOption => 'Soporte y contacto';

  @override
  String get supportContactDescription =>
      'Abre la página de soporte o escribe a soporte@exom.app.';

  @override
  String get emailSupportOption => 'Escribir a soporte';

  @override
  String get emailSupportOptionDescription =>
      'Prepara un email externo para soporte técnico.';

  @override
  String get notificationsSettingsTitle => 'Notificaciones';

  @override
  String get pushNotificationsOption => 'Notificaciones push';

  @override
  String get pushNotificationsDescription =>
      'Avisos de entrenador, seguimiento y recordatorios';

  @override
  String get dataAndSupportTitle => 'Datos y soporte';

  @override
  String get offlineModeOption => 'Modo offline';

  @override
  String get offlineModeDescription =>
      'La app conserva el ultimo Home, Perfil, Calendario, Dieta y Entreno cargados';

  @override
  String get clearCacheOption => 'Borrar caché local';

  @override
  String get clearCacheDescription =>
      'Elimina datos offline guardados en este dispositivo';

  @override
  String get sendFeedbackOption => 'Enviar feedback';

  @override
  String get sendFeedbackDescription =>
      'Comparte dudas, incidencias o feedback técnico';

  @override
  String get helpAndFaqOption => 'Ayuda y FAQ';

  @override
  String get helpAndFaqDescription =>
      'Preguntas frecuentes, uso offline y soporte';

  @override
  String get applicationSettingsTitle => 'Aplicación';

  @override
  String get versionOption => 'Versión';

  @override
  String get versionDescription => 'Build actual del cliente móvil';

  @override
  String get creditsOption => 'Créditos';

  @override
  String get creditsOptionDescription => 'Tecnología y stack del producto';

  @override
  String get logOutButton => 'Cerrar sesión';

  @override
  String get settingsPageTitle => 'Ajustes';

  @override
  String get privacyPolicyNotOpenedError =>
      'No se pudo abrir la política de privacidad.';

  @override
  String get supportPageNotOpenedError =>
      'No se pudo abrir la página de soporte.';

  @override
  String get mailAppNotOpenedError =>
      'No se pudo abrir la aplicación de correo.';

  @override
  String themeAppliedNotification(String themeLabel) {
    return 'Tema $themeLabel aplicado';
  }

  @override
  String unitsAppliedNotification(String unitLabel) {
    return 'Unidades $unitLabel aplicadas';
  }

  @override
  String languageAppliedNotification(String languageLabel) {
    return 'Idioma $languageLabel aplicado';
  }

  @override
  String get notificationsEnabledMessage =>
      'Notificaciones activadas para este dispositivo';

  @override
  String get notificationsDisabledMessage =>
      'Notificaciones desactivadas en este dispositivo';

  @override
  String get cacheDeletedMessage => 'Caché offline borrada correctamente';

  @override
  String get retry => 'Reintentar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get previous => 'Anterior';

  @override
  String get continueButton => 'Continuar';

  @override
  String get update => 'Actualizar';

  @override
  String get created => 'Creado';

  @override
  String get help => 'Ayuda';

  @override
  String get feedback => 'Feedback';

  @override
  String get settings => 'Ajustes';

  @override
  String get history => 'Historial';

  @override
  String get image => 'Imagen';

  @override
  String get video => 'Vídeo';

  @override
  String get reviewed => 'Revisado';

  @override
  String get pending => 'Pendiente';

  @override
  String get today => 'Hoy';

  @override
  String get weight => 'Peso';

  @override
  String get height => 'Altura';

  @override
  String get streak => 'Racha';

  @override
  String get days => 'días';

  @override
  String get hours => 'horas';

  @override
  String get years => 'años';

  @override
  String get sleep => 'Sueño';

  @override
  String get progress => 'Progreso';

  @override
  String get notes => 'Notas';

  @override
  String get meals => 'Comidas';

  @override
  String get training => 'Entrenamiento';

  @override
  String get exercises => 'Ejercicios';

  @override
  String get nutrition => 'Nutrición';

  @override
  String get recovery => 'Recuperación';

  @override
  String get general => 'General';

  @override
  String get quality => 'Calidad';

  @override
  String get hydration => 'Hidratación';

  @override
  String get mood => 'Ánimo';

  @override
  String get stress => 'Estrés';

  @override
  String get effort => 'Esfuerzo';

  @override
  String get sessions => 'Sesiones';

  @override
  String get completed => 'Completado';

  @override
  String get achievements => 'Logros';

  @override
  String get challenges => 'Retos';

  @override
  String get profile => 'Perfil';

  @override
  String get calendar => 'Calendario';

  @override
  String get diets => 'Dietas';

  @override
  String get restTimerTitle => 'Descanso';

  @override
  String restTimerNextExercise(String name) {
    return 'Siguiente: $name';
  }

  @override
  String get restTimerSkip => 'Saltar';

  @override
  String get weightInputTitle => '¿Peso utilizado?';

  @override
  String get weightInputHint => 'ej. 20 (opcional)';

  @override
  String get weightInputSkip => 'Omitir';

  @override
  String get weightInputSave => 'Guardar';

  @override
  String weightBadgeLabel(String weight) {
    return '$weight kg';
  }

  @override
  String get feedbackSelectImage => 'Imagen';

  @override
  String get feedbackSelectVideo => 'Vídeo';

  @override
  String get feedbackFromCamera => 'Desde cámara';

  @override
  String get feedbackFromGallery => 'Desde galería';

  @override
  String get feedbackUploading => 'Subiendo...';

  @override
  String get feedbackSendFromExercise => 'Enviar feedback';

  @override
  String get errorNetwork => 'Error de red';

  @override
  String get errorAccountLocked =>
      'Cuenta bloqueada — contacta a tu entrenador';

  @override
  String get errorSessionExpired => 'Sesión expirada. Inicia sesión nuevamente';

  @override
  String get errorForbidden => 'No tienes permisos para realizar esta acción';

  @override
  String get errorNotFound => 'Recurso no encontrado';

  @override
  String get errorServer => 'Error del servidor. Inténtalo más tarde';

  @override
  String get retryButton => 'Reintentar';

  @override
  String get contactSupportButton => 'Contactar soporte';

  @override
  String get viewOfflineButton => 'Ver offline';

  @override
  String get goToCalendarButton => 'Ir al calendario';

  @override
  String get goHomeButton => 'Inicio';

  @override
  String get serverErrorTitle => 'Algo salió mal';

  @override
  String get serverErrorMessage => 'El servidor no pudo procesar tu solicitud';

  @override
  String serverErrorMessageWithCode(String code) {
    return 'Error $code. El servidor no pudo procesar tu solicitud';
  }

  @override
  String get noConnectionTitle => 'Sin conexión a internet';

  @override
  String get noConnectionMessage =>
      'Comprueba tu conexión e inténtalo de nuevo';

  @override
  String get notFoundTitle => 'Contenido no disponible';

  @override
  String get notFoundMessage =>
      'No encontramos lo que buscas. Puede que haya sido eliminado o aún no está disponible';

  @override
  String get selectedDateLabel => 'la fecha seleccionada';

  @override
  String get measureNeck => 'Cuello';

  @override
  String get measureShoulders => 'Hombros';

  @override
  String get measureChest => 'Pecho';

  @override
  String get measureArm => 'Brazo';

  @override
  String get measureForearm => 'Antebrazo';

  @override
  String get measureWaist => 'Cintura';

  @override
  String get measureHips => 'Caderas';

  @override
  String get measureThigh => 'Muslo';

  @override
  String get measureCalf => 'Gemelo';

  @override
  String get noTrainingsAssigned => 'No tienes entrenamientos asignados';

  @override
  String get noTrainingsAssignedSubtitle =>
      'Tu entrenador aún no te ha asignado un plan';

  @override
  String get noActivitiesThisMonth => 'Sin actividades este mes';

  @override
  String get noActivitiesThisMonthSubtitle =>
      'No hay entrenamientos ni dietas programados';

  @override
  String get onboardingWelcomeTitle => '¡Bienvenido a EXOM!';

  @override
  String get onboardingWelcomeDescription =>
      'Configura tu perfil en unos pocos pasos para que tu entrenador pueda personalizar tu plan.';

  @override
  String get onboardingStartButton => 'Empezar';

  @override
  String get onboardingDoItLaterButton => 'Hacerlo después';

  @override
  String get onboardingBasicsTitle => 'Datos básicos';

  @override
  String get onboardingFirstNameLabel => 'Nombre';

  @override
  String get onboardingLastNameLabel => 'Apellido';

  @override
  String get onboardingBirthDateLabel => 'Fecha de nacimiento';

  @override
  String get onboardingAvatarLabel => 'Foto de perfil (opcional)';

  @override
  String get onboardingBodyTitle => 'Tu cuerpo';

  @override
  String get onboardingHeightLabel => 'Altura (cm)';

  @override
  String get onboardingWeightLabel => 'Peso (kg)';

  @override
  String get onboardingGoalsTitle => 'Tus objetivos';

  @override
  String get onboardingLevelLabel => 'Nivel';

  @override
  String get onboardingMainGoalLabel => 'Objetivo principal';

  @override
  String get onboardingMuscleMassGoalLabel =>
      'Meta de masa muscular (kg, opcional)';

  @override
  String get onboardingTargetCaloriesLabel => 'Calorías objetivo (opcional)';

  @override
  String get onboardingFirstNameRequired => 'Introduce tu nombre';

  @override
  String get onboardingLastNameRequired => 'Introduce tu apellido';

  @override
  String get onboardingCompleteProfileButton => 'Completar perfil';

  @override
  String get onboardingSummaryTitle => 'Resumen';

  @override
  String get onboardingConfirmButton => 'Confirmar';

  @override
  String get onboardingEditButton => 'Editar';

  @override
  String onboardingProgressComplete(int percent) {
    return 'Perfil $percent% completo';
  }

  @override
  String get onboardingSkipButton => 'Saltar';

  @override
  String get onboardingNextButton => 'Siguiente';

  @override
  String get onboardingSubmittingMessage => 'Guardando tu perfil...';

  @override
  String get onboardingSuccessMessage => '¡Perfil completado!';

  @override
  String get onboardingErrorMessage =>
      'Error al guardar el perfil. Inténtalo de nuevo.';
}
