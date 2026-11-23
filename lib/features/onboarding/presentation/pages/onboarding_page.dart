import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_step_layout.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_welcome_step.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_basics_step.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_body_step.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_goals_step.dart';
import 'package:exom_app/features/onboarding/presentation/widgets/onboarding_summary_step.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  /// Key of the slot of [step] (0 welcome … 4 summary) while it is mounted;
  /// a step that is not painted is offstage.
  static Key stepKey(int step) => ValueKey<String>('onboarding-step-$step');

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

/// The steps are stacked and only the page changes which one is on screen.
/// A step stays mounted once it has been shown (the summary only while it is
/// painted, as before), so what was typed in a step survives going back
/// (D17-5) and forward without being sent; a step that is not painted is
/// offstage: no paint, taps, semantics or tickers.
///
/// A step change plays M9 with the two steps overlapped, as in the sketch:
/// from the tap, the step on screen fades out in [ExomMotion.stepExit]
/// towards the side the form leaves, while the new step enters from the side
/// the form moves to in [ExomMotion.step]; advancing also grows the new
/// segment of the progress rule ([ExomMotion.stepProgressRule]). There is no
/// frame without a step: the opacities painted add up to at least ~0.9
/// (round 5). Each step has its own controller (1 in place, 0 hidden), so a
/// change in mid-flight goes on from the current value of every step instead
/// of starting from 0. Reduced motion: a 100 ms crossfade, no offset.
///
/// The step that leaves takes no taps and is out of the semantics (M9); for
/// as long as a step is leaving the new one does not take taps either, so a
/// double tap on the action does not skip a step (the back arrow, outside
/// the steps, does take them).
///
/// The step change goes through the existing `OnboardingStepSelected` /
/// `OnboardingStepCompleted` events (the bloc is not changed). The system back
/// is not taken over: it keeps its behaviour of before.
class _OnboardingViewState extends State<_OnboardingView>
    with TickerProviderStateMixin {
  static const int _stepCount = 5;
  static const int _summaryStep = 4;

  /// Height of the top bar of the data steps (the welcome has none).
  static const double _topBarHeight = 48;

  /// One controller per step, its value is the opacity of the step: 1 in
  /// place, 0 hidden. Each change animates every step from its current value
  /// on the curve of its new direction (the enter curve towards 1 in
  /// [ExomMotion.step], the exit curve towards 0 in [ExomMotion.stepExit],
  /// both scaled to the distance left), so an interruption carries on from
  /// what is painted, without a jump, and the step that comes back rises at
  /// once instead of leaving the screen nearly empty.
  late final List<AnimationController> _steps = [
    for (var i = 0; i < _stepCount; i++)
      AnimationController(
        vsync: this,
        duration: ExomMotion.step,
        reverseDuration: ExomMotion.stepExit,
      )..addStatusListener(_onStepStatus),
  ];

  late final AnimationController _rule = AnimationController(
    vsync: this,
    value: 1,
    duration: ExomMotion.stepProgressRule,
  );
  late final CurvedAnimation _ruleCurve = CurvedAnimation(
    parent: _rule,
    curve: ExomMotion.stepProgressRuleCurve,
  );

  /// Side each step sits at when hidden: 1 the end, -1 the start. It only
  /// changes while the step is at rest (hidden or in place), so a change in
  /// mid-flight cannot make a step jump: it goes back the way it came.
  final List<double> _sides = List<double>.filled(_stepCount, 1);

  /// Steps shown at least once (kept mounted, see the class comment).
  final Set<int> _visited = {};

  /// Step on screen or entering (null before the first step state).
  int? _target;

  /// Step whose segment of the rule grows (the last one advanced to).
  int? _ruleStep;

  /// Last step state, painted while the profile is being saved (the summary
  /// stays on screen, D14-3).
  OnboardingStepActive? _lastActive;

  /// Save error kept above «Confirmar» until the next attempt (D14-3/8).
  OnboardingSubmitError? _submitError;

  void _onStepStatus(AnimationStatus status) {
    // A step that ends its exit goes offstage (or away, the summary).
    if (status == AnimationStatus.dismissed && mounted) setState(() {});
  }

  void _onStepActive(BuildContext context, OnboardingStepActive state) {
    _lastActive = state;
    final previous = _target;
    final step = state.currentStep;
    if (previous == step) return;
    final motion = ExomMotion.of(context);
    for (final controller in _steps) {
      controller
        ..duration = motion.step
        ..reverseDuration = ExomMotion.stepExit;
    }
    _rule.duration = motion.stepProgressRule;
    setState(() {
      _target = step;
      _visited.add(step);
    });
    if (previous == null && step == 0) {
      // The welcome appears as it did; any other first step (a restored one)
      // and every change enter with M9, advancing or going back.
      _steps[0].value = 1;
      return;
    }
    final advancing = previous == null || step > previous;
    for (var i = 0; i < _stepCount; i++) {
      final value = _steps[i].value;
      if (value > 0 && value < 1) continue;
      // The new step enters from the side the form moves to; the others
      // leave towards the opposite one.
      _sides[i] = (i == step) == advancing ? 1 : -1;
    }
    if (advancing && !motion.isReduced) {
      _ruleStep = step;
      _rule.forward(from: 0);
    } else if (motion.isReduced) {
      _rule.value = 1;
    }
    final enterCurve = motion.stepSlides ? ExomMotion.stepCurve : Curves.linear;
    final exitCurve = motion.stepSlides
        ? ExomMotion.sheetExitCurve
        : Curves.linear;
    for (var i = 0; i < _stepCount; i++) {
      if (i == step) {
        _steps[i].animateTo(1, curve: enterCurve);
      } else if (!_steps[i].isDismissed) {
        // Also a step that has just started entering (still at 0), as when
        // two changes arrive in the same frame.
        _steps[i].animateBack(0, curve: exitCurve);
      }
    }
  }

  @override
  void dispose() {
    _ruleCurve.dispose();
    _rule.dispose();
    for (final controller in _steps) {
      controller.dispose();
    }
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

  String _submitErrorTitle(BuildContext context, OnboardingSubmitError state) {
    final apiException = state.apiException;
    if (apiException != null) {
      return localizedApiError(context, apiException);
    }
    return AppLocalizations.of(context).onboardingSaveErrorTitle;
  }

  void _submit(BuildContext context) {
    // A new attempt starts: the previous error goes away at once.
    setState(() => _submitError = null);
    context.read<OnboardingBloc>().add(const OnboardingSubmitted());
  }

  void _select(BuildContext context, int step) {
    context.read<OnboardingBloc>().add(OnboardingStepSelected(step));
  }

  Widget _summary(
    BuildContext context,
    OnboardingStepActive state, {
    required bool busy,
  }) {
    final l10n = AppLocalizations.of(context);
    final error = _submitError;
    return OnboardingSummaryStep(
      accumulatedData: state.accumulatedData,
      avatarUrl: state.avatarUrl,
      busy: busy,
      errorTitle: error == null ? null : _submitErrorTitle(context, error),
      errorBody: error == null ? null : l10n.onboardingSaveErrorBody,
      onConfirm: () => _submit(context),
      onEditBasics: () => _select(context, 1),
      onEditBody: () => _select(context, 2),
      onEditGoals: () => _select(context, 3),
    );
  }

  /// Top bar of the data steps: the back arrow from step 2 on (D17-5). The
  /// bar keeps its height on step 1 so the header does not jump.
  Widget _topBar(BuildContext context, int step, {required bool enabled}) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    return SizedBox(
      height: 48,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: step >= 2
            ? Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: ExomSpacing.xs,
                ),
                child: IconButton(
                  key: const Key('onboarding-back'),
                  tooltip: l10n.onboardingPreviousStep,
                  icon: Icon(ExomIcons.back, color: palette.textPrimary),
                  onPressed: enabled ? () => _select(context, step - 1) : null,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _step(BuildContext context, OnboardingStepActive state, int step) {
    final bloc = context.read<OnboardingBloc>();
    void skip() => bloc.add(const OnboardingSkipped());
    return switch (step) {
      0 => OnboardingWelcomeStep(
        onStart: () =>
            bloc.add(const OnboardingStepCompleted(step: 0, data: {})),
        onSkip: skip,
      ),
      1 => OnboardingBasicsStep(
        initialData: state.accumulatedData,
        initialAvatarUrl: state.avatarUrl,
        avatarUploading: state.avatarUploading,
        onNext: (data) =>
            bloc.add(OnboardingStepCompleted(step: 1, data: data)),
        onSkip: skip,
        onAvatarPicked: (path) => bloc.add(OnboardingAvatarPicked(path)),
      ),
      2 => OnboardingBodyStep(
        initialData: state.accumulatedData,
        onNext: (data) =>
            bloc.add(OnboardingStepCompleted(step: 2, data: data)),
        onSkip: skip,
      ),
      3 => OnboardingGoalsStep(
        initialData: state.accumulatedData,
        onNext: (data) =>
            bloc.add(OnboardingStepCompleted(step: 3, data: data)),
        onSkip: skip,
      ),
      _ => _summary(context, state, busy: false),
    };
  }

  /// The stacked steps: the hidden ones offstage, the one on screen or
  /// entering painted last (its pinned footer covers the leaving one's).
  Widget _buildSteps(BuildContext context, OnboardingStepActive state) {
    final target = _target ?? state.currentStep;
    final shown = {..._visited, target};
    bool hidden(int i) => i != target && _steps[i].isDismissed;
    final leaving = shown.any((i) => i != target && !hidden(i));
    final order = [
      for (var i = 0; i < _stepCount; i++)
        if (i != target &&
            shown.contains(i) &&
            !(i == _summaryStep && hidden(i)))
          i,
      target,
    ];
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: leaving,
            child: Stack(
              children: [
                for (final i in order)
                  Positioned.fill(
                    key: OnboardingPage.stepKey(i),
                    top: i == 0 ? 0 : _topBarHeight,
                    child: _StepSlot(
                      hidden: hidden(i),
                      active: i == target,
                      child: OnboardingStepEntranceScope(
                        animation: _steps[i],
                        curved: _steps[i],
                        rule: i == _ruleStep
                            ? _ruleCurve
                            : kAlwaysCompleteAnimation,
                        direction: _sides[i],
                        leaving: i != target,
                        child: _step(context, state, i),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Bound to the step on screen or entering; the welcome is laid out
        // without it, so it does not jump while it leaves.
        if (target > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _topBar(context, state.currentStep, enabled: true),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingCompleted) {
          context.go('/');
        }
        if (state is OnboardingSubmitError) {
          setState(() => _submitError = state);
        }
        if (state is OnboardingStepActive) {
          _onStepActive(context, state);
        }
      },
      child: ExomStaticBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: BlocBuilder<OnboardingBloc, OnboardingState>(
              builder: (context, state) {
                if (state is OnboardingLoading || state is OnboardingInitial) {
                  return const _OnboardingLoadingView();
                }

                if (state is OnboardingLoadError) {
                  return _buildLoadError(context, state);
                }

                if (state is OnboardingSubmitError) {
                  // Delivered just before the restored step state: keep the
                  // summary painted instead of an empty frame.
                  final last = _lastActive;
                  if (last == null) return const SizedBox.shrink();
                  return Column(
                    children: [
                      _topBar(context, last.currentStep, enabled: false),
                      Expanded(child: _summary(context, last, busy: false)),
                    ],
                  );
                }

                if (state is OnboardingSubmitting) {
                  final last = _lastActive;
                  if (last == null) return const _OnboardingLoadingView();
                  // The summary stays while saving; only the lime button
                  // tells the work (sketch «Guardando»).
                  return Column(
                    children: [
                      _topBar(context, last.currentStep, enabled: false),
                      Expanded(child: _summary(context, last, busy: true)),
                    ],
                  );
                }

                if (state is OnboardingStepActive) {
                  return _buildSteps(context, state);
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// One stacked step. A [hidden] step keeps its state but is offstage (no
/// paint, taps, semantics or tickers); a step that is not [active] (it
/// leaves) is only painted: no taps and out of the semantics (L5-A4c), so
/// the screen reader reads and announces the new step only. Neither of the two
/// can hold the focus.
class _StepSlot extends StatelessWidget {
  const _StepSlot({
    required this.hidden,
    required this.active,
    required this.child,
  });

  final bool hidden;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: hidden,
      child: TickerMode(
        enabled: !hidden,
        child: IgnorePointer(
          ignoring: !active,
          // A hidden or leaving step cannot hold the primary focus (the
          // keyboard would stay open on a field that is no longer seen).
          child: ExcludeFocus(
            excluding: hidden || !active,
            child: ExcludeSemantics(excluding: !active, child: child),
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder shaped like a step: numeral, headline, rule and rows.
class _OnboardingLoadingView extends StatelessWidget {
  const _OnboardingLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        kOnboardingSidePadding,
        56,
        kOnboardingSidePadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExomSkeleton.numeral(),
          SizedBox(height: ExomSpacing.lg),
          ExomSkeleton.headline(),
          SizedBox(height: ExomSpacing.lg),
          ExomSkeleton.rule(),
          SizedBox(height: ExomSpacing.xxl),
          ExomSkeleton.row(),
          ExomSkeleton.row(),
        ],
      ),
    );
  }
}
