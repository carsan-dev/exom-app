import 'dart:math' as math;

import 'package:exom_app/core/config/external_links.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/theme/spacing.dart';
import 'package:exom_app/core/widgets/exom_accordion.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_band.dart';
import 'package:exom_app/core/widgets/exom_flat_row.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Credit line of the developer, kept as the page showed it before L5-B1.
const String _developerCredit = 'Carlos Sanchez Roman · github.com/carsan-dev';

/// Index of the FAQ that starts open (sketch B3: «uso sin conexión»).
const int _initiallyOpenFaq = 3;

/// Where an external link sits, so its error is shown next to it.
enum _LinkSection { support, credits }

/// The last external link that did not open: what to say, where, and how to
/// try it again.
class _LinkFailure {
  const _LinkFailure({
    required this.section,
    required this.uri,
    required this.message,
  });

  final _LinkSection section;
  final Uri uri;
  final String message;
}

/// Help screen (sketch B3): a two-line headline, the way to write to the coach,
/// the numbered FAQ accordion (M7) and the support links, each saying whether
/// it opens the browser or the mail app. A link that does not open ends in an
/// inline message next to it (D14-3), never in a SnackBar.
class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  _LinkFailure? _failure;

  List<_Faq> _faqs(AppLocalizations l10n) => [
    _Faq(
      question: l10n.registerWeightMuscleAndMeasurements,
      answer: l10n.registerWeightExplanation,
    ),
    _Faq(
      question: l10n.markWorkoutCompleted,
      answer: l10n.markWorkoutExplanation,
    ),
    _Faq(question: l10n.markMealCompleted, answer: l10n.markMealExplanation),
    _Faq(question: l10n.useAppOffline, answer: l10n.useAppOfflineExplanation),
    _Faq(
      question: l10n.weeklyRecapPurpose,
      answer: l10n.weeklyRecapExplanation,
    ),
    _Faq(
      question: l10n.contactCoachReportProblem,
      answer: l10n.contactCoachExplanation,
    ),
  ];

  Future<void> _openExternalLink(
    _LinkSection section,
    Uri uri,
    String errorMessage,
  ) async {
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      // No app can handle it: the same outcome as a refused launch.
      launched = false;
    }
    if (!mounted) return;
    setState(() {
      _failure = launched
          ? null
          : _LinkFailure(section: section, uri: uri, message: errorMessage);
    });
  }

  Widget _failureFor(_LinkSection section, AppLocalizations l10n) {
    final failure = _failure;
    if (failure == null || failure.section != section) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ExomSpacing.xl,
        ExomSpacing.md,
        ExomSpacing.xl,
        0,
      ),
      child: ExomInlineMessage(
        key: const Key('help-link-error'),
        kind: ExomMessageKind.error,
        title: failure.message,
        actionLabel: l10n.retry,
        onAction: () =>
            _openExternalLink(section, failure.uri, failure.message),
      ),
    );
  }

  _HelpLinkRow _linkRow({
    required _LinkSection section,
    required String title,
    required String destination,
    required String description,
    required Uri uri,
    required String errorMessage,
  }) => _HelpLinkRow(
    rowKey: const Key('help-link-row'),
    title: title,
    icon: ExomIcons.openExternal,
    details: [destination, description],
    onTap: () => _openExternalLink(section, uri, errorMessage),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.exomPalette;
    final faqs = _faqs(l10n);

    return ExomStaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Sketch B3: the bar only carries «Volver»; the headline is the body.
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(ExomIcons.back),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => context.pop(),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.only(
            bottom: ExomSpacing.xxl + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _HelpHeader(
              kicker: l10n.help,
              first: l10n.helpHeadlineFirst,
              second: l10n.helpHeadlineSecond,
              intro: l10n.helpCenterDescription,
            ),
            const SizedBox(height: ExomSpacing.xxl),
            ExomFeatureBlock(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: ExomSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.helpCoachAuthor,
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: ExomSpacing.sm),
                        Text(
                          l10n.helpCoachText,
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
                  const SizedBox(height: ExomSpacing.lg),
                  _HelpLinkRow(
                    rowKey: const Key('help-feedback-row'),
                    title: l10n.sendQuestionOrIssue,
                    icon: ExomIcons.next,
                    tag: l10n.feedback,
                    onTap: () => context.push(AppRoutes.feedback),
                  ),
                  _HelpLinkRow(
                    rowKey: const Key('help-settings-row'),
                    title: l10n.notificationsAndCache,
                    icon: ExomIcons.next,
                    tag: l10n.settings,
                    onTap: () => context.push(AppRoutes.settings),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                ExomSpacing.xl,
                32,
                ExomSpacing.xl,
                ExomSpacing.sm,
              ),
              child: Semantics(
                header: true,
                label: l10n.frequentlyAskedQuestions,
                excludeSemantics: true,
                child: Text(
                  l10n.frequentlyAskedQuestions.toUpperCase(),
                  style: ExomType.section.copyWith(color: palette.textPrimary),
                ),
              ),
            ),
            ExomFlatRowGroup(
              children: [
                for (var i = 0; i < faqs.length; i++)
                  ExomAccordion(
                    number: i + 1,
                    title: faqs[i].question,
                    initiallyOpen: i == _initiallyOpenFaq,
                    body: _Measure(
                      child: Text(
                        faqs[i].answer,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: palette.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            ExomBand(
              kicker: l10n.supportAndLinks,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _linkRow(
                    section: _LinkSection.support,
                    title: l10n.supportCenter,
                    destination: l10n.helpOpensInBrowser,
                    description: l10n.supportCenterDescription,
                    uri: ExternalLinks.supportPage,
                    errorMessage: l10n.couldNotOpenSupportPage,
                  ),
                  _linkRow(
                    section: _LinkSection.support,
                    title: l10n.privacyPolicyOption,
                    destination: l10n.helpOpensInBrowser,
                    description: l10n.privacyPolicyDescription,
                    uri: ExternalLinks.privacyPolicy,
                    errorMessage: l10n.privacyPolicyNotOpenedError,
                  ),
                  _linkRow(
                    section: _LinkSection.support,
                    title: l10n.serviceSupportEmailOption,
                    destination: l10n.helpOpensInMail,
                    description: l10n.serviceSupportEmailDescription,
                    uri: ExternalLinks.serviceSupportEmail,
                    errorMessage: l10n.mailAppNotOpenedError,
                  ),
                  _linkRow(
                    section: _LinkSection.support,
                    title: l10n.technicalSupportEmailOption,
                    destination: l10n.helpOpensInMail,
                    description: l10n.technicalSupportEmailDescription,
                    uri: ExternalLinks.technicalSupportEmail,
                    errorMessage: l10n.mailAppNotOpenedError,
                  ),
                  _failureFor(_LinkSection.support, l10n),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                ExomSpacing.xl,
                ExomSpacing.xxl,
                ExomSpacing.xl,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExomKicker(l10n.creditsOption),
                  const SizedBox(height: ExomSpacing.sm),
                  _Measure(
                    child: Text(
                      l10n.creditsDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: ExomSpacing.xs),
                  Text(
                    _developerCredit,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  ExomTextLink(
                    label: l10n.developer,
                    onTap: () => _openExternalLink(
                      _LinkSection.credits,
                      ExternalLinks.developerGithub,
                      l10n.couldNotOpenGithubProfile,
                    ),
                  ),
                ],
              ),
            ),
            _failureFor(_LinkSection.credits, l10n),
          ],
        ),
      ),
    );
  }
}

class _Faq {
  const _Faq({required this.question, required this.answer});

  final String question;
  final String answer;
}

/// Caps running text at about 68 characters (`.b-measure{max-width:68ch}`);
/// `ch` is taken as 0.55 em of the 16 px body size, scaled with the text.
class _Measure extends StatelessWidget {
  const _Measure({required this.child});

  final Widget child;

  static const int characters = 68;
  static const double _chEm = 0.55;
  static const double _bodySize = 16;

  @override
  Widget build(BuildContext context) {
    final em = MediaQuery.textScalerOf(context).scale(_bodySize);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: characters * _chEm * em),
        child: child,
      ),
    );
  }
}

/// Top of the page: the «EXOM» watermark behind a kicker, the two-line
/// headline and the intro (`.x-wmw`). The watermark is decoration: no
/// semantics, no text scaling.
class _HelpHeader extends StatelessWidget {
  const _HelpHeader({
    required this.kicker,
    required this.first,
    required this.second,
    required this.intro,
  });

  final String kicker;
  final String first;
  final String second;
  final String intro;

  static const double _watermarkSize = 120;

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    return ClipRect(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: -_watermarkSize * 0.08,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Text(
                  'EXOM',
                  textScaler: TextScaler.noScaling,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: ExomType.hero120.copyWith(
                    height: 0.8,
                    letterSpacing: -0.04 * _watermarkSize,
                    color: palette.surface,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ExomSpacing.xl,
              ExomSpacing.sm,
              ExomSpacing.xl,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExomKicker(kicker),
                const SizedBox(height: ExomSpacing.sm),
                ExomTwoLineHeadline(
                  first: first,
                  second: second,
                  size: ExomHeadlineSize.screen,
                ),
                const SizedBox(height: ExomSpacing.md),
                _Measure(
                  child: Text(
                    intro,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: palette.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Index-style row without a number (`.x-ix`): the title in the section style
/// (Barlow Condensed 800, painted upper case, read in its original case), the
/// [details] under it in secondary text and an optional [tag] at the end.
/// [ExomIndexList] always numbers its entries, which would collide with the FAQ
/// numbering, so the page draws this row on the shared [ExomRowSurface].
class _HelpLinkRow extends StatelessWidget {
  const _HelpLinkRow({
    required this.rowKey,
    required this.title,
    required this.onTap,
    required this.icon,
    this.details = const [],
    this.tag,
  });

  final Key rowKey;
  final String title;
  final List<String> details;
  final String? tag;
  final IconData icon;
  final VoidCallback onTap;

  static const double _iconSize = 22;
  static const double _gap = 14;

  /// Width of the widest word of [text], so a title is never split.
  static double _longestWord(
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    var longest = 0.0;
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      longest = math.max(longest, painter.width);
      painter.dispose();
    }
    return longest.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final detailStyle = TextStyle(
      fontFamily: AppTheme.bodyFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.3,
      color: palette.textSecondary,
    );
    final titleStyle = ExomType.section.copyWith(color: palette.textPrimary);
    final tagText = tag;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: ExomRowSurface(
          key: rowKey,
          onTap: onTap,
          minHeight: 60,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final iconWidth = scaler.scale(_iconSize) + _gap;
              // Inline, title and tag share what is left (the title keeps the
              // half); the tag goes under the title as soon as the inline
              // column would break a word of the title (same rule as
              // ExomIndexList).
              final inlineTitle = (constraints.maxWidth - iconWidth - _gap) / 2;
              final stacked =
                  tagText != null &&
                  inlineTitle <
                      _longestWord(
                        title.toUpperCase(),
                        titleStyle,
                        scaler,
                        direction,
                      );
              final tagWidget = tagText == null
                  ? null
                  : Text(
                      tagText,
                      textAlign: stacked ? TextAlign.start : TextAlign.end,
                      style: detailStyle.copyWith(fontWeight: FontWeight.w600),
                    );
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          label: title,
                          excludeSemantics: true,
                          child: Text(title.toUpperCase(), style: titleStyle),
                        ),
                        if (stacked && tagWidget != null) ...[
                          const SizedBox(height: ExomSpacing.xs),
                          tagWidget,
                        ],
                        for (final line in details) ...[
                          const SizedBox(height: ExomSpacing.xs),
                          Text(line, style: detailStyle),
                        ],
                      ],
                    ),
                  ),
                  if (tagWidget != null && !stacked) ...[
                    const SizedBox(width: _gap),
                    Flexible(child: tagWidget),
                  ],
                  const SizedBox(width: _gap),
                  // Decorative: the row already says where it goes.
                  ExcludeSemantics(
                    child: Icon(
                      icon,
                      size: _iconSize,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
