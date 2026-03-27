// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'Your personal coach, always with you';

  @override
  String get emailFieldLabel => 'Email';

  @override
  String get emailValidationEmpty => 'Enter your email';

  @override
  String get emailValidationInvalid => 'Invalid email';

  @override
  String get passwordFieldLabel => 'Password';

  @override
  String get passwordValidationEmpty => 'Enter your password';

  @override
  String get passwordValidationLength =>
      'Password must be at least 8 characters';

  @override
  String get forgotPasswordButton => 'Forgot your password?';

  @override
  String get emailFirstPrompt => 'Enter your email first';

  @override
  String get passwordResetEmailSent => 'Recovery email sent. Check your inbox.';

  @override
  String get passwordResetEmailFailed =>
      'Could not send the email. Check the address.';

  @override
  String get loginButton => 'Log in';

  @override
  String get continueWithDivider => 'or continue with';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get accountLockedTitle => 'Account locked';

  @override
  String get accountLockedMessage =>
      'Your account has been temporarily locked.\nContact your coach for more information.';

  @override
  String get backToLoginButton => 'Back to login';

  @override
  String get welcomeOnboarding => 'Welcome\nto EXOM!';

  @override
  String get onboardingStepsMessage => 'Follow these steps to get started.';

  @override
  String get completeProfileTitle => 'Complete your profile';

  @override
  String get completeProfileSubtitle =>
      'Add your details so your coach can personalize your plan.';

  @override
  String get waitForCoachTitle => 'Wait for your coach';

  @override
  String get waitForCoachSubtitle =>
      'We will assign you a personal coach who will design your routine.';

  @override
  String get startTransformationTitle => 'Start your transformation';

  @override
  String get startTransformationSubtitle =>
      'Follow your plan, track your progress, and reach your goals.';

  @override
  String get completeProfileButton => 'Complete profile';

  @override
  String get doItLaterButton => 'Do it later';

  @override
  String pageNotFoundError(String error) {
    return 'Page not found: $error';
  }

  @override
  String get userDefaultName => 'User';

  @override
  String get exomMemberLabel => 'EXOM Member';

  @override
  String get profileMenuItem => 'Profile';

  @override
  String get challengesMenuItem => 'Challenges';

  @override
  String get weeklyRecapMenuItem => 'Weekly Recap';

  @override
  String get feedbackMenuItem => 'Feedback';

  @override
  String get settingsMenuItem => 'Settings';

  @override
  String get helpMenuItem => 'Help';

  @override
  String get logOutMenuItem => 'Log Out';

  @override
  String get restDayTitle => 'Rest day';

  @override
  String get restDayMessage =>
      'You have no training assigned for today.\nTake the chance to recover.';

  @override
  String get openCalendarButton => 'Open calendar';

  @override
  String get todaysTrainingTitle => 'Today\'s training';

  @override
  String get trainingUntitledLabel => 'Untitled';

  @override
  String get trainingCompletedLabel => 'Completed';

  @override
  String get viewTrainingButton => 'Open training';

  @override
  String get continueTrainingButton => 'Continue';

  @override
  String get startTrainingButton => 'Start';

  @override
  String get trainingStrength => 'Strength';

  @override
  String get trainingMobility => 'Mobility';

  @override
  String get todaysDietTitle => 'Today\'s diet';

  @override
  String get nutritionPlanDefault => 'Nutrition plan';

  @override
  String get nextMealLabel => 'Next';

  @override
  String get nextMealButton => 'Next meal';

  @override
  String get viewFullDietButton => 'Open full diet';

  @override
  String get todayLabel => 'Today';

  @override
  String get tomorrowLabel => 'Tomorrow';

  @override
  String get dayAfterTomorrowLabel => 'Day after tomorrow';

  @override
  String get yesterdayLabel => 'Yesterday';

  @override
  String get twoDaysAgoLabel => 'Two days ago';

  @override
  String inDaysLabel(int diff) {
    return 'In $diff days';
  }

  @override
  String daysAgoLabel(int diff) {
    return '$diff days ago';
  }

  @override
  String get keepItUpSubtitle => 'Keep it up!';

  @override
  String get sleepQualityGood => 'Good quality';

  @override
  String get sleepQualityFair => 'Fair quality';

  @override
  String get sleepQualityLow => 'Low sleep';

  @override
  String get allTrainingsSection => 'All trainings';

  @override
  String get noTrainingsAvailable => 'No trainings available';

  @override
  String get askCoachForPlan => 'Ask your coach to assign you a plan';

  @override
  String get noTrainingAssignedToday => 'No training assigned today';

  @override
  String get noTrainingAssignedForDate => 'No training assigned for that date';

  @override
  String get enjoyRestDay => 'Enjoy your rest day';

  @override
  String get noDietTodayMessage => 'You have no diet assigned today';

  @override
  String get noDietForDateMessage => 'You have no diet assigned for that date';

  @override
  String get contactCoachForPlanMessage =>
      'Ask your coach to assign you a nutrition plan';

  @override
  String get contactCoachButton => 'Contact coach';

  @override
  String get mealsOfTheDayLabel => 'Meals of the day';

  @override
  String get todaysPlanLabel => 'Today\'s plan';

  @override
  String get planForLabel => 'Plan for';

  @override
  String get completedFeminine => 'Completed';

  @override
  String get openPlan => 'Open plan';

  @override
  String get mealTypeBreakfast => 'Breakfast';

  @override
  String get mealTypeLunch => 'Lunch';

  @override
  String get mealTypeSnack => 'Snack';

  @override
  String get mealTypeDinner => 'Dinner';

  @override
  String get openRecipeButton => 'Open recipe in Google';

  @override
  String get mealCompletedButton => 'Completed';

  @override
  String get markMealCompletedButton => 'Mark as completed';

  @override
  String get nutritionalInfoTitle => 'Nutritional information';

  @override
  String get caloriesLabel => 'Calories';

  @override
  String get proteinLabel => 'Protein';

  @override
  String get carbsLabel => 'Carbs';

  @override
  String get fatsLabel => 'Fats';

  @override
  String get ingredientsTitle => 'Ingredients';

  @override
  String get calendarLoadError => 'Could not load the calendar';

  @override
  String get trainingsCompletedThisWeek =>
      'training sessions completed this week';

  @override
  String get mealsCompletedThisWeek => 'meals completed this week';

  @override
  String get noActivityAssigned => 'No activity assigned';

  @override
  String get openDetail => 'Open detail';

  @override
  String get warmUp => 'Warm-up';

  @override
  String get cooldown => 'Cooldown';

  @override
  String get addQuickNoteOptional => 'Add a quick note (optional)';

  @override
  String get completedExercisesLabel => 'completed exercises';

  @override
  String get workoutCompletedMessage => 'Workout completed!';

  @override
  String get rest => 'rest';

  @override
  String get sets => 'Sets';

  @override
  String get repsOrTime => 'Reps/Time';

  @override
  String get restLabel => 'Rest';

  @override
  String get description => 'Description';

  @override
  String get technique => 'Technique';

  @override
  String get commonMistakes => 'Common mistakes';

  @override
  String get feedbackSentSuccessfully => 'Feedback sent successfully';

  @override
  String get noFeedbackYet => 'You have not sent any feedback yet';

  @override
  String get sendFeedback => 'Send feedback';

  @override
  String get fileUrlImageOrVideo => 'File URL (image or video)';

  @override
  String get urlIsRequired => 'URL is required';

  @override
  String get additionalNotesOptional => 'Additional notes (optional)';

  @override
  String get reviewed => 'Reviewed';

  @override
  String get pending => 'Pending';

  @override
  String get challengesTitle => 'Challenges and Achievements';

  @override
  String get challengesLoadError => 'Could not load challenges';

  @override
  String get mainGoalSection => 'Main goal';

  @override
  String get weeklyChallengesSection => 'Weekly challenges';

  @override
  String get unlockedAchievementsSection => 'Unlocked achievements';

  @override
  String get noActiveChallenges => 'No active challenges';

  @override
  String get noActiveChallengesMessage =>
      'Your coach will assign challenges soon.';

  @override
  String get pendingChallengeLabel => 'Pending challenge';

  @override
  String get challengeDeadlineLabel => 'Deadline';

  @override
  String get challengeUntilLabel => 'Until';

  @override
  String get helpCenter => 'Help center';

  @override
  String get helpCenterDescription =>
      'Everything important to use EXOM day to day: metrics, training, diet, offline mode, and contact options.';

  @override
  String get sendQuestionOrIssue => 'Send a question or issue';

  @override
  String get notificationsAndCache => 'Notifications and cache';

  @override
  String get supportAndLinks => 'Support and links';

  @override
  String get supportCenter => 'Support center';

  @override
  String get supportCenterDescription =>
      'Open EXOM\'s external support and contact page.';

  @override
  String get couldNotOpenSupportPage => 'Could not open the support page.';

  @override
  String get emailSupportDescription =>
      'Open your mail client with an email to soporte@exom.app.';

  @override
  String get couldNotOpenMailApp => 'Could not open the mail app.';

  @override
  String get frequentlyAskedQuestions => 'Frequently asked questions';

  @override
  String get creditsDescription =>
      'EXOM product created as added value for clients. Main development by Carlos Sanchez Roman, with a Flutter mobile app and NestJS backend.';

  @override
  String get developer => 'Developer';

  @override
  String get couldNotOpenGithubProfile => 'Could not open the GitHub profile.';

  @override
  String get registerWeightMuscleAndMeasurements =>
      'How do I log my weight, muscle mass, and measurements?';

  @override
  String get registerWeightExplanation =>
      'Go to your profile and open \"My metrics\". There you can save weight, muscle mass, sleep hours, and body measurements. If you do not have a direct muscle-mass measurement, you can use the SEEN calculator with age, height, sex, and calf size to get an estimate.';

  @override
  String get markWorkoutCompleted => 'How do I mark a workout as completed?';

  @override
  String get markWorkoutExplanation =>
      'Open the day\'s workout from Home or from Trainings. You can mark exercises one by one or complete the entire session from the final summary.';

  @override
  String get markMealCompleted => 'How do I mark a meal as completed?';

  @override
  String get markMealExplanation =>
      'Open the day\'s diet, enter the corresponding meal, and tap the complete button. Home and Calendar will reflect the actual progress for the day.';

  @override
  String get useAppOffline => 'Can I use the app offline?';

  @override
  String get useAppOfflineExplanation =>
      'Yes. The app caches the latest loaded Home, Profile, Calendar, Diet, Training, and Metrics. Offline you can review that data, although changes will not be sent to the server.';

  @override
  String get weeklyRecapPurpose => 'What is the weekly recap for?';

  @override
  String get weeklyRecapExplanation =>
      'The recap lets you summarize your week so your coach understands how you performed, ate, rested, and how you felt.';

  @override
  String get contactCoachReportProblem =>
      'How do I contact my coach or report an issue?';

  @override
  String get contactCoachExplanation =>
      'Use the Feedback section to send questions, issues, or technical material. It is the main in-app channel for your coach or the support team to follow up with you.';

  @override
  String get profilePageTitle => 'Profile';

  @override
  String get beginnerLevel => 'Beginner';

  @override
  String get intermediateLevel => 'Intermediate';

  @override
  String get advancedLevel => 'Advanced';

  @override
  String get loseWeightGoal => 'Lose weight';

  @override
  String get gainMuscleGoal => 'Gain muscle';

  @override
  String get maintainGoal => 'Maintain';

  @override
  String get improveFitnessGoal => 'Improve fitness';

  @override
  String get updateWeightButton => 'Update weight';

  @override
  String get updateMeasurementsButton => 'Update measurements';

  @override
  String get weeklyRecapButton => 'Weekly recap';

  @override
  String get weightProgressTitle => 'Weight progress';

  @override
  String get noDataYetMessage => 'No data yet';

  @override
  String get logMetricsPrompt =>
      'Log your weight and measurements to start\nseeing your progress.';

  @override
  String get logMetricsButton => 'Log metrics';

  @override
  String get muscleMassGoalTitle => 'Muscle mass goal';

  @override
  String get muscleMassLabel => 'Muscle mass';

  @override
  String get goalLabel => 'Goal';

  @override
  String get setYourGoal => 'Set your goal';

  @override
  String get latestMeasurementLabel => 'Latest measurement';

  @override
  String get updateYourMetrics => 'Update your metrics';

  @override
  String get currentCaption => 'current';

  @override
  String get muscleGoalEmptyState =>
      'Log a direct measurement or use the SEEN estimate from metrics to see your progress.';

  @override
  String get logOrCalculateButton => 'Log or calculate';

  @override
  String get ofGoalPercentage => 'of goal';

  @override
  String get daysWithinGoal => 'days within goal';

  @override
  String get todayCaption => 'today';

  @override
  String get bodyDataTitle => 'Body data';

  @override
  String get lastUpdatedLabel => 'Last updated';

  @override
  String get syncedWithProfileAndMetrics => 'Synced with profile and metrics';

  @override
  String get addHeightInMetrics => 'Add it in metrics to improve tracking';

  @override
  String get measurementsLabel => 'Measurements';

  @override
  String get noDataLabel => 'No data';

  @override
  String get updateMetricsButton => 'Update metrics';

  @override
  String get validHeightRequired => 'Enter a valid height before saving.';

  @override
  String get validWeightRequired => 'Enter a valid weight before saving.';

  @override
  String get validSleepRequired =>
      'Enter sleep hours in numeric format before saving.';

  @override
  String get validMuscleMassRequired =>
      'Enter a valid muscle mass before saving.';

  @override
  String measurementReviewTemplate(String measurement) {
    return 'Review the $measurement measurement before saving.';
  }

  @override
  String get noChangesMessage => 'You have not changed any metrics to save.';

  @override
  String get metricsPageTitle => 'Update metrics';

  @override
  String get recordDateTitle => 'Record date';

  @override
  String get recordDateDescription =>
      'The record will be saved for the selected date, so you can log metrics and sleep from previous days.';

  @override
  String get heightSectionTitle => 'Height';

  @override
  String get heightDescription =>
      'Height is saved in your metrics history and also updates your profile to keep the SEEN calculation consistent.';

  @override
  String get weightSectionTitle => 'Weight';

  @override
  String get manualEntryToggle => 'Manual entry';

  @override
  String get weightUpdateNote =>
      'Weight is saved only if you change it in this update.';

  @override
  String get muscleMassSectionTitle => 'Muscle mass';

  @override
  String get muscleMassDescription =>
      'Log your current estimate to compare your progress with your profile goal.';

  @override
  String get seenCalculatorTitle => 'SEEN calculator';

  @override
  String get seenCalculatorDescription =>
      'If you do not have a direct measurement, you can use an estimate based on age, height, sex, and calf circumference.';

  @override
  String get calculateEstimateButton => 'Calculate estimate';

  @override
  String get sleepHoursSectionTitle => 'Sleep hours';

  @override
  String get sleepHoursDescription =>
      'Enter how many hours you slept on the night corresponding to this date.';

  @override
  String get bodyMeasurementsTitle => 'Body measurements';

  @override
  String get listViewToggle => 'List';

  @override
  String get bodyViewToggle => 'Body';

  @override
  String get saveMetricsButton => 'Save metrics';

  @override
  String get quickSeenEstimate => 'Quick SEEN estimate';

  @override
  String get seenFormulaDescription =>
      'Use the SEEN formula to estimate skeletal muscle mass from age, height, sex, and calf circumference.';

  @override
  String get ageLabel => 'Age';

  @override
  String get yearsLabel => 'years';

  @override
  String get calfLabel => 'Calf';

  @override
  String get sexLabel => 'Sex';

  @override
  String get maleOption => 'Male';

  @override
  String get femaleOption => 'Female';

  @override
  String get invalidAgeError => 'Enter a valid age.';

  @override
  String get invalidHeightError => 'Enter a valid height.';

  @override
  String get invalidCalfError => 'Enter a valid calf circumference.';

  @override
  String get selectSexError => 'Select a sex to apply the SEEN formula.';

  @override
  String get estimationFailedError =>
      'Could not calculate a valid estimate with those values.';

  @override
  String get calculateAndUseButton => 'Calculate and use';

  @override
  String get metricsSuccessMessage => 'Metrics saved successfully';

  @override
  String get recapSentSuccessfully => 'Recap sent successfully';

  @override
  String get newRecap => 'New recap';

  @override
  String get editRecap => 'Edit recap';

  @override
  String get weeklyRecapTitle => 'Weekly recap';

  @override
  String get recapTraining => 'Training';

  @override
  String get recapNutrition => 'Nutrition';

  @override
  String get recapRecovery => 'Recovery';

  @override
  String get recapGeneral => 'General';

  @override
  String get couldNotLoadRecap => 'Could not load recap';

  @override
  String get weekWithoutDates => 'Week without dates';

  @override
  String get notRatedFeminine => 'Not rated';

  @override
  String get notRated => 'Not rated';

  @override
  String get noZonesSelected => 'No zones selected';

  @override
  String get noAreasSelected => 'No areas selected';

  @override
  String get youHaveNotSentAnyRecapYet => 'You have not sent any recap yet';

  @override
  String get useThisSpaceToSummarizeYourWeek =>
      'Use this space to summarize your week and give useful context to your coach.';

  @override
  String get createMyFirstRecap => 'Create my first recap';

  @override
  String get yourWeeklyHistory => 'Your weekly history';

  @override
  String get trackYourWeeksReviewPreviousRecaps =>
      'Track your weeks, review previous recaps, and continue pending drafts.';

  @override
  String get viewSummary => 'View summary';

  @override
  String get trainingNotRated => 'Training not rated';

  @override
  String get nutritionNotRated => 'Nutrition not rated';

  @override
  String get moodNotRated => 'Mood not rated';

  @override
  String get completeTheFourBlocksAndSendYourWeeklySummary =>
      'Complete the four sections and send your weekly summary.';

  @override
  String get sendRecap => 'Send recap';

  @override
  String get continueToNextStep => 'Continue to next step';

  @override
  String get generalState => 'General state';

  @override
  String get yourMentalAndEmotionalContextAlsoMatters =>
      'Your mental and emotional context also matters.';

  @override
  String get mainMood => 'Main mood';

  @override
  String get howYouFeltMostOfTheWeek => 'How you felt most of the week.';

  @override
  String get rateStressLevel => 'Rate stress level';

  @override
  String get enableItIfYouWantToReportThePressureOrLoadOfTheWeek =>
      'Enable it if you want to report the pressure or load of the week.';

  @override
  String get perceivedStress => 'Perceived stress';

  @override
  String get howMuchStressDidYouFeelThisWeek =>
      'How much stress did you feel this week?';

  @override
  String get serviceFeedback => 'Service feedback';

  @override
  String get helpImproveTheExperienceAndSupport =>
      'Help improve the experience and support.';

  @override
  String get rateTheApp => 'Rate the app';

  @override
  String get yourOverallExperienceWithTheApp =>
      'Your overall experience with the app.';

  @override
  String get rateTheService => 'Rate the service';

  @override
  String get howYouRateTheSupportReceivedThisWeek =>
      'How you rate the support received this week.';

  @override
  String get selectThePointsWhereYouWantMoreSupport =>
      'Select the points where you want more support.';

  @override
  String get finalComments => 'Final comments';

  @override
  String get closeTheWeekWithWhatMattersForYourCoach =>
      'Close the week with what matters most for your coach.';

  @override
  String get shareAnyRelevantDetailFromYourWeek =>
      'Share any relevant detail from your week.';

  @override
  String get suggestionsOrImprovements => 'Suggestions or improvements';

  @override
  String get egIWouldLikeMoreContextInTheSessions =>
      'Eg: I would like more context in the sessions or better guidance for the weekend.';

  @override
  String get loadAndFeelings => 'Load and feelings';

  @override
  String get tellUsHowYouFeltTrainingThisWeek =>
      'Tell us how you felt training this week.';

  @override
  String get overallEffort => 'Overall effort';

  @override
  String get howDidYouFeelWithTheTrainingLoad =>
      'How did you feel with the training load?';

  @override
  String get completedSessions => 'Completed sessions';

  @override
  String get howDoYouRateTheNumberOfSessions =>
      'How do you rate the number of sessions?';

  @override
  String get perceivedProgress => 'Perceived progress';

  @override
  String get chooseTheProgressThatBestReflectsYourWeek =>
      'Choose the progress that best reflects your week.';

  @override
  String get progressPerception => 'Progress perception';

  @override
  String get yourOverallFeelingAboutThePlanProgress =>
      'Your overall feeling about the plan progress.';

  @override
  String get trainingNotes => 'Training notes';

  @override
  String get addContextSoYourCoachCanReviewYourWeekBetter =>
      'Add context so your coach can review your week better.';

  @override
  String get recapTrainingObservations => 'Observations';

  @override
  String get egItWasHardToKeepThePaceOnThursday =>
      'Eg: it was hard to keep the pace on Thursday or I noticed better squat technique.';

  @override
  String get weekQuality => 'Week quality';

  @override
  String get rateHowYourNutritionWentTheseDays =>
      'Rate how your nutrition went these days.';

  @override
  String get nutritionQuality => 'Nutrition quality';

  @override
  String get yourOverallPerceptionOfThisWeeksNutrition =>
      'Your overall perception of this week\'s nutrition.';

  @override
  String get mealQuality => 'Meal quality';

  @override
  String get howDoYouRateYourNutritionThisWeek =>
      'How do you rate your nutrition this week?';

  @override
  String get tellUsIfYouPaidAttentionToThisArea =>
      'Tell us if you paid attention to this area.';

  @override
  String get iWantToRateMyHydration => 'I want to rate my hydration';

  @override
  String get enableItIfYouWantToReportHowItWentDuringTheWeek =>
      'Enable it if you want to report how it went during the week.';

  @override
  String get hydrationLevel => 'Hydration level';

  @override
  String get chooseTheOptionThatFitsYouBest =>
      'Choose the option that fits you best.';

  @override
  String get nutritionNotes => 'Nutrition notes';

  @override
  String get addContextForIssuesCravingsOrDifficulties =>
      'Add context for issues, cravings, or difficulties.';

  @override
  String get egItWasHardToOrganizeBreakfasts =>
      'Eg: it was hard to organize breakfasts or I kept a better structure on weekends.';

  @override
  String get restAndRecovery => 'Rest and recovery';

  @override
  String get rateHowYourBodyRespondedThisWeek =>
      'Rate how your body responded this week.';

  @override
  String get selectTheRangeThatRepeatedTheMost =>
      'Select the range that repeated the most.';

  @override
  String get fatigueLevel => 'Fatigue level';

  @override
  String get howYourOverallEnergyFelt => 'How your overall energy felt.';

  @override
  String get discomfortOrTightness => 'Discomfort or tightness';

  @override
  String get tapTheAreasThatFeltTheMostLoaded =>
      'Tap the areas that felt the most loaded.';

  @override
  String get areasWithPainOrTension => 'Areas with pain or tension';

  @override
  String get tapTheAffectedBodyAreas => 'Tap the affected body areas.';

  @override
  String get painIntensity => 'Pain intensity';

  @override
  String get overallLevelOfDiscomfortFelt =>
      'Overall level of discomfort felt.';

  @override
  String get recoveryNotes => 'Recovery notes';

  @override
  String get addAnythingImportantToAdjustThePlan =>
      'Add anything important to adjust the plan.';

  @override
  String get egIStillHaveLowerBackTightness =>
      'Eg: I still have lower-back tightness or I have slept better since the training volume dropped.';

  @override
  String get appearanceSettingsTitle => 'Appearance';

  @override
  String get systemThemeOption => 'System';

  @override
  String get systemThemeDescription =>
      'Follow the mode configured on your device';

  @override
  String get lightThemeOption => 'Light';

  @override
  String get lightThemeDescription =>
      'Use the warm light palette aligned with the product look';

  @override
  String get darkThemeOption => 'Dark';

  @override
  String get darkThemeDescription =>
      'Keep the current night experience to reduce glare and fatigue';

  @override
  String get accountSettingsTitle => 'Account';

  @override
  String get editProfileOption => 'Edit profile';

  @override
  String get editProfileDescription =>
      'Photo, goal and visible personal details';

  @override
  String get myMetricsOption => 'My metrics';

  @override
  String get myMetricsDescription =>
      'Weight, muscle mass, sleep and body measurements';

  @override
  String get unitsSettingsTitle => 'Units';

  @override
  String get metricOption => 'Metric';

  @override
  String get metricDescription =>
      'Use kilograms and centimeters across the app';

  @override
  String get imperialDescription =>
      'Use pounds and inches while keeping metric storage internally';

  @override
  String get languageSettingsTitle => 'Language';

  @override
  String get systemLanguageOption => 'System';

  @override
  String get systemLanguageDescription =>
      'Automatically use the language configured on your device';

  @override
  String get spanishLanguageDescription => 'Main interface in Spanish.';

  @override
  String get englishLanguageDescription => 'Main interface in English.';

  @override
  String get privacySettingsTitle => 'Privacy';

  @override
  String get privacyPolicyOption => 'Privacy policy';

  @override
  String get privacyPolicyDescription =>
      'Open the external privacy policy to review data handling';

  @override
  String get supportContactOption => 'Support and contact';

  @override
  String get supportContactDescription =>
      'Open the support page or email soporte@exom.app.';

  @override
  String get emailSupportOption => 'Email support';

  @override
  String get emailSupportOptionDescription =>
      'Prepare an external email for technical support.';

  @override
  String get notificationsSettingsTitle => 'Notifications';

  @override
  String get pushNotificationsOption => 'Push notifications';

  @override
  String get pushNotificationsDescription =>
      'Coach alerts, follow-up and reminders';

  @override
  String get dataAndSupportTitle => 'Data and support';

  @override
  String get offlineModeOption => 'Offline mode';

  @override
  String get offlineModeDescription =>
      'The app keeps the latest Home, Profile, Calendar, Diet and Training data loaded';

  @override
  String get clearCacheOption => 'Clear local cache';

  @override
  String get clearCacheDescription =>
      'Remove offline data stored on this device';

  @override
  String get sendFeedbackOption => 'Send feedback';

  @override
  String get sendFeedbackDescription =>
      'Share doubts, issues or technical feedback';

  @override
  String get helpAndFaqOption => 'Help and FAQ';

  @override
  String get helpAndFaqDescription =>
      'Frequently asked questions, offline usage and support';

  @override
  String get applicationSettingsTitle => 'Application';

  @override
  String get versionOption => 'Version';

  @override
  String get versionDescription => 'Current mobile client build';

  @override
  String get creditsOption => 'Credits';

  @override
  String get creditsOptionDescription => 'Product technology and stack';

  @override
  String get logOutButton => 'Log out';

  @override
  String get settingsPageTitle => 'Settings';

  @override
  String get privacyPolicyNotOpenedError =>
      'Could not open the privacy policy.';

  @override
  String get supportPageNotOpenedError => 'Could not open the support page.';

  @override
  String get mailAppNotOpenedError => 'Could not open the mail app.';

  @override
  String themeAppliedNotification(String themeLabel) {
    return '$themeLabel theme applied';
  }

  @override
  String unitsAppliedNotification(String unitLabel) {
    return '$unitLabel units applied';
  }

  @override
  String languageAppliedNotification(String languageLabel) {
    return '$languageLabel language applied';
  }

  @override
  String get notificationsEnabledMessage =>
      'Notifications enabled on this device';

  @override
  String get notificationsDisabledMessage =>
      'Notifications disabled on this device';

  @override
  String get cacheDeletedMessage => 'Offline cache cleared successfully';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get previous => 'Previous';

  @override
  String get continueButton => 'Continue';

  @override
  String get update => 'Update';

  @override
  String get created => 'Created';

  @override
  String get help => 'Help';

  @override
  String get feedback => 'Feedback';

  @override
  String get settings => 'Settings';

  @override
  String get history => 'History';

  @override
  String get image => 'Image';

  @override
  String get video => 'Video';

  @override
  String get today => 'Today';

  @override
  String get weight => 'Weight';

  @override
  String get height => 'Height';

  @override
  String get streak => 'Streak';

  @override
  String get days => 'days';

  @override
  String get hours => 'hours';

  @override
  String get years => 'years';

  @override
  String get sleep => 'Sleep';

  @override
  String get progress => 'Progress';

  @override
  String get notes => 'Notes';

  @override
  String get meals => 'Meals';

  @override
  String get training => 'Training';

  @override
  String get exercises => 'Exercises';

  @override
  String get nutrition => 'Nutrition';

  @override
  String get recovery => 'Recovery';

  @override
  String get general => 'General';

  @override
  String get quality => 'Quality';

  @override
  String get hydration => 'Hydration';

  @override
  String get mood => 'Mood';

  @override
  String get stress => 'Stress';

  @override
  String get effort => 'Effort';

  @override
  String get sessions => 'Sessions';

  @override
  String get completed => 'Completed';

  @override
  String get achievements => 'Achievements';

  @override
  String get challenges => 'Challenges';

  @override
  String get profile => 'Profile';

  @override
  String get calendar => 'Calendar';

  @override
  String get diets => 'Diets';
}
