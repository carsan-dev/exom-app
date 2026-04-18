import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
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
  bool _isSubmitting = false;
  bool _isSuccess = false;
  String? _sentToEmail;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    setState(() => _isSubmitting = true);

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
      setState(() => _isSubmitting = false);
      final l10n = AppLocalizations.of(context)!;
      final palette = context.exomPalette;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.passwordResetEmailFailed),
          backgroundColor: palette.error,
        ),
      );
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
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 16),
                  GlassCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(24),
                    borderRadius: 28,
                    elevated: true,
                    child: _isSuccess
                        ? _buildSuccess(context)
                        : _buildForm(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final palette = context.exomPalette;
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        icon: Icon(Icons.arrow_back, color: palette.textPrimary),
        onPressed: _onBackToLogin,
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context)!;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.lock_reset_outlined,
            size: 56,
            color: palette.primary,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.forgotPasswordTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.forgotPasswordSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofocus: true,
            onFieldSubmitted: (_) => _onSubmit(),
            style: TextStyle(color: palette.textPrimary),
            decoration: InputDecoration(
              labelText: l10n.emailFieldLabel,
              prefixIcon:
                  Icon(Icons.email_outlined, color: palette.textSecondary),
            ),
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _onSubmit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.sendResetEmailButton),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isSubmitting ? null : _onBackToLogin,
            child: Text(l10n.backToLoginButton),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 64,
          color: context.exomSemantic.success,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.resetEmailSentTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            color: palette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.resetEmailSentSubtitle(_sentToEmail ?? ''),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _onBackToLogin,
          child: Text(l10n.backToLoginButton),
        ),
      ],
    );
  }
}
