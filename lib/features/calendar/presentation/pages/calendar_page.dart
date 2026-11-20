import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/core/formatters/figure_format.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/widgets/exom_arrival.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_empty_state.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_month_grid.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_rich_row.dart';
import 'package:exom_app/core/widgets/exom_segmented_control.dart';
import 'package:exom_app/core/widgets/exom_skeleton.dart';
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
    return BlocBuilder<CalendarBloc, CalendarState>(
      builder: (context, state) {
        if (state is CalendarLoading || state is CalendarInitial) {
          return const _CalendarLoadingView();
        }
        if (state is CalendarError) {
          return _buildErrorState(context, state);
        }
        if (state is CalendarLoaded) {
          final animate = !_contentArrived;
          _contentArrived = true;
          return ExomArrival(
            animate: animate,
            child: _buildContent(context, state),
          );
        }
        return const SizedBox.shrink();
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
        onChanged: (training) => setState(() => _showTrainings = training),
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
      context.read<CalendarBloc>().add(
        CalendarMonthLoadRequested(year: now.year, month: now.month),
      );
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

  Widget _buildContent(BuildContext context, CalendarLoaded state) {
    final l10n = AppLocalizations.of(context);
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
    final blocks = <Widget>[
      _MonthHeader(
        year: state.year,
        month: state.month,
        onPrevious: () => _changeMonth(context, state, -1),
        onNext: () => _changeMonth(context, state, 1),
        onTitleTap: () => _showMonthYearPicker(context, state),
      ),
      if (hero != null)
        Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: hero),
      _buildToggle(context),
      Padding(
        padding: EdgeInsets.only(top: hasActivities ? 8 : 16),
        child: _buildCalendar(context, state, dayMap, challengeMap),
      ),
      if (!hasActivities)
        ExomEmptyState(
          first: l10n.calendarEmptyMonthFirst,
          second: l10n.calendarEmptyMonthSecond,
          lead: l10n.noActivitiesThisMonth,
          body: l10n.noActivitiesThisMonthSubtitle,
        )
      else ...[
        if (!_showTrainings) _buildWeeklyDietExport(context, state),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _buildSelectedDayCard(context, state, dayMap, challengeMap),
        ),
      ],
      _buildChallengesShortcut(context),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final (index, block) in blocks.indexed)
          ExomArrivalItem(index: index, child: block),
      ],
    );
  }

  /// Export (sketch A1 «dietas»): outlined, not filled; the theme's outlined
  /// button is the sketch's `.btn-out`. Same action and busy state as before.
  Widget _buildWeeklyDietExport(BuildContext context, CalendarLoaded state) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isExportingDiet
              ? null
              : () => _exportDiet(context, state),
          icon: _isExportingDiet
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.textPrimary,
                  ),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(
            _isExportingDiet ? l10n.weeklyDietPreparing : l10n.exportDietButton,
          ),
        ),
      ),
    );
  }

  Future<void> _exportDiet(BuildContext context, CalendarLoaded state) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final exportPeriod = await showModalBottomSheet<_DietExportPeriod>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              title: Text(
                l10n.exportPeriodTitle,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_week_outlined),
              title: Text(l10n.exportThisWeek),
              onTap: () => Navigator.pop(sheetContext, _DietExportPeriod.week),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(l10n.exportFullMonth),
              onTap: () => Navigator.pop(sheetContext, _DietExportPeriod.month),
            ),
          ],
        ),
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
        messenger.showSnackBar(SnackBar(content: Text(l10n.dietPeriodEmpty)));
        return;
      }
      if (!context.mounted) return;

      final format = await showModalBottomSheet<WeeklyDietExportFormat>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                title: Text(
                  l10n.weeklyExportFormatTitle,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_view_week_outlined),
                title: Text(l10n.exportMenu),
                onTap: () =>
                    Navigator.pop(sheetContext, WeeklyDietExportFormat.menu),
              ),
              ListTile(
                leading: const Icon(Icons.shopping_cart_outlined),
                title: Text(l10n.weeklyExportShoppingList),
                onTap: () => Navigator.pop(
                  sheetContext,
                  WeeklyDietExportFormat.shoppingList,
                ),
              ),
            ],
          ),
        ),
      );
      if (format == null || !context.mounted) return;

      final labels = WeeklyDietPdfLabels(
        title: exportPeriod == _DietExportPeriod.month
            ? l10n.monthlyDietPdfTitle
            : l10n.weeklyDietPdfTitle,
        noDiet: l10n.weeklyDietNoDiet,
        ingredients: l10n.weeklyDietIngredients,
        alternatives: l10n.weeklyDietAlternatives,
        mealTypes: {
          'BREAKFAST': l10n.mealTypeBreakfast,
          'LUNCH': l10n.mealTypeLunch,
          'SNACK': l10n.mealTypeSnack,
          'DINNER': l10n.mealTypeDinner,
        },
      );
      late final Uint8List bytes;
      late final String filename;
      if (format == WeeklyDietExportFormat.menu) {
        bytes = await GetIt.I<WeeklyDietPdfService>().build(
          week: period,
          locale: locale,
          labels: labels,
        );
        filename = dietExportFilename(
          shoppingList: false,
          start: period.start,
          end: period.end,
          calendarMonth: exportPeriod == _DietExportPeriod.month,
        );
      } else {
        final result = await buildWeeklyShoppingListPdf(
          context,
          period: period,
          calendarMonth: exportPeriod == _DietExportPeriod.month,
          skipSelectorWithoutVariants: true,
          mealTypes: labels.mealTypes,
        );
        if (result == null) return;
        bytes = result.bytes;
        filename = result.filename;
      }
      if (!context.mounted) return;

      await printOrSharePdf(context, bytes: bytes, filename: filename);
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.weeklyDietExportError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingDiet = false);
    }
  }

  void _changeMonth(BuildContext context, CalendarLoaded state, int delta) {
    var year = state.year;
    var month = state.month + delta;
    if (month > 12) {
      month = 1;
      year++;
    } else if (month < 1) {
      month = 12;
      year--;
    }
    context.read<CalendarBloc>().add(
      CalendarMonthLoadRequested(year: year, month: month),
    );
  }

  Future<void> _showMonthYearPicker(
    BuildContext context,
    CalendarLoaded state,
  ) async {
    final bloc = context.read<CalendarBloc>();
    int selectedYear = state.year;
    int selectedMonth = state.month;

    final result = await showDialog<List<int>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) => _MonthYearPickerDialog(
        initialYear: selectedYear,
        initialMonth: selectedMonth,
      ),
    );

    if (result != null) {
      bloc.add(CalendarMonthLoadRequested(year: result[0], month: result[1]));
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
      context.read<CalendarBloc>().add(
        CalendarMonthLoadRequested(
          year: target.year,
          month: target.month,
          selectedDate: state.selectedDate,
        ),
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
          markOf: (date) => _markOf(dayMap[date], date, today),
          flagOf: (date) => challengeMap[date]?.isNotEmpty ?? false,
          flagLabelOf: l10n.calendarDayWithChallenge,
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
            leading: const ExomRowLeading.icon(Icons.bedtime_outlined),
            title: l10n.restDayTitle,
            facts: l10n.calendarRestDayFacts,
          ),
        );
      } else if (_showTrainings && day.hasTraining) {
        rows.add(
          ExomRichRow(
            key: _trainingRowKey,
            leading: const ExomRowLeading.icon(Icons.fitness_center),
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
            leading: const ExomRowLeading.icon(Icons.restaurant_menu),
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
          leading: const ExomRowLeading.icon(Icons.event_busy_outlined),
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
                      formatFigure(context, summary.trainingsAssigned),
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
      leading: const ExomRowLeading.icon(Icons.local_fire_department_outlined),
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
              Icons.emoji_events_outlined,
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
                      Icons.keyboard_arrow_down,
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
          Expanded(child: title),
          if (previous != null)
            IconButton(
              key: _previousMonthKey,
              tooltip: l10n.trainingsHistoryPreviousMonth,
              constraints: _arrowTarget,
              onPressed: previous,
              icon: Icon(Icons.chevron_left, color: palette.textPrimary),
            ),
          if (next != null)
            IconButton(
              key: _nextMonthKey,
              tooltip: l10n.trainingsHistoryNextMonth,
              constraints: _arrowTarget,
              onPressed: next,
              icon: Icon(Icons.chevron_right, color: palette.textPrimary),
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
      icon: Icons.check,
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
      icon: Icons.schedule,
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

// ─── Month/Year Picker Dialog ──────────────────────────────────────────────────

class _MonthYearPickerDialog extends StatefulWidget {
  final int initialYear;
  final int initialMonth;

  const _MonthYearPickerDialog({
    required this.initialYear,
    required this.initialMonth,
  });

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: isDark
                ? BoxDecoration(
                    color: AppColors.headerGlass,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: palette.glassBorder.withValues(alpha: 0.18),
                      width: 0.6,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 32,
                        offset: Offset(0, 10),
                        spreadRadius: -8,
                      ),
                    ],
                  )
                : GlassDecoration.elevated(borderRadius: 24),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Year selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _year--),
                      icon: Icon(
                        Icons.chevron_left,
                        color: palette.textSecondary,
                      ),
                    ),
                    Text(
                      '$_year',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _year++),
                      icon: Icon(
                        Icons.chevron_right,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Month grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.8,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final m = index + 1;
                    final isSelected = m == _month;
                    return GestureDetector(
                      onTap: () => setState(() => _month = m),
                      child: Container(
                        decoration: isSelected
                            ? GlassDecoration.accentCard(
                                palette.primary,
                                borderRadius: 12,
                              )
                            : GlassDecoration.card(borderRadius: 12),
                        alignment: Alignment.center,
                        child: Text(
                          _monthLabel(context, m),
                          style: TextStyle(
                            color: isSelected
                                ? palette.primary
                                : palette.textSecondary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Confirm button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, [_year, _month]),
                    child: Text(l10n.goToMonthButton),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _monthLabel(BuildContext context, int month) {
    final locale = Localizations.localeOf(context).toString();
    final label = DateFormat.MMM(locale).format(DateTime(2000, month));
    return toBeginningOfSentenceCase(label);
  }
}
