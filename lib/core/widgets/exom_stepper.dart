import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
///
/// Optional presentation hooks (L5 T0.4, used by `ExomNumeralStepper`; all
/// off by default, so existing callers render exactly as before):
/// [valueBuilder] replaces the static value display, [valueStyle] replaces
/// the value text style (static and typed), and [onValueTap] makes the value
/// tappable and adds a tap action to the control's semantics node.
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
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
    this.textFieldKey,
    this.errorBelowRow = false,
    this.errorIcon,
    this.valueBuilder,
    this.valueStyle,
    this.onValueTap,
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

  /// Focus of the typed field (L3: the sheet moves focus to the first
  /// invalid field). Only used with [textController].
  final FocusNode? focusNode;

  /// Whether the typed field takes focus when it appears. Off by default.
  final bool autofocus;

  /// Keyboard action of the typed field (e.g. next from reps to weight).
  final TextInputAction? textInputAction;

  /// Key of the inner [TextField], a stable handle for tests.
  final Key? textFieldKey;

  /// Paints [errorText] under the whole row (full width, never clipped
  /// between the ± buttons) instead of inside the field. The field keeps its
  /// error styling and the control is exposed as invalid to screen readers.
  final bool errorBelowRow;

  /// Icon shown before [errorText] when [errorBelowRow] is set.
  final IconData? errorIcon;

  /// Replaces the static value display (no underline, no default text). Only
  /// used without [textController].
  final Widget Function(BuildContext context, T value)? valueBuilder;

  /// Replaces the default value text style (Barlow 36 in the text colour).
  final TextStyle? valueStyle;

  /// Tap on the static value (e.g. to start typing). Also exposed as the tap
  /// action of the control's semantics node.
  final VoidCallback? onValueTap;

  static const double buttonSize = 56;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final valueStyle =
        this.valueStyle ??
        TextStyle(
          fontFamily: AppTheme.displayFontFamily,
          fontSize: 36,
          fontWeight: FontWeight.w800,
          height: 1.0,
          color: palette.textPrimary,
        );

    final error = errorText;
    final errorOutside = errorBelowRow && error != null;
    final Widget centre;
    if (textController != null) {
      centre = TextField(
        key: textFieldKey,
        controller: textController,
        focusNode: focusNode,
        autofocus: autofocus,
        textInputAction: textInputAction,
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
          errorText: errorOutside ? null : error,
          // Keeps the field's error styling; the message is painted below.
          error: errorOutside ? const SizedBox.shrink() : null,
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
          // With the message below the row, the field keeps the underline
          // shape in the error colour (not the theme's outlined error box).
          errorBorder: errorOutside
              ? UnderlineInputBorder(
                  borderSide: BorderSide(color: palette.error, width: 1.5),
                )
              : null,
          focusedErrorBorder: errorOutside
              ? UnderlineInputBorder(
                  borderSide: BorderSide(color: palette.error, width: 2),
                )
              : null,
        ),
      );
    } else if (valueBuilder != null) {
      centre = valueBuilder!(context, value);
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
    final formatted = formatValue(value);
    // An empty value (an empty typed field) cannot be exposed with resulting
    // values: the platform requires both or neither (framework assertion).
    final exposeValue =
        formatted.isNotEmpty &&
        (onIncrement == null || increased != null) &&
        (onDecrement == null || decreased != null);
    final control = Semantics(
      container: true,
      label: exposeValue || formatted.isEmpty ? label : '$label, $formatted',
      value: exposeValue ? formatted : null,
      increasedValue: exposeValue && onIncrement != null && increased != null
          ? formatValue(increased)
          : null,
      decreasedValue: exposeValue && onDecrement != null && decreased != null
          ? formatValue(decreased)
          : null,
      validationResult: errorOutside
          ? SemanticsValidationResult.invalid
          : SemanticsValidationResult.none,
      onIncrease: onIncrement,
      onDecrease: onDecrement,
      onTap: onValueTap,
      child: Row(
        children: [
          _StepButton(
            icon: ExomIcons.remove,
            semanticLabel: decrementLabel,
            onPressed: onDecrement,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: textController != null
                ? centre
                : ExcludeSemantics(
                    child: onValueTap == null
                        ? centre
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onValueTap,
                            child: centre,
                          ),
                  ),
          ),
          const SizedBox(width: 8),
          _StepButton(
            icon: ExomIcons.add,
            semanticLabel: incrementLabel,
            onPressed: onIncrement,
          ),
        ],
      ),
    );
    if (!errorOutside) return control;

    final icon = errorIcon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        control,
        const SizedBox(height: 8),
        Semantics(
          container: true,
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: ExcludeSemantics(
                    child: Icon(icon, size: 18, color: palette.error),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  error,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: palette.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
