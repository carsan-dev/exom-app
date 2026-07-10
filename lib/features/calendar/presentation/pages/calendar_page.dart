import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
import 'package:exom_app/core/widgets/loading_widget.dart';
import 'package:exom_app/features/calendar/domain/entities/calendar_day_entity.dart';
import 'package:exom_app/features/calendar/presentation/bloc/calendar_bloc.dart';
import 'package:exom_app/features/challenges/domain/entities/challenge_entity.dart';
import 'package:exom_app/features/diets/domain/usecases/get_weekly_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/usecases/get_monthly_diet_usecase.dart';
import 'package:exom_app/features/diets/domain/entities/diet_entity.dart';
import 'package:exom_app/features/diets/domain/entities/diet_period_entity.dart';
import 'package:exom_app/features/diets/domain/entities/weekly_diet_export.dart';
import 'package:exom_app/features/diets/domain/utils/diet_export_period_utils.dart';
import 'package:exom_app/features/diets/services/weekly_diet_pdf_service.dart';
import 'package:exom_app/features/diets/services/weekly_shopping_list_builder.dart';

enum _PdfAction { print, share }

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

class _CalendarLoadingView extends StatelessWidget {
  const _CalendarLoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _CalendarMonthHeaderSkeleton(),
        const _CalendarToggleSkeleton(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: const [
              _CalendarGridSkeleton(),
              _CalendarWeekProgressSkeleton(),
              _CalendarSelectedDaySkeleton(),
              _CalendarShortcutSkeleton(),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalendarMonthHeaderSkeleton extends StatelessWidget {
  const _CalendarMonthHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: const [
          ShimmerCard(
            height: 44,
            width: 44,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          Expanded(
            child: Center(
              child: ShimmerCard(
                height: 20,
                width: 154,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          ShimmerCard(
            height: 44,
            width: 44,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ],
      ),
    );
  }
}

class _CalendarToggleSkeleton extends StatelessWidget {
  const _CalendarToggleSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(4),
        borderRadius: 26,
        child: const Row(
          children: [
            Expanded(
              child: ShimmerCard(
                height: 34,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ShimmerCard(
                height: 34,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarGridSkeleton extends StatelessWidget {
  const _CalendarGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      borderRadius: 24,
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ShimmerCard(
                height: 12,
                width: 18,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              ShimmerCard(
                height: 12,
                width: 18,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              ShimmerCard(
                height: 12,
                width: 18,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              ShimmerCard(
                height: 12,
                width: 18,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              ShimmerCard(
                height: 12,
                width: 18,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              ShimmerCard(
                height: 12,
                width: 18,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              ShimmerCard(
                height: 12,
                width: 18,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.86,
            ),
            itemCount: 35,
            itemBuilder: (context, index) => const ShimmerCard(
              height: 46,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarWeekProgressSkeleton extends StatelessWidget {
  const _CalendarWeekProgressSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          ShimmerCard(
            height: 24,
            width: 52,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          SizedBox(width: 8),
          ShimmerCard(
            height: 14,
            width: 154,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ],
      ),
    );
  }
}

class _CalendarSelectedDaySkeleton extends StatelessWidget {
  const _CalendarSelectedDaySkeleton();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      borderRadius: 18,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerCard(
                height: 40,
                width: 40,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerCard(
                      height: 16,
                      width: 126,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    SizedBox(height: 8),
                    ShimmerCard(
                      height: 14,
                      width: 82,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          ShimmerCard(
            height: 40,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
        ],
      ),
    );
  }
}

class _CalendarShortcutSkeleton extends StatelessWidget {
  const _CalendarShortcutSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ShimmerCard(
        height: 48,
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
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

  DateTime _resolveFocusedDay(CalendarLoaded state) {
    final selected = state.selectedDate;
    if (selected.year == state.year && selected.month == state.month) {
      return selected;
    }
    final now = DateTime.now();
    if (state.year == now.year && state.month == now.month) {
      return DateTime(now.year, now.month, now.day);
    }
    return DateTime(state.year, state.month, 1);
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
          return _buildContent(context, state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildErrorState(BuildContext context, CalendarError state) {
    void retry() {
      final now = DateTime.now();
      context.read<CalendarBloc>().add(
        CalendarMonthLoadRequested(year: now.year, month: now.month),
      );
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
          : AppLocalizations.of(context).calendarLoadError,
      onRetry: retry,
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

    return Column(
      children: [
        // Month header
        _MonthHeader(
          year: state.year,
          month: state.month,
          onPrevious: () => _changeMonth(context, state, -1),
          onNext: () => _changeMonth(context, state, 1),
          onTitleTap: () => _showMonthYearPicker(context, state),
        ),

        // Toggle: Entrenos / Dietas
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: GlassDecoration.elevated(borderRadius: 26),
            child: Row(
              children: [
                Expanded(
                  child: _ToggleChip(
                    label: l10n.training,
                    icon: Icons.fitness_center,
                    color: context.trainingAccent,
                    isSelected: _showTrainings,
                    onTap: () => setState(() => _showTrainings = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ToggleChip(
                    label: l10n.diets,
                    icon: Icons.restaurant_menu,
                    color: context.dietAccent,
                    isSelected: !_showTrainings,
                    onTap: () => setState(() => _showTrainings = false),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Calendar + details
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _buildCalendar(context, state, dayMap, challengeMap),
              if (!hasActivities)
                EmptyWidget(
                  message: l10n.noActivitiesThisMonth,
                  subtitle: l10n.noActivitiesThisMonthSubtitle,
                  icon: Icons.event_busy_outlined,
                )
              else ...[
                _buildWeekProgress(context, state),
                if (!_showTrainings) _buildWeeklyDietExport(context, state),
                _buildSelectedDayCard(context, state, dayMap, challengeMap),
              ],
              _buildChallengesShortcut(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyDietExport(BuildContext context, CalendarLoaded state) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: FilledButton.icon(
        onPressed: _isExportingDiet ? null : () => _exportDiet(context, state),
        icon: _isExportingDiet
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.picture_as_pdf_outlined),
        label: Text(
          _isExportingDiet ? l10n.weeklyDietPreparing : l10n.exportDietButton,
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
        final selections =
            await showModalBottomSheet<List<WeeklyMealSelection>>(
              context: context,
              isScrollControlled: true,
              builder: (sheetContext) => _WeeklyVariantSelector(
                week: period,
                locale: locale,
                title: l10n.weeklyVariantSelectorTitle,
                mainLabel: l10n.weeklyVariantMain,
                generateLabel: l10n.weeklyGenerateShoppingList,
                mealTypes: labels.mealTypes,
              ),
            );
        if (selections == null || !context.mounted) return;
        final items = const WeeklyShoppingListBuilder().build(
          week: period,
          selections: selections,
          locale: locale,
        );
        bytes = await GetIt.I<WeeklyDietPdfService>().buildShoppingList(
          week: period,
          items: items,
          locale: locale,
          labels: WeeklyShoppingListPdfLabels(
            title: exportPeriod == _DietExportPeriod.month
                ? l10n.monthlyShoppingListPdfTitle
                : l10n.weeklyShoppingListPdfTitle,
            empty: exportPeriod == _DietExportPeriod.month
                ? l10n.monthlyShoppingListEmpty
                : l10n.weeklyShoppingListEmpty,
          ),
        );
        filename = dietExportFilename(
          shoppingList: true,
          start: period.start,
          end: period.end,
          calendarMonth: exportPeriod == _DietExportPeriod.month,
        );
      }
      if (!context.mounted) return;

      final action = await showModalBottomSheet<_PdfAction>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: Text(l10n.weeklyDietPrint),
                onTap: () => Navigator.pop(sheetContext, _PdfAction.print),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: Text(l10n.weeklyDietShare),
                onTap: () => Navigator.pop(sheetContext, _PdfAction.share),
              ),
            ],
          ),
        ),
      );
      if (action == _PdfAction.print) {
        await Printing.layoutPdf(name: filename, onLayout: (_) async => bytes);
      } else if (action == _PdfAction.share) {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }
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

  Widget _buildCalendar(
    BuildContext context,
    CalendarLoaded state,
    Map<DateTime, CalendarDayEntity> dayMap,
    Map<DateTime, List<ChallengeEntity>> challengeMap,
  ) {
    final palette = context.exomPalette;
    final locale = Localizations.localeOf(context).toString();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: GlassDecoration.elevated(borderRadius: 24),
      child: TableCalendar<CalendarDayEntity>(
        firstDay: DateTime(2024),
        lastDay: DateTime(2030),
        focusedDay: _resolveFocusedDay(state),
        selectedDayPredicate: (day) => isSameDay(day, state.selectedDate),
        startingDayOfWeek: StartingDayOfWeek.monday,
        locale: locale,
        headerVisible: false,
        daysOfWeekHeight: 32,
        rowHeight: 48,
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: palette.textDisabled,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          weekendStyle: TextStyle(
            color: palette.textDisabled,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: TextStyle(color: palette.textPrimary, fontSize: 14),
          weekendTextStyle: TextStyle(color: palette.textPrimary, fontSize: 14),
          todayDecoration: BoxDecoration(
            color: palette.primary.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: palette.primary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          selectedDecoration: BoxDecoration(
            color: palette.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(
            color: palette.onPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          cellMargin: const EdgeInsets.all(4),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, date, _) {
            final key = DateTime(date.year, date.month, date.day);
            return _buildDayCell(
              context,
              date,
              dayMap[key],
              hasChallengeMarker: challengeMap[key]?.isNotEmpty ?? false,
              isSelected: false,
              isToday: false,
            );
          },
          todayBuilder: (context, date, _) {
            final key = DateTime(date.year, date.month, date.day);
            return _buildDayCell(
              context,
              date,
              dayMap[key],
              hasChallengeMarker: challengeMap[key]?.isNotEmpty ?? false,
              isSelected: false,
              isToday: true,
            );
          },
          selectedBuilder: (context, date, _) {
            final key = DateTime(date.year, date.month, date.day);
            return _buildDayCell(
              context,
              date,
              dayMap[key],
              hasChallengeMarker: challengeMap[key]?.isNotEmpty ?? false,
              isSelected: true,
              isToday: isSameDay(date, DateTime.now()),
            );
          },
        ),
        onDaySelected: (selectedDay, focusedDay) {
          context.read<CalendarBloc>().add(CalendarDaySelected(selectedDay));
        },
        onPageChanged: (focusedDay) {
          context.read<CalendarBloc>().add(
            CalendarMonthLoadRequested(
              year: focusedDay.year,
              month: focusedDay.month,
              selectedDate: state.selectedDate,
            ),
          );
        },
      ),
    );
  }

  bool _dayHasVisibleActivity(CalendarDayEntity? day) {
    if (day == null) return false;
    if (_showTrainings) {
      return day.hasTraining || day.isRestDay;
    }
    return day.hasDiet;
  }

  Color _dayAccentColor(BuildContext context, CalendarDayEntity? day) {
    final semantic = context.exomSemantic;
    if (day == null) {
      return _showTrainings ? context.trainingAccent : context.dietAccent;
    }
    if (_showTrainings) {
      if (day.isRestDay) {
        return context.exomPalette.textDisabled;
      }
      return day.trainingCompleted ? semantic.success : context.trainingAccent;
    }
    return day.dietCompleted ? semantic.success : context.dietAccent;
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime date,
    CalendarDayEntity? day, {
    required bool hasChallengeMarker,
    required bool isSelected,
    required bool isToday,
  }) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final hasActivity = _dayHasVisibleActivity(day);
    final accent = _dayAccentColor(context, day);
    final borderColor = hasActivity || isSelected || isToday
        ? accent.withValues(alpha: isSelected ? 0.40 : 0.24)
        : palette.glassBorder.withValues(alpha: 0.10);
    final fillColor = isSelected
        ? accent.withValues(alpha: 0.18)
        : isToday
        ? palette.primary.withValues(alpha: 0.12)
        : hasActivity
        ? accent.withValues(alpha: 0.08)
        : Colors.transparent;

    return Center(
      child: Container(
        width: 40,
        height: 46,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.6),
          boxShadow: hasActivity || isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                    spreadRadius: -8,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: isToday ? palette.primary : palette.textPrimary,
                  fontSize: 14,
                  fontWeight: hasActivity || isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
            if (hasActivity)
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            if (hasChallengeMarker)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: semantic.warning.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    size: 10,
                    color: semantic.warning,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekProgress(BuildContext context, CalendarLoaded state) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final summary = state.weekSummary;
    if (summary == null) return const SizedBox.shrink();

    final int completed;
    final int total;
    final String label;
    final Color color;

    if (_showTrainings) {
      completed = summary.trainingsCompleted;
      total = summary.trainingsAssigned;
      label = l10n.trainingsCompletedThisWeek;
      color = context.trainingAccent;
    } else {
      completed = summary.mealsCompleted;
      total = summary.totalMeals;
      label = l10n.mealsCompletedThisWeek;
      color = context.dietAccent;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: GlassDecoration.card(
              borderRadius: 999,
              borderColor: color.withValues(alpha: 0.18),
            ),
            child: Text(
              '$completed/$total',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: palette.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayCard(
    BuildContext context,
    CalendarLoaded state,
    Map<DateTime, CalendarDayEntity> dayMap,
    Map<DateTime, List<ChallengeEntity>> challengeMap,
  ) {
    if (state.selectedDate == DateTime(0)) return const SizedBox.shrink();

    final key = DateTime(
      state.selectedDate.year,
      state.selectedDate.month,
      state.selectedDate.day,
    );
    final day = dayMap[key];
    final dayChallenges = challengeMap[key] ?? const <ChallengeEntity>[];
    final isToday = isSameDay(state.selectedDate, DateTime.now());
    final locale = Localizations.localeOf(context).toString();
    final l10n = AppLocalizations.of(context);
    final String dateLabel;
    if (isToday) {
      dateLabel = l10n.todayLabel;
    } else {
      final formattedDate = DateFormat.MMMMd(locale).format(state.selectedDate);
      dateLabel = toBeginningOfSentenceCase(formattedDate) ?? formattedDate;
    }

    if (day == null) {
      if (dayChallenges.isNotEmpty) {
        return _challengeOnlyDayCard(context, dayChallenges, dateLabel);
      }
      return _emptyDayCard(context, dateLabel);
    }

    if (day.isRestDay) {
      return _restDayCard(context, dateLabel);
    }

    if (_showTrainings) {
      return _trainingDayCard(context, day, dateLabel);
    } else {
      return _dietDayCard(context, day, dateLabel);
    }
  }

  Widget _challengeOnlyDayCard(
    BuildContext context,
    List<ChallengeEntity> challenges,
    String dateLabel,
  ) {
    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final titles = challenges
        .map((challenge) => challenge.title.trim())
        .where((title) => title.isNotEmpty)
        .toList(growable: false);
    final preview = titles.take(2).join(' • ');
    final extraCount = titles.length > 2 ? titles.length - 2 : 0;
    final description = preview.isEmpty
        ? l10n.challengesMenuItem
        : extraCount > 0
        ? '$preview +$extraCount'
        : preview;

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      accentColor: semantic.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: semantic.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: semantic.warning.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: semantic.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.challenges} • $dateLabel',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/challenges'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(l10n.challengesMenuItem),
              style: OutlinedButton.styleFrom(
                foregroundColor: semantic.warning,
                side: BorderSide(
                  color: semantic.warning.withValues(alpha: 0.35),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyDayCard(BuildContext context, String dateLabel) {
    final palette = context.exomPalette;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.glassBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: palette.glassBorder.withValues(alpha: 0.16),
                width: 0.6,
              ),
            ),
            child: Icon(
              Icons.event_busy,
              color: palette.textDisabled,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.noActivityAssigned,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _restDayCard(BuildContext context, String dateLabel) {
    final palette = context.exomPalette;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.glassBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: palette.glassBorder.withValues(alpha: 0.16),
                width: 0.6,
              ),
            ),
            child: Icon(Icons.hotel, color: palette.textDisabled, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.restDayTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trainingDayCard(
    BuildContext context,
    CalendarDayEntity day,
    String dateLabel,
  ) {
    if (!day.hasTraining) return _emptyDayCard(context, dateLabel);

    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context);

    final statusColor = day.trainingCompleted
        ? semantic.success
        : context.trainingAccent;
    final statusLabel = day.trainingCompleted ? l10n.completed : l10n.pending;
    final statusIcon = day.trainingCompleted
        ? Icons.check_circle
        : Icons.schedule;

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      accentColor: statusColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Icon(Icons.fitness_center, color: statusColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.training} • $dateLabel',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  context.go('/trainings?date=${_apiDate(day.date)}'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(l10n.openDetail),
              style: OutlinedButton.styleFrom(
                foregroundColor: statusColor,
                side: BorderSide(color: statusColor.withValues(alpha: 0.35)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengesShortcut(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: GlassDecoration.card(borderRadius: 18),
      child: OutlinedButton.icon(
        onPressed: () => context.go('/challenges'),
        icon: Icon(
          Icons.emoji_events_outlined,
          size: 18,
          color: palette.primary,
        ),
        label: Text(l10n.challengesMenuItem),
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primary,
          side: BorderSide(color: palette.primary.withValues(alpha: 0.22)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _dietDayCard(
    BuildContext context,
    CalendarDayEntity day,
    String dateLabel,
  ) {
    if (!day.hasDiet) return _emptyDayCard(context, dateLabel);

    final palette = context.exomPalette;
    final semantic = context.exomSemantic;
    final l10n = AppLocalizations.of(context);

    final statusColor = day.dietCompleted
        ? semantic.success
        : context.dietAccent;
    final statusLabel = day.dietCompleted
        ? l10n.completedFeminine
        : l10n.pending;
    final statusIcon = day.dietCompleted ? Icons.check_circle : Icons.schedule;

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      accentColor: statusColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.nutritionPlanDefault} • $dateLabel',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/diets?date=${_apiDate(day.date)}'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(l10n.openPlan),
              style: OutlinedButton.styleFrom(
                foregroundColor: statusColor,
                side: BorderSide(color: statusColor.withValues(alpha: 0.35)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Month Header ──────────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final int year;
  final int month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTitleTap;

  const _MonthHeader({
    required this.year,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onTitleTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final locale = Localizations.localeOf(context).toString();
    final formattedTitle = DateFormat.yMMMM(
      locale,
    ).format(DateTime(year, month));
    final title = toBeginningOfSentenceCase(formattedTitle);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          Container(
            decoration: GlassDecoration.card(borderRadius: 14),
            child: IconButton(
              onPressed: onPrevious,
              icon: Icon(Icons.chevron_left, color: palette.textSecondary),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTitleTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: palette.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: GlassDecoration.card(borderRadius: 14),
            child: IconButton(
              onPressed: onNext,
              icon: Icon(Icons.chevron_right, color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Toggle Chip ───────────────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? GlassDecoration.accentCard(color, borderRadius: 20)
            : const BoxDecoration(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : palette.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : palette.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Month/Year Picker Dialog ──────────────────────────────────────────────────

class _WeeklyVariantSelector extends StatefulWidget {
  const _WeeklyVariantSelector({
    required this.week,
    required this.locale,
    required this.title,
    required this.mainLabel,
    required this.generateLabel,
    required this.mealTypes,
  });

  final DietPeriodEntity week;
  final String locale;
  final String title;
  final String mainLabel;
  final String generateLabel;
  final Map<String, String> mealTypes;

  @override
  State<_WeeklyVariantSelector> createState() => _WeeklyVariantSelectorState();
}

class _WeeklyVariantSelectorState extends State<_WeeklyVariantSelector> {
  late final Map<String, String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = {};
    for (final day in widget.week.days) {
      for (final meal in day.diet?.meals ?? const <MealEntity>[]) {
        if (meal.variants.isNotEmpty) {
          _selectedIds[WeeklyMealSelection.selectionKey(day.date, meal.id)] =
              meal.id;
        }
      }
    }
  }

  List<WeeklyMealSelection> _result() => [
    for (final day in widget.week.days)
      for (final meal in day.diet?.meals ?? const <MealEntity>[])
        if (meal.variants.isNotEmpty)
          WeeklyMealSelection(
            date: day.date,
            parentMealId: meal.id,
            selectedMealId:
                _selectedIds[WeeklyMealSelection.selectionKey(
                  day.date,
                  meal.id,
                )] ??
                meal.id,
          ),
  ];

  @override
  Widget build(BuildContext context) {
    final dayFormat = DateFormat.EEEE(widget.locale);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  for (final day in widget.week.days)
                    if ((day.diet?.meals ?? const <MealEntity>[]).any(
                      (meal) => meal.variants.isNotEmpty,
                    )) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 6),
                        child: Text(
                          toBeginningOfSentenceCase(dayFormat.format(day.date)),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      for (final meal
                          in day.diet?.meals ?? const <MealEntity>[])
                        if (meal.variants.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  _selectedIds[WeeklyMealSelection.selectionKey(
                                    day.date,
                                    meal.id,
                                  )],
                              decoration: InputDecoration(
                                labelText:
                                    widget.mealTypes[meal.type.toUpperCase()] ??
                                    meal.type,
                                border: const OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: meal.id,
                                  child: Text(
                                    '${widget.mainLabel}: ${meal.name}',
                                  ),
                                ),
                                ...meal.variants.map(
                                  (variant) => DropdownMenuItem(
                                    value: variant.id,
                                    child: Text(variant.name),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedIds[WeeklyMealSelection.selectionKey(
                                        day.date,
                                        meal.id,
                                      )] =
                                      value;
                                });
                              },
                            ),
                          ),
                    ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _result()),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(widget.generateLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
