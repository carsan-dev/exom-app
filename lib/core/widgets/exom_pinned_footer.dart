import 'package:exom_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Largest share of the screen height a pinned footer may take.
const double kExomPinnedFooterMaxHeightFraction = 0.4;

/// Fixed bottom zone of the redesigned training screens (Inicio, detail,
/// active exercise, circuit): background, top hairline and padded content.
///
/// At normal sizes it is exactly its content. With large text on a small
/// screen it stops at [kExomPinnedFooterMaxHeightFraction] of the screen and
/// its content scrolls, so it can never cover the page above it.
class ExomPinnedFooter extends StatelessWidget {
  const ExomPinnedFooter({
    super.key,
    required this.padding,
    required this.child,
  });

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(top: BorderSide(color: palette.borderSoft, width: 1)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.sizeOf(context).height *
              kExomPinnedFooterMaxHeightFraction,
        ),
        child: SingleChildScrollView(
          // Not the route's primary scrollable: the body list owns that.
          primary: false,
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
