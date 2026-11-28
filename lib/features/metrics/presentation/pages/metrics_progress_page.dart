import 'dart:math' as math;

import 'package:exom_app/core/formatters/unit_converters.dart';
import 'package:exom_app/core/formatters/unit_formatters.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_figure_columns.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_numbered_section_header.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/core/widgets/exom_app_bar.dart';
import 'package:exom_app/features/home/presentation/widgets/home_headline.dart';
import 'package:exom_app/features/metrics/domain/entities/body_metric_entity.dart';
import 'package:exom_app/features/metrics/presentation/bloc/metrics_bloc.dart';
import 'package:exom_app/features/metrics/presentation/pages/metrics_page.dart';
import 'package:exom_app/features/metrics/presentation/widgets/weight_chart_axis.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Weights drawn in the chart and used for the «X less in N weeks»
/// line: the most recent ones, as in the sketch (eight weekly points).
const int _kChartPoints = 8;

/// Rows shown under «Últimas medidas».
const int _kLatestRows = 6;

/// «Progreso» frame of Métricas (L5-E9a, sketch `e-migradas.html` «Progreso»):
/// two-line headline, the latest weight at 96 with its change and chart in the
/// featured block, the latest measurements in columns (01), the progress
/// photos entry (02) and the pinned «Añadir medida» that opens the day form
/// ([MetricsFormPage]).
class MetricsProgressPage extends StatelessWidget {
  const MetricsProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MetricsBloc>()..add(const MetricsHistoryRequested()),
      child: const _ProgressView(),
    );
  }
}

class _ProgressView extends StatefulWidget {
  const _ProgressView();

  @override
  State<_ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<_ProgressView> {
  bool _formOpen = false;

  /// Last loaded summary of THIS page instance, painted (read-only) while a
  /// reload is in flight so a retry does not blank the screen or reset the
  /// scroll. Dropped by any state that is not a load in progress.
  MetricsHistoryLoaded? _previous;

  Future<void> _openForm() async {
    if (_formOpen) return;
    _formOpen = true;
    final bloc = context.read<MetricsBloc>();
    try {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const MetricsFormPage()));
    } finally {
      _formOpen = false;
    }
    // The form pops itself after a successful save: refresh the summary.
    if (mounted && !bloc.isClosed) bloc.add(const MetricsHistoryRequested());
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ExomStaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: ExomAppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: Icon(ExomIcons.back, color: palette.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: BlocBuilder<MetricsBloc, MetricsState>(
                builder: (context, state) {
                  if (state is MetricsHistoryLoaded) {
                    _previous = state;
                  } else if (state is! MetricsHistoryLoading) {
                    _previous = null;
                  }
                  final held = state is MetricsHistoryLoading
                      ? _previous
                      : null;
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: HomeTitle(l10n.progressTitle),
                      ),
                      ..._content(
                        context,
                        held ?? state,
                        refreshing: held != null,
                      ),
                    ],
                  );
                },
              ),
            ),
            ExomPinnedFooter(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
              child: ExomPrimaryButton(
                key: const Key('progress-add-measure'),
                label: l10n.progressAddMeasure,
                trailingIcon: ExomIcons.add,
                onPressed: _openForm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [refreshing] paints a previously loaded [state] while the next load is in
  /// flight: same content, retry buttons disabled and a small progress mark.
  List<Widget> _content(
    BuildContext context,
    MetricsState state, {
    bool refreshing = false,
  }) {
    final bloc = context.read<MetricsBloc>();
    if (state is MetricsHistoryFailure) {
      return [
        const _Intro(),
        _HistoryMessage(
          message: state.offline
              ? AppLocalizations.of(context).progressHistoryOffline
              : AppLocalizations.of(context).progressHistoryError,
          onRetry: () => bloc.add(const MetricsHistoryRequested()),
        ),
        const SizedBox(height: 24),
        const _PhotosSection(n: 1),
      ];
    }
    if (state is MetricsHistoryLoaded) {
      // Network and server errors arrive as [MetricsHistoryFailure], so an
      // empty history with no latest record is an account without records.
      final unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
        (cubit) => cubit.state.unitSystem,
      );
      final l10n = AppLocalizations.of(context);
      final format = _ProgressFormat(l10n, unitSystem);
      final series = _weightSeries(state.weightHistory);
      final shown = series.length > _kChartPoints
          ? series.sublist(series.length - _kChartPoints)
          : series;
      final unavailability = state.latestUnavailability;
      final latestUnavailable =
          unavailability != MetricsLatestUnavailability.none;
      final cached = state.historyFromCache || state.latestFromCache;
      final VoidCallback? retry = refreshing
          ? null
          : () => bloc.add(const MetricsHistoryRequested());
      return [
        if (cached)
          _CachedBanner(
            text: l10n.progressCachedBanner,
            // The page has no pull-to-refresh: with nothing missing, the
            // banner carries the only retry. The section notice owns it
            // otherwise, so two retry buttons never show together.
            showRetry: !latestUnavailable,
            onRetry: retry,
            refreshing: refreshing,
            announce: !latestUnavailable,
          )
        else if (refreshing && !latestUnavailable)
          // No retry on screen to carry the mark (e.g. the reload after
          // saving a measure, L4-I26c): the mark alone, in the slot of the
          // cached banner, only while the reload is in flight.
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _RefreshMark(key: Key('progress-refresh-mark')),
            ),
          ),
        const _Intro(),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _WeightFeature(points: shown, format: format),
        ),
        const SizedBox(height: 8),
        ExomNumberedSectionHeader(n: 1, title: l10n.progressLatestMeasures),
        _LatestMeasures(
          rows: _latestRows(series, state.latest, format),
          format: format,
          unavailableNotice: latestUnavailable
              ? (unavailability == MetricsLatestUnavailability.offline
                    ? l10n.progressLatestUnavailableOffline
                    : l10n.progressLatestUnavailableError)
              : null,
          onRetry: retry,
          refreshing: refreshing,
        ),
        const _PhotosSection(n: 2),
      ];
    }
    final l10n = AppLocalizations.of(context);
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Semantics(
            label: l10n.progressLoading,
            child: const CircularProgressIndicator(),
          ),
        ),
      ),
    ];
  }
}

/// Subtitle and two-line headline under the title. They follow the cached band
/// (when there is one) so the band stays next to the title, as before.
class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: _MutedText(l10n.progressSubtitle),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: ExomTwoLineHeadline(
            first: l10n.progressHeadlineFirst,
            second: l10n.progressHeadlineSecond,
          ),
        ),
      ],
    );
  }
}

// ── Data ────────────────────────────────────────────────────────────────────

class _WeightPoint {
  const _WeightPoint(this.day, this.kg);

  /// Calendar day as a UTC midnight, so day differences are exact.
  final DateTime day;
  final double kg;
}

DateTime _day(DateTime date) => DateTime.utc(date.year, date.month, date.day);

/// One weight per day (the last one listed wins, as in the profile chart),
/// oldest first.
List<_WeightPoint> _weightSeries(List<BodyMetricEntity> history) {
  final byDay = <DateTime, double>{};
  for (final entry in history) {
    final kg = entry.weightKg;
    if (kg != null) byDay[_day(entry.date)] = kg;
  }
  final days = byDay.keys.toList()..sort();
  return [for (final day in days) _WeightPoint(day, byDay[day]!)];
}

enum _Kind { weight, length }

typedef _Field = ({
  String key,
  _Kind kind,
  double? Function(BodyMetricEntity) read,
  String Function(AppLocalizations) label,
});

String _side(AppLocalizations l10n, String measure, bool left) =>
    l10n.progressMeasureSide(
      measure,
      left ? l10n.leftSideLabel : l10n.rightSideLabel,
    );

/// Measurement types in display order (same order as the day form).
final List<_Field> _fields = [
  (
    key: 'weight_kg',
    kind: _Kind.weight,
    read: (m) => m.weightKg,
    label: (l) => l.weightSectionTitle,
  ),
  (
    key: 'muscle_mass_kg',
    kind: _Kind.weight,
    read: (m) => m.muscleMassKg,
    label: (l) => l.muscleMassSectionTitle,
  ),
  (
    key: 'height_cm',
    kind: _Kind.length,
    read: (m) => m.heightCm,
    label: (l) => l.heightSectionTitle,
  ),
  (
    key: 'neck_cm',
    kind: _Kind.length,
    read: (m) => m.neckCm,
    label: (l) => l.measureNeck,
  ),
  (
    key: 'shoulders_cm',
    kind: _Kind.length,
    read: (m) => m.shouldersCm,
    label: (l) => l.measureShoulders,
  ),
  (
    key: 'chest_cm',
    kind: _Kind.length,
    read: (m) => m.chestCm,
    label: (l) => l.measureChest,
  ),
  (
    key: 'arm_left_cm',
    kind: _Kind.length,
    read: (m) => m.armLeftCm,
    label: (l) => _side(l, l.measureArm, true),
  ),
  (
    key: 'arm_right_cm',
    kind: _Kind.length,
    read: (m) => m.armRightCm,
    label: (l) => _side(l, l.measureArm, false),
  ),
  (
    key: 'forearm_left_cm',
    kind: _Kind.length,
    read: (m) => m.forearmLeftCm,
    label: (l) => _side(l, l.measureForearm, true),
  ),
  (
    key: 'forearm_right_cm',
    kind: _Kind.length,
    read: (m) => m.forearmRightCm,
    label: (l) => _side(l, l.measureForearm, false),
  ),
  (
    key: 'waist_cm',
    kind: _Kind.length,
    read: (m) => m.waistCm,
    label: (l) => l.measureWaist,
  ),
  (
    key: 'hips_cm',
    kind: _Kind.length,
    read: (m) => m.hipsCm,
    label: (l) => l.measureHips,
  ),
  (
    key: 'thigh_left_cm',
    kind: _Kind.length,
    read: (m) => m.thighLeftCm,
    label: (l) => _side(l, l.measureThigh, true),
  ),
  (
    key: 'thigh_right_cm',
    kind: _Kind.length,
    read: (m) => m.thighRightCm,
    label: (l) => _side(l, l.measureThigh, false),
  ),
  (
    key: 'calf_left_cm',
    kind: _Kind.length,
    read: (m) => m.calfLeftCm,
    label: (l) => _side(l, l.measureCalf, true),
  ),
  (
    key: 'calf_right_cm',
    kind: _Kind.length,
    read: (m) => m.calfRightCm,
    label: (l) => _side(l, l.measureCalf, false),
  ),
];

class _MeasureRowData {
  const _MeasureRowData({
    required this.fieldKey,
    required this.order,
    required this.day,
    required this.label,
    required this.value,
    required this.unit,
  });

  final String fieldKey;
  final int order;
  final DateTime day;
  final String label;

  /// Figure already formatted for the locale, without its unit.
  final String value;
  final String unit;
}

/// Newest values first: every type of the latest record plus the earlier
/// weights of the history (the history endpoint only carries weight).
List<_MeasureRowData> _latestRows(
  List<_WeightPoint> series,
  BodyMetricEntity? latest,
  _ProgressFormat format,
) {
  final rows = <_MeasureRowData>[];
  DateTime? latestWeightDay;
  if (latest != null) {
    final day = _day(latest.date);
    for (var i = 0; i < _fields.length; i++) {
      final field = _fields[i];
      final value = field.read(latest);
      if (value == null) continue;
      if (field.key == 'weight_kg') latestWeightDay = day;
      rows.add(
        _MeasureRowData(
          fieldKey: field.key,
          order: i,
          day: day,
          label: field.label(format.l10n),
          value: field.kind == _Kind.weight
              ? format.weightFigure(value)
              : format.lengthFigure(value),
          unit: field.kind == _Kind.weight
              ? format.weightUnit
              : format.lengthUnit,
        ),
      );
    }
  }
  for (final point in series) {
    if (point.day == latestWeightDay) continue;
    rows.add(
      _MeasureRowData(
        fieldKey: 'weight_kg',
        order: 0,
        day: point.day,
        label: format.l10n.weightSectionTitle,
        value: format.weightFigure(point.kg),
        unit: format.weightUnit,
      ),
    );
  }
  rows.sort((a, b) {
    final byDay = b.day.compareTo(a.day);
    return byDay != 0 ? byDay : a.order.compareTo(b.order);
  });
  return rows.take(_kLatestRows).toList();
}

/// Locale-aware numbers (decimal comma in Spanish) in the user's units.
class _ProgressFormat {
  _ProgressFormat(this.l10n, this.unitSystem)
    : _number = NumberFormat('0.#', l10n.localeName),
      _longDate = DateFormat.MMMMd(l10n.localeName),
      _shortDate = DateFormat('d MMM', l10n.localeName);

  final AppLocalizations l10n;
  final UnitSystem unitSystem;
  final NumberFormat _number;
  final DateFormat _longDate;
  final DateFormat _shortDate;

  String get weightUnit => weightUnitSymbol(unitSystem);

  /// Kilograms in display units, rounded to the one decimal shown.
  double displayWeight(double kg) =>
      (UnitConverters.weightToDisplay(kg, unitSystem) * 10).round() / 10;

  String number(double value) => _number.format(value);

  String weight(double kg) => '${number(displayWeight(kg))} $weightUnit';

  /// The weight figure without its unit (the numeral paints the unit apart).
  String weightFigure(double kg) => number(displayWeight(kg));

  String get lengthUnit => lengthUnitSymbol(unitSystem);

  String lengthFigure(double cm) =>
      number(UnitConverters.lengthToDisplay(cm, unitSystem));

  String longDate(DateTime day) => _longDate.format(day);

  String shortDate(DateTime day) => _shortDate.format(day);

  /// «7 semanas» when the span is whole weeks, «10 días» otherwise. It is the
  /// interval between two weighings, not a distance to today.
  String period(int days) => days >= 7 && days % 7 == 0
      ? l10n.progressPeriodWeeks(days ~/ 7)
      : l10n.progressPeriodDays(days);
}

// ── Widgets ─────────────────────────────────────────────────────────────────

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: context.exomPalette.textSecondary,
      ),
    );
  }
}

/// Small spinner with an accessible label, shown next to a disabled retry
/// while the reload is in flight.
class _RefreshMark extends StatelessWidget {
  const _RefreshMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Its own node: merged into the notice it would announce both texts.
      container: true,
      liveRegion: true,
      label: AppLocalizations.of(context).progressLoading,
      excludeSemantics: true,
      child: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

/// Discreet «offline, saved data» line (icon + text, never colour alone),
/// styled like [ExomSyncStatus]. With [showRetry] a compact text action sits
/// to the right of the text, or under it when it does not fit; a null
/// [onRetry] shows it disabled (reload in flight, [refreshing]).
class _CachedBanner extends StatelessWidget {
  const _CachedBanner({
    required this.text,
    required this.showRetry,
    required this.onRetry,
    this.refreshing = false,
    this.announce = true,
  });

  final String text;
  final bool showRetry;
  final VoidCallback? onRetry;
  final bool refreshing;

  /// Live region only when no section notice is announcing at the same time.
  /// While [refreshing] the progress mark is the only announcement (L4-I26b).
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          // Icon + text take their natural width and the text wraps by
          // itself (hanging indent), so the retry can sit beside them or
          // drop below. The icon is stacked so the width never rounds over.
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Semantics(
                  liveRegion: announce && !refreshing,
                  child: Text(
                    text,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 1,
                child: ExcludeSemantics(
                  child: Icon(
                    ExomIcons.offline,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (showRetry)
            ExomQuietButton(
              label: AppLocalizations.of(context).retry,
              onPressed: onRetry,
            ),
          if (showRetry && refreshing) const _RefreshMark(),
        ],
      ),
    );
  }
}

/// Featured block of the weight (sketch `.x-feat` + `.x-hero.e-wt`): kicker
/// «Peso · el 18 de noviembre», the latest weight at 96 in the data colour with
/// the change over the chart's weeks beside it, and the chart.
class _WeightFeature extends StatelessWidget {
  const _WeightFeature({required this.points, required this.format});

  final List<_WeightPoint> points;
  final _ProgressFormat format;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = format.l10n;
    final children = <Widget>[];
    if (points.isEmpty) {
      children.addAll([
        _padded(ExomKicker(l10n.weightSectionTitle)),
        const SizedBox(height: 12),
        _padded(_MutedText(l10n.progressWeightEmpty)),
      ]);
    } else {
      final last = points.last;
      Widget? side;
      if (points.length >= 2) {
        final first = points.first;
        final diff =
            format.displayWeight(last.kg) - format.displayWeight(first.kg);
        final rounded = (diff * 10).round() / 10;
        final period = format.period(last.day.difference(first.day).inDays);
        final amount = '${format.number(rounded.abs())} ${format.weightUnit}';
        final sentence = rounded == 0
            ? l10n.progressDeltaSame(period)
            : rounded < 0
            ? l10n.progressDeltaLess(amount, period)
            : l10n.progressDeltaMore(amount, period);
        side = Text(
          sentence,
          style: TextStyle(
            fontFamily: AppTheme.bodyFontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: palette.textPrimary,
          ),
        );
      }
      children.addAll([
        _padded(
          ExomKicker(
            '${l10n.weightSectionTitle} · '
            '${l10n.progressOnDate(format.longDate(last.day))}',
          ),
        ),
        const SizedBox(height: 16),
        _padded(
          ExomNumeral(
            key: const Key('progress-weight-hero'),
            value: format.weightFigure(last.kg),
            unit: format.weightUnit,
            size: ExomNumeralSize.hero96,
            side: side,
          ),
        ),
      ]);
    }
    children.addAll([
      const SizedBox(height: 16),
      _padded(
        points.length < 2
            ? _MutedText(l10n.progressChartEmpty)
            : _WeightChart(points: points, format: format),
      ),
    ]);
    return ExomFeatureBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  static Widget _padded(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: child,
  );
}

/// Line chart of [points] (sketch `.x-chart`): line and dots in the data
/// colour, the last dot filled, kg axis on the right (the sketch's side) and
/// first, middle and last dates below. Screen readers get a one-sentence
/// summary instead.
class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.points, required this.format});

  /// Gap between the plot's right edge (where the last dot sits) and the axis
  /// labels: the dot's radius and stroke plus a visible margin.
  static const double _axisGap = 12;

  final List<_WeightPoint> points;
  final _ProgressFormat format;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final values = [for (final p in points) format.displayWeight(p.kg)];
    final axis = weightAxis(values.reduce(math.min), values.reduce(math.max));
    final minY = axis.min;
    final maxY = axis.max;
    final interval = axis.interval;
    final last = points.length - 1;
    final labelled = {0, if (points.length >= 3) last ~/ 2, last};
    final axisStyle = TextStyle(fontSize: 13, color: palette.textSecondary);
    // The top label is centred on the plot's top edge, so it reaches half its
    // line above it: leave that room under the unit. The last dot sits on the
    // plot's right edge, so the labels start `_axisGap` clear of it and the
    // reserved column grows with the text size.
    final labelSize = MediaQuery.textScalerOf(context).scale(13);
    final unitGap = labelSize * 0.65 + 4;
    final axisWidth = math.max(44.0, _axisGap + labelSize * 1.9);
    final summary = format.l10n.progressChartSemantics(
      format.longDate(points.first.day),
      format.longDate(points.last.day),
      format.weight(points.first.kg),
      format.weight(points.last.kg),
    );

    return Semantics(
      key: const Key('progress-weight-chart'),
      container: true,
      image: true,
      label: summary,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(format.weightUnit, style: axisStyle),
          ),
          SizedBox(height: unitGap),
          Padding(
            // Room for the first dot (radius 3.5 + stroke) at the left edge.
            padding: const EdgeInsets.only(left: 6),
            child: SizedBox(
              height: 170,
              child: LineChart(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                LineChartData(
                  minX: 0,
                  maxX: last.toDouble(),
                  minY: minY,
                  maxY: maxY,
                  lineTouchData: const LineTouchData(enabled: false),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: palette.borderSoft, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    leftTitles: const AxisTitles(),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: axisWidth,
                        interval: interval,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          space: _axisGap,
                          child: Text(format.number(value), style: axisStyle),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (value != index.toDouble() ||
                              !labelled.contains(index)) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            fitInside: SideTitleFitInsideData.fromTitleMeta(
                              meta,
                            ),
                            child: Text(
                              format.shortDate(points[index].day),
                              style: axisStyle,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < values.length; i++)
                          FlSpot(i.toDouble(), values[i]),
                      ],
                      color: palette.data,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        getDotPainter: (spot, _, _, index) =>
                            FlDotCirclePainter(
                              radius: index == last ? 5 : 3.5,
                              color: index == last
                                  ? palette.data
                                  : palette.surface,
                              strokeColor: palette.data,
                              strokeWidth: 1.75,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Latest measurements (sketch `.x-cols`): the newest values in columns, three
/// per row, each with its date in the label. [ExomFigureColumns] stacks the
/// figures in one column when the width or the text size do not allow a row.
class _LatestMeasures extends StatelessWidget {
  const _LatestMeasures({
    required this.rows,
    required this.format,
    required this.onRetry,
    this.refreshing = false,
    this.unavailableNotice,
  });

  /// Figures per row of columns (the sketch shows three).
  static const int _perRow = 3;

  final List<_MeasureRowData> rows;
  final _ProgressFormat format;
  final VoidCallback? onRetry;

  /// A reload is in flight: the retry is disabled and shows a progress mark.
  final bool refreshing;

  /// Why the latest record's measurements are missing (null when it was
  /// read, even if there is no record).
  final String? unavailableNotice;

  @override
  Widget build(BuildContext context) {
    final notice = unavailableNotice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // While refreshing, the progress mark below is the only
                // live region (L4-I26b).
                Semantics(
                  liveRegion: !refreshing,
                  child: _MutedText(notice),
                ),
                const SizedBox(height: 12),
                ExomSecondaryButton(
                  label: format.l10n.retry,
                  onPressed: onRetry,
                ),
                if (refreshing)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(child: _RefreshMark()),
                  ),
              ],
            ),
          )
        else if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: _MutedText(format.l10n.progressMeasuresEmpty),
          ),
        for (var start = 0; start < rows.length; start += _perRow)
          ExomFigureColumns(
            numbered: false,
            items: [
              for (final row in rows.skip(start).take(_perRow))
                ExomFigure(
                  itemKey: ValueKey(
                    'progress-measure-${row.fieldKey}-'
                    '${DateFormat('yyyy-MM-dd').format(row.day)}',
                  ),
                  value: row.value,
                  unit: row.unit,
                  label: '${row.label} · ${format.shortDate(row.day)}',
                ),
            ],
          ),
      ],
    );
  }
}

/// «02 Fotos de progreso»: header and the entry that opens the existing
/// progress photos route. No «Última sesión» subtitle or thumbnails: that data
/// is only available through a new network read.
class _PhotosSection extends StatelessWidget {
  const _PhotosSection({required this.n});

  /// Number of the section header («01» when the measurements are not shown).
  final int n;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExomNumberedSectionHeader(n: n, title: l10n.progressPhotosTitle),
        ExomFlatRowGroup(
          children: [
            ExomFlatRow(
              key: const Key('progress-photos-row'),
              leading: ExcludeSemantics(
                child: Icon(
                  ExomIcons.camera,
                  size: 22,
                  color: palette.textPrimary,
                ),
              ),
              title: l10n.progressPhotosEntry,
              onTap: () => context.push(AppRoutes.progressPhotos),
            ),
          ],
        ),
      ],
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: context.exomPalette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ExomSecondaryButton(label: l10n.retry, onPressed: onRetry),
        ],
      ),
    );
  }
}
