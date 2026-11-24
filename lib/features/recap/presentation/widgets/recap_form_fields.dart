import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_choice_chips.dart';
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_numeral.dart';
import 'package:exom_app/core/widgets/exom_scale_chips.dart';
import 'package:exom_app/core/widgets/exom_step_header.dart';
import 'package:exom_app/features/recap/presentation/widgets/recap_anatomy_selector.dart';
import 'package:exom_app/l10n/app_localizations.dart';

String formatRecapOption(String value) {
  return value
      .split('_')
      .where((segment) => segment.isNotEmpty)
      .map(
        (segment) =>
            '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String recapCopy(BuildContext context, String value) {
  const translations = <String, List<String>>{
    'ENTRENO': ['Entreno', 'Training'],
    'NUTRICION': ['Nutricion', 'Nutrition'],
    'RECUPERACION': ['Recuperacion', 'Recovery'],
    'GENERAL': ['General', 'General'],
    'REVIEWED': ['Revisado', 'Reviewed'],
    'SUBMITTED': ['Enviado', 'Submitted'],
    'DRAFT': ['Borrador', 'Draft'],
    'MAL': ['Mal', 'Bad'],
    'NO': ['No', 'No'],
    'REGULAR': ['Regular', 'Fair'],
    'SI': ['Si', 'Yes'],
    'NORMAL': ['Normal', 'Normal'],
    'BIEN': ['Bien', 'Good'],
    'MUY_BIEN': ['Muy bien', 'Very good'],
    'MUY_MAL': ['Muy mal', 'Very bad'],
    'ENTRENAMIENTO': ['Entrenamiento', 'Training'],
    'ADHERENCIA': ['Adherencia', 'Consistency'],
    'APP': ['App', 'App'],
    'NADA': ['Nada', 'None'],
    'POCO': ['Poco', 'Low'],
    'ESTABLE': ['Estable', 'Steady'],
    'MEJORANDO': ['Mejorando', 'Improving'],
    'EXCELENTE': ['Excelente', 'Excellent'],
    'BAJA': ['Baja', 'Low'],
    'MODERADA': ['Moderada', 'Moderate'],
    'ALTA': ['Alta', 'High'],
    'MUY_ALTA': ['Muy alta', 'Very high'],
    'MALA': ['Mala', 'Poor'],
    'BUENA': ['Buena', 'Good'],
    'MUY_BUENA': ['Muy buena', 'Very good'],
    'MENOS_5': ['Menos de 5 h', 'Under 5 h'],
    'ENTRE_5_6': ['Entre 5 y 6 h', 'Between 5 and 6 h'],
    'ENTRE_6_7': ['Entre 6 y 7 h', 'Between 6 and 7 h'],
    'MAS_8': ['Mas de 8 h', 'Over 8 h'],
    'CANSADO': ['Cansado', 'Tired'],
    'FUERTE': ['Fuerte', 'Strong'],
    'LEVE': ['Leve', 'Mild'],
    'MODERADO': ['Moderado', 'Moderate'],
    'ALTO': ['Alto', 'High'],
    'CUELLO': ['Cuello', 'Neck'],
    'HOMBROS': ['Hombros', 'Shoulders'],
    'ESPALDA': ['Espalda', 'Back'],
    'LUMBAR': ['Lumbar', 'Lower back'],
    'GLUTEOS': ['Gluteos', 'Glutes'],
    'CUADRICEPS': ['Cuadriceps', 'Quads'],
    'ISQUIOS': ['Isquios', 'Hamstrings'],
    'GEMELOS': ['Gemelos', 'Calves'],
    'neck': ['Cuello', 'Neck'],
    'shoulders': ['Hombros', 'Shoulders'],
    'chest': ['Pecho', 'Chest'],
    'upperArm': ['Brazo', 'Upper arm'],
    'forearm': ['Antebrazo', 'Forearm'],
    'waist': ['Cintura', 'Waist'],
    'hips': ['Caderas', 'Hips'],
    'thigh': ['Muslo', 'Thigh'],
    'calf': ['Pantorrilla', 'Calf'],
    'FRONTAL': ['Frontal', 'Front'],
    'POSTERIOR': ['Posterior', 'Back'],
  };

  final translation = translations[value];
  if (translation != null) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return languageCode == 'en' ? translation[1] : translation[0];
  }

  return formatRecapOption(value);
}

class RecapSliderField extends StatelessWidget {
  final String label;
  final String helperText;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double value) valueLabelBuilder;
  final ValueChanged<double> onChanged;

  const RecapSliderField({
    super.key,
    required this.label,
    required this.helperText,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.valueLabelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: palette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helperText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textDisabled,
            fontSize: 12, // l5-allow: unused widget, kept as it was (C5a)
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                activeColor: palette.primary,
                inactiveColor: palette.surfaceVariant,
                label: valueLabelBuilder(value),
                onChanged: onChanged,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: GlassDecoration.card(borderRadius: 12),
              child: Text(
                valueLabelBuilder(value),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Header of a question of the form (`.x-q-l`): its position («01»…), the
/// label and, under it, the helper text. The fields splice it at the top of
/// their own column, so the label and the control share a column.
List<Widget> recapFieldHeader(
  BuildContext context, {
  required String label,
  String? helperText,
  int? number,
}) {
  final theme = Theme.of(context);
  final palette = context.exomPalette;
  final n = number;
  final helper = helperText;
  return [
    Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (n != null) ...[
          ExomIndexNumber(n),
          const SizedBox(width: ExomSpacing.sm),
        ],
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: palette.textPrimary,
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
    if (helper != null && helper.isNotEmpty) ...[
      const SizedBox(height: ExomSpacing.xs),
      Text(
        helper,
        style: theme.textTheme.bodySmall?.copyWith(
          color: palette.textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
      ),
    ],
    const SizedBox(height: ExomSpacing.md),
  ];
}

class RecapChoiceChipsField extends StatelessWidget {
  final String label;
  final String helperText;
  final String? value;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final int? number;

  const RecapChoiceChipsField({
    super.key,
    required this.label,
    required this.helperText,
    required this.value,
    required this.options,
    required this.onSelected,
    this.number,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...recapFieldHeader(
          context,
          label: label,
          helperText: helperText,
          number: number,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ExomChoiceChips<String>(
            options: options,
            selected: value,
            labelOf: (option) => recapCopy(context, option),
            onSelected: onSelected,
          ),
        ),
      ],
    );
  }
}

class RecapMultiSelectField extends StatelessWidget {
  final String label;
  final String helperText;
  final List<String> values;
  final List<String> options;
  final ValueChanged<List<String>> onChanged;
  final int? number;

  const RecapMultiSelectField({
    super.key,
    required this.label,
    required this.helperText,
    required this.values,
    required this.options,
    required this.onChanged,
    this.number,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...recapFieldHeader(
          context,
          label: label,
          helperText: helperText,
          number: number,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ExomChoiceChips<String>.multi(
            options: options,
            selectedValues: values.toSet(),
            labelOf: (option) => recapCopy(context, option),
            onToggled: (option) {
              final nextValues = List<String>.from(values);
              if (nextValues.contains(option)) {
                nextValues.remove(option);
              } else {
                nextValues.add(option);
              }
              onChanged(nextValues);
            },
          ),
        ),
      ],
    );
  }
}

/// Faces rating (D14-4): five chips, 1 to 5 as painted. What the form keeps is
/// the index 0-4 of the chip, as it did with the faces; [value] is that index.
/// Tapping the chip already shown writes it again, so a value that was only
/// displayed (the form shows 2 when it has none) can be confirmed.
class RecapEmojiRatingField extends StatelessWidget {
  final String label;
  final String helperText;
  final int value; // 0-4
  final ValueChanged<int> onChanged;
  final int? number;

  const RecapEmojiRatingField({
    super.key,
    required this.label,
    required this.helperText,
    required this.value,
    required this.onChanged,
    this.number,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...recapFieldHeader(
          context,
          label: label,
          helperText: helperText,
          number: number,
        ),
        ExomScaleChips(
          min: 1,
          max: 5,
          selected: value + 1,
          allowDeselect: true,
          lowLabel: recapCopy(context, 'MUY_MAL'),
          highLabel: recapCopy(context, 'MUY_BIEN'),
          onChanged: (chip) => onChanged(chip == null ? value : chip - 1),
        ),
      ],
    );
  }
}

/// Stars rating (D14-4): five chips, 1 to 5, in the text colour. [value] is
/// what the form keeps (1-5). Tapping the chip already shown writes it again.
class RecapStarRatingField extends StatelessWidget {
  final String label;
  final String helperText;
  final int value; // 1-5
  final ValueChanged<int> onChanged;
  final int? number;

  const RecapStarRatingField({
    super.key,
    required this.label,
    required this.helperText,
    required this.value,
    required this.onChanged,
    this.number,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...recapFieldHeader(
          context,
          label: label,
          helperText: helperText,
          number: number,
        ),
        ExomScaleChips(
          min: 1,
          max: 5,
          selected: value,
          allowDeselect: true,
          lowLabel: recapCopy(context, 'MUY_MAL'),
          highLabel: recapCopy(context, 'EXCELENTE'),
          onChanged: (chip) => onChanged(chip ?? value),
        ),
      ],
    );
  }
}

// ── Body map (front / back) ────────────────────────────────────────────────
class RecapBodyMapField extends StatelessWidget {
  final String label;
  final String helperText;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final int? number;

  const RecapBodyMapField({
    super.key,
    required this.label,
    required this.helperText,
    required this.values,
    required this.onChanged,
    this.number,
  });

  void _toggleZone(String zoneId) {
    final next = List<String>.from(values);
    if (next.contains(zoneId)) {
      next.remove(zoneId);
    } else {
      next.add(zoneId);
    }
    onChanged(next);
  }

  String _zoneLabel(BuildContext context, String value) {
    return RecapAnatomyZone.fromId(value)?.label(context) ??
        recapCopy(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final selectedZoneIds = values
        .where((value) => RecapAnatomyZone.fromId(value) != null)
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...recapFieldHeader(
          context,
          label: label,
          helperText: helperText,
          number: number,
        ),
        RecapAnatomySelector(
          height: 440,
          selectedZoneIds: selectedZoneIds,
          onZoneSelected: _toggleZone,
        ),
        if (values.isNotEmpty) ...[
          const SizedBox(height: ExomSpacing.md),
          ExomKicker(
            AppLocalizations.of(context).recapChosenZones(values.length),
          ),
          const SizedBox(height: ExomSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ExomChoiceChips<String>.multi(
              options: values,
              selectedValues: values.toSet(),
              labelOf: (zone) => _zoneLabel(context, zone),
              onToggled: _toggleZone,
            ),
          ),
        ],
      ],
    );
  }
}

class RecapIntegerField extends StatefulWidget {
  final String label;
  final String helperText;
  final String hintText;
  final String? suffixText;
  final String maxErrorText;
  final int? value;
  final int max;
  final ValueChanged<int?> onChanged;
  final int? number;

  const RecapIntegerField({
    super.key,
    required this.label,
    required this.helperText,
    required this.hintText,
    this.suffixText,
    required this.maxErrorText,
    required this.value,
    required this.max,
    required this.onChanged,
    this.number,
  });

  @override
  State<RecapIntegerField> createState() => _RecapIntegerFieldState();
}

class _RecapIntegerFieldState extends State<RecapIntegerField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant RecapIntegerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.value?.toString() ?? '';
    if (oldWidget.value != widget.value && _controller.text != nextText) {
      _controller
        ..text = nextText
        ..selection = TextSelection.collapsed(offset: nextText.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _overMax =>
      _controller.text.isNotEmpty &&
      (int.tryParse(_controller.text) ?? widget.max + 1) > widget.max;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final invalid = _overMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...recapFieldHeader(
          context,
          label: widget.label,
          helperText: widget.helperText,
          number: widget.number,
        ),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(widget.max.toString().length + 1),
          ],
          style: TextStyle(color: palette.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hintText,
            suffixText: widget.suffixText,
            // The reason is the inline message below; this only paints the
            // field in the error colour.
            error: invalid ? const SizedBox.shrink() : null,
            hintStyle: TextStyle(color: palette.textDisabled),
          ),
          onChanged: (text) {
            setState(() {});
            widget.onChanged(text.isEmpty ? null : int.tryParse(text));
          },
        ),
        if (invalid) ...[
          const SizedBox(height: ExomSpacing.sm),
          ExomInlineMessage(
            kind: ExomMessageKind.error,
            title: widget.maxErrorText,
          ),
        ],
      ],
    );
  }
}

class RecapTextAreaField extends StatefulWidget {
  final String label;
  final String hintText;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final int? number;

  const RecapTextAreaField({
    super.key,
    required this.label,
    required this.hintText,
    required this.initialValue,
    required this.onChanged,
    this.number,
  });

  @override
  State<RecapTextAreaField> createState() => _RecapTextAreaFieldState();
}

class _RecapTextAreaFieldState extends State<RecapTextAreaField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant RecapTextAreaField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller
        ..text = widget.initialValue
        ..selection = TextSelection.collapsed(
          offset: widget.initialValue.length,
        );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...recapFieldHeader(
          context,
          label: widget.label,
          number: widget.number,
        ),
        TextField(
          controller: _controller,
          maxLines: 4,
          minLines: 4,
          style: TextStyle(color: palette.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(color: palette.textDisabled),
          ),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

/// Number of steps of the form after the start view.
const int kRecapSteps = 5;

/// The week the recap belongs to («16 nov - 22 nov»), for the steps of the
/// form below it: a draft of an earlier week must say which week it is.
class RecapWeekScope extends InheritedWidget {
  const RecapWeekScope({super.key, required this.label, required super.child});

  final String label;

  static String? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RecapWeekScope>()?.label;

  @override
  bool updateShouldNotify(RecapWeekScope oldWidget) => label != oldWidget.label;
}

/// The week of the recap in secondary text with its calendar mark.
class RecapWeekLabel extends StatelessWidget {
  const RecapWeekLabel(this.label, {super.key});

  static const Key labelKey = ValueKey('recap-week-label');

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(
            ExomIcons.calendar,
            size: 16,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(width: ExomSpacing.sm),
        Flexible(
          child: Text(
            label,
            key: labelKey,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// One step of the form (sketch C4): the step header with its rule, the
/// trainer's line and the numbered [questions], in one scroll.
class RecapStepFrame extends StatelessWidget {
  final int step;
  final String first;
  final String second;
  final String coach;
  final List<Widget> questions;

  const RecapStepFrame({
    super.key,
    required this.step,
    required this.first,
    required this.second,
    required this.coach,
    required this.questions,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final week = RecapWeekScope.maybeOf(context);
    String two(int n) => n.toString().padLeft(2, '0');
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The step numeral of the sketch (`01 /05`) is painted only: the
          // rule below says the position to assistive technology. The week
          // beside it is read.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: 18,
              runSpacing: ExomSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                ExcludeSemantics(
                  child: ExomNumeral(
                    value: two(step),
                    unit: '/${two(kRecapSteps)}',
                    unitColor: context.exomPalette.textMuted,
                    size: ExomNumeralSize.hero120,
                  ),
                ),
                if (week != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ExomSpacing.xs),
                    child: RecapWeekLabel(week),
                  ),
              ],
            ),
          ),
          const SizedBox(height: ExomSpacing.md),
          ExomStepHeader(
            step: step,
            total: kRecapSteps,
            kicker: l10n.recapStepKicker(step, kRecapSteps),
            first: first,
            second: second,
          ),
          const SizedBox(height: ExomSpacing.lg),
          ExomCoachBlock(author: l10n.recapListCoachAuthor, text: coach),
          const SizedBox(height: ExomSpacing.xxl),
          for (final question in questions) ...[
            question,
            const SizedBox(height: ExomSpacing.xxl),
          ],
        ],
      ),
    );
  }
}
