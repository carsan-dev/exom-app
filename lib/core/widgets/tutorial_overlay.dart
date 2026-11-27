import 'package:exom_app/core/performance/performance_profile.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/core/widgets/glass_bottom_nav.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

// Where the arrow points
enum _PointsAt {
  bottomNav, // arrow ↓ at bottom nav icon
  headerProfile, // arrow ↑ at profile button in header
  drawerItem, // compact callout anchored to a drawer menu item
}

class _TutorialStep {
  final String? route; // null = don't navigate via GoRouter
  final _PointsAt pointsAt;
  final int navIndex; // bottom nav slot (0..4), only for bottomNav steps
  final int
  drawerItemIndex; // drawer item index (0-based), only for drawer steps
  final bool openDrawer; // whether to open drawer for this step
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) description;

  const _TutorialStep({
    this.route,
    required this.pointsAt,
    this.navIndex = 0,
    this.drawerItemIndex = 0,
    this.openDrawer = false,
    required this.title,
    required this.description,
  });
}

final _steps = [
  _TutorialStep(
    route: '/',
    pointsAt: _PointsAt.bottomNav,
    navIndex: 2,
    title: (l10n) => l10n.tutorialHomeTitle,
    description: (l10n) => l10n.tutorialHomeDesc,
  ),
  _TutorialStep(
    route: '/trainings',
    pointsAt: _PointsAt.bottomNav,
    navIndex: 1,
    title: (l10n) => l10n.tutorialTrainingsTitle,
    description: (l10n) => l10n.tutorialTrainingsDesc,
  ),
  _TutorialStep(
    route: '/diets',
    pointsAt: _PointsAt.bottomNav,
    navIndex: 3,
    title: (l10n) => l10n.tutorialDietsTitle,
    description: (l10n) => l10n.tutorialDietsDesc,
  ),
  _TutorialStep(
    route: '/calendar',
    pointsAt: _PointsAt.bottomNav,
    navIndex: 4,
    title: (l10n) => l10n.tutorialCalendarTitle,
    description: (l10n) => l10n.tutorialCalendarDesc,
  ),
  _TutorialStep(
    route: '/challenges',
    pointsAt: _PointsAt.bottomNav,
    navIndex: 0,
    title: (l10n) => l10n.tutorialChallengesTitle,
    description: (l10n) => l10n.tutorialChallengesDesc,
  ),
  _TutorialStep(
    pointsAt: _PointsAt.headerProfile,
    title: (l10n) => l10n.tutorialProfileTitle,
    description: (l10n) => l10n.tutorialProfileDesc,
  ),
  _TutorialStep(
    pointsAt: _PointsAt.drawerItem,
    drawerItemIndex:
        2, // Weekly Recap is 3rd item (0: Profile, 1: Challenges, 2: Recap)
    openDrawer: true,
    title: (l10n) => l10n.tutorialRecapTitle,
    description: (l10n) => l10n.tutorialRecapDesc,
  ),
  _TutorialStep(
    pointsAt: _PointsAt.drawerItem,
    drawerItemIndex: 3, // Feedback is 4th item
    openDrawer: true,
    title: (l10n) => l10n.tutorialFeedbackTitle,
    description: (l10n) => l10n.tutorialFeedbackDesc,
  ),
];

class TutorialOverlay extends StatefulWidget {
  final ValueChanged<String> onNavigate;
  final VoidCallback onOpenDrawer;
  final VoidCallback onCloseDrawer;
  final VoidCallback onComplete;
  final List<GlobalKey> drawerItemKeys;

  const TutorialOverlay({
    super.key,
    required this.onNavigate,
    required this.onOpenDrawer,
    required this.onCloseDrawer,
    required this.onComplete,
    required this.drawerItemKeys,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  int _currentStep = 0;
  bool _drawerOpen = false;

  void _next() {
    if (_currentStep < _steps.length - 1) {
      final nextStep = _currentStep + 1;
      final next = _steps[nextStep];

      // Handle drawer transitions
      if (next.openDrawer && !_drawerOpen) {
        widget.onOpenDrawer();
        _drawerOpen = true;
        // Wait for drawer animation before showing next step
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) setState(() => _currentStep = nextStep);
        });
      } else if (!next.openDrawer && _drawerOpen) {
        widget.onCloseDrawer();
        _drawerOpen = false;
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) setState(() => _currentStep = nextStep);
        });
      } else {
        setState(() => _currentStep = nextStep);
      }

      // Navigate via GoRouter if step has a route
      if (next.route != null) {
        widget.onNavigate(next.route!);
      }
    } else {
      widget.onComplete();
    }
  }

  /// Center X of a bottom nav slot.
  double _navSlotCenterX(BuildContext context, int index) {
    final w = MediaQuery.of(context).size.width;
    final slot = w / 5;
    return slot * index + slot / 2;
  }

  /// X position for header profile button.
  double _headerProfileX(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w - 16 - 48 - 24; // center of profile icon button
  }

  Rect? _rectForKey(GlobalKey key) {
    final targetContext = key.currentContext;
    if (targetContext == null) return null;

    final renderObject = targetContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & renderObject.size;
  }

  Rect _drawerItemTargetRect(BuildContext context, int itemIndex) {
    if (itemIndex >= 0 && itemIndex < widget.drawerItemKeys.length) {
      final targetRect = _rectForKey(widget.drawerItemKeys[itemIndex]);
      if (targetRect != null) return targetRect;
    }

    final drawerLeftEdge = _drawerLeftEdge(context);
    final centerY = _drawerItemY(context, itemIndex);
    return Rect.fromCenter(
      center: Offset(drawerLeftEdge + 120, centerY),
      width: 100,
      height: 24,
    );
  }

  /// Approximate label center Y for a drawer item, used as a fallback only.
  double _drawerItemY(BuildContext context, int itemIndex) {
    final topPadding = MediaQuery.of(context).padding.top;
    const drawerHeaderHeight = 121.0; // header content + padding
    const gapAfterHeader = 8.0;
    const itemHeight = 60.0;
    return topPadding +
        drawerHeaderHeight +
        gapAfterHeader +
        (itemIndex * itemHeight) +
        (itemHeight / 2);
  }

  /// Left edge X of the endDrawer.
  /// Flutter default Drawer width is min(304, screenWidth - 56).
  double _drawerLeftEdge(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    // endDrawer opens from right. Its left edge = screenWidth - drawerWidth.
    final drawerWidth = w < 360 ? w - 56 : 304.0;
    return w - drawerWidth;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final topPadding = mediaQuery.padding.top;
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;

    // f-resto.html `.f-tip`: min(280, screen - 40), 20 from the edges.
    const bubbleMaxWidth = 280.0;
    const horizontalMargin = 20.0;
    // Room kept free beyond the bubble when it has to scroll.
    const edgeMargin = 12.0;

    // Build arrow + bubble based on step type
    final List<Widget> children = [];

    if (step.pointsAt == _PointsAt.bottomNav) {
      // ── Arrow down at nav bar, in the panel colour ──
      final arrowCenterX = _navSlotCenterX(context, step.navIndex);
      final bubbleWidth = (screenWidth - horizontalMargin * 2).clamp(
        0.0,
        bubbleMaxWidth,
      );
      var bubbleLeft = arrowCenterX - bubbleWidth / 2;
      if (bubbleLeft < horizontalMargin) bubbleLeft = horizontalMargin;
      if (bubbleLeft + bubbleWidth > screenWidth - horizontalMargin) {
        bubbleLeft = screenWidth - horizontalMargin - bubbleWidth;
      }
      final arrowBottom = GlassBottomNav.totalHeight + bottomPadding + 4;
      final bubbleBottom = arrowBottom + _arrowHeight;

      children.addAll([
        Positioned(
          left: bubbleLeft,
          bottom: bubbleBottom,
          width: bubbleWidth,
          child: _buildBubble(
            context,
            palette,
            l10n,
            step,
            isLast,
            maxHeight:
                screenHeight -
                bubbleBottom -
                topPadding -
                kToolbarHeight -
                edgeMargin,
          ),
        ),
        Positioned(
          left: arrowCenterX - _arrowWidth / 2,
          bottom: arrowBottom,
          child: _arrow(palette.surface, _ArrowDirection.down),
        ),
      ]);
    } else if (step.pointsAt == _PointsAt.headerProfile) {
      // ── Arrow up at header profile button, in the top bar colour ──
      final arrowCenterX = _headerProfileX(context);
      final bubbleWidth = (screenWidth - horizontalMargin * 2).clamp(
        0.0,
        bubbleMaxWidth,
      );
      var bubbleLeft = arrowCenterX - bubbleWidth / 2;
      if (bubbleLeft < horizontalMargin) bubbleLeft = horizontalMargin;
      if (bubbleLeft + bubbleWidth > screenWidth - horizontalMargin) {
        bubbleLeft = screenWidth - horizontalMargin - bubbleWidth;
      }
      final arrowTop = topPadding + kToolbarHeight + 4;
      final bubbleTop = arrowTop + _arrowHeight;

      children.addAll([
        Positioned(
          left: bubbleLeft,
          top: bubbleTop,
          width: bubbleWidth,
          child: _buildBubble(
            context,
            palette,
            l10n,
            step,
            isLast,
            maxHeight:
                screenHeight -
                bubbleTop -
                GlassBottomNav.totalHeight -
                bottomPadding -
                edgeMargin,
          ),
        ),
        Positioned(
          left: arrowCenterX - _arrowWidth / 2,
          top: arrowTop,
          child: _arrow(palette.data, _ArrowDirection.up),
        ),
      ]);
    } else if (step.pointsAt == _PointsAt.drawerItem) {
      // ── Bubble anchored under the drawer row, inside the panel ──
      // (`.f-tip-in`: 12 from the panel edges, same shape as the others).
      final drawerLeftEdge = _drawerLeftEdge(context);
      final targetRect = _drawerItemTargetRect(context, step.drawerItemIndex);
      const drawerMargin = 12.0;
      final bubbleWidth = (screenWidth - drawerLeftEdge - drawerMargin * 2)
          .clamp(0.0, bubbleMaxWidth)
          .toDouble();
      final bubbleLeft = drawerLeftEdge + drawerMargin;
      // The arrow points at the start of the row label.
      final arrowCenterX = (targetRect.left + 16)
          .clamp(bubbleLeft + 16, bubbleLeft + bubbleWidth - 16)
          .toDouble();
      final arrowTop = targetRect.bottom + 4;
      final bubbleTop = arrowTop + _arrowHeight;

      children.addAll([
        Positioned(
          left: bubbleLeft,
          top: bubbleTop,
          width: bubbleWidth,
          child: _buildBubble(
            context,
            palette,
            l10n,
            step,
            isLast,
            maxHeight: screenHeight - bubbleTop - bottomPadding - edgeMargin,
          ),
        ),
        Positioned(
          left: arrowCenterX - _arrowWidth / 2,
          top: arrowTop,
          child: _arrow(palette.data, _ArrowDirection.up),
        ),
      ]);
    }

    return Material(
      color: step.pointsAt == _PointsAt.drawerItem
          ? Colors
                .transparent // drawer already has scrim
          : ExomSheetRoute.scrimColor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // block taps
        child: Stack(children: children),
      ),
    );
  }

  Widget _arrow(Color color, _ArrowDirection direction) => CustomPaint(
    size: const Size(_arrowWidth, _arrowHeight),
    painter: _TrianglePainter(color: color, direction: direction),
  );

  /// f-resto.html `.f-tip`: flat panel of radius 4 with a 1 px rule and a
  /// 3 px data bar on top; «02 / 08», the title in Barlow painted upper case,
  /// the description at 16 and the step's single lime action. It scrolls when
  /// it is taller than [maxHeight] (large text, short screens), so the action
  /// stays reachable.
  Widget _buildBubble(
    BuildContext context,
    ExomThemePalette palette,
    AppLocalizations l10n,
    _TutorialStep step,
    bool isLast, {
    required double maxHeight,
  }) {
    final reduced = PerformanceProfile.prefersReducedMotion(context);
    final number = _currentStep + 1;
    final total = _steps.length;
    final title = step.title(l10n);
    final rule = BorderSide(
      color: palette.borderSoft,
      width: ExomRule.hairline,
    );

    return AnimatedSwitcher(
      duration: reduced ? ExomMotion.reducedFade : ExomMotion.inPlaceSwitch,
      switchInCurve: ExomMotion.inPlaceCurve,
      switchOutCurve: ExomMotion.inPlaceCurve,
      child: ConstrainedBox(
        key: ValueKey(_currentStep),
        constraints: BoxConstraints(maxHeight: maxHeight < 0 ? 0 : maxHeight),
        // Radius 4 by clipping: a border radius needs one colour on every
        // side, and the top bar is in the data colour.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ExomRadius.control),
          child: DecoratedBox(
            key: const Key('tutorial-bubble'),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border(
                top: BorderSide(color: palette.data, width: 3),
                left: rule,
                right: rule,
                bottom: rule,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    label: l10n.tutorialStepProgress(number, total),
                    excludeSemantics: true,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: ExomIndexNumber.format(number),
                            style: ExomIndexNumber.style(
                              palette.data,
                            ).copyWith(fontSize: 16),
                          ),
                          TextSpan(text: ' / ${ExomIndexNumber.format(total)}'),
                        ],
                      ),
                      style: ExomType.kicker.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    header: true,
                    label: title,
                    excludeSemantics: true,
                    child: Text(
                      title.toUpperCase(),
                      style: ExomType.section.copyWith(
                        color: palette.textPrimary,
                        height: 0.95,
                        letterSpacing: -0.44, // -.02em
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    step.description(l10n),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFontFamily,
                      color: palette.textSecondary,
                      fontSize: 16,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ExomPrimaryButton(
                    label: isLast
                        ? l10n.tutorialDoneButton
                        : l10n.tutorialNextButton,
                    trailingIcon: isLast ? ExomIcons.check : ExomIcons.forward,
                    onPressed: _next,
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

/// `.f-tip::after`: 14 x 9.
const _arrowWidth = 14.0;
const _arrowHeight = 9.0;

enum _ArrowDirection { up, down, right }

class _TrianglePainter extends CustomPainter {
  final Color color;
  final _ArrowDirection direction;
  const _TrianglePainter({required this.color, required this.direction});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    switch (direction) {
      case _ArrowDirection.down:
        path
          ..moveTo(0, 0)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, 0)
          ..close();
      case _ArrowDirection.up:
        path
          ..moveTo(0, size.height)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..close();
      case _ArrowDirection.right:
        path
          ..moveTo(0, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(0, size.height)
          ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) =>
      old.color != color || old.direction != direction;
}
