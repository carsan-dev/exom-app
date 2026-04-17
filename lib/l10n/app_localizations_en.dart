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
  String get splashTagline => 'Train. Eat. Evolve.';

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
  String get linkSocialTitle => 'Link sign-in';

  @override
  String linkSocialDescription(Object email, Object provider) {
    return 'An EXOM account already exists for $email. Enter your current password to also link $provider so you can sign in with both methods.';
  }

  @override
  String get linkSocialConfirmButton => 'Link';

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
  String get richInLabel => 'Rich in';

  @override
  String get openRecipeButton => 'Open recipe in Google';

  @override
  String get recipeButton => 'Recipe';

  @override
  String get mealCompletedButton => 'Completed';

  @override
  String get completeButton => 'Complete';

  @override
  String get markMealCompletedButton => 'Mark as completed';

  @override
  String get markExerciseCompletedButton => 'Mark as completed';

  @override
  String get exerciseCompletedButton => 'Exercise completed';

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
  String get goToMonthButton => 'Go to month';

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
  String exerciseMetadata(int sets, String reps, int rest) {
    return '$sets sets x $reps · Rest ${rest}s';
  }

  @override
  String get description => 'Description';

  @override
  String get explanation => 'Explanation';

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
  String get challengesTitle => 'My Challenges';

  @override
  String get challengesSubtitle => 'Push your limits every day';

  @override
  String get challengesLoadError => 'Could not load challenges';

  @override
  String get mainGoalSection => 'Main goal';

  @override
  String get weeklyChallengesSection => 'Weekly challenges';

  @override
  String get unlockedAchievementsSection => 'Unlocked achievements';

  @override
  String get viewAllButton => 'View all';

  @override
  String get achievementBoardTitle => 'All achievements';

  @override
  String get noActiveChallenges => 'No active challenges';

  @override
  String get noActiveChallengesMessage =>
      'Your coach has not assigned any challenges yet. Start completing your workouts and meals to unlock automatic challenges.';

  @override
  String get lockedAchievementsHint => 'Complete challenges to unlock medals';

  @override
  String get noUnlockedAchievementsTitle => 'No achievements unlocked yet';

  @override
  String get noUnlockedAchievementsMessage =>
      'Complete challenges to unlock medals. You can view every available achievement.';

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
  String get sleepVeryLow => 'Very low sleep';

  @override
  String get sleepInsufficient => 'Insufficient sleep';

  @override
  String get sleepOptimal => 'Optimal sleep';

  @override
  String get sleepTooMuch => 'Too much sleep';

  @override
  String get bodyMeasurementsTitle => 'Body measurements';

  @override
  String get listViewToggle => 'List';

  @override
  String get bodyViewToggle => 'Body';

  @override
  String get frontViewLabel => 'Front';

  @override
  String get backViewLabel => 'Back';

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
  String seenEstimateApplied(String estimate, String asmi) {
    return 'SEEN estimate applied: $estimate (ASMI $asmi kg/m²)';
  }

  @override
  String get recapStartTitle => 'Weekly ReCap Form';

  @override
  String get recapStartDescription =>
      'Complete the four steps so your coach understands how your week went and can adjust your plan.';

  @override
  String get recapStartButton => 'Start';

  @override
  String get recapSendFormButton => 'Send form';

  @override
  String get recapReviewAndSendButton => 'Review and send';

  @override
  String get recapImprovementTitle => 'Help us improve';

  @override
  String get recapImprovementRatingsTitle => 'Ratings';

  @override
  String get recapImprovementRatingsSubtitle =>
      'Your feedback helps us improve the experience and support.';

  @override
  String get recapWhatCanWeImprove => 'What can we improve?';

  @override
  String get recapTellUsMore => 'Tell us more';

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
  String get supportContactDescription => 'Open the EXOM support page.';

  @override
  String get emailSupportOption => 'Email support';

  @override
  String get emailSupportOptionDescription =>
      'Prepare an external email for support.';

  @override
  String get serviceSupportEmailOption => 'Service questions';

  @override
  String get serviceSupportEmailDescription =>
      'Email exom.method@gmail.com for account access, service and EXOM Method questions.';

  @override
  String get technicalSupportEmailOption => 'Technical questions';

  @override
  String get technicalSupportEmailDescription =>
      'Email csroman.dev@gmail.com for app errors, installation or technical issues.';

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
  String get recommendedUpdateTitle => 'New version available';

  @override
  String get recommendedUpdateMessage =>
      'A recommended EXOM update is available. You can keep using the app, but we recommend installing the latest version.';

  @override
  String get requiredUpdateTitle => 'Update required';

  @override
  String get requiredUpdateMessage =>
      'Your EXOM version is no longer supported. Update the app to continue.';

  @override
  String get creditsOption => 'Credits';

  @override
  String get creditsOptionDescription => 'Product technology and stack';

  @override
  String get logOutButton => 'Log out';

  @override
  String get settingsPageTitle => 'Settings';

  @override
  String get updateStoreNotOpenedError => 'Could not open the app store.';

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
  String get reviewed => 'Reviewed';

  @override
  String get pending => 'Pending';

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

  @override
  String get restTimerTitle => 'Rest';

  @override
  String restTimerNextExercise(String name) {
    return 'Next: $name';
  }

  @override
  String get restTimerSkip => 'Skip';

  @override
  String get weightInputTitle => 'Weight used?';

  @override
  String get weightInputHint => 'e.g. 20 (optional)';

  @override
  String get weightInputSkip => 'Skip';

  @override
  String get weightInputSave => 'Save';

  @override
  String weightBadgeLabel(String weight) {
    return '$weight kg';
  }

  @override
  String get feedbackSelectImage => 'Image';

  @override
  String get feedbackSelectVideo => 'Video';

  @override
  String get feedbackFromCamera => 'From camera';

  @override
  String get feedbackFromGallery => 'From gallery';

  @override
  String get feedbackUploading => 'Uploading...';

  @override
  String get feedbackSendFromExercise => 'Send feedback';

  @override
  String get errorNetwork => 'Network error';

  @override
  String get errorAccountLocked => 'Account locked — contact your coach';

  @override
  String get errorSessionExpired => 'Session expired. Please log in again';

  @override
  String get errorForbidden => 'You don\'t have permission for this action';

  @override
  String get errorNotFound => 'Resource not found';

  @override
  String get errorServer => 'Server error. Try again later';

  @override
  String get retryButton => 'Retry';

  @override
  String get contactSupportButton => 'Contact support';

  @override
  String get viewOfflineButton => 'View offline';

  @override
  String get goToCalendarButton => 'Go to calendar';

  @override
  String get goHomeButton => 'Home';

  @override
  String get serverErrorTitle => 'Something went wrong';

  @override
  String get serverErrorMessage => 'The server couldn\'t process your request';

  @override
  String serverErrorMessageWithCode(String code) {
    return 'Error $code. The server couldn\'t process your request';
  }

  @override
  String get noConnectionTitle => 'No internet connection';

  @override
  String get noConnectionMessage => 'Check your connection and try again';

  @override
  String get notFoundTitle => 'Content not available';

  @override
  String get notFoundMessage =>
      'We couldn\'t find what you\'re looking for. It may have been removed or isn\'t available yet';

  @override
  String get selectedDateLabel => 'the selected date';

  @override
  String get measureNeck => 'Neck';

  @override
  String get measureShoulders => 'Shoulders';

  @override
  String get measureChest => 'Chest';

  @override
  String get measureArm => 'Arm';

  @override
  String get measureForearm => 'Forearm';

  @override
  String get leftSideLabel => 'Left';

  @override
  String get rightSideLabel => 'Right';

  @override
  String get leftSideShortLabel => 'Left';

  @override
  String get rightSideShortLabel => 'Right';

  @override
  String get measureWaist => 'Waist';

  @override
  String get measureHips => 'Hips';

  @override
  String get measureThigh => 'Thigh';

  @override
  String get measureCalf => 'Calf';

  @override
  String get noTrainingsAssigned => 'No trainings assigned';

  @override
  String get noTrainingsAssignedSubtitle =>
      'Your coach hasn\'t assigned a plan yet';

  @override
  String get noActivitiesThisMonth => 'No activities this month';

  @override
  String get noActivitiesThisMonthSubtitle => 'No trainings or diets scheduled';

  @override
  String get onboardingWelcomeTitle => 'Welcome to EXOM!';

  @override
  String get onboardingWelcomeDescription =>
      'Set up your profile in a few steps so your coach can personalize your plan.';

  @override
  String get onboardingStartButton => 'Get started';

  @override
  String get onboardingDoItLaterButton => 'Do it later';

  @override
  String get onboardingBasicsTitle => 'Basic info';

  @override
  String get onboardingFirstNameLabel => 'First name';

  @override
  String get onboardingLastNameLabel => 'Last name';

  @override
  String get onboardingBirthDateLabel => 'Date of birth';

  @override
  String get onboardingAvatarLabel => 'Profile photo (optional)';

  @override
  String get onboardingBodyTitle => 'Your body';

  @override
  String get onboardingHeightLabel => 'Height (cm)';

  @override
  String get onboardingWeightLabel => 'Weight (kg)';

  @override
  String get onboardingGoalsTitle => 'Your goals';

  @override
  String get onboardingLevelLabel => 'Level';

  @override
  String get onboardingMainGoalLabel => 'Main goal';

  @override
  String get onboardingMuscleMassGoalLabel => 'Muscle mass goal (kg, optional)';

  @override
  String get onboardingTargetCaloriesLabel => 'Target calories (optional)';

  @override
  String get onboardingFirstNameRequired => 'Enter your first name';

  @override
  String get onboardingLastNameRequired => 'Enter your last name';

  @override
  String get onboardingCompleteProfileButton => 'Complete profile';

  @override
  String get onboardingSummaryTitle => 'Summary';

  @override
  String get onboardingConfirmButton => 'Confirm';

  @override
  String get onboardingEditButton => 'Edit';

  @override
  String onboardingProgressComplete(int percent) {
    return 'Profile $percent% complete';
  }

  @override
  String get onboardingSkipButton => 'Skip';

  @override
  String get onboardingNextButton => 'Next';

  @override
  String get onboardingSubmittingMessage => 'Saving your profile...';

  @override
  String get onboardingSuccessMessage => 'Profile complete!';

  @override
  String get onboardingErrorMessage =>
      'Error saving profile. Please try again.';

  @override
  String get continueDraftRecap => 'Continue draft';

  @override
  String get recapAlreadySubmittedThisWeek =>
      'You already have a recap submitted this week';

  @override
  String get tutorialPromptTitle => 'Want a quick tour?';

  @override
  String get tutorialPromptDescription =>
      'We\'ll show you around the main sections of the app in just a few seconds.';

  @override
  String get tutorialStartButton => 'Start guide';

  @override
  String get tutorialSkipButton => 'Skip';

  @override
  String get tutorialHomeTitle => 'Home';

  @override
  String get tutorialHomeDesc =>
      'Your daily dashboard. See today\'s training, diet plan, and progress stats at a glance.';

  @override
  String get tutorialTrainingsTitle => 'Trainings';

  @override
  String get tutorialTrainingsDesc =>
      'View and complete your daily workouts. Track each exercise as you go.';

  @override
  String get tutorialDietsTitle => 'Diets';

  @override
  String get tutorialDietsDesc =>
      'Follow your personalized meal plan. Check off meals throughout the day.';

  @override
  String get tutorialCalendarTitle => 'Calendar';

  @override
  String get tutorialCalendarDesc =>
      'See your full schedule. Review past and upcoming trainings and meals.';

  @override
  String get tutorialChallengesTitle => 'Challenges';

  @override
  String get tutorialChallengesDesc =>
      'Earn achievements and track your streaks. Stay motivated with goals.';

  @override
  String get tutorialProfileTitle => 'Profile';

  @override
  String get tutorialProfileDesc =>
      'Tap the person icon in the top bar to view your profile, stats, and body metrics.';

  @override
  String get tutorialRecapTitle => 'Weekly Recap';

  @override
  String get tutorialRecapDesc =>
      'Open the menu (top-right) to find the weekly recap. Summarize your week for your coach.';

  @override
  String get tutorialFeedbackTitle => 'Feedback';

  @override
  String get tutorialFeedbackDesc =>
      'Also in the menu. Send questions, issues, or feedback directly to your coach.';

  @override
  String get tutorialNextButton => 'Next';

  @override
  String get tutorialDoneButton => 'Done';
}
