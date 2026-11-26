import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// L5-D23 (i), sketch frames `f-ej-ult`, `f-ej-ult-off` and `f-circ-ult`:
/// before the last set (active exercise, E3b) or in the last round (circuit,
/// E3c), the video reminder is an informative band ([title] as kicker and
/// [message], the same texts as the old dialog) with the «Recordármelo»
/// switch on; switched off, one flat row with the same switch to turn it back
/// on. The switch writes `last_set_video_reminder_enabled`, as Ajustes (the
/// caller saves it). The switch is in the text colour, never lime.
///
/// Inside the band the kicker, the message and the switch row are one stack
/// with 8 between them and no rule (`.pad.stack.g8`, `.x-swrow`), all on the
/// page margins. Set [joinsPrevious] when the reminder sits directly under a
/// block that already closes with a rule (the load columns): the band or the
/// line then shares that rule instead of opening an empty strip between two
/// rules.
class LastSetVideoReminder extends StatelessWidget {
  const LastSetVideoReminder({
    super.key,
    required this.enabled,
    required this.title,
    required this.message,
    required this.onChanged,
    this.joinsPrevious = false,
  });

  final bool enabled;

  /// Kicker of the band («Prepárate para grabar», «Última serie»).
  final String title;

  /// Body of the band; the caller picks the copy for its screen.
  final String message;
  final ValueChanged<bool> onChanged;

  /// True when the reminder directly follows a ruled block (no gap above).
  final bool joinsPrevious;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    if (!enabled) {
      return ExomFlatRowGroup(
        children: [
          MergeSemantics(
            key: const Key('last-set-video-reminder-off'),
            child: Semantics(
              toggled: false,
              child: ExomFlatRow(
                title: l10n.lastSetVideoRemindMe,
                subtitles: [l10n.lastSetVideoReminderOption],
                trailing: const ExcludeSemantics(
                  child: ExomSquareSwitch(value: false),
                ),
                onTap: () => onChanged(true),
                topRule: !joinsPrevious,
              ),
            ),
          ),
        ],
      );
    }
    return ExomBand(
      key: const Key('last-set-video-reminder'),
      joinsPrevious: joinsPrevious,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ExomKicker(title, icon: ExomIcons.camera),
            ),
          ),
          const SizedBox(height: ExomSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              message,
              style: TextStyle(
                fontFamily: AppTheme.bodyFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: ExomSpacing.sm),
          ExomSwitchRow(
            label: l10n.lastSetVideoRemindMe,
            value: true,
            onChanged: onChanged,
            topRule: false,
          ),
        ],
      ),
    );
  }
}
