import 'dart:async';
import 'dart:math' as math;

import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_progress_rule.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/exom_step_transition.dart';
import 'package:exom_app/core/widgets/exom_sync_status.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/home/presentation/widgets/home_clock.dart';
import 'package:exom_app/features/home/presentation/widgets/home_headline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/features/recap/domain/entities/recap_entity.dart';
import 'package:exom_app/features/recap/presentation/bloc/recap_bloc.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_form_fields.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_start_view.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_step_general.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_step_improvement.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_step_nutrition.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_step_recovery.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_step_training.dart';
import 'package:exom_app/injection_container.dart';

class RecapPage extends StatelessWidget {
  const RecapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RecapBloc>()..add(const RecapLoadRequested()),
      child: const _RecapView(),
    );
  }
}

class _RecapView extends StatefulWidget {
  const _RecapView();

  @override
  State<_RecapView> createState() => _RecapViewState();
}

class _RecapViewState extends State<_RecapView> with TickerProviderStateMixin {
  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');

  /// The form was open since the list was last shown. Saving and sending go
  /// through `RecapLoading` before they fail, so the previous state alone
  /// cannot tell a failed save from a failed load of the list.
  bool _formOpen = false;

  /// «Enviado» is on screen: the server confirmed a send from the form and the
  /// user has not left the screen yet. Page-local, the bloc already holds the
  /// fresh list.
  bool _sentVisible = false;

  /// Week of the recap being sent, taken from the form that was open.
  ({DateTime start, DateTime end})? _formWeek;

  /// Week of the recap that was just sent, for the line of «Enviado».
  ({DateTime start, DateTime end})? _sentWeek;

  /// Leaving «Enviado» swaps the secondary button for the list's primary one
  /// in the same spot; a second tap of a double tap must not reach it, so the
  /// list footer ignores pointers while the body transition runs.
  bool _footerLocked = false;
  Timer? _footerLock;

  static const Duration _footerLockDuration = Duration(milliseconds: 250);

  /// Lime sweep that draws «Enviado» from top to bottom when it enters. At
  /// rest (value 1) it shows nothing; while it runs the screen takes no taps.
  late final AnimationController _sweep;

  /// Landing of the «5» once the sweep is over (secondary action). At rest
  /// (value 1) the numeral has its own size.
  late final AnimationController _land;

  /// The sweep that runs was started by «Enviado» and lands the numeral when
  /// it ends (not when it is cut short by leaving the screen).
  bool _landAfterSweep = false;

  /// A send was dispatched from the form and the bloc has not answered yet:
  /// while it is `RecapLoading` the page keeps showing [_lastForm] (with its
  /// footer busy) instead of the loading skeleton.
  bool _submitInFlight = false;

  /// Last form state received, shown while its send is in flight.
  RecapFormActive? _lastForm;

  /// The paper plane is still flying (it started on the tap and the form has
  /// not reported its end yet). Never true with reduced motion.
  bool _flightActive = false;

  /// The server confirmed the send while the plane was still flying: the form
  /// stays on screen until the flight ends, then «Enviado» takes over. The
  /// confirmation is already real; only its presentation waits.
  bool _sentPending = false;

  /// The plane landed: if the confirmation already arrived, show «Enviado».
  void _onFlightEnd() {
    _flightActive = false;
    if (!_sentPending || !mounted) return;
    _sentPending = false;
    setState(() {
      _sentVisible = true;
      _sentWeek = _formWeek;
    });
    _startSweep();
  }

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: _SentSweep.duration,
      value: 1,
    )..addStatusListener(_onSweepStatus);
    _land = AnimationController(
      vsync: this,
      duration: _RecapSentView.landDuration,
      value: 1,
    );
  }

  bool get _sweeping => _sweep.isAnimating;

  void _onSweepStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _landAfterSweep) {
      _landAfterSweep = false;
      _land.forward(from: 0);
    }
    if (mounted) setState(() {});
  }

  /// Starts the sweep of «Enviado» and, after it, the landing of the
  /// numeral; with reduced motion it appears at once, without either.
  void _startSweep() {
    if (ExomMotion.of(context).isReduced) {
      _landAfterSweep = false;
      _sweep.value = 1;
      _land.value = 1;
      return;
    }
    _landAfterSweep = true;
    _land.value = 0;
    _sweep.forward(from: 0);
  }

  void _dismissSent() {
    if (!_sentVisible) return;
    _landAfterSweep = false;
    _sweep.value = 1;
    _land.value = 1;
    _footerLock?.cancel();
    _footerLock = Timer(_footerLockDuration, () {
      if (!mounted) return;
      setState(() => _footerLocked = false);
    });
    setState(() {
      _sentVisible = false;
      _sentWeek = null;
      _footerLocked = true;
    });
  }

  @override
  void dispose() {
    _footerLock?.cancel();
    _sweep.dispose();
    _land.dispose();
    super.dispose();
  }

  /// Leaving the form towards the list: the reload that follows is a load of
  /// the list, so its failure is shown in line and not as a failed save.
  void _cancelForm(BuildContext context) {
    _formOpen = false;
    context.read<RecapBloc>().add(const RecapFormCancelled());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecapBloc, RecapState>(
      listener: (context, state) {
        final palette = context.exomPalette;

        // D14-3: a failed load of the list is shown in line (the error view);
        // the SnackBar is only for a save or send that fails in the form.
        final errorFromForm = state is RecapError && _formOpen;
        // The server confirmed a send that started in the form (read before
        // `_formOpen` is reset): «Enviado» takes the place of the list.
        final sentFromForm = state is RecapSubmitted && _formOpen;
        if (state is RecapFormActive) {
          _flightActive = false;
          _sentPending = false;
          _formOpen = true;
          _formWeek = _weekOf(state.formData);
          _lastForm = state;
        } else if (state is! RecapLoading) {
          _formOpen = false;
        }
        // The send in flight ends with any answer of the bloc.
        if (state is! RecapLoading) _submitInFlight = false;

        if (_sentPending && state is! RecapSubmitted) _sentPending = false;
        if (state is RecapError) _flightActive = false;

        if (sentFromForm && _flightActive) {
          // The plane is still flying: wait for it (at most its remaining
          // flight) instead of cutting it with «Enviado».
          setState(() => _sentPending = true);
        } else if (sentFromForm) {
          setState(() {
            _sentVisible = true;
            _sentWeek = _formWeek;
          });
          _startSweep();
        } else if (_sentVisible && state is! RecapListLoaded) {
          _dismissSent();
        }

        if (errorFromForm) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizedErrorTextOf(
                  context,
                  state.message,
                  fallback: (l10n) => l10n.recapSaveError,
                ),
                style: TextStyle(color: palette.background),
              ),
              backgroundColor: palette.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ExomRadius.control),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        // While its send is in flight the form stays on screen (the bloc is
        // `RecapLoading`), so the plane is seen leaving and the button turns
        // busy in place.
        final submitting =
            _lastForm != null &&
            ((state is RecapLoading && _submitInFlight) || _sentPending);
        final formState = state is RecapFormActive
            ? state
            : submitting
            ? _lastForm
            : null;
        final isFormActive = formState != null;
        final showSent = _sentVisible && state is RecapListLoaded;
        final palette = context.exomPalette;
        final l10n = AppLocalizations.of(context);

        final page = ExomStaticBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            // Sketch C3: on the list the bar only carries «Volver» and the
            // reload action; the screen title is the first line of the body.
            appBar: AppBar(
              title: showSent
                  ? null
                  : isFormActive
                  ? Text(
                      formState.step == 5
                          ? l10n.recapImprovementTitle
                          : formState.recapId == null
                          ? l10n.newRecap
                          : l10n.editRecap,
                    )
                  : null,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              leading: showSent
                  ? IgnorePointer(
                      ignoring: _sweeping,
                      child: IconButton(
                        key: const ValueKey('recap-sent-close'),
                        onPressed: _dismissSent,
                        tooltip: l10n.recapSentClose,
                        icon: Icon(ExomIcons.close, color: palette.textPrimary),
                      ),
                    )
                  : isFormActive
                  ? IgnorePointer(
                      // The send is already dispatched: nothing to cancel.
                      ignoring: submitting,
                      child: IconButton(
                        onPressed: () => _cancelForm(context),
                        tooltip: l10n.cancel,
                        icon: Icon(ExomIcons.close, color: palette.textPrimary),
                      ),
                    )
                  : context.canPop()
                  ? IconButton(
                      onPressed: () => context.pop(),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      icon: Icon(ExomIcons.back, color: palette.textPrimary),
                    )
                  : null,
              actions: isFormActive || showSent
                  ? null
                  : [
                      IconButton(
                        onPressed: () => context.read<RecapBloc>().add(
                          const RecapLoadRequested(),
                        ),
                        tooltip: l10n.retry,
                        icon: Icon(ExomIcons.retry, color: palette.textPrimary),
                      ),
                    ],
            ),
            body: _SentSweep(
              sweep: _sweep,
              child: Column(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: _bodyTransition,
                      // «Enviado» replaces what was there at once: the sweep
                      // draws it over the plain background.
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.center,
                        children: [if (!showSent) ...previous, ?current],
                      ),
                      child: _buildBody(context, state, formState),
                    ),
                  ),
                  if (showSent)
                    _buildSentFooter(context)
                  else if (state is RecapListLoaded)
                    IgnorePointer(
                      ignoring: _footerLocked,
                      child: _buildFooter(context, state.recaps),
                    ),
                ],
              ),
            ),
          ),
        );
        return PopScope(
          canPop: !showSent,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _dismissSent();
          },
          child: page,
        );
      },
    );
  }

  /// Fade of the body switcher; «Enviado» does not fade in (the sweep, or
  /// nothing with reduced motion, brings it) but still fades out when leaving.
  static Widget _bodyTransition(Widget child, Animation<double> animation) {
    if (child.key == const ValueKey('recap-sent')) {
      return _FadeOutOnly(animation: animation, child: child);
    }
    return FadeTransition(opacity: animation, child: child);
  }

  /// Pinned action of the list (D14-1): «Nuevo recap», «Continuar borrador»
  /// (draft of this week) or «Crear mi primer recap» (empty list). With a recap
  /// already sent this week and no draft the action is blocked: no lime, and
  /// the reason in line above it instead of a SnackBar.
  Widget _buildFooter(BuildContext context, List<RecapEntity> recaps) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final currentWeekDraft = _findCurrentWeekDraft(recaps);
    final isBlocked =
        _hasSubmittedRecapThisWeek(recaps) && currentWeekDraft == null;
    final label = currentWeekDraft != null
        ? l10n.continueDraftRecap
        : recaps.isEmpty
        ? l10n.createMyFirstRecap
        : l10n.newRecap;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ExomPinnedFooter(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBlocked) ...[
            Text(
              l10n.recapAlreadySubmittedThisWeek,
              style: TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                fontSize: 14,
                height: 1.4,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: ExomSpacing.sm),
          ],
          ExomPrimaryButton(
            key: const ValueKey('recap-new'),
            label: label,
            trailingIcon: ExomIcons.forward,
            onPressed: isBlocked
                ? null
                : () {
                    if (currentWeekDraft != null) {
                      _openDraftRecap(currentWeekDraft);
                      return;
                    }
                    context.read<RecapBloc>().add(const RecapCreateRequested());
                  },
          ),
        ],
      ),
    );
  }

  /// Pinned action of «Enviado»: a secondary button, not the lime one.
  Widget _buildSentFooter(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ExomPinnedFooter(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
      child: ExomSecondaryButton(
        key: const ValueKey('recap-sent-back'),
        label: AppLocalizations.of(context).recapBackToRecaps,
        onPressed: _dismissSent,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    RecapState state,
    RecapFormActive? form,
  ) {
    if (_sentVisible && state is RecapListLoaded) {
      return _RecapSentView(
        key: const ValueKey('recap-sent'),
        weekLine: _sentWeekLine(context),
        landing: _land,
      );
    }

    if (form != null) {
      return _RecapFormView(
        key: const ValueKey('recap-form'),
        state: form,
        submitting: state is RecapLoading || _sentPending,
        onFieldChanged: (field, value) => context.read<RecapBloc>().add(
          RecapFieldUpdated(field: field, value: value),
        ),
        onStepChanged: (step) =>
            context.read<RecapBloc>().add(RecapStepChanged(step)),
        onSaveDraft: () =>
            context.read<RecapBloc>().add(const RecapSaveRequested()),
        // Dispatched on the tap itself; the flight of the icon is feedback.
        onSubmit: () {
          _submitInFlight = true;
          _flightActive = !ExomMotion.of(context).isReduced;
          context.read<RecapBloc>().add(
            RecapSubmitRequested(recapId: form.recapId),
          );
        },
        onCancel: () => _cancelForm(context),
        onFlightEnd: _onFlightEnd,
        formatWeekRange: _formatWeekRange,
      );
    }

    if (state is RecapLoading || state is RecapInitial) {
      return _RecapLoadingView(
        key: const ValueKey('recap-loading'),
        header: _buildListHeader(context),
      );
    }

    if (state is RecapListLoaded) {
      return _RecapListView(
        key: const ValueKey('recap-list'),
        header: _buildListHeader(context),
        recaps: state.recaps,
        onRefresh: () async {
          context.read<RecapBloc>().add(const RecapLoadRequested());
        },
        onOpenRecap: (recap) async {
          if (!recap.isDraft) {
            await context.push(AppRoutes.recapDetail(recap.id));
            if (!context.mounted) return;

            context.read<RecapBloc>().add(const RecapLoadRequested());
            return;
          }

          context.read<RecapBloc>().add(
            RecapFormStarted(
              recapId: recap.id,
              initialData: _buildInitialData(recap),
            ),
          );
        },
        formatWeekRange: (recap) => _formatWeekRange(_buildInitialData(recap)),
      );
    }

    if (state is RecapError) {
      return _RecapErrorView(
        key: const ValueKey('recap-error'),
        header: _buildListHeader(context),
        message: localizedErrorTextOf(
          context,
          state.message,
          fallback: (l10n) => l10n.recapLoadError,
        ),
        onRetry: () =>
            context.read<RecapBloc>().add(const RecapLoadRequested()),
      );
    }

    return const SizedBox.shrink(key: ValueKey('recap-empty'));
  }

  /// Title and current week (sketch `.t1` + `.sec`), shared by every state of
  /// the list. The week comes from the screen clock ([HomeClock]).
  Widget _buildListHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final languageCode = Localizations.localeOf(context).languageCode;
    final today = _today(context);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final format = DateFormat.MMMMd(languageCode);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeTitle(l10n.weeklyRecapTitle),
          const SizedBox(height: ExomSpacing.sm),
          Text(
            l10n.recapListWeekSubtitle(
              format.format(weekStart),
              format.format(weekEnd),
            ),
            style: TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              fontSize: 15,
              height: 1.35,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  DateTime _today(BuildContext context) => HomeClock.todayOf(context);

  /// Week of a form's data, or null when it carries no valid dates.
  ({DateTime start, DateTime end})? _weekOf(Map<String, dynamic> formData) {
    final start = DateTime.tryParse('${formData['week_start_date'] ?? ''}');
    final end = DateTime.tryParse('${formData['week_end_date'] ?? ''}');
    if (start == null || end == null) return null;
    return (start: start, end: end);
  }

  /// «Semana del … al …» of the recap that was sent, formatted like the rows
  /// of the list header; null when the week is not known.
  String? _sentWeekLine(BuildContext context) {
    final week = _sentWeek;
    if (week == null) return null;
    final format = DateFormat.MMMMd(
      Localizations.localeOf(context).languageCode,
    );
    return AppLocalizations.of(
      context,
    ).recapListWeekSubtitle(format.format(week.start), format.format(week.end));
  }

  RecapEntity? _findCurrentWeekDraft(List<RecapEntity> recaps) {
    for (final recap in recaps) {
      if (_isCurrentWeekRecap(recap) && recap.isDraft) {
        return recap;
      }
    }
    return null;
  }

  bool _hasSubmittedRecapThisWeek(List<RecapEntity> recaps) {
    for (final recap in recaps) {
      if (_isCurrentWeekRecap(recap) && !recap.isDraft) {
        return true;
      }
    }
    return false;
  }

  bool _isCurrentWeekRecap(RecapEntity recap) {
    final today = _today(context);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    return _isSameDate(recap.weekStartDate, weekStart) &&
        _isSameDate(recap.weekEndDate, weekEnd);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _openDraftRecap(RecapEntity draft) {
    context.read<RecapBloc>().add(
      RecapFormStarted(
        recapId: draft.id,
        initialData: _buildInitialData(draft),
      ),
    );
  }

  Map<String, dynamic> _buildInitialData(RecapEntity recap) {
    return {
      'week_start_date': _apiDateFormat.format(recap.weekStartDate),
      'week_end_date': _apiDateFormat.format(recap.weekEndDate),
      'training_effort': recap.trainingEffort,
      'training_sessions': recap.trainingSessions,
      'average_daily_steps': recap.averageDailySteps,
      'training_progress': recap.trainingProgress,
      'training_notes': recap.trainingNotes,
      'nutrition_quality': recap.nutritionQuality,
      'hydration_enabled': recap.hydrationEnabled,
      'hydration_level': recap.hydrationLevel,
      'food_quality': recap.foodQuality,
      'nutrition_notes': recap.nutritionNotes,
      'sleep_hours_range': recap.sleepHoursRange,
      'fatigue_level': recap.fatigueLevel,
      'muscle_pain_zones': List<String>.from(recap.musclePainZones),
      'pain_intensity': recap.painIntensity,
      'recovery_notes': recap.recoveryNotes,
      'mood': recap.mood,
      'stress_enabled': recap.stressEnabled,
      'stress_level': recap.stressLevel,
      'hunger_level': recap.hungerLevel,
      'energy_level': recap.energyLevel,
      'digestion_level': recap.digestionLevel,
      'general_notes': recap.generalNotes,
      'improvement_app_rating': recap.improvementAppRating,
      'improvement_service_rating': recap.improvementServiceRating,
      'improvement_areas': List<String>.from(recap.improvementAreas),
      'improvement_feedback_text': recap.improvementFeedbackText,
    }..removeWhere((_, value) => value == null);
  }

  String _formatWeekRange(Map<String, dynamic> formData) {
    final l10n = AppLocalizations.of(context);
    final start = formData['week_start_date'] as String?;
    final end = formData['week_end_date'] as String?;
    if (start == null || end == null) {
      return l10n.weekWithoutDates;
    }

    final startDate = DateTime.tryParse(start);
    final endDate = DateTime.tryParse(end);
    if (startDate == null || endDate == null) {
      return l10n.weekWithoutDates;
    }

    final format = DateFormat(
      'dd MMM',
      Localizations.localeOf(context).languageCode,
    );
    return '${format.format(startDate)} - ${format.format(endDate)}';
  }
}

/// Fades [child] out when [animation] runs in reverse; entering it is opaque.
class _FadeOutOnly extends AnimatedWidget {
  const _FadeOutOnly({
    required Animation<double> animation,
    required this.child,
  }) : super(listenable: animation);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final opacity = animation.status == AnimationStatus.reverse
        ? animation.value
        : 1.0;
    return Opacity(opacity: opacity, child: child);
  }
}

/// Entry of «Enviado» (L5-C5b): in 300 ms (slow in and out) a 6 px lime band
/// travels from the top of the body to the bottom of the pinned footer; above
/// it the screen is drawn, below it only the page background shows. It does
/// not stop at the bottom: it fades out over the last fifth of the body
/// (follow-through), fully transparent when it reaches the bottom edge. While it runs the screen takes no taps. At rest (value 1)
/// [child] is shown as is.
class _SentSweep extends StatelessWidget {
  const _SentSweep({required this.sweep, required this.child});

  final AnimationController sweep;
  final Widget child;

  static const Duration duration = Duration(milliseconds: 300);
  static const Curve _curve = Curves.easeInOutCubic;
  static const double _band = 6;

  /// Fraction of the body height where the band starts fading out.
  static const double _fadeStart = 0.8;

  @override
  Widget build(BuildContext context) {
    final lime = context.exomPalette.data;
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: sweep,
        child: child,
        builder: (context, content) {
          final running = sweep.isAnimating;
          final height = constraints.maxHeight;
          final bottom = _curve.transform(sweep.value) * height;
          final top = bottom - _band;
          final fadeStart = height * _fadeStart;
          final fade = height > fadeStart
              ? ((bottom - fadeStart) / (height - fadeStart)).clamp(0.0, 1.0)
              : 0.0;
          return Stack(
            fit: StackFit.passthrough,
            children: [
              ClipRect(
                clipper: _TopClipper(math.min(bottom, height)),
                clipBehavior: running ? Clip.hardEdge : Clip.none,
                child: IgnorePointer(ignoring: running, child: content),
              ),
              if (running)
                Positioned(
                  key: const ValueKey('recap-sent-sweep'),
                  top: top,
                  left: 0,
                  right: 0,
                  height: _band,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 1 - fade,
                      child: ColoredBox(color: lime),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TopClipper extends CustomClipper<Rect> {
  const _TopClipper(this.bottom);

  final double bottom;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, 0, size.width, bottom);

  @override
  bool shouldReclip(_TopClipper oldClipper) => oldClipper.bottom != bottom;
}

/// Loading: the header and skeleton rows with the shape of the final rows.
class _RecapLoadingView extends StatelessWidget {
  const _RecapLoadingView({super.key, required this.header});

  final Widget header;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        header,
        const SizedBox(height: ExomSpacing.xxl),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              ExomSkeleton.row(),
              ExomSkeleton.row(),
              ExomSkeleton.row(),
              ExomSkeleton.row(),
            ],
          ),
        ),
      ],
    );
  }
}

/// «Enviado» (L5-C5b, sketch «C4 · (b) Enviado»): the milestone numeral on a
/// plain band, the confirmed send in words, the week and the note of the
/// trainer. The action to leave is pinned by the page.
///
/// After the sweep the «5» lands ([landing], 180 ms, ease-out): a small squash
/// from 1.06 through 0.98 to its own size, on its baseline.
class _RecapSentView extends StatelessWidget {
  const _RecapSentView({
    super.key,
    required this.weekLine,
    required this.landing,
  });

  /// «Semana del … al …»; null when the week of the recap is not known.
  final String? weekLine;

  /// Landing of the numeral; at 1 it has its own size.
  final Animation<double> landing;

  static const int _steps = 5;
  static const Duration landDuration = Duration(milliseconds: 180);
  static final Animatable<double> _landScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.06, end: 0.98), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 0.98, end: 1.0), weight: 1),
  ]).chain(CurveTween(curve: Curves.easeOut));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final line = weekLine;
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        // Plain band, like the milestones of «Retos» (L5-D40): no crossed bands.
        ExomBand(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ExcludeSemantics(
                child: ScaleTransition(
                  key: const ValueKey('recap-sent-numeral-land'),
                  scale: landing.drive(_landScale),
                  alignment: AlignmentDirectional.bottomStart.resolve(
                    Directionality.of(context),
                  ),
                  child: ExomNumeral(
                    value: '$_steps',
                    size: ExomNumeralSize.hero140,
                    isData: false,
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, ExomSpacing.md, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ExomKicker(l10n.recapSentKicker),
              ),
              const SizedBox(height: ExomSpacing.md),
              ExomTwoLineHeadline(
                first: l10n.recapSentTitleFirst,
                second: l10n.recapSentTitleSecond,
                size: ExomHeadlineSize.screen,
              ),
              const SizedBox(height: ExomSpacing.md),
              Semantics(
                container: true,
                label: l10n.exomStepOf(_steps, _steps),
                child: const ExcludeSemantics(
                  child: ExomProgressRule(
                    value: 1,
                    thickness: ExomRule.bar,
                    segments: _steps,
                  ),
                ),
              ),
              if (line != null) ...[
                const SizedBox(height: ExomSpacing.md),
                Text(
                  line,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFontFamily,
                    fontSize: 15,
                    height: 1.35,
                    color: palette.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: ExomSpacing.md),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ExomSyncStatus(
                  state: ExomSyncState.confirmada,
                  label: l10n.recapSentStatus,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ExomSpacing.xxl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ExomCoachBlock(
            author: l10n.recapListCoachAuthor,
            text: l10n.recapSentCoach,
            avatar: kRecapCoachAvatar,
          ),
        ),
      ],
    );
  }
}

/// The list: header, the count of new trainer comments (or the headline alone)
/// and one row per week. Empty, the invitation of the trainer.
class _RecapListView extends StatelessWidget {
  final Widget header;
  final List<RecapEntity> recaps;
  final Future<void> Function() onRefresh;
  final Future<void> Function(RecapEntity recap) onOpenRecap;
  final String Function(RecapEntity recap) formatWeekRange;

  const _RecapListView({
    super.key,
    required this.header,
    required this.recaps,
    required this.onRefresh,
    required this.onOpenRecap,
    required this.formatWeekRange,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    if (recaps.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          header,
          const SizedBox(height: ExomSpacing.sm),
          ExomEmptyState(
            first: l10n.recapListEmptyHeadlineFirst,
            second: l10n.recapListEmptyHeadlineSecond,
            lead: l10n.youHaveNotSentAnyRecapYet,
            body: l10n.useThisSpaceToSummarizeYourWeek,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ExomCoachBlock(
              // D16: the model carries no trainer name.
              author: l10n.recapListCoachAuthor,
              text: l10n.recapListEmptyCoachText,
              avatar: kRecapCoachAvatar,
            ),
          ),
        ],
      );
    }

    final unread = recaps
        .where((recap) => recap.hasUnreadClientFeedback)
        .length;
    final trioNeeded = _RecapTrio.neededWidth(context, [
      for (final recap in recaps) _RecapWeekRow.trioItems(l10n, recap),
    ]);

    return RefreshIndicator(
      color: palette.primary,
      backgroundColor: palette.surface,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          header,
          const SizedBox(height: ExomSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: unread > 0
                ? _UnreadHero(
                    value: NumberFormat.decimalPattern(
                      l10n.localeName,
                    ).format(unread),
                    label: l10n.recapListNewCommentsCount(unread),
                  )
                : ExomTwoLineHeadline(
                    first: l10n.recapListHeadlineFirst,
                    second: l10n.recapListHeadlineSecond,
                  ),
          ),
          const SizedBox(height: ExomSpacing.xxl),
          ExomFlatRowGroup(
            children: [
              for (final recap in recaps)
                _RecapWeekRow(
                  key: ValueKey('recap-row-${recap.id}'),
                  recap: recap,
                  weekLabel: formatWeekRange(recap),
                  trioNeeded: trioNeeded,
                  onTap: () async {
                    await onOpenRecap(recap);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hero of the list with unread trainer comments: the headline first and, under
/// it, the numeral with its label stuck below, read together as one node
/// («1 comentario nuevo de tu entrenador»), so the headline never sits between
/// the figure and what it counts.
class _UnreadHero extends StatelessWidget {
  const _UnreadHero({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExomTwoLineHeadline(
          first: l10n.recapListHeadlineFirst,
          second: l10n.recapListHeadlineSecond,
        ),
        const SizedBox(height: ExomSpacing.md),
        Semantics(
          key: const ValueKey('recap-unread-hero'),
          container: true,
          label: '$value $label',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExomNumeral(value: value, size: ExomNumeralSize.hero96),
              const SizedBox(height: ExomSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFontFamily,
                  fontSize: 14,
                  height: 1.35,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One week (sketch `.x-row`): its range, its state, three values and a
/// chevron. A recap with a new trainer comment is a featured block with the
/// notice under the row (`.x-feat`).
class _RecapWeekRow extends StatelessWidget {
  final RecapEntity recap;
  final String weekLabel;
  final VoidCallback onTap;

  /// Widest word of the whole list, so every row shares its trio columns.
  final double trioNeeded;

  const _RecapWeekRow({
    super.key,
    required this.recap,
    required this.weekLabel,
    required this.onTap,
    required this.trioNeeded,
  });

  /// Label and raw value of the three cells of a week.
  static List<(String, String?)> trioItems(
    AppLocalizations l10n,
    RecapEntity recap,
  ) => [
    (l10n.recapTraining, recap.trainingProgress),
    (l10n.recapNutrition, recap.nutritionQuality),
    (l10n.mood, recap.mood),
  ];

  static const EdgeInsetsGeometry _padding = EdgeInsetsDirectional.fromSTEB(
    20,
    12,
    12,
    12,
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final featured = recap.hasUnreadClientFeedback;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    weekLabel,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFontFamily,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: palette.textPrimary,
                    ),
                  ),
                  _statusOf(context),
                ],
              ),
              const SizedBox(height: 6),
              _RecapTrio(items: trioItems(l10n, recap), needed: trioNeeded),
            ],
          ),
        ),
        Icon(ExomIcons.next, size: 22, color: palette.textSecondary),
      ],
    );

    final row = MergeSemantics(
      child: Semantics(
        button: true,
        child: featured
            ? _FeaturedRowSurface(
                onTap: onTap,
                padding: _padding,
                child: content,
              )
            : ExomRowSurface(
                onTap: onTap,
                minHeight: 72,
                padding: _padding,
                child: content,
              ),
      ),
    );

    if (!featured) return row;
    // The bar belongs to its row: 16 dp of air above it (plus the 12 dp of the
    // row before) and none between it and the row's own padding (12 dp).
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ExomFeatureBlock(
        topPadding: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            row,
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: ExcludeSemantics(
                      child: Icon(
                        ExomIcons.notifications,
                        size: MediaQuery.textScalerOf(context).scale(18),
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.recapNewCoachComment,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// D19: the list comes from the server, so a sent («Enviado») and a reviewed
  /// recap are both confirmed (text colour with a check, never the «sending»
  /// cloud, which means «uploading now»); a draft is pending (clock).
  Widget _statusOf(BuildContext context) {
    final state = switch (recap.status) {
      'REVIEWED' || 'SUBMITTED' => ExomSyncState.confirmada,
      _ => ExomSyncState.pendiente,
    };
    return ExomSyncStatus(
      state: state,
      label: recapCopy(context, recap.status),
    );
  }
}

/// Row surface of a featured recap: like [ExomRowSurface] without the top
/// hairline, which the bar of the featured block replaces.
class _FeaturedRowSurface extends StatelessWidget {
  const _FeaturedRowSurface({
    required this.child,
    required this.onTap,
    required this.padding,
  });

  final Widget child;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: palette.surfaceElevated,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// The three values of a week (`.c-trio`): label and value per cell, in as many
/// columns as the width allows for the widest word of the whole list (measured
/// once, with the real styles and the text scaler), so every row of the list
/// shares its columns and no word is ever split.
class _RecapTrio extends StatelessWidget {
  const _RecapTrio({required this.items, required this.needed});

  /// Label and raw value; a null or blank value is «Sin valorar».
  final List<(String, String?)> items;

  /// Width of the longest word of every visible row, from [neededWidth].
  final double needed;

  static const double _gap = 12;

  static TextStyle _labelStyle(ExomThemePalette palette) => TextStyle(
    fontFamily: AppTheme.bodyFontFamily,
    fontSize: 13,
    height: 1.3,
    color: palette.textSecondary,
  );

  static TextStyle _notRatedStyle(ExomThemePalette palette) => TextStyle(
    fontFamily: AppTheme.bodyFontFamily,
    fontSize: 15,
    height: 1.35,
    color: palette.textSecondary,
  );

  static TextStyle _valueStyle(ExomThemePalette palette) => TextStyle(
    fontFamily: AppTheme.displayFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1,
    letterSpacing: -0.24,
    color: palette.textPrimary,
  );

  static List<(String, String?)> _shown(
    BuildContext context,
    List<(String, String?)> items,
  ) => [
    for (final (label, value) in items)
      (
        label,
        (value == null || value.trim().isEmpty)
            ? null
            : recapCopy(context, value).toUpperCase(),
      ),
  ];

  /// Width of the longest word among the cells of all [rows].
  static double neededWidth(
    BuildContext context,
    Iterable<List<(String, String?)>> rows,
  ) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final labelStyle = _labelStyle(palette);
    final notRatedStyle = _notRatedStyle(palette);
    final valueStyle = _valueStyle(palette);

    // Words split on plain whitespace only: a no-break space keeps its words.
    double longestWord(String text, TextStyle style) {
      var longest = 0.0;
      for (final word in text.split(RegExp(r'[ \t\n]+'))) {
        if (word.isEmpty) continue;
        final painter = TextPainter(
          text: TextSpan(text: word, style: style),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        longest = math.max(longest, painter.width);
        painter.dispose();
      }
      return longest;
    }

    var needed = 0.0;
    for (final row in rows) {
      for (final (label, value) in _shown(context, row)) {
        needed = math.max(needed, longestWord(label, labelStyle));
        needed = math.max(
          needed,
          value == null
              ? longestWord(l10n.recapListNotRated, notRatedStyle)
              : longestWord(value, valueStyle),
        );
      }
    }
    return needed;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final labelStyle = _labelStyle(palette);
    final notRatedStyle = _notRatedStyle(palette);
    final valueStyle = _valueStyle(palette);
    final shown = _shown(context, items);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Columns are as many as every word fits in whole; never a split word.
        var columns = items.length;
        while (columns > 1 &&
            (width - _gap * (columns - 1)) / columns < needed + 1) {
          columns--;
        }
        final cell = (width - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: ExomSpacing.sm,
          children: [
            for (final (label, value) in shown)
              SizedBox(
                width: cell,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: labelStyle),
                    if (value == null)
                      Text(l10n.recapListNotRated, style: notRatedStyle)
                    else
                      Text(value, style: valueStyle),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Load error in line (sketch C3 «Error»): headline with the second line in the
/// error colour, the cause and «Reintentar».
class _RecapErrorView extends StatelessWidget {
  const _RecapErrorView({
    super.key,
    required this.header,
    required this.message,
    required this.onRetry,
  });

  final Widget header;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        header,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExomTwoLineHeadline(
                first: l10n.recapListErrorHeadlineFirst,
                second: l10n.recapListErrorHeadlineSecond,
                isError: true,
              ),
              const SizedBox(height: 14),
              ExomInlineMessage(
                kind: ExomMessageKind.error,
                title: l10n.couldNotLoadRecap,
                body: message,
              ),
              const SizedBox(height: 14),
              ExomSecondaryButton(
                key: const ValueKey('recap-retry'),
                label: l10n.retry,
                icon: ExomIcons.retry,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The step form (L5-C5a, sketch «C4 · Recap, formulario por pasos»): the start
/// view and the five steps inside an [ExomStepTransition] (M9), with the
/// action of the step pinned below. A failed save or send still shows its own
/// SnackBar (it is not a validation); an invalid value is explained under its
/// field and in a line above the buttons.
///
/// «ENVIAR RECAP» (L5-C5b): the send is dispatched on the tap, once. From then
/// on the form takes no taps and the paper plane flies up out of the button as
/// feedback (drawn in the overlay, so no footer clips it). While the send is in
/// flight ([submitting]) the button turns busy after
/// [ExomMotion.busyIndicatorDelay]. With reduced motion there is no flight.
class _RecapFormView extends StatefulWidget {
  final RecapFormActive state;
  final void Function(String field, dynamic value) onFieldChanged;
  final ValueChanged<int> onStepChanged;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final String Function(Map<String, dynamic> formData) formatWeekRange;

  /// The plane finished its flight.
  final VoidCallback onFlightEnd;

  /// The send of this form is in flight (the bloc has not answered yet).
  final bool submitting;

  const _RecapFormView({
    super.key,
    required this.state,
    required this.onFieldChanged,
    required this.onStepChanged,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onCancel,
    required this.formatWeekRange,
    required this.onFlightEnd,
    this.submitting = false,
  });

  @override
  State<_RecapFormView> createState() => _RecapFormViewState();
}

class _RecapFormViewState extends State<_RecapFormView>
    with SingleTickerProviderStateMixin {
  static const int _stepStart = 0;
  static const int _stepImprovement = 5;
  static const Key _sendIconKey = ValueKey('recap-send-icon');

  late final AnimationController _flight;
  final LayerLink _sendSlot = LayerLink();
  final OverlayPortalController _plane = OverlayPortalController();

  /// The send was tapped: the form ignores taps from then on.
  bool _sending = false;

  /// The plane left its slot in the button (not with reduced motion).
  bool _planeLaunched = false;

  /// [ExomMotion.busyIndicatorDelay] passed since the tap: if the send is
  /// still in flight the button shows it is busy.
  bool _busyDelayPassed = false;
  Timer? _busyDelay;

  RecapFormActive get state => widget.state;
  ValueChanged<int> get onStepChanged => widget.onStepChanged;
  void Function(String field, dynamic value) get onFieldChanged =>
      widget.onFieldChanged;

  bool get _isStartStep => state.step == _stepStart;
  bool get _isImprovementStep => state.step == _stepImprovement;
  bool get _hasValidationErrors =>
      !isValidRecapAverageDailySteps(state.formData['average_daily_steps']);

  @override
  void initState() {
    super.initState();
    _flight = AnimationController(
      vsync: this,
      duration: _FlyingSendIcon.duration,
    )..addStatusListener(_onFlightStatus);
  }

  @override
  void didUpdateWidget(_RecapFormView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The bloc answered with the form again: it takes taps once more.
    if (oldWidget.submitting && !widget.submitting) {
      _busyDelay?.cancel();
      _flight.value = 0;
      _sending = false;
      _planeLaunched = false;
      _busyDelayPassed = false;
    }
  }

  void _send() {
    if (_sending) return;
    // The action starts on the tap; the flight only accompanies it.
    widget.onSubmit();
    final reduced = ExomMotion.of(context).isReduced;
    setState(() {
      _sending = true;
      _planeLaunched = !reduced;
    });
    _busyDelay = Timer(ExomMotion.busyIndicatorDelay, () {
      if (mounted) setState(() => _busyDelayPassed = true);
    });
    if (reduced) return;
    _plane.show();
    _flight.forward(from: 0);
  }

  void _onFlightStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && _plane.isShowing) {
      _plane.hide();
    }
    if (status == AnimationStatus.completed && mounted) widget.onFlightEnd();
  }

  @override
  void dispose() {
    _busyDelay?.cancel();
    _flight.dispose();
    super.dispose();
  }

  Widget _stepBody() {
    switch (state.step) {
      case 1:
        return RecapStepTraining(
          formData: state.formData,
          onChanged: onFieldChanged,
        );
      case 2:
        return RecapStepNutrition(
          formData: state.formData,
          onChanged: onFieldChanged,
        );
      case 3:
        return RecapStepRecovery(
          formData: state.formData,
          onChanged: onFieldChanged,
        );
      case 4:
        return RecapStepGeneral(
          formData: state.formData,
          onChanged: onFieldChanged,
        );
      case 5:
        return RecapStepImprovement(
          formData: state.formData,
          onChanged: onFieldChanged,
        );
      default:
        return RecapStartView(
          formData: state.formData,
          weekLabel: widget.formatWeekRange(state.formData),
          onStart: () => onStepChanged(1),
          onReviewAndSend: () => onStepChanged(5),
          onCancel: widget.onCancel,
        );
    }
  }

  /// Slot of the send icon in the button. The icon rests here; when it flies
  /// it is drawn in the overlay, following this slot, and the slot is empty.
  Widget _sendIconSlot() {
    return OverlayPortal(
      controller: _plane,
      overlayChildBuilder: (context) => Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _sendSlot,
          showWhenUnlinked: false,
          child: IgnorePointer(
            child: SizedBox.square(
              dimension: _FlyingSendIcon.size,
              child: _FlyingSendIcon(flight: _flight, iconKey: _sendIconKey),
            ),
          ),
        ),
      ),
      child: CompositedTransformTarget(
        link: _sendSlot,
        child: _planeLaunched
            ? const SizedBox.square(dimension: _FlyingSendIcon.size)
            : Icon(ExomIcons.send, key: _sendIconKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return IgnorePointer(
      ignoring: _sending,
      child: Column(
        children: [
          Expanded(
            child: RecapWeekScope(
              label: widget.formatWeekRange(state.formData),
              child: ExomStepTransition(step: state.step, child: _stepBody()),
            ),
          ),
          if (!_isStartStep)
            ExomPinnedFooter(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasValidationErrors) ...[
                    ExomInlineMessage(
                      kind: ExomMessageKind.error,
                      title: l10n.correctInvalidRecapFields,
                    ),
                    const SizedBox(height: ExomSpacing.md),
                  ],
                  ExomPrimaryButton(
                    key: const ValueKey('recap-step-action'),
                    label: _isImprovementStep
                        ? l10n.sendRecap
                        : l10n.recapNextStep,
                    trailingIcon: _isImprovementStep
                        ? ExomIcons.send
                        : ExomIcons.forward,
                    trailing: _isImprovementStep ? _sendIconSlot() : null,
                    busy:
                        _isImprovementStep &&
                        widget.submitting &&
                        _busyDelayPassed,
                    onPressed: _isImprovementStep
                        ? (_hasValidationErrors ? null : _send)
                        : () => onStepChanged(state.step + 1),
                  ),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ExomQuietButton(
                        label: l10n.previous,
                        onPressed: () => onStepChanged(state.step - 1),
                      ),
                      ExomQuietButton(
                        label: l10n.recapSaveDraft,
                        onPressed: _hasValidationErrors
                            ? null
                            : widget.onSaveDraft,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Paper plane of «ENVIAR RECAP» in flight (280 ms, nothing before the send:
/// it is dispatched on the tap). 60 ms of anticipation (a 3 dp dip with a
/// slight squash), then 220 ms along a curved path up and to the right,
/// accelerating, stretched along its motion mid-flight and shrinking and
/// fading out in the last third. Builds nothing when it is not flying.
class _FlyingSendIcon extends AnimatedWidget {
  const _FlyingSendIcon({
    required Animation<double> flight,
    required this.iconKey,
  }) : super(listenable: flight);

  final Key iconKey;

  static const double size = 22;
  static const Duration duration = Duration(milliseconds: 280);
  static const double _anticipation = 60 / 280;
  static const double _dip = 3;
  static const double _squashX = 1.08;
  static const double _squashY = 0.9;
  static const double _stretch = 0.12;
  static const double _endScale = 0.6;
  static const Offset _start = Offset(0, _dip);
  static const Offset _control = Offset(2, -60);
  static const Offset _end = Offset(28, -(kExomButtonMinHeight + 40));
  static const Interval _fade = Interval(2 / 3, 1);

  /// The plane leaves the lime button at ~40% of the arc; by 70% it has the
  /// page text colour.
  static const Interval _recolor = Interval(0.4, 0.7);

  Animation<double> get _flight => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    if (!_flight.isAnimating) return const SizedBox.shrink();
    final value = _flight.value;
    final Matrix4 transform;
    var opacity = 1.0;
    // Starts as the button's foreground; the overlay would otherwise give it
    // its own default icon colour.
    var color = kExomPrimaryForeground;
    if (value < _anticipation) {
      final dip = Curves.easeOut.transform(value / _anticipation);
      transform = Matrix4.translationValues(0, _dip * dip, 0).multiplied(
        Matrix4.diagonal3Values(
          1 + (_squashX - 1) * dip,
          1 + (_squashY - 1) * dip,
          1,
        ),
      );
    } else {
      final f = (value - _anticipation) / (1 - _anticipation);
      final t = ExomMotion.sheetExitCurve.transform(f);
      final u = 1 - t;
      final position =
          _start * (u * u) + _control * (2 * u * t) + _end * (t * t);
      final tangent =
          (_control - _start) * (2 * u) + (_end - _control) * (2 * t);
      final angle = tangent.direction;
      // The squash of the anticipation is released in the first quarter.
      final squash = (1 - f / 0.25).clamp(0.0, 1.0);
      final along = 1 + _stretch * math.sin(math.pi * f);
      final shrink = 1 - (1 - _endScale) * _fade.transform(f);
      opacity = 1 - _fade.transform(f);
      color = Color.lerp(
        kExomPrimaryForeground,
        context.exomPalette.textPrimary,
        _recolor.transform(f),
      )!;
      transform = Matrix4.translationValues(position.dx, position.dy, 0)
          .multiplied(Matrix4.rotationZ(angle))
          .multiplied(Matrix4.diagonal3Values(along, 1 / along, 1))
          .multiplied(Matrix4.rotationZ(-angle))
          .multiplied(
            Matrix4.diagonal3Values(
              (1 + (_squashX - 1) * squash) * shrink,
              (1 + (_squashY - 1) * squash) * shrink,
              1,
            ),
          );
    }
    return Transform(
      alignment: Alignment.center,
      transform: transform,
      child: Opacity(
        opacity: opacity,
        child: Icon(ExomIcons.send, key: iconKey, size: size, color: color),
      ),
    );
  }
}
