import 'dart:math' as math;

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
///
/// [compact] (L6 A-O1, the set sheet's footer rows): the ± are drawn at
/// [compactButtonSize] inside the same [buttonSize] tap area (4 dp of
/// invisible margin per side) and sit [compactGap] from the value, so the
/// visible gap stays 6 dp; the typed field is a little shorter.
///
/// [typedSample] (A-D1): the widest text the typed field is expected to hold.
/// When it, at the system text scale and with the [unit], does not fit
/// between the ± buttons, the field takes the full width and the ± sit under
/// it, so a large system font never clips the typed digits. The choice only
/// depends on the sample, the scale and the width, never on what is typed.
/// The field sits under a `GlobalKey` owned by the control, so when the width
/// or the scale changes and the layout switches between the row and the
/// stacked form, the same `TextField` element moves with its state (focus,
/// text and selection) instead of being rebuilt; a switch in the very frame
/// where the keyboard moves may still re-reveal the caret.
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
    this.compact = false,
    this.typedSample,
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

  /// Widest text of the typed field, to stack the ± under it when the field
  /// would not fit between them (large system text).
  final String? typedSample;

  /// Draws the ± at [compactButtonSize] within the [buttonSize] tap area.
  final bool compact;

  /// Tap area of each ± (visible size too, unless [compact]).
  static const double buttonSize = 56;

  /// Visible size of each ± when [compact].
  static const double compactButtonSize = 48;

  /// Gap between each ± tap area and the value when [compact].
  static const double compactGap = 2;

  /// Style of the unit shown after a typed value, shared by the field and
  /// by the measure of [typedSample] (colour is added by the field).
  static const TextStyle _unitSuffixStyle = TextStyle(
    fontFamily: AppTheme.bodyFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// Gap between each ± and the value otherwise.
  static const double gap = 8;

  @override
  Widget build(BuildContext context) =>
      _CentreKeyHost(builder: (centreKey) => _buildWith(context, centreKey));

  Widget _buildWith(BuildContext context, GlobalKey centreKey) {
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
    // Stacked, the unit leaves the field (it would take part of the width the
    // digits need) and sits between the ± instead.
    Widget centreFor(bool stacked) {
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
            suffixText: stacked ? null : unit,
            suffixStyle: _unitSuffixStyle.copyWith(
              color: palette.textSecondary,
            ),
            contentPadding: EdgeInsets.symmetric(vertical: compact ? 4 : 6),
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
      return KeyedSubtree(key: centreKey, child: centre);
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
    Widget buildControl(bool stacked) {
      final keyedCentre = centreFor(stacked);
      return Semantics(
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
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  keyedCentre,
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StepButton(
                        icon: ExomIcons.remove,
                        semanticLabel: decrementLabel,
                        onPressed: onDecrement,
                        compact: compact,
                      ),
                      if (unit case final unitText?)
                        ExcludeSemantics(
                          child: Text(
                            unitText,
                            style: _unitSuffixStyle.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                      _StepButton(
                        icon: ExomIcons.add,
                        semanticLabel: incrementLabel,
                        onPressed: onIncrement,
                        compact: compact,
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  _StepButton(
                    icon: ExomIcons.remove,
                    semanticLabel: decrementLabel,
                    onPressed: onDecrement,
                    compact: compact,
                  ),
                  SizedBox(width: compact ? compactGap : gap),
                  Expanded(
                    child: textController != null
                        ? keyedCentre
                        : ExcludeSemantics(
                            child: onValueTap == null
                                ? keyedCentre
                                : GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: onValueTap,
                                    child: keyedCentre,
                                  ),
                          ),
                  ),
                  SizedBox(width: compact ? compactGap : gap),
                  _StepButton(
                    icon: ExomIcons.add,
                    semanticLabel: incrementLabel,
                    onPressed: onIncrement,
                    compact: compact,
                  ),
                ],
              ),
      );
    }

    final sample = typedSample;
    final Widget control = textController != null && sample != null
        ? LayoutBuilder(
            builder: (context, constraints) {
              final scaler = MediaQuery.textScalerOf(context);
              final painter = TextPainter(
                text: TextSpan(
                  children: [
                    TextSpan(text: sample, style: valueStyle),
                    if (unit != null)
                      TextSpan(text: unit, style: _unitSuffixStyle),
                  ],
                ),
                textDirection: Directionality.of(context),
                textScaler: scaler,
                maxLines: 1,
              )..layout();
              // The field has no horizontal contentPadding (only vertical),
              // so the 4 dp are the caret (2 dp) and its rounding.
              final needed = painter.width + 4;
              painter.dispose();
              final gaps = compact ? compactGap : gap;
              final room = constraints.maxWidth - 2 * (buttonSize + gaps);
              return buildControl(needed > room);
            },
          )
        : buildControl(false);

    // With the message below the row and a text field, the control always
    // sits in this Column, error or not: switching between the bare control
    // and a Column when the error appears would remount the TextField, and the
    // new EditableText of an already focused field never listens to the
    // keyboard insets, so it would not scroll itself above the keyboard and
    // the pinned actions (E-D1).
    if (!errorOutside && !(errorBelowRow && textController != null)) {
      return control;
    }

    final icon = errorIcon;
    // The focused field reveals its caret when it gains focus or the keyboard
    // moves; with a message below the row, that reveal also takes in the
    // message (INT-D1), always wrapped so the TextField is never remounted.
    return _RevealErrorBelow(
      enabled: error != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          control,
          if (error != null) ...[
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
        ],
      ),
    );
  }
}

/// Extends a descendant's request to be shown on screen (the focused field
/// revealing its caret) down to this box's bottom, so the error message
/// painted under the field is revealed with it. When the field and the
/// message do not both fit in the enclosing viewport, the original request
/// is kept: the field and its caret take priority.
class _RevealErrorBelow extends SingleChildRenderObjectWidget {
  const _RevealErrorBelow({required this.enabled, required super.child});

  final bool enabled;

  @override
  _RenderRevealErrorBelow createRenderObject(BuildContext context) =>
      _RenderRevealErrorBelow(enabled: enabled);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderRevealErrorBelow renderObject,
  ) {
    renderObject.enabled = enabled;
  }
}

class _RenderRevealErrorBelow extends RenderProxyBox {
  _RenderRevealErrorBelow({required this.enabled});

  bool enabled;

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (enabled && descendant != null && descendant != this && hasSize) {
      final requested = rect ?? descendant.paintBounds;
      final local = MatrixUtils.transformRect(
        descendant.getTransformTo(this),
        requested,
      );
      final widened = Rect.fromLTRB(
        local.left,
        local.top,
        local.right,
        math.max(local.bottom, size.height),
      );
      // Nearest enclosing viewport that scrolls vertically; horizontal ones
      // are skipped. If none is found, the nearest one is used as before.
      var viewport = RenderAbstractViewport.maybeOf(this);
      final nearest = viewport;
      while (viewport is RenderViewportBase &&
          viewport.axis != Axis.vertical) {
        final parent = viewport.parent;
        viewport = parent is RenderObject
            ? RenderAbstractViewport.maybeOf(parent)
            : null;
      }
      viewport ??= nearest;
      final fits =
          viewport is RenderBox &&
          (viewport as RenderBox).hasSize &&
          widened.height <= (viewport as RenderBox).size.height;
      if (fits) {
        super.showOnScreen(
          descendant: this,
          rect: widened,
          duration: duration,
          curve: curve,
        );
        return;
      }
    }
    super.showOnScreen(
      descendant: descendant,
      rect: rect,
      duration: duration,
      curve: curve,
    );
  }
}

class _StepButton extends StatefulWidget {
  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.compact = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool compact;

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
        child: SizedBox.square(
          dimension: ExomStepper.buttonSize,
          child: Center(child: _box(palette, enabled)),
        ),
      ),
    );
  }

  Widget _box(ExomThemePalette palette, bool enabled) {
    final visible = widget.compact
        ? ExomStepper.compactButtonSize
        : ExomStepper.buttonSize;
    return Container(
      width: visible,
      height: visible,
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
    );
  }
}

/// Owns the [GlobalKey] of the control's field (see [ExomStepper.typedSample]).
class _CentreKeyHost extends StatefulWidget {
  const _CentreKeyHost({required this.builder});

  final Widget Function(GlobalKey centreKey) builder;

  @override
  State<_CentreKeyHost> createState() => _CentreKeyHostState();
}

class _CentreKeyHostState extends State<_CentreKeyHost> {
  final GlobalKey _centreKey = GlobalKey();

  @override
  Widget build(BuildContext context) => widget.builder(_centreKey);
}
