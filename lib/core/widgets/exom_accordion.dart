import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:flutter/material.dart';

// M7 (T0.5): unificar con ExomMotionSpec al integrar.
const Duration _kHeight = Duration(milliseconds: 200);
const Duration _kChevron = Duration(milliseconds: 200);
const Duration _kContent = Duration(milliseconds: 120);

/// Flat accordion (`.acc`): a 56 px header row with an optional [number]
/// («01», [ExomIndexNumber]), the [title] in 600 and a chevron, over a [body]
/// padded 20 at the sides and 16 below. A 1 px `rule` sits on top; close a
/// list of accordions with a bottom rule (e.g. `ExomFlatRowGroup`).
///
/// Motion M7: opening grows the height over 200 ms and turns the chevron 180°
/// with it, while the content fades in over 120 ms; closing reverses from
/// wherever it is, so a tap during the animation acts at once. With reduced
/// motion ([ExomMotion.of]) the height does not animate: the content fades in
/// or out over [ExomMotion.reducedFade] and the space appears or goes at once.
///
/// Semantics: the header is one button node with the expanded state; the body
/// is only in the tree while it is shown.
class ExomAccordion extends StatefulWidget {
  const ExomAccordion({
    super.key,
    required this.title,
    required this.body,
    this.number,
    this.initiallyOpen = false,
  });

  final String title;
  final Widget body;
  final int? number;
  final bool initiallyOpen;

  @override
  State<ExomAccordion> createState() => _ExomAccordionState();
}

class _ExomAccordionState extends State<ExomAccordion>
    with TickerProviderStateMixin {
  late bool _open;
  late final AnimationController _height;
  late final AnimationController _chevron;
  late final AnimationController _content;
  late final Animation<double> _heightCurve;
  late final Animation<double> _turns;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    // Created eagerly: their start value must follow the initial state, not
    // the state at the first toggle.
    _open = widget.initiallyOpen;
    final start = _open ? 1.0 : 0.0;
    _height = AnimationController(
      vsync: this,
      duration: _kHeight,
      value: start,
    );
    _chevron = AnimationController(
      vsync: this,
      duration: _kChevron,
      value: start,
    );
    _content = AnimationController(
      vsync: this,
      duration: _kContent,
      value: start,
    );
    _heightCurve = CurvedAnimation(parent: _height, curve: Curves.easeOut);
    _turns = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _chevron, curve: Curves.easeOut));
    _opacity = CurvedAnimation(parent: _content, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _height.dispose();
    _chevron.dispose();
    _content.dispose();
    super.dispose();
  }

  void _toggle() {
    final reduced = ExomMotion.of(context).isReduced;
    setState(() => _open = !_open);
    if (reduced) {
      _content.duration = ExomMotion.reducedFade;
      _chevron.value = _open ? 1 : 0;
      if (_open) {
        _height.value = 1;
        _content.forward();
      } else {
        // No height animation: the space goes once the content faded out.
        _content.reverse().whenCompleteOrCancel(() {
          if (mounted && !_open) _height.value = 0;
        });
      }
      return;
    }
    _content.duration = _kContent;
    if (_open) {
      _height.forward();
      _chevron.forward();
      _content.forward();
    } else {
      _height.reverse();
      _chevron.reverse();
      _content.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final number = widget.number;
    final body = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
      child: widget.body,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MergeSemantics(
          child: Semantics(
            button: true,
            expanded: _open,
            child: ExomRowSurface(
              key: const Key('exom-accordion-header'),
              onTap: _toggle,
              child: Row(
                children: [
                  if (number != null) ...[
                    ExomIndexNumber(number),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  RotationTransition(
                    turns: _turns,
                    child: Icon(
                      Icons.expand_more,
                      size: 22,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _height,
          child: body,
          builder: (context, child) {
            if (!_open && _height.value == 0) return const SizedBox.shrink();
            return SizeTransition(
              sizeFactor: _heightCurve,
              axisAlignment: -1,
              child: FadeTransition(
                key: const Key('exom-accordion-fade'),
                opacity: _opacity,
                child: child,
              ),
            );
          },
        ),
      ],
    );
  }
}
