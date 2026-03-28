import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_progress_indicator.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_welcome_step.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_basics_step.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_body_step.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_goals_step.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_summary_step.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OnboardingBloc>()..add(const OnboardingStarted()),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView();

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  final _pageController = PageController();

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildLoadError(BuildContext context, OnboardingLoadError state) {
    void retry() {
      context.read<OnboardingBloc>().add(const OnboardingStarted());
    }

    final apiException = state.apiException;
    if (apiException?.isNetworkError == true) {
      return NoConnectionWidget(onRetry: retry);
    }
    if (apiException?.isServerError == true) {
      return ServerErrorWidget(
        errorCode: apiException!.statusCode.toString(),
        onRetry: retry,
      );
    }
    return ErrorWidget2(
      message: apiException != null
          ? localizedApiError(context, apiException)
          : AppLocalizations.of(context).onboardingErrorMessage,
      onRetry: retry,
    );
  }

  String _submitErrorMessage(
    BuildContext context,
    OnboardingSubmitError state,
  ) {
    final apiException = state.apiException;
    if (apiException != null) {
      return localizedApiError(context, apiException);
    }
    return AppLocalizations.of(context).onboardingErrorMessage;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return BlocListener<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingCompleted) {
          context.go('/');
        }
        if (state is OnboardingSubmitError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_submitErrorMessage(context, state)),
              backgroundColor: AppColors.error,
            ),
          );
        }
        if (state is OnboardingStepActive) {
          _goToPage(state.currentStep);
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: BlocBuilder<OnboardingBloc, OnboardingState>(
            builder: (context, state) {
              if (state is OnboardingLoading || state is OnboardingInitial) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is OnboardingLoadError) {
                return _buildLoadError(context, state);
              }

              if (state is OnboardingSubmitting) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(l10n.onboardingSubmittingMessage),
                    ],
                  ),
                );
              }

              if (state is OnboardingStepActive) {
                return Column(
                  children: [
                    // Progress indicator for steps 1-4
                    if (state.currentStep > 0) ...[
                      const SizedBox(height: 16),
                      OnboardingProgressIndicator(
                        currentStep: state.currentStep - 1,
                        totalSteps: state.totalSteps - 1,
                      ),
                    ],
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          // Step 0: Welcome
                          OnboardingWelcomeStep(
                            onStart: () => context.read<OnboardingBloc>().add(
                              const OnboardingStepCompleted(step: 0, data: {}),
                            ),
                            onSkip: () => context.read<OnboardingBloc>().add(
                              const OnboardingSkipped(),
                            ),
                          ),
                          // Step 1: Basics
                          OnboardingBasicsStep(
                            initialData: state.accumulatedData,
                            initialAvatarUrl: state.avatarUrl,
                            avatarUploading: state.avatarUploading,
                            onNext: (data) =>
                                context.read<OnboardingBloc>().add(
                                  OnboardingStepCompleted(step: 1, data: data),
                                ),
                            onSkip: () => context.read<OnboardingBloc>().add(
                              const OnboardingSkipped(),
                            ),
                            onAvatarPicked: (path) => context
                                .read<OnboardingBloc>()
                                .add(OnboardingAvatarPicked(path)),
                          ),
                          // Step 2: Body
                          OnboardingBodyStep(
                            initialData: state.accumulatedData,
                            onNext: (data) =>
                                context.read<OnboardingBloc>().add(
                                  OnboardingStepCompleted(step: 2, data: data),
                                ),
                            onSkip: () => context.read<OnboardingBloc>().add(
                              const OnboardingSkipped(),
                            ),
                          ),
                          // Step 3: Goals
                          OnboardingGoalsStep(
                            initialData: state.accumulatedData,
                            onNext: (data) =>
                                context.read<OnboardingBloc>().add(
                                  OnboardingStepCompleted(step: 3, data: data),
                                ),
                            onSkip: () => context.read<OnboardingBloc>().add(
                              const OnboardingSkipped(),
                            ),
                          ),
                          // Step 4: Summary
                          OnboardingSummaryStep(
                            accumulatedData: state.accumulatedData,
                            avatarUrl: state.avatarUrl,
                            onConfirm: () => context.read<OnboardingBloc>().add(
                              const OnboardingSubmitted(),
                            ),
                            onEditBasics: () => context
                                .read<OnboardingBloc>()
                                .add(const OnboardingStepSelected(1)),
                            onEditBody: () => context
                                .read<OnboardingBloc>()
                                .add(const OnboardingStepSelected(2)),
                            onEditGoals: () => context
                                .read<OnboardingBloc>()
                                .add(const OnboardingStepSelected(3)),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
