import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_step_transition.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Mark of a day in [ExomMonthGrid], the same shapes as the week strip of
/// Inicio (`week_day_selector.dart`): a dot for a pending session, a check
/// for a done one and a hollow ring for a session not done. The caller
/// decides which applies (e.g. a pending session before today is [missed]).
enum ExomDayMark { none, pending, done, missed }

/// Month grid of the L5 redesign (ESPEC §3, `.x-month`, `.day`).
///
/// Seven columns starting on MONDAY, weekday initials in 13 secondary, a
/// hairline between weeks, flat square cells. Days of the neighbouring months
/// complete the first and last weeks in the secondary colour; they carry no
/// mark and cannot be tapped.
///
/// States: [today] has a 1.5 dp outline in the text colour; the [selected]
/// day is filled with `selectionFill` (never lime); a done day is filled with
/// `limeFill` + `onLimeFill` (plus the light theme's outline) when
/// [doneAsFill], otherwise only its check is painted, in `palette.data`
/// (rule D19). Use `doneAsFill: false` on screens with a lime button (footer
/// guard, DIRECCION §2). The fill crossfades in `ExomMotion.chipCrossfade`
/// (120 ms reduced).
///
/// Sizes (L5-D34): the tap area of each day is exactly its column (a seventh
/// of the width, never overlapping a neighbour) and at least 48 dp high; the
/// visual cell inside it is at least 44 dp. A column of at least 44 dp needs
/// at least 7 x 44 = 308 dp of width, so on a 320 dp screen the grid goes
/// full bleed or with horizontal margins of at most 6 dp: the screen that uses
/// it must not add more horizontal margin than that.
///
/// [today] is injected (the screen's clock), never read here. Weeks and days
/// are calendar arithmetic (`DateTime(y, m, d + n)`), never a `Duration`, so
/// daylight saving changes cannot shift a day (L3b P5b).
///
/// Semantics: one node per day of the month with its localised date and
/// «hoy» / «sesión hecha» / «sesión pendiente» / «sesión no hecha», the
/// selected state and, with [onSelect], a tap action. [markLabelOf]
/// (optional, L5-A4 O4) replaces those session words for a grid whose marks
/// are not sessions (e.g. diets); without it the labels are unchanged.
///
/// Optional flag (L5-A4a, sketch `.a-fl`): a day for which [flagOf] returns
/// true carries a small flame in its top end corner, in the secondary text
/// colour (in the ink of the fill on a selected or filled day, never lime as
/// ink), and [flagLabelOf] extends that day's label. Without [flagOf] the grid
/// is unchanged.
///
/// Optional motion (L5-A4c, sketch `a-diario.html#calendario`), both off by
/// default so the grid is unchanged without them:
/// * [slideSelection]: the selection fill is a layer under the days of its
///   week that slides from the previously selected column to the new one in
///   `ExomMotion.selectionSlide` (M4, 200 ms ease-out) while the numbers
///   change ink in the same time (`.a1-fill`, `.a1-now`, `.a1-was`). Moving to
///   another week, it slides along the new week from the previous column.
///   Reduced motion: the in-place crossfade above.
/// * [monthTransition]: when [month] changes, the weeks of the new month
///   enter horizontally through `ExomStepTransition` (240 ms, from the end
///   side when the month advances, the start side when it goes back; reduced
///   motion a fade) while the weekday initials stay (`.month-dow` outside
///   `.xf`).
class ExomMonthGrid extends StatefulWidget {
  const ExomMonthGrid({
    super.key,
    required this.month,
    required this.selected,
    required this.markOf,
    required this.today,
    this.onSelect,
    this.doneAsFill = false,
    this.flagOf,
    this.flagLabelOf,
    this.markLabelOf,
    this.slideSelection = false,
    this.monthTransition = false,
  });

  /// Any day of the month to show.
  final DateTime month;
  final DateTime? selected;
  final ExomDayMark Function(DateTime day) markOf;

  /// Today's date from the caller's clock.
  final DateTime today;
  final ValueChanged<DateTime>? onSelect;
  final bool doneAsFill;

  /// Days of the month that carry the corner flag.
  final bool Function(DateTime day)? flagOf;

  /// Label of a flagged day built from its usual label.
  final String Function(String label)? flagLabelOf;

  /// Label of a day with [mark] (never [ExomDayMark.none]) built from its
  /// date (and «hoy») label; null uses the session labels.
  final String Function(String label, ExomDayMark mark)? markLabelOf;

  /// Slides the selection fill between days (see the class comment).
  final bool slideSelection;

  /// Moves the weeks horizontally when [month] changes (see the class
  /// comment).
  final bool monthTransition;

  /// Key of the sliding selection fill ([slideSelection]), for tests.
  static const Key selectionFillKey = ValueKey('exom-month-selection-fill');

  /// Key of the corner flag of [day], for tests.
  static Key flagKey(DateTime day) => ValueKey('exom-month-flag-${_id(day)}');

  /// Key of the weekday initials row, for tests.
  static const Key weekdayHeaderKey = ValueKey('exom-month-weekdays');

  /// Key of the tap area (detector) of [day], for tests.
  static Key cellKey(DateTime day) => ValueKey('exom-month-hit-${_id(day)}');

  /// Key of the visual cell of [day], for tests.
  static Key visualKey(DateTime day) => ValueKey('exom-month-cell-${_id(day)}');

  /// Key of the mark of [day], for tests.
  static Key markKey(DateTime day) => ValueKey('exom-month-mark-${_id(day)}');

  static String _id(DateTime d) => '${d.year}-${d.month}-${d.day}';

  static const double _minVisual = 44;
  static const double _minHit = 48;
  static const double _rowInset = 2;

  /// Local midnights of the full weeks (Monday to Sunday) covering [month].
  static List<DateTime> daysOf(DateTime month) {
    final year = month.year;
    final m = month.month;
    final lead = DateTime(year, m, 1).weekday - DateTime.monday;
    final daysInMonth = DateTime(year, m + 1, 0).day;
    final count = ((lead + daysInMonth + 6) ~/ 7) * 7;
    return [for (var i = 0; i < count; i++) DateTime(year, m, 1 - lead + i)];
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  State<ExomMonthGrid> createState() => _ExomMonthGridState();
}

class _ExomMonthGridState extends State<ExomMonthGrid> {
  /// Day the selection fill slides from, when the last change of [selected]
  /// moved it inside the same month.
  DateTime? _slideFrom;

  /// Counts the selection changes, so each one restarts the slide.
  int _slideSerial = 0;

  ExomMonthGrid get _w => widget;
  DateTime get month => widget.month;
  DateTime? get selected => widget.selected;
  DateTime get today => widget.today;
  bool get doneAsFill => widget.doneAsFill;
  ExomDayMark Function(DateTime day) get markOf => widget.markOf;
  ValueChanged<DateTime>? get onSelect => widget.onSelect;
  bool Function(DateTime day)? get flagOf => widget.flagOf;
  String Function(String label)? get flagLabelOf => widget.flagLabelOf;
  String Function(String label, ExomDayMark mark)? get markLabelOf =>
      widget.markLabelOf;

  static bool _sameDay(DateTime a, DateTime b) => ExomMonthGrid._sameDay(a, b);

  @override
  void didUpdateWidget(ExomMonthGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.selected;
    final now = widget.selected;
    final sameMonth =
        oldWidget.month.year == month.year &&
        oldWidget.month.month == month.month;
    if (before == null || now == null || !sameMonth) {
      _slideFrom = null;
      return;
    }
    if (_sameDay(before, now)) return;
    _slideFrom = before.month == month.month && before.year == month.year
        ? before
        : null;
    _slideSerial++;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final motion = ExomMotion.of(context);
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final days = ExomMonthGrid.daysOf(month);
    final weeks = days.length ~/ 7;
    final initialFormat = DateFormat('EEEEE', language);
    final dateFormat = DateFormat.MMMMEEEEd(language);
    final rule = BorderSide(
      color: palette.borderSoft,
      width: ExomRule.hairline,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final column = width / 7;
        final inset = ((column - ExomMonthGrid._minVisual) / 2)
            .clamp(0.0, 1.0)
            .toDouble();
        final slides = _w.slideSelection && motion.selectionSlides;
        final selectedDay = selected;
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final header = ExcludeSemantics(
          child: Row(
            key: ExomMonthGrid.weekdayHeaderKey,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: ExomSpacing.xs,
                    ),
                    child: Text(
                      initialFormat.format(days[i]).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFontFamily,
                        fontSize: 13,
                        height: 1.3,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

        /// Sliding fill of the selected day when it lies in week [w].
        Widget? fillOf(int w) {
          if (!slides || selectedDay == null) return null;
          for (var i = 0; i < 7; i++) {
            final day = days[w * 7 + i];
            if (day.month != month.month || !_sameDay(day, selectedDay)) {
              continue;
            }
            final from = _slideFrom;
            // Weeks start on Monday: the column is the weekday.
            final fromColumn = from == null
                ? i
                : from.weekday - DateTime.monday;
            // Directional distance in columns, as a physical offset.
            final distance = (fromColumn - i) * column * (rtl ? -1 : 1);
            return PositionedDirectional(
              start: column * i + inset,
              width: column - 2 * inset,
              top: ExomMonthGrid._rowInset,
              bottom: ExomMonthGrid._rowInset,
              child: _SlidingFill(
                key: ValueKey(_slideSerial),
                color: palette.selectionFill,
                from: distance,
                duration: motion.selection,
              ),
            );
          }
          return null;
        }

        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var w = 0; w < weeks; w++)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: rule,
                    bottom: w == weeks - 1 ? rule : BorderSide.none,
                  ),
                ),
                child: Stack(
                  children: [
                    // Keeps every tap area at least 48 high.
                    const SizedBox(height: ExomMonthGrid._minHit),
                    ?fillOf(w),
                    // Painted only: each day is read through its tap area.
                    ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: ExomMonthGrid._rowInset,
                        ),
                        // Equal height for the seven cells of the week.
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < 7; i++)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: inset,
                                    ),
                                    child: _cell(
                                      context,
                                      days[w * 7 + i],
                                      palette,
                                      motion.chipCrossfade,
                                      slides ? motion.selection : null,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    for (var i = 0; i < 7; i++)
                      if (days[w * 7 + i].month == month.month)
                        PositionedDirectional(
                          start: column * i,
                          width: column,
                          top: 0,
                          bottom: 0,
                          child: _hitArea(
                            days[w * 7 + i],
                            _label(l10n, dateFormat, days[w * 7 + i]),
                          ),
                        ),
                  ],
                ),
              ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            if (_w.monthTransition)
              ExomStepTransition(
                step: month.year * 12 + month.month,
                child: body,
              )
            else
              ...body.children,
          ],
        );
      },
    );
  }

  String _label(AppLocalizations l10n, DateFormat format, DateTime day) {
    var label = format.format(day);
    if (_sameDay(day, today)) label = l10n.homeWeekDayToday(label);
    final mark = markOf(day);
    final markLabel = markLabelOf;
    if (markLabel != null) {
      if (mark != ExomDayMark.none) label = markLabel(label, mark);
    } else {
      switch (mark) {
        case ExomDayMark.none:
          break;
        case ExomDayMark.pending:
          label = l10n.homeWeekDayPending(label);
        case ExomDayMark.done:
          label = l10n.homeWeekDayDone(label);
        case ExomDayMark.missed:
          label = l10n.homeWeekDayMissed(label);
      }
    }
    final flagLabel = flagLabelOf;
    if (flagLabel != null && _isFlagged(day)) label = flagLabel(label);
    return label;
  }

  bool _isFlagged(DateTime day) =>
      day.month == month.month && (flagOf?.call(day) ?? false);

  Widget _hitArea(DateTime day, String label) {
    final select = onSelect;
    final isSelected = selected != null && _sameDay(day, selected!);
    return Semantics(
      container: true,
      button: select != null,
      selected: isSelected,
      label: label,
      onTap: select == null ? null : () => select(day),
      excludeSemantics: true,
      child: select == null
          ? const SizedBox.expand()
          : GestureDetector(
              key: ExomMonthGrid.cellKey(day),
              behavior: HitTestBehavior.opaque,
              onTap: () => select(day),
            ),
    );
  }

  Widget _cell(
    BuildContext context,
    DateTime day,
    ExomThemePalette palette,
    Duration duration,
    Duration? slide,
  ) {
    final inMonth = day.month == month.month;
    final mark = inMonth ? markOf(day) : ExomDayMark.none;
    final isSelected = inMonth && selected != null && _sameDay(day, selected!);
    final isToday = inMonth && _sameDay(day, today);
    final filledDone = !isSelected && doneAsFill && mark == ExomDayMark.done;

    final Color? fill;
    final Color ink;
    BorderSide? outline;
    if (isSelected) {
      // With a sliding fill the layer under the week paints it.
      fill = slide == null ? palette.selectionFill : null;
      ink = palette.onSelectionFill;
    } else if (filledDone) {
      fill = palette.limeFill;
      ink = palette.onLimeFill;
      final limeOutline = palette.limeFillOutline;
      if (limeOutline != null) {
        outline = BorderSide(color: limeOutline, width: ExomRule.outline);
      }
    } else {
      fill = null;
      ink = inMonth ? palette.textPrimary : palette.textSecondary;
    }
    if (isToday) {
      outline = BorderSide(color: palette.textPrimary, width: ExomRule.outline);
    }
    final side = outline;

    final Color markInk = isSelected || filledDone
        ? ink
        : (mark == ExomDayMark.done ? palette.data : palette.textPrimary);
    final Widget? markWidget = switch (mark) {
      ExomDayMark.none => null,
      ExomDayMark.done => Icon(
        key: ExomMonthGrid.markKey(day),
        ExomIcons.check,
        size: _checkSize,
        color: markInk,
      ),
      ExomDayMark.pending => DecoratedBox(
        key: ExomMonthGrid.markKey(day),
        decoration: BoxDecoration(
          color: isSelected ? ink : palette.textSecondary,
          shape: BoxShape.circle,
        ),
        child: const SizedBox.square(dimension: _dotSize),
      ),
      ExomDayMark.missed => DecoratedBox(
        key: ExomMonthGrid.markKey(day),
        decoration: BoxDecoration(
          border: Border.all(color: markInk, width: ExomRule.outline),
          shape: BoxShape.circle,
        ),
        child: const SizedBox.square(dimension: _dotSize),
      ),
    };

    Widget number(Color color) => Text(
      '${day.day}',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppTheme.bodyFontFamily,
        fontSize: 16,
        fontWeight: inMonth ? FontWeight.w600 : FontWeight.w400,
        height: 1.2,
        color: color,
      ),
    );

    final cell = AnimatedContainer(
      key: ExomMonthGrid.visualKey(day),
      duration: duration,
      curve: Curves.linear,
      constraints: const BoxConstraints(minHeight: ExomMonthGrid._minVisual),
      decoration: BoxDecoration(
        color: fill,
        border: side == null ? null : Border.fromBorderSide(side),
      ),
      padding: const EdgeInsets.symmetric(vertical: ExomSpacing.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (slide == null)
            number(ink)
          else
            // The number changes ink with the sliding fill (`.a1-now`,
            // `.a1-was`).
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: ink),
              duration: slide,
              curve: ExomMotion.inPlaceCurve,
              builder: (context, color, _) => number(color ?? ink),
            ),
          const SizedBox(height: 3),
          SizedBox(
            height: _checkSize,
            child: markWidget == null ? null : Center(child: markWidget),
          ),
        ],
      ),
    );
    if (!inMonth || !_isFlagged(day)) return cell;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        cell,
        PositionedDirectional(
          top: _flagInsetTop,
          end: _flagInsetEnd,
          child: Icon(
            key: ExomMonthGrid.flagKey(day),
            ExomIcons.streak,
            size: _flagSize,
            color: isSelected || filledDone ? ink : palette.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Corner flag of the sketch (`.a-fl`: 11 px, 3 px from the top, 5 from
  /// the end).
  static const double _flagSize = 11;
  static const double _flagInsetTop = 3;
  static const double _flagInsetEnd = 5;

  /// Mark sizes of the week strip of Inicio (L4b-D4).
  static const double _dotSize = 6;
  static const double _checkSize = 12;
}

/// Selection fill under a week ([ExomMonthGrid.slideSelection]): it starts
/// [from] dp away (physical, horizontal) and slides to its place in
/// [duration], ease-out (M4). A new key restarts it.
class _SlidingFill extends StatelessWidget {
  const _SlidingFill({
    super.key,
    required this.color,
    required this.from,
    required this.duration,
  });

  final Color color;
  final double from;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final fill = ColoredBox(
      key: ExomMonthGrid.selectionFillKey,
      color: color,
      child: const SizedBox.expand(),
    );
    if (from == 0) return fill;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: 0),
      duration: duration,
      curve: ExomMotion.inPlaceCurve,
      child: fill,
      builder: (context, t, child) =>
          Transform.translate(offset: Offset(from * t, 0), child: child),
    );
  }
}
