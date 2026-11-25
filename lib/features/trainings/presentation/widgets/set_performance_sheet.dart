import 'dart:math' as math;

import 'package:exom_app/core/formatters/unit_formatters.dart';
import 'package:exom_app/core/formatters/weight_input.dart';
import 'package:exom_app/core/preferences/app_preferences.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/core/widgets/exom_stepper.dart';
import 'package:exom_app/features/trainings/domain/entities/training_entity.dart';
import 'package:exom_app/features/trainings/domain/services/set_input_parser.dart';
import 'package:exom_app/features/trainings/domain/services/set_prefill.dart';
import 'package:exom_app/features/trainings/domain/services/training_performance_utils.dart';
import 'package:exom_app/features/trainings/presentation/widgets/set_value_text.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Result of the set sheet. [weight] is in **kilograms** (canonical unit,
/// decision D5); [seconds] is always seconds (minutes input is converted);
/// [skipped] is «Completar sin registrar». A dismissed sheet returns null.
typedef SetPerformanceResult = ({
  int? reps,
  int? seconds,
  double? weight,
  int? rir,
  bool skipped,
});

/// Smallest size of the fitted value numeral (the size before L5-E4).
const double _numeralMinSize = 36;

/// Room kept for the caret and the suffix gap when fitting the numeral.
const double _numeralFitSlack = 8;

/// Style of the unit after a typed value (`ExomStepper`'s suffix).
const TextStyle _unitStyle = TextStyle(
  fontFamily: AppTheme.bodyFontFamily,
  fontSize: 16,
  fontWeight: FontWeight.w600,
);

/// Upper bounds of decision D3 (typo guards; the API has none).
const int kMaxSetReps = 999;
const int kMaxSetSeconds = 6 * 60 * 60;
const int kMaxSetMinutes = 6 * 60;

/// Content of the set-logging sheet (sketch «A · Hoja de registro»), shown
/// with `showExomSheet`. Shared by the active exercise and the circuit: it
/// never reads a bloc; every input is explicit and already resolved by the
/// caller (see `set_prefill.dart` for the precedence rules).
///
/// Untouched fields are returned verbatim: when the text of a field is still
/// the text it was opened (or filled by «Igual que la anterior») with, the
/// source value is returned as is (kg double, seconds, RIR), so re-saving
/// never drifts through unit conversion or rounding (D5) and a stored RIR
/// above 5 is kept while «5+» shows it.
class SetPerformanceSheet extends StatefulWidget {
  const SetPerformanceSheet({
    super.key,
    required this.title,
    required this.objective,
    required this.timeUnit,
    required this.countRequired,
    required this.unitSystem,
    required this.decimalSeparator,
    this.initialCount,
    this.initialWeightKg,
    this.initialRir,
    this.previous,
    this.today,
  });

  /// «Serie 2».
  final String title;

  /// Prescription text («8 reps · RIR 2»); empty hides it.
  final String objective;

  /// Null for reps; seconds or minutes for timed sets.
  final TimePerformanceUnit? timeUnit;

  /// Set tracking is mandatory: the reps/seconds field must be filled and
  /// «Completar sin registrar» is not offered.
  final bool countRequired;
  final UnitSystem unitSystem;
  final String decimalSeparator;

  /// Reps, or seconds for timed sets (converted to minutes for display when
  /// [timeUnit] is minutes and it divides evenly).
  final int? initialCount;
  final double? initialWeightKg;
  final int? initialRir;

  /// Previous session's set: «Anterior …» and «Igual que la anterior».
  final SetPerformance? previous;

  /// Today's already logged value for this set («Hoy: …» line).
  final SetPerformance? today;

  @override
  State<SetPerformanceSheet> createState() => _SetPerformanceSheetState();
}

class _SetPerformanceSheetState extends State<SetPerformanceSheet> {
  final _countController = TextEditingController();
  final _weightController = TextEditingController();
  final _countFocus = FocusNode();
  final _weightFocus = FocusNode();
  final _countKey = GlobalKey();
  final _weightKey = GlobalKey();

  TimePerformanceUnit? _timeUnit;

  // Baselines of the untouched-field rule.
  String _countBaselineText = '';
  int? _countBaselineValue;
  String _weightBaselineText = '';
  double? _weightBaselineKg;

  int? _rir;
  String? _countError;
  String? _weightError;
  bool _saving = false;

  bool get _timed => _timeUnit != null;
  bool get _minutes => _timeUnit == TimePerformanceUnit.minutes;
  WeightText get _weightText =>
      WeightText(widget.unitSystem, widget.decimalSeparator);
  String get _unitSymbol => weightUnitSymbol(widget.unitSystem);
  double get _maxWeight => maxWeightDisplay(widget.unitSystem);
  double get _step => weightStep(widget.unitSystem);

  @override
  void initState() {
    super.initState();
    _timeUnit = timePerformanceUnitForInput(
      widget.timeUnit,
      widget.timeUnit == null ? null : widget.initialCount,
    );
    _setCount(widget.initialCount);
    _setWeight(widget.initialWeightKg);
    _rir = widget.initialRir;
  }

  @override
  void dispose() {
    _countController.dispose();
    _weightController.dispose();
    _countFocus.dispose();
    _weightFocus.dispose();
    super.dispose();
  }

  // ---- field helpers ----

  /// Sets the count field from a canonical value (reps or seconds) and makes
  /// it the new untouched baseline.
  void _setCount(int? canonical) {
    final text = canonical == null
        ? ''
        : '${_timed ? timeInputFromSeconds(canonical, _timeUnit) : canonical}';
    _countController.text = text;
    _countBaselineText = text;
    _countBaselineValue = canonical;
  }

  void _setWeight(double? kg) {
    final text = kg == null ? '' : _weightText.number(kg);
    _weightController.text = text;
    _weightBaselineText = text;
    _weightBaselineKg = kg;
  }

  int get _countMax => !_timed
      ? kMaxSetReps
      : _minutes
      ? kMaxSetMinutes
      : kMaxSetSeconds;

  String? get _countUnitSymbol => !_timed
      ? null
      : _minutes
      ? 'min'
      : 's';

  ParsedInput<int> _parseCount() => parseCount(
    _countController.text,
    max: _countMax,
    unitSymbol: _countUnitSymbol,
  );

  ParsedInput<double> _parseWeight() => parseWeight(
    _weightController.text,
    max: _maxWeight,
    unitSymbol: _unitSymbol,
  );

  int get _countStep => _timed && !_minutes ? 5 : 1;

  int? _countBase() {
    final parsed = _parseCount();
    if (parsed is ParsedValue<int>) return parsed.value;
    if (parsed is ParsedInvalid<int>) return null;
    // Empty: start from the prescription/prefill when there is one.
    final initial = widget.initialCount;
    if (initial == null) return 0;
    return _timed ? timeInputFromSeconds(initial, _timeUnit) : initial;
  }

  int? _stepCountValue(int direction) {
    final base = _countBase();
    if (base == null) return null;
    return (base + direction * _countStep).clamp(1, _countMax);
  }

  double? _weightBase() {
    final parsed = _parseWeight();
    if (parsed is ParsedValue<double>) return parsed.value;
    if (parsed is ParsedInvalid<double>) return null;
    final initial = widget.initialWeightKg;
    return initial == null ? 0 : kgToDisplay(initial, widget.unitSystem);
  }

  double? _stepWeightValue(int direction) {
    final base = _weightBase();
    if (base == null) return null;
    final next = ((base + direction * _step) * 100).round() / 100;
    return next.clamp(0, _maxWeight).toDouble();
  }

  String _formatDisplay(double value) =>
      formatDisplayDecimal(value, decimalSeparator: widget.decimalSeparator);

  void _stepCount(int direction) {
    final next = _stepCountValue(direction);
    if (next == null) return;
    setState(() {
      _countController.text = '$next';
      _countError = null;
    });
  }

  void _stepWeight(int direction) {
    final next = _stepWeightValue(direction);
    if (next == null) return;
    setState(() {
      _weightController.text = _formatDisplay(next);
      _weightError = null;
    });
  }

  void _onCountChanged(String _) {
    setState(() {
      if (_countError != null && _parseCount() is ParsedValue<int>) {
        _countError = null;
      }
    });
  }

  void _onWeightChanged(String _) {
    setState(() {
      if (_weightError != null && _parseWeight() is! ParsedInvalid<double>) {
        _weightError = null;
      }
    });
  }

  void _applyPrevious() {
    final previous = widget.previous;
    if (previous == null) return;
    setState(() {
      final count = _timed ? previous.seconds : previous.reps;
      if (_minutes && count != null && count % 60 != 0) {
        _timeUnit = TimePerformanceUnit.seconds;
      }
      _setCount(count);
      _setWeight(previous.weightKg);
      _rir = previous.rir;
      _countError = null;
      _weightError = null;
    });
  }

  // ---- errors ----

  String get _decimalExample => '62${widget.decimalSeparator}5';

  String _countExample() {
    final raw = _countController.text.trim().replaceAll(',', '.');
    final asDecimal = double.tryParse(raw);
    if (asDecimal != null && asDecimal >= 1 && raw.contains('.')) {
      return '${asDecimal.floor()}';
    }
    final initial = widget.initialCount;
    if (initial != null) {
      return '${_timed ? timeInputFromSeconds(initial, _timeUnit) : initial}';
    }
    return _timed ? (_minutes ? '10' : '45') : '8';
  }

  String _countRequiredMessage(AppLocalizations l10n) =>
      _timed ? l10n.setPerformanceSecondsError : l10n.setPerformanceRepsError;

  String _countMessage(
    AppLocalizations l10n,
    SetFormError error,
    SetInputError? input,
  ) {
    if (error == SetFormError.noData) return l10n.setPerformanceDataError;
    if (error == SetFormError.countRequired) return _countRequiredMessage(l10n);
    final value = _countController.text.trim();
    return switch (input) {
      SetInputError.negative ||
      SetInputError.belowMin => _countRequiredMessage(l10n),
      SetInputError.notInteger ||
      SetInputError.ambiguous ||
      SetInputError.tooManyDecimals => l10n.setInputNotInteger(_countExample()),
      SetInputError.aboveMax => l10n.setInputAboveMax(
        _countUnitSymbol == null
            ? '$_countMax'
            : '$_countMax $_countUnitSymbol',
      ),
      SetInputError.notANumber ||
      null => l10n.setInputNotANumber(value, _countExample()),
    };
  }

  String _weightMessage(AppLocalizations l10n, SetInputError? input) {
    final value = _weightController.text.trim();
    return switch (input) {
      SetInputError.negative ||
      SetInputError.belowMin => l10n.setPerformanceWeightError,
      SetInputError.ambiguous => l10n.setInputWeightAmbiguous(
        value,
        _decimalExample,
      ),
      SetInputError.tooManyDecimals => l10n.setInputTooManyDecimals(
        _decimalExample,
      ),
      SetInputError.aboveMax => l10n.setInputAboveMax(
        '${_formatDisplay(_maxWeight)} $_unitSymbol',
      ),
      SetInputError.notInteger ||
      SetInputError.notANumber ||
      null => l10n.setInputNotANumber(value, _decimalExample),
    };
  }

  // ---- actions ----

  void _save() {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    // Untouched values pass through unchanged, even a legacy value outside
    // today's bounds: only what the user typed is validated.
    final baselineCount = _countBaselineValue;
    final baselineKg = _weightBaselineKg;
    final countUntouched =
        baselineCount != null && _countController.text == _countBaselineText;
    final weightUntouched =
        baselineKg != null && _weightController.text == _weightBaselineText;
    final countInput = countUntouched
        ? ParsedValue<int>(baselineCount)
        : _parseCount();
    final weightInput = weightUntouched
        ? ParsedValue<double>(baselineKg)
        : _parseWeight();
    final validation = validateSetForm(
      count: countInput,
      weight: weightInput,
      countRequired: widget.countRequired,
    );
    if (!validation.isValid) {
      final countError = validation.countError;
      final weightError = validation.weightError;
      setState(() {
        _countError = countError == null
            ? null
            : _countMessage(l10n, countError, validation.countInputError);
        _weightError = weightError == null
            ? null
            : _weightMessage(l10n, validation.weightInputError);
      });
      final focus = countError != null ? _countFocus : _weightFocus;
      final key = countError != null ? _countKey : _weightKey;
      focus.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = key.currentContext;
        if (target != null && target.mounted) {
          Scrollable.ensureVisible(
            target,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
            alignment: 0.1,
          );
        }
      });
      return;
    }

    final int? count = validation.count;
    final int? canonicalCount = countUntouched
        ? baselineCount
        : count == null
        ? null
        : _timed
        ? secondsFromTimeInput(count, _timeUnit)
        : count;
    final double? weightDisplay = validation.weight;
    final double? weightKg = weightUntouched
        ? baselineKg
        : weightDisplay == null
        ? null
        : displayToKg(weightDisplay, widget.unitSystem);

    setState(() => _saving = true);
    Navigator.of(context).pop<SetPerformanceResult>((
      reps: _timed ? null : canonicalCount,
      seconds: _timed ? canonicalCount : null,
      weight: weightKg,
      rir: _rir,
      skipped: false,
    ));
  }

  void _completeWithoutTracking() {
    if (_saving) return;
    setState(() => _saving = true);
    Navigator.of(context).pop<SetPerformanceResult>((
      reps: null,
      seconds: null,
      weight: null,
      rir: null,
      skipped: true,
    ));
  }

  /// [style] (Barlow 64) shrunk so that [text] and its [unit] fit between the
  /// ± buttons of a stepper [width] wide, instead of scrolling inside the
  /// field at large text sizes: the numeral scales down like `ExomNumeral`
  /// (sketch `.numstep-v .num64{font-size:min(4em,18cqw)}`). Never below 36,
  /// the size before L5-E4; the text itself is never touched.
  TextStyle _fitNumeral(
    BuildContext context,
    TextStyle style,
    String text,
    String? unit,
    double width,
  ) {
    final size = style.fontSize ?? _numeralMinSize;
    if (!width.isFinite) return style;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double measure(String value, TextStyle textStyle) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: textStyle),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final measured = painter.width;
      painter.dispose();
      return measured;
    }

    final unitWidth = unit == null
        ? 0.0
        : measure(unit, _unitStyle) + _numeralFitSlack;
    final room =
        width -
        2 * ExomStepper.buttonSize -
        2 * 8 -
        unitWidth -
        _numeralFitSlack;
    final needed = measure(text.isEmpty ? '0' : text, style);
    if (needed <= room || room <= 0) return style;
    final fitted = math.max(_numeralMinSize, size * room / needed);
    return style.copyWith(fontSize: fitted.floorToDouble());
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final media = MediaQuery.of(context);
    // The ExomSheet frame scrolls its whole content and caps it at 90 % of
    // the space above the keyboard. To keep the actions pinned, this content
    // takes at most that height (minus the handle and the bottom safe area,
    // which the frame's SafeArea hides from this MediaQuery), scrolls its
    // fields itself and leaves the actions outside the scroll view.
    final bottomSafe = MediaQueryData.fromView(View.of(context)).padding.bottom;
    final maxHeight = math.max(
      0.0,
      (media.size.height - media.padding.top - media.viewInsets.bottom) * 0.9 -
          16 -
          bottomSafe -
          1,
    );

    final mutedStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 14,
      height: 1.4,
      color: palette.textSecondary,
    );
    final labelStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: palette.textPrimary,
    );

    final previous = widget.previous;
    final previousLabel = previous == null
        ? null
        : setValueLabel(l10n, previous, _weightText);
    final todayLabel = widget.today == null
        ? null
        : setValueLabel(l10n, widget.today!, _weightText, withRir: true);
    final objective = widget.objective.trim();
    final summary = objective.isEmpty
        ? (previousLabel == null ? null : l10n.setPerformancePrevious(previousLabel))
        : previousLabel == null
        ? l10n.setSheetObjective(objective)
        : l10n.setSheetObjectiveWithPrevious(objective, previousLabel);

    final countParsed = _parseCount();
    final countValid = countParsed is! ParsedInvalid<int>;
    final weightValid = _parseWeight() is! ParsedInvalid<double>;
    final countDown = countValid ? _stepCountValue(-1) : null;
    final countUp = countValid ? _stepCountValue(1) : null;
    final weightDown = weightValid ? _stepWeightValue(-1) : null;
    final weightUp = weightValid ? _stepWeightValue(1) : null;
    final stepText = '${_formatDisplay(_step)} $_unitSymbol';

    // L5-E4: the values are Barlow 64 numerals in the data colour (sketch
    // `.numstep`, `.num64.x-d`), typed or not, as in `ExomNumeralStepper`.
    final numeralStyle = ExomType.hero64.copyWith(
      height: 1,
      color: palette.data,
    );

    final countLabel = !_timed
        ? l10n.setSheetRepsLabel
        : _minutes
        ? l10n.setPerformanceMinutes
        : l10n.setSheetSecondsLabel;

    final fields = Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              widget.title.toUpperCase(),
              // Sketch `.t1b` (L5-E4): the section size, 28.
              style: ExomType.headline2Section.copyWith(
                color: palette.textPrimary,
              ),
            ),
          ),
          if (summary != null) ...[
            const SizedBox(height: 6),
            Text(summary, style: mutedStyle),
          ],
          if (todayLabel != null) ...[
            const SizedBox(height: 4),
            Text(l10n.todayWithLabel(todayLabel), style: mutedStyle),
          ],
          if (previous != null && previousLabel != null) ...[
            const SizedBox(height: 18),
            ExomSecondaryButton(
              key: const Key('set-sheet-same-as-previous'),
              label: l10n.setSheetSameAsPrevious(previousLabel),
              onPressed: _applyPrevious,
            ),
          ],
          const SizedBox(height: 18),
          Text(countLabel, style: labelStyle),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) => ExomStepper<String>(
              key: _countKey,
              value: _countController.text,
              formatValue: (text) => text,
              label: countLabel,
              decrementLabel: !_timed
                  ? l10n.setSheetRepsDecrement
                  : _minutes
                  ? l10n.setSheetMinutesDecrement
                  : l10n.setSheetSecondsDecrement(_countStep),
              incrementLabel: !_timed
                  ? l10n.setSheetRepsIncrement
                  : _minutes
                  ? l10n.setSheetMinutesIncrement
                  : l10n.setSheetSecondsIncrement(_countStep),
              onDecrement: countDown == null ? null : () => _stepCount(-1),
              onIncrement: countUp == null ? null : () => _stepCount(1),
              decreasedValue: countDown == null ? null : '$countDown',
              increasedValue: countUp == null ? null : '$countUp',
              unit: _countUnitSymbol,
              textController: _countController,
              textFieldKey: const Key('set-sheet-count-field'),
              focusNode: _countFocus,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              inputFormatters: [LengthLimitingTextInputFormatter(10)],
              onTextChanged: _onCountChanged,
              onTextSubmitted: (_) => _weightFocus.requestFocus(),
              errorText: _countError,
              errorBelowRow: true,
              errorIcon: ExomIcons.error,
              valueStyle: _fitNumeral(
                context,
                numeralStyle,
                _countController.text,
                _countUnitSymbol,
                constraints.maxWidth,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(l10n.setSheetWeightLabel, style: labelStyle),
              Text(l10n.setSheetWeightHint(stepText), style: mutedStyle),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) => ExomStepper<String>(
              key: _weightKey,
              value: _weightController.text,
              formatValue: (text) => text.isEmpty ? text : '$text $_unitSymbol',
              label: widget.unitSystem == UnitSystem.imperial
                  ? l10n.setSheetWeightLbA11y
                  : l10n.setSheetWeightKgA11y,
              decrementLabel: l10n.setSheetWeightDecrement(stepText),
              incrementLabel: l10n.setSheetWeightIncrement(stepText),
              onDecrement: weightDown == null ? null : () => _stepWeight(-1),
              onIncrement: weightUp == null ? null : () => _stepWeight(1),
              decreasedValue: weightDown == null
                  ? null
                  : _formatDisplay(weightDown),
              increasedValue: weightUp == null
                  ? null
                  : _formatDisplay(weightUp),
              unit: _unitSymbol,
              textController: _weightController,
              textFieldKey: const Key('set-sheet-weight-field'),
              focusNode: _weightFocus,
              textInputAction: TextInputAction.done,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              // No filtering formatter: invalid text must stay as typed (D3).
              inputFormatters: [LengthLimitingTextInputFormatter(10)],
              onTextChanged: _onWeightChanged,
              errorText: _weightError,
              errorBelowRow: true,
              errorIcon: ExomIcons.error,
              valueStyle: _fitNumeral(
                context,
                numeralStyle,
                _weightController.text,
                _unitSymbol,
                constraints.maxWidth,
              ),
            ),
          ),
          ...[
            const SizedBox(height: 18),
            Text(l10n.setSheetRirLabel, style: labelStyle),
            const SizedBox(height: 6),
            ExomChoiceChips<int>(
              key: const Key('set-sheet-rir'),
              options: const [0, 1, 2, 3, 4, 5],
              selected: rirChipFor(_rir),
              labelOf: (value) => value == 5 ? '5+' : '$value',
              semanticLabelOf: (value) => value == 5
                  ? l10n.setSheetRirFivePlusA11y
                  : l10n.setSheetRirChipA11y(value),
              onSelected: (value) => setState(() {
                // Tapping the selected chip clears the RIR (saved without it);
                // «5+» saves 5.
                _rir = value == rirChipFor(_rir) ? null : value;
              }),
            ),
          ],
        ],
      ),
    );

    final actions = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.borderSoft)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ExomPrimaryButton(
              key: const Key('set-sheet-save'),
              label: l10n.setSheetSave,
              trailingIcon: ExomIcons.check,
              busy: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: 4),
            Center(
              child: ExomQuietButton(
                key: const Key('set-sheet-cancel'),
                label: l10n.cancel,
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
              ),
            ),
            if (!widget.countRequired)
              Center(
                child: ExomQuietButton(
                  key: const Key('set-sheet-skip-tracking'),
                  label: l10n.completeWithoutTracking,
                  onPressed: _saving ? null : _completeWithoutTracking,
                ),
              ),
          ],
        ),
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(child: SingleChildScrollView(child: fields)),
          actions,
        ],
      ),
    );
  }
}
