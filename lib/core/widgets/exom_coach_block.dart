import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:flutter/material.dart';

/// Trainer notice (`.x-coach`): `panel` fill with a 2 px top rule in the data
/// colour, a byline (square initial, [author], optional [time]) and the
/// [text] in 17 / 600.
///
/// [author] comes from the caller (the real name, or "tu entrenador" when the
/// model has none, D15/D16); the component never decides it. Assistive
/// technology reads one node: `author, time. text`; the initial is decorative.
class ExomCoachBlock extends StatelessWidget {
  const ExomCoachBlock({
    super.key,
    required this.text,
    required this.author,
    this.time,
  });

  final String text;
  final String author;
  final String? time;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Semantics(
      container: true,
      label: _spokenLabel(author, time, text),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(
            top: BorderSide(color: palette.data, width: ExomRule.replyEdge),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Byline(author: author, time: time, showInitial: true),
              const SizedBox(height: 8),
              Text(
                text,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trainer reply (`.x-coach-reply`): no panel, a 2 px leading edge in the data
/// colour, a byline without initial and the [text] in 15 / 400. Same [author]
/// and semantics rules as [ExomCoachBlock].
class ExomReplyBlock extends StatelessWidget {
  const ExomReplyBlock({
    super.key,
    required this.text,
    required this.author,
    this.time,
  });

  final String text;
  final String author;
  final String? time;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return Semantics(
      container: true,
      label: _spokenLabel(author, time, text),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: palette.data, width: ExomRule.replyEdge),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 2, 0, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Byline(author: author, time: time, showInitial: false),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _spokenLabel(String author, String? time, String text) {
  final by = time == null ? author : '$author, $time';
  return '$by. $text';
}

class _Byline extends StatelessWidget {
  const _Byline({
    required this.author,
    required this.time,
    required this.showInitial,
  });

  final String author;
  final String? time;
  final bool showInitial;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final initial = author.trim().isEmpty
        ? ''
        : author.trim().characters.first.toUpperCase();
    final style = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: palette.textPrimary,
    );
    final timeText = time;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        if (showInitial)
          SizedBox(
            width: 32,
            height: 32,
            child: ColoredBox(
              color: palette.surfaceElevated,
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        Text(author, style: style),
        if (timeText != null)
          Text(
            timeText,
            style: style.copyWith(
              fontWeight: FontWeight.w400,
              color: palette.textSecondary,
            ),
          ),
      ],
    );
  }
}
