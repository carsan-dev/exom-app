import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_motion.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_index_number.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:flutter/material.dart';

/// Horizontal padding of the onboarding content (sketch `.pad`, 20 px).
const double kOnboardingSidePadding = ExomSpacing.xl;

/// Secondary body text of the onboarding (sketch `.sec`).
TextStyle onboardingSecondaryStyle(BuildContext context) => TextStyle(
  fontFamily: AppTheme.bodyFontFamily,
  fontSize: 16,
  height: 1.4,
  color: context.exomPalette.textSecondary,
);

/// Emphasised body text of the onboarding (sketch `.strong`).
TextStyle onboardingStrongStyle(BuildContext context) => TextStyle(
  fontFamily: AppTheme.bodyFontFamily,
  fontSize: 16,
  height: 1.35,
  fontWeight: FontWeight.w600,
  color: context.exomPalette.textPrimary,
);

/// Field error with its icon (sketch `.field-error`), for `errorBuilder`.
Widget onboardingFieldError(BuildContext context, String error) {
  final palette = context.exomPalette;
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(ExomIcons.error, size: 16, color: palette.error),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            error,
            style: TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              fontSize: 14,
              height: 1.35,
              color: palette.error,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Transition of a form step (M9) shared by the page with its steps: the
/// page drives [animation] (0 hidden, 1 in place) as the step enters
/// (forward) and leaves (reverse); [curved] is the same progress on the
/// curves of each direction (the page passes the same animation when it
/// already moves on those curves), and [direction] is the side the step sits at
/// when hidden (1 the end, -1 the start, before the reading direction).
/// [rule] (0 to 1) grows the new segment of the progress rule when a step
/// advances; it is 1 otherwise. [leaving] is true while the step is not the
/// one on screen or entering: its pinned footer then fades with it.
class OnboardingStepEntranceScope extends InheritedWidget {
  const OnboardingStepEntranceScope({
    super.key,
    required this.animation,
    required this.curved,
    required this.rule,
    required this.direction,
    this.leaving = false,
    required super.child,
  });

  final Animation<double> animation;
  final Animation<double> curved;
  final Animation<double> rule;
  final double direction;
  final bool leaving;

  static OnboardingStepEntranceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnboardingStepEntranceScope>();

  @override
  bool updateShouldNotify(OnboardingStepEntranceScope oldWidget) =>
      oldWidget.animation != animation ||
      oldWidget.curved != curved ||
      oldWidget.rule != rule ||
      oldWidget.direction != direction ||
      oldWidget.leaving != leaving;
}

/// M9 on the content of a step, a push (L5-C5b): it enters from the side
/// the form moves to, a full width away, and leaves the other way, always
/// opaque and clipped to its area while it moves; reduced motion is a fade
/// without offset. Without a scope (a step shown alone) it paints [child] as
/// is. Taps reach the new step from the first frame.
class OnboardingStepEntrance extends StatelessWidget {
  const OnboardingStepEntrance({super.key, required this.child});

  /// Key of the entrance, for tests.
  static const Key transitionKey = Key('onboarding-step-transition');

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = OnboardingStepEntranceScope.maybeOf(context);
    if (scope == null) return child;
    final motion = ExomMotion.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (motion.stepSlides) {
      final curved = scope.curved;
      final side = scope.direction * (rtl ? -1 : 1);
      return KeyedSubtree(
        key: transitionKey,
        // Always opaque: no fade, so no ghost of the step that leaves.
        child: FadeTransition(
          opacity: kAlwaysCompleteAnimation,
          child: LayoutBuilder(
            builder: (context, constraints) => AnimatedBuilder(
              animation: curved,
              child: child,
              builder: (context, child) => ClipRect(
                // Clipped only while it moves, so a step at rest paints as
                // it did.
                clipBehavior: curved.value < 1 ? Clip.hardEdge : Clip.none,
                child: Transform.translate(
                  offset: Offset(
                    (1 - curved.value) * side * constraints.maxWidth,
                    0,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    }
    // Reduced motion: a fade in place (the zero offset keeps the shape of
    // the push, which tests read).
    return KeyedSubtree(
      key: transitionKey,
      child: FadeTransition(
        opacity: scope.animation,
        child: Transform.translate(offset: Offset.zero, child: child),
      ),
    );
  }
}

/// Layout of one onboarding step: the scrolling [children] (with the M9
/// entrance) and the pinned [footer] (sketch `.foot`), which the scaffold
/// keeps above the keyboard.
class OnboardingStepLayout extends StatelessWidget {
  const OnboardingStepLayout({
    super.key,
    required this.children,
    required this.footer,
  });

  final List<Widget> children;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    // The footer of the step on screen or entering is there at once (the
    // action is never missing); the one of a step that leaves fades with it,
    // under the new one. The fade is always in the tree so the footer keeps
    // its state when an interruption turns a leaving step into the new one.
    final scope = OnboardingStepEntranceScope.maybeOf(context);
    final Animation<double> footerOpacity;
    if (scope != null && scope.leaving) {
      // With the push (L5-C5b) the footer stays in place: the new step's is
      // there at once and the leaving one's goes at once, with no fade.
      footerOpacity = ExomMotion.of(context).stepSlides
          ? kAlwaysDismissedAnimation
          : scope.animation;
    } else {
      footerOpacity = kAlwaysCompleteAnimation;
    }
    return Column(
      children: [
        Expanded(
          child: OnboardingStepEntrance(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              excludeFromSemantics: true,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(
                  top: ExomSpacing.sm,
                  bottom: ExomSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
        FadeTransition(
          opacity: footerOpacity,
          child: ExomPinnedFooter(
            padding: const EdgeInsets.fromLTRB(
              kOnboardingSidePadding,
              ExomSpacing.md,
              kOnboardingSidePadding,
              ExomSpacing.md,
            ),
            child: footer,
          ),
        ),
      ],
    );
  }
}

/// Footer actions of a step: an optional inline [errorTitle] / [errorBody]
/// right above the only lime button, then an optional quiet action.
class OnboardingStepActions extends StatelessWidget {
  const OnboardingStepActions({
    super.key,
    required this.primaryKey,
    required this.primaryLabel,
    required this.onPrimary,
    this.busy = false,
    this.quietLabel,
    this.onQuiet,
    this.errorKey,
    this.errorTitle,
    this.errorBody,
  });

  final Key primaryKey;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool busy;
  final String? quietLabel;
  final VoidCallback? onQuiet;
  final Key? errorKey;
  final String? errorTitle;
  final String? errorBody;

  @override
  Widget build(BuildContext context) {
    final error = errorTitle;
    final quiet = quietLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (error != null) ...[
          ExomInlineMessage(
            key: errorKey,
            kind: ExomMessageKind.error,
            title: error,
            body: errorBody,
          ),
          const SizedBox(height: ExomSpacing.md),
        ],
        ExomPrimaryButton(
          key: primaryKey,
          label: primaryLabel,
          trailingIcon: ExomIcons.forward,
          busy: busy,
          onPressed: onPrimary,
        ),
        if (quiet != null) ...[
          const SizedBox(height: 6),
          ExomQuietButton(label: quiet, onPressed: busy ? null : onQuiet),
        ],
      ],
    );
  }
}

/// Field with its [label] painted above it (round 4, O3). The floating label
/// of an `InputDecoration` is one line and is cut with an ellipsis when it does
/// not fit; this one wraps onto as many lines as it needs. The [field] must
/// not carry its own `labelText`. Assistive technology reads the label once,
/// as the label of the field.
class OnboardingLabeledField extends StatelessWidget {
  const OnboardingLabeledField({
    super.key,
    required this.label,
    required this.field,
  });

  final String label;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: onboardingSecondaryStyle(context)),
          const SizedBox(height: 6),
          field,
        ],
      ),
    );
  }
}

/// Numbered question of a step (sketch `.x-q`, `.x-q-l`): a hairline on top,
/// «01» and the [label], then the [child] control. When the control carries
/// the same label for assistive technology ([labelInControl]) the painted
/// label is excluded from semantics, so it is read once.
class OnboardingQuestion extends StatelessWidget {
  const OnboardingQuestion({
    super.key,
    required this.n,
    required this.label,
    required this.child,
    this.labelInControl = false,
    this.bottomRule = false,
  });

  final int n;
  final String label;
  final Widget child;
  final bool labelInControl;
  final bool bottomRule;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final rule = BorderSide(
      color: palette.borderSoft,
      width: ExomRule.hairline,
    );
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        ExcludeSemantics(child: ExomIndexNumber(n)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: onboardingStrongStyle(context))),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: rule, bottom: bottomRule ? rule : BorderSide.none),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: kOnboardingSidePadding,
          vertical: 18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            labelInControl ? ExcludeSemantics(child: heading) : heading,
            const SizedBox(height: ExomSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
