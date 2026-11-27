import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/l10n/app_localizations.dart';

/// Main bottom navigation (V4, redesign L2).
///
/// Flat opaque bar in the theme `panel` colour with a 1 px `rule` on top. The
/// active tab is marked by a short 2 px bar above it plus `text` colour (and
/// weight 600 on its label); inactive tabs use `muted`. No lime in the bar: the
/// centre EXOM mark is tinted with the same colour as the other icons.
///
/// Tabs, in order: Retos, Entrenar, Inicio (centre), Dietas, Calendario. Each
/// slot fills a fifth of the width and the full bar height (>= 48x48).
///
/// [showLabels] (decision D6, approved 2026-11-18) shows a text label under
/// each icon: DM Sans 13, single line. The label's text scale is capped at
/// 1.0 below [labelScaleMinSlotWidth] per tab (320 dp phones) and at up to
/// [labelMaxTextScale] from there on, as long as the five labels still fit
/// without truncation or collisions (see [labelTextScalerFor]). A label may
/// spill up to [labelSpill] beyond its slot on each side (inwards only for the
/// two edge tabs, which keep [labelEdgeInset] from the screen edge).
///
/// The tab's spoken name equals its visible label (WCAG 2.5.3 label-in-name);
/// it comes from the `navTab*A11y` strings.
class ExomBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool showLabels;

  const ExomBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.showLabels = true,
  });

  static const _icons = [
    ExomIcons.trophy,
    ExomIcons.train,
    null, // center = EXOM mark
    ExomIcons.diet,
    ExomIcons.calendarMonth,
  ];

  static const _barHeight = 64.0;
  static const _iconSize = 24.0;
  static const _iosBottomInsetReduction = 22.0;
  static const _iosBottomInsetReductionThreshold = 28.0;

  /// Height of the bar without the platform bottom inset. The same with and
  /// without labels, so shell insets do not depend on [showLabels].
  static const totalHeight = _barHeight;

  /// Label size (plan §6: DM Sans, minimum 13).
  static const labelFontSize = 13.0;

  /// Highest text scale of the labels, only reached when the slots are at
  /// least [labelScaleMinSlotWidth] wide and the labels fit.
  static const labelMaxTextScale = 1.3;

  /// Below this slot width (a 390 dp screen has 78 dp slots) the labels stay
  /// at 13 regardless of the system text scale, so they fit at 320 dp.
  static const labelScaleMinSlotWidth = 78.0;

  /// Horizontal room a label may take beyond its slot, per side.
  static const labelSpill = 8.0;

  /// Margin between the two edge labels and the screen edge.
  static const labelEdgeInset = 4.0;

  /// Minimum gap kept between neighbouring labels when choosing the scale.
  static const _labelMinGap = 2.0;

  static TextStyle _labelStyle(bool selected) => TextStyle(
    fontFamily: AppTheme.bodyFontFamily,
    fontSize: labelFontSize,
    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
    height: 1.15,
    letterSpacing: -0.13,
  );

  /// Text scaler for the labels: the system scaler clamped to 1.0 for narrow
  /// slots, otherwise to the largest step in (1.0, [labelMaxTextScale]] at
  /// which every label (measured at weight 600, the widest case) is painted
  /// whole, inside the screen and at least 2 dp from its neighbours.
  @visibleForTesting
  static TextScaler labelTextScalerFor({
    required TextScaler system,
    required double slotWidth,
    required List<String> labels,
    required TextDirection textDirection,
  }) {
    final base = system.clamp(maxScaleFactor: 1.0);
    if (slotWidth < labelScaleMinSlotWidth) {
      return base;
    }
    // The search costs up to ~30 text layouts; the inputs (labels follow the
    // locale) rarely change, so the last result is reused across builds.
    final cached = _lastLabelScale;
    if (cached != null &&
        cached.system == system &&
        cached.slotWidth == slotWidth &&
        cached.textDirection == textDirection &&
        listEquals(cached.labels, labels)) {
      return cached.result;
    }
    var result = base;
    for (var cap = labelMaxTextScale; cap > 1.0; cap -= 0.05) {
      final scaler = system.clamp(maxScaleFactor: cap);
      if (_labelsFit(scaler, slotWidth, labels, textDirection)) {
        result = scaler;
        break;
      }
    }
    _lastLabelScale = (
      system: system,
      slotWidth: slotWidth,
      textDirection: textDirection,
      labels: List<String>.of(labels),
      result: result,
    );
    return result;
  }

  static ({
    TextScaler system,
    double slotWidth,
    TextDirection textDirection,
    List<String> labels,
    TextScaler result,
  })?
  _lastLabelScale;

  /// Number of text layouts the label-scale search has run (tests).
  @visibleForTesting
  static int labelLayoutCount = 0;

  static bool _labelsFit(
    TextScaler scaler,
    double slotWidth,
    List<String> labels,
    TextDirection textDirection,
  ) {
    final spans = <(double, double)>[];
    final last = labels.length - 1;
    for (var i = 0; i < labels.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: labels[i], style: _labelStyle(true)),
        textDirection: textDirection,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      labelLayoutCount++;
      final width = painter.width;
      painter.dispose();
      final isEdge = i == 0 || i == last;
      final room = isEdge
          ? slotWidth - labelEdgeInset + labelSpill
          : slotWidth + labelSpill * 2;
      if (width > room) {
        return false;
      }
      final slotLeft = slotWidth * i;
      final inner = slotWidth - labelEdgeInset;
      final double left;
      if (i == 0) {
        left = width > inner
            ? labelEdgeInset
            : labelEdgeInset + (inner - width) / 2;
      } else if (i == last) {
        left = width > inner
            ? slotLeft + inner - width
            : slotLeft + (inner - width) / 2;
      } else {
        left = slotLeft + (slotWidth - width) / 2;
      }
      spans.add((left, left + width));
    }
    for (var i = 1; i < spans.length; i++) {
      if (spans[i].$1 - spans[i - 1].$2 < _labelMinGap) {
        return false;
      }
    }
    return true;
  }

  static double reservedHeight(BuildContext context) =>
      totalHeight + platformBottomInset(context);

  static double platformBottomInset(BuildContext context) {
    if (kIsWeb) {
      return 0;
    }
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return bottomInset;
      case TargetPlatform.iOS:
        if (bottomInset > _iosBottomInsetReductionThreshold) {
          return bottomInset - _iosBottomInsetReduction;
        }
        return bottomInset;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final bottomInset = platformBottomInset(context);
    // V4: the flat bar's slots span the full width (sketch: five equal
    // columns); only a landscape safe-area inset is respected. The former iOS
    // 16 px iOS inset belonged to the floating circle and is gone.
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final horizontalInset = kIsWeb
        ? 0.0
        : (viewPadding.left > viewPadding.right
              ? viewPadding.left
              : viewPadding.right);
    final a11yLabels = [
      l10n.navTabChallengesA11y,
      l10n.navTabTrainingsA11y,
      l10n.navTabHomeA11y,
      l10n.navTabDietsA11y,
      l10n.navTabCalendarA11y,
    ];
    final labels = [
      l10n.navTabChallengesLabel,
      l10n.navTabTrainingsLabel,
      l10n.navTabHomeLabel,
      l10n.navTabDietsLabel,
      l10n.navTabCalendarLabel,
    ];

    return SizedBox(
      height: reservedHeight(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.borderSoft, width: 1)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: horizontalInset,
            right: horizontalInset,
            bottom: bottomInset,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / 5;
              final labelScaler = labelTextScalerFor(
                system: MediaQuery.textScalerOf(context),
                slotWidth: slotWidth,
                labels: labels,
                textDirection: Directionality.of(context),
              );
              final selected = selectedIndex >= 0 && selectedIndex < 5;
              final row = Row(
                children: List.generate(5, (i) {
                  final isSelected = i == selectedIndex;
                  return SizedBox(
                    width: slotWidth,
                    height: _barHeight,
                    child: _NavTab(
                      index: i,
                      icon: _icons[i],
                      selected: isSelected,
                      semanticLabel: a11yLabels[i],
                      label: showLabels ? labels[i] : null,
                      slotWidth: slotWidth,
                      labelScaler: labelScaler,
                      activeColor: palette.textPrimary,
                      inactiveColor: palette.textSecondary,
                      onTap: () {
                        if (!isSelected) {
                          HapticFeedback.lightImpact();
                        }
                        onTap(i);
                      },
                    ),
                  );
                }),
              );
              if (!selected) return row;
              // M2: one active bar for the whole row, sliding between slots
              // (cut with reduced motion). Painted under the tabs, which keep
              // receiving every tap.
              return Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedPositionedDirectional(
                    duration: ExomMotion.of(context).navIndicatorSlide,
                    curve: ExomMotion.navIndicatorCurve,
                    top: 0,
                    start: slotWidth * selectedIndex + slotWidth * 0.22,
                    width: slotWidth * 0.56,
                    height: 2,
                    child: ColoredBox(color: palette.textPrimary),
                  ),
                  row,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.index,
    required this.icon,
    required this.selected,
    required this.semanticLabel,
    required this.label,
    required this.slotWidth,
    required this.labelScaler,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final int index;
  final IconData? icon;
  final bool selected;
  final String semanticLabel;
  final String? label;
  final double slotWidth;
  final TextScaler labelScaler;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;
    final Widget glyph = icon == null
        ? SizedBox.square(
            dimension: ExomBottomNav._iconSize,
            child: SvgPicture.asset(
              'assets/images/exom_balance.svg',
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          )
        : Icon(icon, size: ExomBottomNav._iconSize, color: color);

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  glyph,
                  if (label != null) ...[
                    const SizedBox(height: 4),
                    ExcludeSemantics(
                      child: Padding(
                        // Keeps the two edge labels off the screen edge.
                        padding: EdgeInsetsDirectional.only(
                          start: index == 0 ? ExomBottomNav.labelEdgeInset : 0,
                          end: index == 4 ? ExomBottomNav.labelEdgeInset : 0,
                        ),
                        child: OverflowBox(
                          fit: OverflowBoxFit.deferToChild,
                          // A label wider than its slot spills inwards at the
                          // two edge slots so it never leaves the screen.
                          alignment: index == 0
                              ? Alignment.centerLeft
                              : index == 4
                              ? Alignment.centerRight
                              : Alignment.center,
                          maxWidth: slotWidth + ExomBottomNav.labelSpill * 2,
                          child: Text(
                            label!,
                            key: ValueKey('exom-bottom-nav-label-$index'),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            textScaler: labelScaler,
                            style: ExomBottomNav._labelStyle(
                              selected,
                            ).copyWith(color: color),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
