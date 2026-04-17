import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/glass_bottom_nav.dart';

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
  final IconData icon;
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) description;

  const _TutorialStep({
    this.route,
    required this.pointsAt,
    this.navIndex = 0,
    this.drawerItemIndex = 0,
    this.openDrawer = false,
    required this.icon,
    required this.title,
    required this.description,
  });
}

final _steps = [
  _TutorialStep(
    route: '/',
    pointsAt: _PointsAt.bottomNav,
    navIndex: 2,
    icon: Icons.home_outlined,
    title: (l10n) => l10n.tutorialHomeTitle,
    description: (l10n) => l10n.tutorialHomeDesc,
  ),
  _TutorialStep(
    route: '/trainings',
    pointsAt: _PointsAt.bottomNav,
    navIndex: 1,
    icon: Icons.fitness_center,
    title: (l10n) => l10n.tutorialTrainingsTitle,
    description: (l10n) => l10n.tutorialTrainingsDesc,
  ),
  _TutorialStep(
    route: '/diets',
    pointsAt: _PointsAt.bottomNav,
    navIndex: 3,
    icon: Icons.restaurant,
    title: (l10n) => l10n.tutorialDietsTitle,
    description: (l10n) => l10n.tutorialDietsDesc,
  ),
  _TutorialStep(
    route: '/calendar',
    pointsAt: _PointsAt.bottomNav,
    navIndex: 4,
    icon: Icons.calendar_month,
    title: (l10n) => l10n.tutorialCalendarTitle,
    description: (l10n) => l10n.tutorialCalendarDesc,
  ),
  _TutorialStep(
    route: '/challenges',
    pointsAt: _PointsAt.bottomNav,
    navIndex: 0,
    icon: Icons.emoji_events_outlined,
    title: (l10n) => l10n.tutorialChallengesTitle,
    description: (l10n) => l10n.tutorialChallengesDesc,
  ),
  _TutorialStep(
    pointsAt: _PointsAt.headerProfile,
    icon: Icons.person_outline,
    title: (l10n) => l10n.tutorialProfileTitle,
    description: (l10n) => l10n.tutorialProfileDesc,
  ),
  _TutorialStep(
    pointsAt: _PointsAt.drawerItem,
    drawerItemIndex:
        2, // Weekly Recap is 3rd item (0: Profile, 1: Challenges, 2: Recap)
    openDrawer: true,
    icon: Icons.bar_chart_outlined,
    title: (l10n) => l10n.tutorialRecapTitle,
    description: (l10n) => l10n.tutorialRecapDesc,
  ),
  _TutorialStep(
    pointsAt: _PointsAt.drawerItem,
    drawerItemIndex: 3, // Feedback is 4th item
    openDrawer: true,
    icon: Icons.feedback_outlined,
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
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;

    const bubbleMaxWidth = 280.0;
    const horizontalMargin = 20.0;

    // Build arrow + bubble based on step type
    final List<Widget> children = [];

    if (step.pointsAt == _PointsAt.bottomNav) {
      // ── Arrow down at nav bar ──
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
      final bubbleBottom =
          GlassBottomNav.totalHeight + bottomPadding + _arrowSize + 4;

      children.addAll([
        Positioned(
          left: bubbleLeft,
          bottom: bubbleBottom,
          width: bubbleWidth,
          child: _buildBubble(palette, l10n, step, isLast),
        ),
        Positioned(
          left: arrowCenterX - _arrowSize / 2,
          bottom: GlassBottomNav.totalHeight + bottomPadding + 4,
          child: CustomPaint(
            size: const Size(_arrowSize, _arrowSize),
            painter: _TrianglePainter(
              color: palette.surfaceElevated,
              direction: _ArrowDirection.down,
            ),
          ),
        ),
      ]);
    } else if (step.pointsAt == _PointsAt.headerProfile) {
      // ── Arrow up at header profile button ──
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
      final bubbleTop = topPadding + kToolbarHeight + _arrowSize + 4;

      children.addAll([
        Positioned(
          left: bubbleLeft,
          top: bubbleTop,
          width: bubbleWidth,
          child: _buildBubble(palette, l10n, step, isLast),
        ),
        Positioned(
          left: arrowCenterX - _arrowSize / 2,
          top: topPadding + kToolbarHeight + 4,
          child: CustomPaint(
            size: const Size(_arrowSize, _arrowSize),
            painter: _TrianglePainter(
              color: palette.surfaceElevated,
              direction: _ArrowDirection.up,
            ),
          ),
        ),
      ]);
    } else if (step.pointsAt == _PointsAt.drawerItem) {
      // ── Compact bubble inside the drawer ──
      final drawerLeftEdge = _drawerLeftEdge(context);
      final targetRect = _drawerItemTargetRect(context, step.drawerItemIndex);
      const drawerMargin = 16.0;
      const drawerBubbleMaxWidth = 220.0;
      final bubbleWidth = (screenWidth - drawerLeftEdge - drawerMargin * 2)
          .clamp(0.0, drawerBubbleMaxWidth)
          .toDouble();
      final minBubbleLeft = drawerLeftEdge + drawerMargin;
      final maxBubbleLeft = screenWidth - drawerMargin - bubbleWidth;
      final bubbleLeft = (targetRect.center.dx - bubbleWidth / 2)
          .clamp(minBubbleLeft, maxBubbleLeft)
          .toDouble();
      final arrowCenterX = targetRect.center.dx
          .clamp(bubbleLeft + 20, bubbleLeft + bubbleWidth - 20)
          .toDouble();
      final arrowTop = targetRect.bottom + 4;
      final bubbleTop = targetRect.bottom + _arrowSize + 4;

      children.addAll([
        Positioned(
          left: bubbleLeft,
          top: bubbleTop,
          width: bubbleWidth,
          child: _buildBubble(palette, l10n, step, isLast, compact: true),
        ),
        Positioned(
          left: arrowCenterX - _arrowSize / 2,
          top: arrowTop,
          child: CustomPaint(
            size: const Size(_arrowSize, _arrowSize),
            painter: _TrianglePainter(
              color: palette.surfaceElevated,
              direction: _ArrowDirection.up,
            ),
          ),
        ),
      ]);
    }

    return Material(
      color: step.pointsAt == _PointsAt.drawerItem
          ? Colors
                .transparent // drawer already has scrim
          : Colors.black.withValues(alpha: 0.5),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // block taps
        child: Stack(children: children),
      ),
    );
  }

  Widget _buildBubble(
    ExomThemePalette palette,
    AppLocalizations l10n,
    _TutorialStep step,
    bool isLast, {
    bool compact = false,
  }) {
    final bubblePadding = compact ? 16.0 : 20.0;
    final iconSize = compact ? 36.0 : 40.0;
    final iconGlyphSize = compact ? 20.0 : 22.0;
    final titleFontSize = compact ? 16.0 : 18.0;
    final descriptionFontSize = compact ? 12.0 : 13.0;
    final buttonHeight = compact ? 34.0 : 36.0;
    final buttonHorizontalPadding = compact ? 16.0 : 18.0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(_currentStep),
        padding: EdgeInsets.all(bubblePadding),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.borderSoft, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon + title row
            Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: palette.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step.icon,
                    color: palette.primary,
                    size: iconGlyphSize,
                  ),
                ),
                SizedBox(width: compact ? 10 : 12),
                Expanded(
                  child: Text(
                    step.title(l10n),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 10),

            // Description
            Text(
              step.description(l10n),
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: descriptionFontSize,
                height: 1.4,
              ),
            ),
            SizedBox(height: compact ? 14 : 16),

            // Dots + button row
            Row(
              children: [
                ...List.generate(_steps.length, (i) {
                  final isActive = i == _currentStep;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 5),
                    width: isActive ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive ? palette.primary : palette.textDisabled,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
                const Spacer(),
                SizedBox(
                  height: buttonHeight,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: buttonHorizontalPadding,
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isLast
                          ? l10n.tutorialDoneButton
                          : l10n.tutorialNextButton,
                      style: TextStyle(
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _arrowSize = 12.0;

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
