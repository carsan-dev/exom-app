import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// − value + stepper of the set sheet (sketch «A · Hoja de registro»).
///
/// Pure UI: it shows [value] through [formatValue] and calls [onDecrement] /
/// [onIncrement]; it never parses or clamps. A null callback disables that
/// button. The ± buttons are 56x56 with their own accessible labels and do not
/// scale on press (principle 1 omission: they are pressed dozens of times);
/// they only change colour.
///
/// The whole control is one semantics node labelled [label] whose value is the
/// formatted value, with increase/decrease actions bound to the callbacks.
///
/// Typed entry: pass [textController] to show a [TextField] instead of the
/// static value. Every edit is forwarded verbatim to [onTextChanged] /
/// [onTextSubmitted]; the caller owns parsing, normalisation and errors
/// ([errorText] is displayed under the field).
class ExomStepper<T> extends StatelessWidget {
  const ExomStepper({
    super.key,
    required this.value,
    required this.formatValue,
    required this.label,
    required this.decrementLabel,
    required this.incrementLabel,
    required this.onDecrement,
    required this.onIncrement,
    this.unit,
    this.textController,
    this.keyboardType,
    this.inputFormatters,
    this.onTextChanged,
    this.onTextSubmitted,
    this.errorText,
    this.increasedValue,
    this.decreasedValue,
  });

  final T value;
  final String Function(T value) formatValue;
  final String label;
  final String decrementLabel;
  final String incrementLabel;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  /// Small unit shown after a typed value (e.g. "kg").
  final String? unit;
  final TextEditingController? textController;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onTextChanged;
  final ValueChanged<String>? onTextSubmitted;
  final String? errorText;

  /// Values the increase/decrease actions lead to, for screen readers. The
  /// semantics `value` is only exposed when every enabled action has its
  /// resulting value (a platform requirement); otherwise the formatted value
  /// is appended to the label.
  final T? increasedValue;
  final T? decreasedValue;

  static const double buttonSize = 56;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final valueStyle = TextStyle(
      fontFamily: AppTheme.displayFontFamily,
      fontSize: 36,
      fontWeight: FontWeight.w800,
      height: 1.0,
      color: palette.textPrimary,
    );

    final Widget centre;
    if (textController != null) {
      centre = TextField(
        controller: textController,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onTextChanged,
        onSubmitted: onTextSubmitted,
        textAlign: TextAlign.center,
        style: valueStyle,
        decoration: InputDecoration(
          filled: false,
          isDense: true,
          labelText: null,
          errorText: errorText,
          errorMaxLines: 3,
          suffixText: unit,
          suffixStyle: TextStyle(
            fontFamily: AppTheme.bodyFontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: palette.textSecondary,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          border: UnderlineInputBorder(
            borderSide: BorderSide(color: palette.textSecondary, width: 1.5),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: palette.textSecondary, width: 1.5),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: palette.textPrimary, width: 2),
          ),
        ),
      );
    } else {
      centre = DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: palette.textSecondary, width: 1.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatValue(value),
              textAlign: TextAlign.center,
              maxLines: 1,
              style: valueStyle,
            ),
          ),
        ),
      );
    }

    final increased = increasedValue;
    final decreased = decreasedValue;
    final exposeValue =
        (onIncrement == null || increased != null) &&
        (onDecrement == null || decreased != null);
    final formatted = formatValue(value);
    return Semantics(
      container: true,
      label: exposeValue ? label : '$label, $formatted',
      value: exposeValue ? formatted : null,
      increasedValue: exposeValue && onIncrement != null && increased != null
          ? formatValue(increased)
          : null,
      decreasedValue: exposeValue && onDecrement != null && decreased != null
          ? formatValue(decreased)
          : null,
      onIncrease: onIncrement,
      onDecrease: onDecrement,
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove,
            semanticLabel: decrementLabel,
            onPressed: onDecrement,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: textController != null
                ? centre
                : ExcludeSemantics(child: centre),
          ),
          const SizedBox(width: 8),
          _StepButton(
            icon: Icons.add,
            semanticLabel: incrementLabel,
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatefulWidget {
  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final enabled = widget.onPressed != null;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onPressed,
        child: Container(
          width: ExomStepper.buttonSize,
          height: ExomStepper.buttonSize,
          decoration: BoxDecoration(
            color: _pressed ? palette.surfaceElevated : null,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: enabled ? palette.textSecondary : palette.borderSoft,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 24,
            color: enabled ? palette.textPrimary : palette.textDisabled,
          ),
        ),
      ),
    );
  }
}
