import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/glass_decorations.dart';

/// Frosted glass bottom navigation bar with real BackdropFilter blur.
///
/// Preserves the animated green circle from the original _ExomBottomNav
/// but adds a frosted glass bar background with blur effect.
class GlassBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const GlassBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  static const _icons = [
    Icons.emoji_events_outlined,
    Icons.fitness_center,
    null, // center = EXOM logo
    Icons.restaurant,
    Icons.calendar_month,
  ];

  static const _circleSize = 64.0;
  static const _barHeight = 64.0;
  static const _circleOverlap = 10.0;
  static const totalHeight = _barHeight + _circleOverlap;

  @override
  Widget build(BuildContext context) {
    final targetX = _slotCenterX(context, selectedIndex);
    final palette = context.exomPalette;
    final inactiveColor = palette.textDisabled;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: totalHeight + bottomInset,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: targetX),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        builder: (context, centerX, _) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Frosted glass bar — fills full SizedBox including circle
              // overlap zone so no scaffold background peeks through.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: totalHeight + bottomInset,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(decoration: GlassDecoration.navBar()),
                  ),
                ),
              ),

              // Green circle with glow
              Positioned(
                left: centerX - _circleSize / 2,
                bottom: bottomInset + _barHeight - _circleSize + _circleOverlap,
                child: Container(
                  width: _circleSize,
                  height: _circleSize,
                  decoration: BoxDecoration(
                    color: palette.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: palette.primary.withValues(alpha: 0.35),
                        blurRadius: 30,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _buildIcon(
                      selectedIndex,
                      true,
                      activeColor: palette.onPrimary,
                      inactiveColor: inactiveColor,
                    ),
                  ),
                ),
              ),

              // Icon row (active slot hidden — rendered inside circle)
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomInset,
                height: _barHeight,
                child: Row(
                  children: List.generate(5, (i) {
                    final isSelected = i == selectedIndex;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: isSelected,
                        label: _a11yLabel(i),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (!isSelected) {
                              HapticFeedback.lightImpact();
                            }
                            onTap(i);
                          },
                          child: SizedBox(
                            height: _barHeight,
                            child: Center(
                              child: isSelected
                                  ? const SizedBox.shrink()
                                  : _buildIcon(
                                      i,
                                      false,
                                      activeColor: palette.onPrimary,
                                      inactiveColor: inactiveColor,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIcon(
    int index,
    bool isActive, {
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final color = isActive ? activeColor : inactiveColor;
    const size = 28.0;
    if (index == 2) {
      return SvgPicture.asset(
        'assets/images/logo_small.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Icon(_icons[index], size: size, color: color);
  }

  double _slotCenterX(BuildContext context, int index) {
    final w = MediaQuery.of(context).size.width;
    final slot = w / 5;
    return slot * index + slot / 2;
  }

  String _a11yLabel(int index) {
    switch (index) {
      case 0:
        return 'Retos';
      case 1:
        return 'Entrenamientos';
      case 2:
        return 'Inicio';
      case 3:
        return 'Dietas';
      case 4:
        return 'Calendario';
      default:
        return '';
    }
  }
}
