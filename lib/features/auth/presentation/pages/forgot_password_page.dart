import 'package:flutter/material.dart';
import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:go_router/go_router.dart';

import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';
import 'package:exom_app/injection_container.dart';
import 'package:exom_app/l10n/app_localizations.dart';

import '../../domain/repositories/auth_repository.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _emailFocus = FocusNode();
  bool _isSubmitting = false;
  bool _isSuccess = false;
  bool _sendFailed = false;
  String? _sentToEmail;

  Animation<double>? _routeAnimation;
  bool _focusHandled = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusHandled) return;
    _focusHandled = true;
    // The field still opens with the keyboard, but only once the push
    // transition has settled: asking for the keyboard on the first frame made
    // the entry stutter (L5-D35, pending of T0.5). The route animation is read
    // after the first frame, when the push has started.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.isCompleted) {
        _focusEmail();
      } else {
        _routeAnimation = animation..addStatusListener(_onRouteStatus);
      }
    });
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
    _focusEmail();
  }

  void _focusEmail() {
    if (!mounted || _isSuccess || _isSubmitting) return;
    _emailFocus.requestFocus();
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    setState(() {
      _isSubmitting = true;
      _sendFailed = false;
    });

    try {
      await sl<AuthRepository>().forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
        _sentToEmail = email;
      });
    } catch (_) {
      if (!mounted) return;
      // The error stays in the footer until the next attempt; the typed email
      // is kept.
      setState(() {
        _isSubmitting = false;
        _sendFailed = true;
      });
    }
  }

  void _onBackToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExomStaticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  excludeFromSemantics: true,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTopBar(context),
                        const SizedBox(height: 8),
                        _isSuccess
                            ? _buildSuccess(context)
                            : _buildForm(context),
                      ],
                    ),
                  ),
                ),
              ),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final palette = context.exomPalette;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: IconButton(
        icon: Icon(ExomIcons.back, color: palette.textPrimary),
        onPressed: _onBackToLogin,
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExomTwoLineHeadline(
            first: l10n.forgotHeadlineFirst,
            second: l10n.forgotHeadlineSecond,
            size: ExomHeadlineSize.screen,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.forgotPasswordSubtitle,
            style: TextStyle(
              fontFamily: AppTheme.bodyFontFamily,
              fontSize: 16,
              height: 1.4,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            key: const Key('forgot-email'),
            controller: _emailController,
            focusNode: _emailFocus,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _onSubmit(),
            style: TextStyle(color: palette.textPrimary),
            decoration: InputDecoration(labelText: l10n.emailFieldLabel),
            errorBuilder: _fieldError,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.emailValidationEmpty;
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
                return l10n.emailValidationInvalid;
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  /// Validation message with an icon, so the error never depends on colour
  /// alone.
  static Widget _fieldError(BuildContext context, String error) {
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

  Widget _buildSuccess(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExomTwoLineHeadline(
          first: l10n.resetEmailSentFirst,
          second: l10n.resetEmailSentSecond,
          size: ExomHeadlineSize.screen,
          semanticsLabel: l10n.resetEmailSentTitle,
        ),
        const SizedBox(height: 24),
        ExomInlineMessage(
          kind: ExomMessageKind.ok,
          title: l10n.resetEmailSentLinkTitle,
          body: l10n.resetEmailSentSubtitle(_sentToEmail ?? ''),
        ),
      ],
    );
  }

  /// Pinned footer (sketch `.foot`): the send error right above the lime
  /// button; once sent there is no next step, so no lime, only the way back.
  Widget _buildFooter(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ExomPinnedFooter(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSuccess)
            ExomSecondaryButton(
              label: l10n.backToLoginButton,
              onPressed: _onBackToLogin,
            )
          else ...[
            if (_sendFailed) ...[
              ExomInlineMessage(
                key: const Key('forgot-error'),
                kind: ExomMessageKind.error,
                title: l10n.passwordResetEmailFailed,
              ),
              const SizedBox(height: 12),
            ],
            ExomPrimaryButton(
              key: const Key('forgot-submit'),
              label: l10n.sendResetEmailButton,
              trailingIcon: ExomIcons.forward,
              busy: _isSubmitting,
              onPressed: _onSubmit,
            ),
            ExomQuietButton(
              label: l10n.backToLoginButton,
              onPressed: _isSubmitting ? null : _onBackToLogin,
            ),
          ],
        ],
      ),
    );
  }
}
