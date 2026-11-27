import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Flat V4 section: `panel` fill (or `raised` when [raised]) with 1 px `rule`
/// hairlines on top and/or bottom and no radius or shadow (plan §6: "Paneles
/// planos, con filetes finos").
class ExomPanel extends StatelessWidget {
  const ExomPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.raised = false,
    this.topRule = true,
    this.bottomRule = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool raised;
  final bool topRule;
  final bool bottomRule;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final rule = BorderSide(color: palette.borderSoft, width: 1);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: raised ? palette.surfaceElevated : palette.surface,
        border: Border(
          top: topRule ? rule : BorderSide.none,
          bottom: bottomRule ? rule : BorderSide.none,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
