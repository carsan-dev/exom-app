import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/injection_container.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/social_login_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
        AuthLoginRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(AppRoutes.home);
        } else if (state is AuthAccountLocked) {
          context.go(AppRoutes.accountLocked);
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: palette.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  _buildBranding(context),
                  const SizedBox(height: 48),
                  _buildEmailField(context),
                  const SizedBox(height: 16),
                  _buildPasswordField(context),
                  const SizedBox(height: 8),
                  _buildForgotPassword(context),
                  const SizedBox(height: 24),
                  _buildLoginButton(),
                  const SizedBox(height: 24),
                  _buildDivider(context),
                  const SizedBox(height: 24),
                  _buildSocialButtons(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranding(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: palette.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              'EX',
              style: theme.textTheme.displaySmall?.copyWith(
                color: palette.onPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'EXOM',
          style: theme.textTheme.displayLarge?.copyWith(
            color: palette.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.appTagline,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.textSecondary,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailField(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context)!;

    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: TextStyle(color: palette.textPrimary),
      decoration: InputDecoration(
        labelText: l10n.emailFieldLabel,
        prefixIcon: Icon(Icons.email_outlined, color: palette.textSecondary),
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
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context)!;

    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _onLoginPressed(),
      style: TextStyle(color: palette.textPrimary),
      decoration: InputDecoration(
        labelText: l10n.passwordFieldLabel,
        prefixIcon: Icon(Icons.lock_outline, color: palette.textSecondary),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: palette.textSecondary,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return l10n.passwordValidationEmpty;
        }
        if (value.length < 8) {
          return l10n.passwordValidationLength;
        }
        return null;
      },
    );
  }

  Widget _buildForgotPassword(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => _onForgotPassword(context),
        child: Text(l10n.forgotPasswordButton),
      ),
    );
  }

  Future<void> _onForgotPassword(BuildContext context) async {
    final email = _emailController.text.trim();
    final l10n = AppLocalizations.of(context)!;
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.emailFirstPrompt),
        ),
      );
      return;
    }

    try {
      await sl<FirebaseAuthService>().sendPasswordResetEmail(email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.passwordResetEmailSent),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.passwordResetEmailFailed,
            ),
          ),
        );
      }
    }
  }

  Widget _buildLoginButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        final l10n = AppLocalizations.of(context)!;
        return ElevatedButton(
          onPressed: isLoading ? null : _onLoginPressed,
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.loginButton),
        );
      },
    );
  }

  Widget _buildDivider(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(child: Divider(color: palette.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.continueWithDivider,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(child: Divider(color: palette.divider)),
      ],
    );
  }

  Widget _buildSocialButtons(BuildContext context) {
    final isAndroid = Platform.isAndroid;
    final isIOS = Platform.isIOS;
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return Column(
          children: [
            if (isAndroid)
              SocialLoginButton(
                icon: Icon(
                  Icons.g_mobiledata,
                  size: 26,
                  color: palette.textPrimary,
                ),
                label: l10n.continueWithGoogle,
                isLoading: isLoading,
                onPressed: () => context.read<AuthBloc>().add(
                  const AuthGoogleLoginRequested(),
                ),
              ),
            if (isIOS) ...[
              if (isAndroid) const SizedBox(height: 12),
              SocialLoginButton(
                icon: Icon(Icons.apple, size: 24, color: palette.textPrimary),
                label: l10n.continueWithApple,
                isLoading: isLoading,
                onPressed: () => context.read<AuthBloc>().add(
                  const AuthAppleLoginRequested(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
