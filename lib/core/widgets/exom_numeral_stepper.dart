import 'package:exom_app/core/formatters/weight_input.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Numeral with stepper of the L5 redesign (ESPEC §3, `.numstep`): a 64
/// numeral ([ExomNumeral], `ExomType.hero64`) in the data colour with its
/// [unit], between − and + buttons of 56, built on [ExomStepper] (pure UI).
///
/// No defaults: [min], [max], [step] and [unit] come from each screen's
/// current validation (contract table «Rangos de los steppers»). The
/// component does not validate business rules:
///
/// * ± move [value] by [step], clamped to [min]..[max]; at a limit the button
///   that would cross it is disabled (state «límite»).
/// * Tapping the numeral starts typing (state «editando»). The value is shown
///   and parsed with the locale separator (`weight_input.dart`); a comma or a
///   point is accepted, at most one, no grouping, no sign.
/// * A parsed typed value is emitted through [onChanged] when it lies in
///   [min]..[max] or when [acceptsTypedOutOfRange] is true (today's manual
///   modes accept any value > 0 without a cap). Otherwise, and for text that
///   does not parse (including empty), [onInvalidInput] receives the raw text
///   and nothing is emitted; typing stays open until the text is valid.
/// * [errorText] is the caller's message (state «error»), painted under the
///   row with an icon, announced as a live region; the control is exposed as
///   invalid.
///
/// A null [onChanged] disables the buttons and typing.
class ExomNumeralStepper extends StatefulWidget {
  const ExomNumeralStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.label,
    required this.decrementLabel,
    required this.incrementLabel,
    required this.onChanged,
    required this.acceptsTypedOutOfRange,
    this.onInvalidInput,
    this.errorText,
  }) : assert(min <= max, 'min must not exceed max'),
       assert(step > 0, 'step must be positive');

  final double value;
  final double min;
  final double max;
  final double step;
  final String unit;
  final String label;
  final String decrementLabel;
  final String incrementLabel;
  final ValueChanged<double>? onChanged;

  /// Whether a typed value outside [min]..[max] is emitted (the ± range then
  /// only bounds the buttons).
  final bool acceptsTypedOutOfRange;
  final ValueChanged<String>? onInvalidInput;
  final String? errorText;

  /// Key of the tappable numeral, for tests.
  static const Key valueKey = ValueKey('exom-numeral-stepper-value');

  /// Key of the typed field, for tests.
  static const Key fieldKey = ValueKey('exom-numeral-stepper-field');

  /// [raw] as a number: digits with at most one «,» or «.» as the decimal
  /// separator. Null when it does not parse or is not finite.
  static double? parse(String raw) {
    final text = raw.trim();
    if (!_number.hasMatch(text)) return null;
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null || !value.isFinite) return null;
    return value;
  }

  static final RegExp _number = RegExp(r'^(\d+([.,]\d*)?|[.,]\d+)$');

  @override
  State<ExomNumeralStepper> createState() => _ExomNumeralStepperState();
}

class _ExomNumeralStepperState extends State<ExomNumeralStepper> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _editing = false;
  bool _typedValid = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _format(double value) => formatDisplayDecimal(
    value,
    decimalSeparator: decimalSeparatorFor(
      Localizations.localeOf(context).languageCode,
    ),
  );

  /// Removes floating point noise (0.1 + 0.2) from a stepped value.
  static double _clean(double value) => (value * 1e6).round() / 1e6;

  double _stepped(int direction) => _clean(
    widget.value + direction * widget.step,
  ).clamp(widget.min, widget.max).toDouble();

  void _onFocusChange() {
    if (!_focus.hasFocus) _finish();
  }

  void _startEditing() {
    _controller.text = _format(widget.value);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    _typedValid = true;
    setState(() => _editing = true);
  }

  void _finish() {
    if (_editing && _typedValid) setState(() => _editing = false);
  }

  void _onText(String raw) {
    final change = widget.onChanged;
    if (change == null) return;
    final parsed = ExomNumeralStepper.parse(raw);
    final inRange =
        parsed != null && parsed >= widget.min && parsed <= widget.max;
    if (parsed != null && (inRange || widget.acceptsTypedOutOfRange)) {
      _typedValid = true;
      change(parsed);
    } else {
      _typedValid = false;
      widget.onInvalidInput?.call(raw);
    }
  }

  void _step(int direction) {
    final change = widget.onChanged;
    if (change == null) return;
    final next = _stepped(direction);
    if (_editing) {
      _controller.text = _format(next);
      _typedValid = true;
    }
    change(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final enabled = widget.onChanged != null;
    final canDecrement = enabled && widget.value > widget.min;
    final canIncrement = enabled && widget.value < widget.max;
    final unit = widget.unit;
    return ExomStepper<double>(
      value: widget.value,
      formatValue: (v) => '${_format(v)} $unit',
      label: widget.label,
      decrementLabel: widget.decrementLabel,
      incrementLabel: widget.incrementLabel,
      onDecrement: canDecrement ? () => _step(-1) : null,
      onIncrement: canIncrement ? () => _step(1) : null,
      decreasedValue: canDecrement ? _stepped(-1) : null,
      increasedValue: canIncrement ? _stepped(1) : null,
      unit: unit,
      textController: _editing ? _controller : null,
      textFieldKey: ExomNumeralStepper.fieldKey,
      focusNode: _focus,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      textInputAction: TextInputAction.done,
      onTextChanged: _onText,
      onTextSubmitted: (_) => _finish(),
      errorText: widget.errorText,
      errorBelowRow: true,
      errorIcon: ExomIcons.error,
      valueStyle: ExomType.hero64.copyWith(height: 1, color: palette.data),
      onValueTap: enabled && !_editing ? _startEditing : null,
      valueBuilder: (context, value) => Center(
        key: ExomNumeralStepper.valueKey,
        child: ExomNumeral(
          value: _format(value),
          unit: unit,
          size: ExomNumeralSize.hero64,
        ),
      ),
    );
  }
}
