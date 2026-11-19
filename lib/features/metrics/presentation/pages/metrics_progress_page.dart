import 'dart:math' as math;

import 'package:exom_app/core/formatters/unit_converters.dart';
import 'package:exom_app/core/formatters/unit_formatters.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/preferences/app_preferences_cubit.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/glass_app_bar.dart';
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

/// «Progreso» frame of Métricas (sketch `t-progreso`): latest weight and its
/// change, weight chart, latest measurements, progress photos and the pinned
/// «Añadir medida» that opens the day form ([MetricsFormPage]).
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
        appBar: GlassAppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: Icon(Icons.arrow_back, color: palette.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: BlocBuilder<MetricsBloc, MetricsState>(
                builder: (context, state) => ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: HomeTitle(l10n.progressTitle),
                    ),
                    ..._content(context, state),
                  ],
                ),
              ),
            ),
            ExomPinnedFooter(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
              child: ExomPrimaryButton(
                key: const Key('progress-add-measure'),
                label: l10n.progressAddMeasure,
                trailingIcon: Icons.add,
                onPressed: _openForm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, MetricsState state) {
    final bloc = context.read<MetricsBloc>();
    if (state is MetricsHistoryFailure) {
      return [
        _HistoryMessage(
          message: state.offline
              ? AppLocalizations.of(context).progressHistoryOffline
              : AppLocalizations.of(context).progressHistoryError,
          onRetry: () => bloc.add(const MetricsHistoryRequested()),
        ),
        const SizedBox(height: 24),
        const _PhotosRow(),
      ];
    }
    if (state is MetricsHistoryLoaded) {
      // The metrics datasource swallows every error and returns [] / null, so
      // "no history and no latest" may be a failed request, not an empty
      // account. Do not claim the user has no data; offer a retry instead.
      // Pending owner decision: let the datasource tell error from empty.
      if (state.weightHistory.isEmpty && state.latest == null) {
        return [
          _HistoryMessage(
            message: AppLocalizations.of(context).progressHistoryUnavailable,
            onRetry: () => bloc.add(const MetricsHistoryRequested()),
          ),
          const SizedBox(height: 24),
          const _PhotosRow(),
        ];
      }
      final unitSystem = context.select<AppPreferencesCubit, UnitSystem>(
        (cubit) => cubit.state.unitSystem,
      );
      final l10n = AppLocalizations.of(context);
      final format = _ProgressFormat(l10n, unitSystem);
      final series = _weightSeries(state.weightHistory);
      final shown = series.length > _kChartPoints
          ? series.sublist(series.length - _kChartPoints)
          : series;
      return [
        _WeightSummary(points: shown, format: format),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: shown.length < 2
              ? _MutedText(l10n.progressChartEmpty)
              : _WeightChart(points: shown, format: format),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
          child: _SectionTitle(l10n.progressLatestMeasures),
        ),
        _LatestMeasures(
          rows: _latestRows(series, state.latest, format),
          format: format,
        ),
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
  });

  final String fieldKey;
  final int order;
  final DateTime day;
  final String label;
  final String value;
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
              ? format.weight(value)
              : format.length(value),
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
        value: format.weight(point.kg),
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

  String length(double cm) {
    final display = UnitConverters.lengthToDisplay(cm, unitSystem);
    return '${number(display)} ${lengthUnitSymbol(unitSystem)}';
  }

  String longDate(DateTime day) => _longDate.format(day);

  String shortDate(DateTime day) => _shortDate.format(day);

  /// «7 semanas» when the span is whole weeks, «10 días» otherwise. It is the
  /// interval between two weighings, not a distance to today.
  String period(int days) => days >= 7 && days % 7 == 0
      ? l10n.progressPeriodWeeks(days ~/ 7)
      : l10n.progressPeriodDays(days);
}

// ── Widgets ─────────────────────────────────────────────────────────────────

/// Section title (sketch `.t2`): Barlow Condensed 800, 22 px, uppercase.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: text,
      excludeSemantics: true,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: AppTheme.displayFontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          height: 0.95,
          letterSpacing: -0.44,
          color: context.exomPalette.textPrimary,
        ),
      ),
    );
  }
}

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

class _WeightSummary extends StatelessWidget {
  const _WeightSummary({required this.points, required this.format});

  final List<_WeightPoint> points;
  final _ProgressFormat format;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = format.l10n;
    final children = <Widget>[_SectionTitle(l10n.weightSectionTitle)];
    if (points.isEmpty) {
      children.addAll([
        const SizedBox(height: 8),
        _MutedText(l10n.progressWeightEmpty),
      ]);
    } else {
      final last = points.last;
      children.addAll([
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: format.weight(last.kg),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: ' ${l10n.progressOnDate(format.longDate(last.day))}',
              ),
            ],
          ),
          style: TextStyle(
            fontSize: 18,
            height: 1.35,
            color: palette.textPrimary,
          ),
        ),
      ]);
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
        children.addAll([const SizedBox(height: 4), _MutedText(sentence)]);
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Line chart of [points] (sketch `.chart`): line and dots in the text
/// colour, the last dot filled, kg axis on the left and first, middle and
/// last dates below. Screen readers get a one-sentence summary instead.
class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.points, required this.format});

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
          Text(format.weightUnit, style: axisStyle),
          const SizedBox(height: 4),
          Padding(
            // Room for the last dot (radius 4 + stroke) at the right edge.
            padding: const EdgeInsets.only(right: 10),
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
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: interval,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
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
                      color: palette.textPrimary,
                      barWidth: 2,
                      dotData: FlDotData(
                        getDotPainter: (spot, _, _, index) =>
                            FlDotCirclePainter(
                              radius: index == last ? 4 : 3.5,
                              color: index == last
                                  ? palette.textPrimary
                                  : palette.background,
                              strokeColor: palette.textPrimary,
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

/// Flat rows (sketch `.rows`): type and date on the left, value on the right,
/// then the progress photos row.
class _LatestMeasures extends StatelessWidget {
  const _LatestMeasures({required this.rows, required this.format});

  final List<_MeasureRowData> rows;
  final _ProgressFormat format;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _MutedText(format.l10n.progressMeasuresEmpty),
          ),
        for (final row in rows)
          KeyedSubtree(
            key: ValueKey(
              'progress-measure-${row.fieldKey}-'
              '${DateFormat('yyyy-MM-dd').format(row.day)}',
            ),
            child: _MeasureRow(
              label: row.label,
              date: format.shortDate(row.day),
              value: row.value,
            ),
          ),
        const _PhotosRow(),
      ],
    );
  }
}

class _RowFrame extends StatelessWidget {
  const _RowFrame({required this.child, this.last = false});

  final Widget child;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final rule = BorderSide(color: context.exomPalette.borderSoft, width: 1);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: rule, bottom: last ? rule : BorderSide.none),
      ),
      child: child,
    );
  }
}

class _MeasureRow extends StatelessWidget {
  const _MeasureRow({
    required this.label,
    required this.date,
    required this.value,
  });

  final String label;
  final String date;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return _RowFrame(
      child: Semantics(
        container: true,
        child: MergeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.3,
                            color: palette.textPrimary,
                          ),
                        ),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.3,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the existing progress photos route. No «Última sesión» subtitle:
/// that data is only available through a new network read.
class _PhotosRow extends StatelessWidget {
  const _PhotosRow();

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return _RowFrame(
      last: true,
      child: Semantics(
        container: true,
        button: true,
        child: InkWell(
          key: const Key('progress-photos-row'),
          onTap: () => context.push(AppRoutes.progressPhotos),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 22,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).progressPhotosEntry,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right,
                      size: 22,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
