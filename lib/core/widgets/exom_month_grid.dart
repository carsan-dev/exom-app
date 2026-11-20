import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
/// selected state and, with [onSelect], a tap action.
///
/// Optional flag (L5-A4a, sketch `.a-fl`): a day for which [flagOf] returns
/// true carries a small flame in its top end corner, in the secondary text
/// colour (in the ink of the fill on a selected or filled day, never lime as
/// ink), and [flagLabelOf] extends that day's label. Without [flagOf] the grid
/// is unchanged.
class ExomMonthGrid extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final motion = ExomMotion.of(context);
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final days = daysOf(month);
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
        final inset = ((column - _minVisual) / 2).clamp(0.0, 1.0).toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Row(
                key: weekdayHeaderKey,
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
            ),
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
                    const SizedBox(height: _minHit),
                    // Painted only: each day is read through its tap area.
                    ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: _rowInset,
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
      },
    );
  }

  String _label(AppLocalizations l10n, DateFormat format, DateTime day) {
    var label = format.format(day);
    if (_sameDay(day, today)) label = l10n.homeWeekDayToday(label);
    switch (markOf(day)) {
      case ExomDayMark.none:
        break;
      case ExomDayMark.pending:
        label = l10n.homeWeekDayPending(label);
      case ExomDayMark.done:
        label = l10n.homeWeekDayDone(label);
      case ExomDayMark.missed:
        label = l10n.homeWeekDayMissed(label);
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
              key: cellKey(day),
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
      fill = palette.selectionFill;
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
        key: markKey(day),
        Icons.check,
        size: _checkSize,
        color: markInk,
      ),
      ExomDayMark.pending => DecoratedBox(
        key: markKey(day),
        decoration: BoxDecoration(
          color: isSelected ? ink : palette.textSecondary,
          shape: BoxShape.circle,
        ),
        child: const SizedBox.square(dimension: _dotSize),
      ),
      ExomDayMark.missed => DecoratedBox(
        key: markKey(day),
        decoration: BoxDecoration(
          border: Border.all(color: markInk, width: ExomRule.outline),
          shape: BoxShape.circle,
        ),
        child: const SizedBox.square(dimension: _dotSize),
      ),
    };

    final cell = AnimatedContainer(
      key: visualKey(day),
      duration: duration,
      curve: Curves.linear,
      constraints: const BoxConstraints(minHeight: _minVisual),
      decoration: BoxDecoration(
        color: fill,
        border: side == null ? null : Border.fromBorderSide(side),
      ),
      padding: const EdgeInsets.symmetric(vertical: ExomSpacing.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${day.day}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              fontSize: 16,
              fontWeight: inMonth ? FontWeight.w600 : FontWeight.w400,
              height: 1.2,
              color: ink,
            ),
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
            key: flagKey(day),
            Icons.local_fire_department_outlined,
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
