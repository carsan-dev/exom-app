import 'package:flutter/material.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exom_app/core/config/external_links.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  List<_Faq> _faqs(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
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
  }

  Future<void> _openExternalLink(
    BuildContext context,
    Uri uri,
    String errorMessage,
  ) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.help),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.helpCenter,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.helpCenterDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.feedback_outlined,
                  title: l10n.feedback,
                  subtitle: l10n.sendQuestionOrIssue,
                  onTap: () => context.push(AppRoutes.feedback),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.settings_outlined,
                  title: l10n.settings,
                  subtitle: l10n.notificationsAndCache,
                  onTap: () => context.push(AppRoutes.settings),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.supportAndLinks,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _HelpLinkTile(
                  icon: Icons.support_agent_outlined,
                  title: l10n.supportCenter,
                  subtitle: l10n.supportCenterDescription,
                  onTap: () => _openExternalLink(
                    context,
                    ExternalLinks.supportPage,
                    l10n.couldNotOpenSupportPage,
                  ),
                ),
                _HelpLinkTile(
                  icon: Icons.privacy_tip_outlined,
                  title: l10n.privacyPolicyOption,
                  subtitle: l10n.privacyPolicyDescription,
                  onTap: () => _openExternalLink(
                    context,
                    ExternalLinks.privacyPolicy,
                    l10n.privacyPolicyNotOpenedError,
                  ),
                ),
                _HelpLinkTile(
                  icon: Icons.alternate_email,
                  title: l10n.emailSupportOption,
                  subtitle: l10n.emailSupportDescription,
                  onTap: () => _openExternalLink(
                    context,
                    ExternalLinks.supportEmail,
                    l10n.mailAppNotOpenedError,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.frequentlyAskedQuestions,
            style: theme.textTheme.titleLarge?.copyWith(
              color: palette.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ..._faqs(context).map((faq) => _FaqTile(faq: faq)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.creditsOption,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.creditsDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                _HelpLinkTile(
                  icon: Icons.code,
                  title: l10n.developer,
                  subtitle: 'Carlos Sanchez Roman · github.com/carsan-dev',
                  onTap: () => _openExternalLink(
                    context,
                    ExternalLinks.developerGithub,
                    l10n.couldNotOpenGithubProfile,
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

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: palette.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: palette.primary, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: palette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textDisabled,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpLinkTile extends StatelessWidget {
  const _HelpLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: palette.primary, size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: palette.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: palette.textDisabled,
          fontSize: 12,
        ),
      ),
      trailing: Icon(Icons.open_in_new, color: palette.textDisabled, size: 18),
      onTap: onTap,
    );
  }
}

class _Faq {
  const _Faq({required this.question, required this.answer});

  final String question;
  final String answer;
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.faq});

  final _Faq faq;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded
              ? palette.primary.withValues(alpha: 0.4)
              : palette.divider,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.faq.question,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _expanded
                            ? palette.primary
                            : palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: palette.textDisabled,
                    size: 20,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                Text(
                  widget.faq.answer,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
