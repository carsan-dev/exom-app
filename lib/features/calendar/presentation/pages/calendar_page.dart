import 'dart:async';

import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/formatters/figure_format.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_arrival.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_index_list.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_month_grid.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_operation_bar.dart';
import 'package:exom_app/core/widgets/exom_rich_row.dart';
import 'package:exom_app/core/widgets/exom_segmented_control.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
import 'package:exom_app/core/widgets/exom_step_transition.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/presentation/bloc/calendar_bloc.dart';
import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';
import 'package:exom_app/features/diets/domain/usecases/get_weekly_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_monthly_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_export.dart';
import 'package:exom_app/features/diets/domain/utils/diet_export_period_utils.dart';
import 'package:exom_app/features/diets/services/weekly_diet_pdf_service.dart';
import 'package:exom_app/features/diets/presentation/widgets/weekly_shopping_list_flow.dart';

enum _DietExportPeriod { week, month }

/// Outcome of the last diet export (D14-3), shown inline under the export
/// button for the month in which it happened.
class _ExportMessage {
  const _ExportMessage({
    required this.kind,
    required this.title,
    required this.year,
    required this.month,
  });

  final ExomMessageKind kind;
  final String title;
  final int year;
  final int month;
}

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key, this.initialDate});

  final String? initialDate;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final parsed = initialDate != null ? DateTime.tryParse(initialDate!) : null;
    final target = parsed ?? now;
    final selected = DateTime(target.year, target.month, target.day);
    return BlocProvider(
      create: (_) => GetIt.I<CalendarBloc>()
        ..add(
          CalendarMonthLoadRequested(
            year: target.year,
            month: target.month,
            selectedDate: selected,
          ),
        ),
      child: const _CalendarView(),
    );
  }
}

// Keys of the L5-A4a screen, for tests.
const Key _monthTitleKey = Key('calendar-month-title');
const Key _previousMonthKey = Key('calendar-month-previous');
const Key _nextMonthKey = Key('calendar-month-next');
const Key _dayBlockKey = Key('calendar-day-block');
const Key _trainingRowKey = Key('calendar-row-training');
const Key _dietRowKey = Key('calendar-row-diet');
const Key _restRowKey = Key('calendar-row-rest');
const Key _emptyRowKey = Key('calendar-row-empty');
const Key _challengesRowKey = Key('calendar-row-challenges');
const Key _challengesShortcutKey = Key('calendar-challenges-shortcut');

/// Fling speed (logical px/s) from which a horizontal swipe on the month
/// changes month, as the previous paged calendar did.
const double _swipeVelocity = 200;

/// First load (sketch A1 «Calendario · carga»): flat blocks with the shape of
/// the month title, the numeral and its headline, the segmented control and
/// the day block with its top bar. Excluded from semantics by the skeletons.
class _CalendarLoadingView extends StatelessWidget {
  const _CalendarLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: const [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: ExomSkeleton.headline(),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: ExomSkeleton.numeral(),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: ExomSkeleton.headline(),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: ExomSkeleton.rule(),
        ),
        SizedBox(height: 16),
        ExomFeatureBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [ExomSkeleton.row(), ExomSkeleton.row()],
          ),
        ),
      ],
    );
  }
}

class _CalendarView extends StatefulWidget {
  const _CalendarView();

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  bool _showTrainings = true;
  bool _isExportingDiet = false;

  /// M3: only the first content replaces the skeleton with the arrival; later
  /// loads (another month) show their content as is.
  bool _contentArrived = false;

  /// D14-3: the export's message (it was a `SnackBar`). Cleared by the next
  /// export tap, a tab change and a month change (any other month, loading or
  /// error state), so it never comes back for a later visit to its month.
  _ExportMessage? _exportMessage;

  // L5-A4c: month changes keep the shown month until the one asked for
  // arrives. The bloc handles its events concurrently (no transformer), so
  // responses can arrive after a later request or out of order. The page
  // follows only its TARGET (the last month it asked for):
  // * a CalendarLoaded of the target is adopted (also a day selection or a
  //   refresh of that month);
  // * a CalendarLoaded of another month is never adopted. While the target is
  //   pending it is ignored (the page stays busy). If it arrives after the
  //   target was adopted (late response of an abandoned month) the bloc has
  //   settled on a month the page does not show, so the page asks for the
  //   target again, once;
  // * an error while the target is pending (or with nothing shown) is shown
  //   as before; a late error after the target was adopted is treated like a
  //   late month: the target is asked for again.
  // No endless re-requests: a re-request is only sent when nothing is
  // pending, and only in answer to a response of an abandoned request. The
  // responses to target requests are adopted, never re-requested, and the
  // abandoned requests in flight are finite, so the re-requests are too.

  /// The month on screen (always the target once adopted).
  CalendarLoaded? _shown;

  /// The month (year, month) the page wants: the first month loaded, then the
  /// last one it asked for. The title and the arrows work from it.
  (int, int)? _target;

  /// A request of [_target] has not been answered yet.
  bool _pending = false;

  /// The load error on screen.
  CalendarError? _error;

  /// The load has lasted more than [ExomMotion.busyIndicatorDelay].
  bool _slow = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    // The bloc may already hold a state the listener will not report.
    _absorb(context.read<CalendarBloc>().state, react: false);
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  /// Updates what the page shows for a new [state] of the bloc (see the
  /// rules above). With [react] it may ask for the target again.
  void _absorb(CalendarState state, {required bool react}) {
    switch (state) {
      case CalendarLoading():
        _error = null;
      case CalendarLoaded():
        final month = (state.year, state.month);
        _target ??= month;
        if (month == _target) {
          _shown = state;
          _pending = false;
          _error = null;
        } else if (!_pending && react) {
          _askTarget();
        }
      case CalendarError():
        if (_pending || _shown == null) {
          _error = state;
          _shown = null;
          _pending = false;
        } else if (react) {
          _askTarget();
        }
      default:
        break;
    }
  }

  /// Asks the bloc for [_target] again, keeping the selected day.
  void _askTarget() {
    final target = _target;
    if (target == null) return;
    _pending = true;
    final selected = _shown?.selectedDate;
    context.read<CalendarBloc>().add(
      CalendarMonthLoadRequested(
        year: target.$1,
        month: target.$2,
        selectedDate:
            selected != null &&
                selected.year == target.$1 &&
                selected.month == target.$2
            ? selected
            : null,
      ),
    );
  }

  bool _isBusy(CalendarState state) => _pending || state is CalendarLoading;

  void _onStateChanged(BuildContext context, CalendarState state) {
    _absorb(state, react: true);
    // The slow-load indicator: armed once per busy period over a kept month.
    if (_isBusy(state) && _shown != null) {
      _slowTimer ??= Timer(ExomMotion.busyIndicatorDelay, () {
        if (mounted) setState(() => _slow = true);
      });
    } else {
      _slowTimer?.cancel();
      _slowTimer = null;
      _slow = false;
    }
  }

  /// Asks the bloc for [year]-[month] (every month change of this page).
  void _requestMonth(
    BuildContext context,
    int year,
    int month, {
    DateTime? selectedDate,
  }) {
    final bloc = context.read<CalendarBloc>();
    setState(() {
      _target = (year, month);
      _pending = true;
    });
    bloc.add(
      CalendarMonthLoadRequested(
        year: year,
        month: month,
        selectedDate: selectedDate,
      ),
    );
  }

  String _apiDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  DateTime _normalizeDay(DateTime date) {
    final localDate = date.toLocal();
    return DateTime(localDate.year, localDate.month, localDate.day);
  }

  DateTime? _challengeMarkerDate(ChallengeEntity challenge) {
    final markerDate =
        challenge.completedAt ?? challenge.deadline ?? challenge.assignedAt;
    return _normalizeDay(markerDate);
  }

  /// Today's local date: the grid's «today» and the line between pending and
  /// not done.
  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CalendarBloc, CalendarState>(
      listener: _onStateChanged,
      builder: (context, state) {
        if (state is! CalendarLoaded) _exportMessage = null;
        final error = _error;
        if (error != null) return _buildErrorState(context, error);
        // First load: the skeleton. A later load keeps the last month.
        final shown = _shown;
        if (shown == null) return const _CalendarLoadingView();
        final busy = _isBusy(state);
        final animate = !_contentArrived;
        _contentArrived = true;
        return ExomArrival(
          animate: animate,
          child: _buildContent(context, shown, busy: busy, slow: busy && _slow),
        );
      },
    );
  }

  /// Entrenamiento / Dietas (ESPEC §3, `.segc`).
  Widget _buildToggle(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: ExomSegmentedControl<bool>(
        options: const [true, false],
        selected: _showTrainings,
        labelOf: (training) => training ? l10n.training : l10n.diets,
        onChanged: (training) => setState(() {
          _showTrainings = training;
          _exportMessage = null;
        }),
      ),
    );
  }

  /// Load error (sketch A1 «sin conexión»): the month title (the month the
  /// retry loads) and the segmented control stay; offline adds the two-line
  /// headline; the cause and «Reintentar» are an inline message.
  Widget _buildErrorState(BuildContext context, CalendarError state) {
    final l10n = AppLocalizations.of(context);
    void retry() {
      final now = DateTime.now();
      _requestMonth(context, now.year, now.month);
    }

    final apiException = state.apiException;
    final offline = apiException?.isNetworkError == true;
    final String message;
    if (offline) {
      message = l10n.calendarOfflineMessage;
    } else if (apiException != null) {
      message = localizedApiError(context, apiException);
    } else {
      message = l10n.calendarLoadError;
    }
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _MonthHeader(year: now.year, month: now.month),
        _buildToggle(context),
        if (offline)
          ExomEmptyState(
            first: l10n.calendarOfflineFirst,
            second: l10n.calendarOfflineSecond,
          )
        else
          const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ExomInlineMessage(
            kind: ExomMessageKind.error,
            title: message,
            body: offline ? l10n.noConnectionMessage : null,
            actionLabel: l10n.retryButton,
            onAction: retry,
          ),
        ),
      ],
    );
  }

  /// [busy]: another month is loading; this one stays and ignores taps
  /// except on the header and the segmented control. [slow]: that load is
  /// slow, so the operation bar shows over the top edge.
  Widget _buildContent(
    BuildContext context,
    CalendarLoaded state, {
    bool busy = false,
    bool slow = false,
  }) {
    final l10n = AppLocalizations.of(context);
    final message = _exportMessage;
    if (message != null &&
        (message.year != state.year || message.month != state.month)) {
      _exportMessage = null;
    }
    final dayMap = <DateTime, CalendarDayEntity>{};
    for (final day in state.days) {
      final key = DateTime(day.date.year, day.date.month, day.date.day);
      dayMap[key] = day;
    }

    final challengeMap = <DateTime, List<ChallengeEntity>>{};
    for (final challenge in state.challenges) {
      final markerDate = _challengeMarkerDate(challenge);
      if (markerDate == null) continue;
      challengeMap.putIfAbsent(markerDate, () => []).add(challenge);
    }

    final hasChallengeMarkers = challengeMap.keys.any(
      (date) => date.year == state.year && date.month == state.month,
    );

    final hasActivities =
        state.days.any((d) => d.hasTraining || d.hasDiet || d.isRestDay) ||
        hasChallengeMarkers;

    final hero = _buildHero(context, state);
    final (year, month) = _target ?? (state.year, state.month);
    final monthStep = state.year * 12 + state.month;
    Widget frozen(Widget child) => IgnorePointer(ignoring: busy, child: child);
    final blocks = <Widget>[
      _MonthHeader(
        year: year,
        month: month,
        onPrevious: () => _changeMonth(context, year, month, -1),
        onNext: () => _changeMonth(context, year, month, 1),
        onTitleTap: () => _showMonthYearPicker(context, year, month),
      ),
      if (hero != null)
        frozen(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            // L5-A4c: the figure moves with the month.
            child: ExomStepTransition(step: monthStep, child: hero),
          ),
        ),
      _buildToggle(context),
      frozen(
        Padding(
          padding: EdgeInsets.only(top: hasActivities ? 8 : 16),
          child: _buildCalendar(context, state, dayMap, challengeMap),
        ),
      ),
      if (!hasActivities)
        ExomEmptyState(
          first: l10n.calendarEmptyMonthFirst,
          second: l10n.calendarEmptyMonthSecond,
          lead: l10n.noActivitiesThisMonth,
          body: l10n.noActivitiesThisMonthSubtitle,
        )
      else ...[
        if (!_showTrainings) frozen(_buildWeeklyDietExport(context, state)),
        frozen(
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildSelectedDayCard(context, state, dayMap, challengeMap),
          ),
        ),
      ],
      frozen(_buildChallengesShortcut(context)),
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (final (index, block) in blocks.indexed)
              ExomArrivalItem(index: index, child: block),
          ],
        ),
        // L5-A4c: a slow month load shows the operation bar over the kept
        // month, at the top edge, without moving it.
        if (slow)
          const Positioned(
            top: 0,
            left: 20,
            right: 20,
            child: ExomOperationBar(),
          ),
      ],
    );
  }

  /// Export (sketch A1 «dietas»): outlined, not filled; the theme's outlined
  /// button is the sketch's `.btn-out`. Same action and busy state as before.
  /// Its outcome (empty period, failure) is an inline message under it.
  Widget _buildWeeklyDietExport(BuildContext context, CalendarLoaded state) {
    final message = _exportMessage;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildExportButton(context, state),
          if (message != null) ...[
            const SizedBox(height: ExomSpacing.md),
            ExomInlineMessage(kind: message.kind, title: message.title),
          ],
        ],
      ),
    );
  }

  Widget _buildExportButton(BuildContext context, CalendarLoaded state) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isExportingDiet ? null : () => _exportDiet(context, state),
        icon: _isExportingDiet
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.textPrimary,
                ),
              )
            : const Icon(ExomIcons.pdf),
        label: Text(
          _isExportingDiet ? l10n.weeklyDietPreparing : l10n.exportDietButton,
        ),
      ),
    );
  }

  /// Shows [title] inline under the export button, for the month of [state].
  void _showExportMessage(
    CalendarLoaded state,
    ExomMessageKind kind,
    String title,
  ) {
    if (!mounted) return;
    setState(
      () => _exportMessage = _ExportMessage(
        kind: kind,
        title: title,
        year: state.year,
        month: state.month,
      ),
    );
  }

  Future<void> _exportDiet(BuildContext context, CalendarLoaded state) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    // A new tap on the export button clears the previous outcome.
    if (_exportMessage != null) setState(() => _exportMessage = null);
    // D14-2 (sketch A1 «Elige un periodo»): straight sheet, numbered index.
    // The period is read as soon as it is picked, as with the previous
    // Material sheet: the page stays, so there is no need to wait for the
    // sheet's disposal before the read and the format sheet.
    final exportPeriod = await showExomSheet<_DietExportPeriod>(
      context: context,
      waitForDisposal: false,
      builder: (_) => _ExportChoiceSheet<_DietExportPeriod>(
        first: l10n.calendarExportPeriodFirst,
        second: l10n.calendarExportPeriodSecond,
        semanticsLabel: l10n.exportPeriodTitle,
        choices: [
          (l10n.exportThisWeek, _DietExportPeriod.week),
          (l10n.exportFullMonth, _DietExportPeriod.month),
        ],
      ),
    );
    if (exportPeriod == null || !context.mounted) return;
    setState(() => _isExportingDiet = true);
    try {
      late final DietPeriodEntity period;
      if (exportPeriod == _DietExportPeriod.month) {
        period = await GetIt.I<GetMonthlyDietUseCase>()(
          state.year,
          state.month,
        );
      } else {
        final monday = mondayFor(state.selectedDate);
        period = await GetIt.I<GetWeeklyDietUseCase>()(_apiDate(monday));
      }
      if (!period.hasDiets) {
        _showExportMessage(state, ExomMessageKind.info, l10n.dietPeriodEmpty);
        return;
      }
      if (!context.mounted) return;

      // D14-2: the format is the same straight sheet as the period; the next
      // step (selector or print / share) opens as soon as it is picked.
      final format = await showExomSheet<WeeklyDietExportFormat>(
        context: context,
        waitForDisposal: false,
        builder: (_) => _ExportChoiceSheet<WeeklyDietExportFormat>(
          first: l10n.calendarExportFormatFirst,
          second: l10n.calendarExportFormatSecond,
          semanticsLabel: l10n.weeklyExportFormatTitle,
          choices: [
            (l10n.exportMenu, WeeklyDietExportFormat.menu),
            (
              l10n.weeklyExportShoppingList,
              WeeklyDietExportFormat.shoppingList,
            ),
          ],
        ),
      );
      if (format == null || !context.mounted) return;

      final mealTypes = {
        'BREAKFAST': l10n.mealTypeBreakfast,
        'LUNCH': l10n.mealTypeLunch,
        'SNACK': l10n.mealTypeSnack,
        'DINNER': l10n.mealTypeDinner,
      };
      if (format == WeeklyDietExportFormat.shoppingList) {
        // L5-E8: the shopping list is a pair of screens that build the PDF
        // themselves («Compartir lista»); the export ends when they close.
        await openShoppingList(
          context,
          period: period,
          calendarMonth: exportPeriod == _DietExportPeriod.month,
          mealTypes: mealTypes,
        );
        return;
      }

      final labels = WeeklyDietPdfLabels(
        title: exportPeriod == _DietExportPeriod.month
            ? l10n.monthlyDietPdfTitle
            : l10n.weeklyDietPdfTitle,
        noDiet: l10n.weeklyDietNoDiet,
        ingredients: l10n.weeklyDietIngredients,
        alternatives: l10n.weeklyDietAlternatives,
        mealTypes: mealTypes,
      );
      final bytes = await GetIt.I<WeeklyDietPdfService>().build(
        week: period,
        locale: locale,
        labels: labels,
      );
      final filename = dietExportFilename(
        shoppingList: false,
        start: period.start,
        end: period.end,
        calendarMonth: exportPeriod == _DietExportPeriod.month,
      );
      if (!context.mounted) return;

      await printOrSharePdf(context, bytes: bytes, filename: filename);
    } catch (_) {
      _showExportMessage(
        state,
        ExomMessageKind.error,
        l10n.weeklyDietExportError,
      );
    } finally {
      if (mounted) setState(() => _isExportingDiet = false);
    }
  }

  /// [delta] months from [year]-[month], the month of the title (the
  /// requested one while it loads).
  void _changeMonth(BuildContext context, int year, int month, int delta) {
    var targetYear = year;
    var targetMonth = month + delta;
    if (targetMonth > 12) {
      targetMonth = 1;
      targetYear++;
    } else if (targetMonth < 1) {
      targetMonth = 12;
      targetYear--;
    }
    _requestMonth(context, targetYear, targetMonth);
  }

  Future<void> _showMonthYearPicker(
    BuildContext context,
    int shownYear,
    int shownMonth,
  ) async {
    // D14-2: straight sheet; one tap on a month goes there (no «Ir al mes»).
    final result = await showExomSheet<(int, int)>(
      context: context,
      builder: (_) =>
          _MonthYearSheet(shownYear: shownYear, shownMonth: shownMonth),
    );

    // The month already shown (or already asked for): the sheet just closes,
    // without reloading or resetting the selected day.
    if (result != null &&
        context.mounted &&
        result != (shownYear, shownMonth)) {
      final (year, month) = result;
      _requestMonth(context, year, month);
    }
  }

  /// Protagonist (sketch A1 `.x-hero-96`): Entrenamiento counts the training
  /// days of the month that are done; Dietas, the meals done this week (week
  /// summary of the selected day). Nothing scheduled: a plain 0, in the text
  /// colour (it is not an achievement). Dietas without a week summary (the
  /// bloc swallows its failure): no figure at all, never an invented 0.
  Widget? _buildHero(BuildContext context, CalendarLoaded state) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final int done;
    final int total;
    if (!_showTrainings && state.weekSummary == null) {
      return null;
    } else if (_showTrainings) {
      final scheduled = state.days.where(
        (d) =>
            d.hasTraining &&
            d.date.year == state.year &&
            d.date.month == state.month,
      );
      total = scheduled.length;
      done = scheduled.where((d) => d.trainingCompleted).length;
    } else {
      total = state.weekSummary?.totalMeals ?? 0;
      done = state.weekSummary?.mealsCompleted ?? 0;
    }
    final footStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 14,
      height: 1.35,
      color: palette.textSecondary,
    );

    if (total == 0) {
      final noSessions = l10n.calendarHeroNoSessions;
      return ExomNumeral(
        value: formatFigure(context, 0),
        isData: false,
        side: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showTrainings) ...[
              Text(
                noSessions.toUpperCase(),
                semanticsLabel: noSessions,
                style: ExomType.headline2Section.copyWith(
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              _showTrainings
                  ? l10n.calendarHeroNoSessionsFoot('${state.year}')
                  : l10n.calendarHeroDietFoot,
              style: footStyle,
            ),
          ],
        ),
      );
    }

    return ExomNumeral(
      value: formatFigure(context, done),
      unit: '/${formatFigure(context, total)}',
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExomTwoLineHeadline(
            first: _showTrainings
                ? l10n.calendarHeroTrainingFirst
                : l10n.calendarHeroDietFirst,
            second: _showTrainings
                ? l10n.calendarHeroTrainingSecond
                : l10n.calendarHeroDietSecond,
          ),
          const SizedBox(height: 4),
          Text(
            _showTrainings
                ? l10n.calendarHeroTrainingFoot
                : l10n.calendarHeroDietFoot,
            style: footStyle,
          ),
        ],
      ),
    );
  }

  /// Month grid (ESPEC §3, `ExomMonthGrid`): Monday first, the marks of the
  /// selected tab and the challenge flag. Done days are lime fills: the screen
  /// has no lime button (DIRECCION §2). Margins of 2 dp (L5-D34). A
  /// horizontal swipe still changes month, keeping the selected day, as the
  /// previous paged calendar did.
  Widget _buildCalendar(
    BuildContext context,
    CalendarLoaded state,
    Map<DateTime, CalendarDayEntity> dayMap,
    Map<DateTime, List<ChallengeEntity>> challengeMap,
  ) {
    final l10n = AppLocalizations.of(context);
    final today = _today();

    void swipe(DragEndDetails details) {
      final velocity = details.primaryVelocity ?? 0;
      if (velocity.abs() < _swipeVelocity) return;
      final target = DateTime(
        state.year,
        state.month + (velocity < 0 ? 1 : -1),
      );
      _requestMonth(
        context,
        target.year,
        target.month,
        selectedDate: state.selectedDate,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onHorizontalDragEnd: swipe,
        child: ExomMonthGrid(
          month: DateTime(state.year, state.month),
          selected: state.selectedDate,
          today: today,
          doneAsFill: true,
          // L5-A4c: the day fill slides and the weeks move with the month.
          slideSelection: true,
          monthTransition: true,
          markOf: (date) => _markOf(dayMap[date], date, today),
          flagOf: (date) => challengeMap[date]?.isNotEmpty ?? false,
          flagLabelOf: l10n.calendarDayWithChallenge,
          // O4: in Dietas the marks are diets, not sessions.
          markLabelOf: _showTrainings
              ? null
              : (label, mark) => switch (mark) {
                  ExomDayMark.done => l10n.calendarDayDietDone(label),
                  ExomDayMark.pending => l10n.calendarDayDietPending(label),
                  ExomDayMark.missed => l10n.calendarDayDietMissed(label),
                  ExomDayMark.none => label,
                },
          onSelect: (date) =>
              context.read<CalendarBloc>().add(CalendarDaySelected(date)),
        ),
      ),
    );
  }

  /// Mark of [date] in the selected tab: done, pending from today on, not
  /// done before today, or none when nothing is scheduled.
  ExomDayMark _markOf(CalendarDayEntity? day, DateTime date, DateTime today) {
    if (day == null) return ExomDayMark.none;
    final scheduled = _showTrainings ? day.hasTraining : day.hasDiet;
    if (!scheduled) return ExomDayMark.none;
    final done = _showTrainings ? day.trainingCompleted : day.dietCompleted;
    if (done) return ExomDayMark.done;
    return date.isBefore(today) ? ExomDayMark.missed : ExomDayMark.pending;
  }

  /// Block of the selected day (sketch A1 `.x-feat`): its date, the week's
  /// trainings (Entrenamiento) and one row per item. The whole row opens the
  /// training or the diet of that day (it was «Ver detalle» / «Ver plan»).
  Widget _buildSelectedDayCard(
    BuildContext context,
    CalendarLoaded state,
    Map<DateTime, CalendarDayEntity> dayMap,
    Map<DateTime, List<ChallengeEntity>> challengeMap,
  ) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final selected = state.selectedDate;
    final key = DateTime(selected.year, selected.month, selected.day);
    final day = dayMap[key];
    final dayChallenges = challengeMap[key] ?? const <ChallengeEntity>[];
    final formattedDate = DateFormat.MMMMEEEEd(locale).format(selected);
    final dateLabel = toBeginningOfSentenceCase(formattedDate);
    final summary = state.weekSummary;

    // A rest day can still carry a diet (`has_diet` is independent of
    // `is_rest_day`): the rest row only speaks about training and the diet
    // row follows as on any other day.
    final rows = <Widget>[];
    if (day != null) {
      if (day.isRestDay) {
        rows.add(
          ExomRichRow(
            key: _restRowKey,
            leading: const ExomRowLeading.icon(ExomIcons.sleep),
            title: l10n.restDayTitle,
            facts: l10n.calendarRestDayFacts,
          ),
        );
      } else if (_showTrainings && day.hasTraining) {
        rows.add(
          ExomRichRow(
            key: _trainingRowKey,
            leading: const ExomRowLeading.icon(ExomIcons.train),
            title: l10n.training,
            status: day.trainingCompleted
                ? _DoneStatus(label: l10n.completed)
                : _PendingStatus(label: l10n.pending),
            onTap: () => context.go('/trainings?date=${_apiDate(day.date)}'),
          ),
        );
      }
      if (day.hasDiet) {
        rows.add(
          ExomRichRow(
            key: _dietRowKey,
            leading: const ExomRowLeading.icon(ExomIcons.meal),
            title: l10n.nutritionPlanDefault,
            status: day.dietCompleted
                ? _DoneStatus(label: l10n.completedFeminine)
                : _PendingStatus(label: l10n.pending),
            onTap: () => context.go('/diets?date=${_apiDate(day.date)}'),
          ),
        );
      }
    }
    if (dayChallenges.isNotEmpty) {
      rows.add(_challengeRow(context, dayChallenges));
    }
    if (rows.isEmpty) {
      rows.add(
        ExomRichRow(
          key: _emptyRowKey,
          leading: const ExomRowLeading.icon(ExomIcons.eventBusy),
          title: l10n.noActivityAssigned,
        ),
      );
    }

    return ExomFeatureBlock(
      child: Column(
        key: _dayBlockKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(header: true, child: ExomKicker(dateLabel)),
                if (_showTrainings && summary != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.calendarWeekTrainings(
                      formatFigure(context, summary.trainingsCompleted),
                      summary.trainingsAssigned,
                    ),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFontFamily,
                      fontSize: 14,
                      height: 1.35,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          ExomFlatRowGroup(bottomRule: false, children: rows),
        ],
      ),
    );
  }

  /// «Retos» row of a day with challenges (sketch A1: «1 reto activo hoy»):
  /// how many challenges the day carries; nothing when there are none.
  Widget _challengeRow(BuildContext context, List<ChallengeEntity> challenges) {
    final l10n = AppLocalizations.of(context);
    final count = challenges.length;

    return ExomRichRow(
      key: _challengesRowKey,
      leading: const ExomRowLeading.icon(ExomIcons.streak),
      title: l10n.challenges,
      facts: count == 0
          ? null
          : l10n.calendarActiveChallengesToday(
              count,
              formatFigure(context, count),
            ),
      onTap: () => context.go('/challenges'),
    );
  }

  /// Access to «Retos» kept below the day (not drawn by the sketch; it was
  /// always on the screen).
  Widget _buildChallengesShortcut(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: ExomFlatRowGroup(
        children: [
          ExomFlatRow(
            key: _challengesShortcutKey,
            leading: Icon(
              ExomIcons.trophy,
              size: 24,
              color: palette.textPrimary,
            ),
            title: l10n.challengesMenuItem,
            onTap: () => context.go('/challenges'),
          ),
        ],
      ),
    );
  }
}

// ─── Month Header ──────────────────────────────────────────────────────────────

/// Month header (sketch A1 `.x-mhead`): the month as a title-button in
/// Barlow 44 (upper case painted only) that opens the month and year picker,
/// and the previous / next arrows. The title shrinks to its width instead of
/// overflowing or being cut (L4-I22). Without [onTitleTap] it is a plain
/// header and without [onPrevious] / [onNext] there are no arrows (load
/// error).
class _MonthHeader extends StatelessWidget {
  final int year;
  final int month;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTitleTap;

  const _MonthHeader({
    required this.year,
    required this.month,
    this.onPrevious,
    this.onNext,
    this.onTitleTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final date = DateTime(year, month);
    final name = DateFormat.MMMM(locale).format(date);
    final fullTitle = toBeginningOfSentenceCase(
      DateFormat.yMMMM(locale).format(date),
    );
    final tap = onTitleTap;
    final previous = onPrevious;
    final next = onNext;

    final title = Semantics(
      key: _monthTitleKey,
      container: true,
      button: tap != null,
      header: tap == null,
      label: tap != null ? l10n.calendarMonthTitleLabel(fullTitle) : fullTitle,
      onTap: tap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name.toUpperCase(),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: ExomType.screenTitle.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  if (tap != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      ExomIcons.expand,
                      size: 24,
                      color: palette.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 0),
      child: Row(
        children: [
          // L5-A4c: the title moves to the requested month at once.
          Expanded(
            child: ExomStepTransition(step: year * 12 + month, child: title),
          ),
          if (previous != null)
            IconButton(
              key: _previousMonthKey,
              tooltip: l10n.trainingsHistoryPreviousMonth,
              constraints: _arrowTarget,
              onPressed: previous,
              icon: Icon(ExomIcons.previous, color: palette.textPrimary),
            ),
          if (next != null)
            IconButton(
              key: _nextMonthKey,
              tooltip: l10n.trainingsHistoryNextMonth,
              constraints: _arrowTarget,
              onPressed: next,
              icon: Icon(ExomIcons.next, color: palette.textPrimary),
            ),
        ],
      ),
    );
  }
}

/// Touch target of each month arrow (plan §2 and §11).
const BoxConstraints _arrowTarget = BoxConstraints(minWidth: 48, minHeight: 48);

/// «Hecha» of the client (D19): check and text in the data colour.
class _DoneStatus extends StatelessWidget {
  const _DoneStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _Status(
      label: label,
      icon: ExomIcons.check,
      colour: context.exomPalette.data,
    );
  }
}

/// «Pendiente» (sketch `.st-pend`): clock and text in the pending colour.
class _PendingStatus extends StatelessWidget {
  const _PendingStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _Status(
      label: label,
      icon: ExomIcons.time,
      colour: context.exomSemantic.warning,
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.label,
    required this.icon,
    required this.colour,
  });

  final String label;
  final IconData icon;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: ExcludeSemantics(child: Icon(icon, size: 18, color: colour)),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: colour,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Sheets (L5-A4b, D14-2) ──────────────────────────────────────────────────

/// Top bar of the calendar sheets (sketch `.sheet.a-bar`), in the data colour
/// at the [ExomRule.bar] thickness of the redesign (the sketch draws 3 px).
/// `showExomSheet` owns the drag handle, so the bar sits under it.
class _SheetTopBar extends StatelessWidget {
  const _SheetTopBar();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(height: ExomRule.bar, color: context.exomPalette.data),
    );
  }
}

/// Export choice sheet (sketch A1 «Dietas · calendario / Elige un periodo»):
/// the kicker, a two-line headline read as [semanticsLabel] and the numbered
/// entries, each closing the sheet with its value. The period sheet is the
/// one the sketch draws; the format sheet (menu or shopping list), not drawn,
/// follows the same pattern.
class _ExportChoiceSheet<T> extends StatelessWidget {
  const _ExportChoiceSheet({
    required this.first,
    required this.second,
    required this.semanticsLabel,
    required this.choices,
  });

  final String first;
  final String second;
  final String semanticsLabel;

  /// Entries in order: title and the value the sheet returns.
  final List<(String, T)> choices;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetTopBar(),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExomKicker(l10n.calendarExportPeriodKicker),
              const SizedBox(height: ExomSpacing.sm),
              ExomTwoLineHeadline(
                first: first,
                second: second,
                semanticsLabel: semanticsLabel,
              ),
            ],
          ),
        ),
        ExomIndexList(
          items: [
            for (final (title, value) in choices)
              ExomIndexItem(
                title: title,
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

/// Month and year (sketch A1 «Calendario · hoja de mes y año»): the kicker,
/// the year in Barlow 28 between its arrows and the twelve months as 48 dp
/// choices, the shown month filled. The arrows only change the year; one tap
/// on a month closes the sheet with that year and month. Years are not
/// bounded, as in the previous picker.
class _MonthYearSheet extends StatefulWidget {
  const _MonthYearSheet({required this.shownYear, required this.shownMonth});

  /// Month the calendar shows now.
  final int shownYear;
  final int shownMonth;

  @override
  State<_MonthYearSheet> createState() => _MonthYearSheetState();
}

class _MonthYearSheetState extends State<_MonthYearSheet> {
  late int _year = widget.shownYear;

  /// Three-letter month label of the sketch («Ene… Sep… Dic», «Jan… Sep…
  /// Dec»), without the dot: intl abbreviates September «sept» in Spanish,
  /// which broke into «Sep / t» at 320 dp with large text (L5-A4 D2).
  static String _monthAbbreviation(String locale, int month) {
    final short = DateFormat.MMM(
      locale,
    ).format(DateTime(2000, month)).replaceAll('.', '');
    final letters = short.characters;
    return toBeginningOfSentenceCase(
      letters.length > 3 ? letters.take(3).toString() : short,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final year = _year;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetTopBar(),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ExomKicker(l10n.calendarMonthPickerKicker),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  IconButton(
                    tooltip: l10n.calendarPreviousYear,
                    constraints: _arrowTarget,
                    onPressed: () => setState(() => _year--),
                    icon: Icon(ExomIcons.previous, color: palette.textPrimary),
                  ),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        '$year',
                        textAlign: TextAlign.center,
                        style: ExomType.headline2Section.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.calendarNextYear,
                    constraints: _arrowTarget,
                    onPressed: () => setState(() => _year++),
                    icon: Icon(ExomIcons.next, color: palette.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ExomChoiceChips<int>(
                options: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                selected: year == widget.shownYear ? widget.shownMonth : null,
                columns: 4,
                fitLabels: true,
                labelOf: (month) => _monthAbbreviation(locale, month),
                semanticLabelOf: (month) => toBeginningOfSentenceCase(
                  DateFormat.yMMMM(locale).format(DateTime(year, month)),
                ),
                onSelected: (month) => Navigator.pop(context, (year, month)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
