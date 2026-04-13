import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/auth/firebase_auth_service.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/glass_card.dart';
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
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
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

  Future<void> _showLinkPasswordDialog(
    BuildContext context, {
    required String email,
    required String provider,
  }) async {
    final controller = TextEditingController(text: _passwordController.text);
    final formKey = GlobalKey<FormState>();
    final l10n = AppLocalizations.of(context)!;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.linkSocialTitle),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.linkSocialDescription(email, provider)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.passwordFieldLabel,
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
                  onFieldSubmitted: (_) {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.of(dialogContext).pop(controller.text);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(controller.text);
                }
              },
              child: Text(l10n.linkSocialConfirmButton),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (!context.mounted) {
      return;
    }

    if (password == null) {
      context.read<AuthBloc>().add(const AuthLinkCancelled());
      return;
    }

    _emailController.text = email;
    _passwordController.text = password;
    context.read<AuthBloc>().add(AuthLinkPasswordSubmitted(password: password));
  }

  String _logoAsset(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? 'assets/images/logo_dark.svg'
        : 'assets/images/logo.svg';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.exomPalette;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(AppRoutes.home);
        } else if (state is AuthAccountLocked) {
          context.go(AppRoutes.accountLocked);
        } else if (state is AuthLinkPasswordRequired) {
          _showLinkPasswordDialog(
            context,
            email: state.email,
            provider: state.provider,
          );
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: palette.error,
            ),
          );
        }
      },
      child: ExomStaticBackground(
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
                  vertical: 32,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      _buildBranding(context),
                      const SizedBox(height: 36),
                      GlassCard(
                        margin: EdgeInsets.zero,
                        padding: const EdgeInsets.all(24),
                        borderRadius: 28,
                        elevated: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                    ],
                  ),
                ),
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
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 164,
              height: 164,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.22),
                    blurRadius: 70,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
            SvgPicture.asset(_logoAsset(context), height: 72),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l10n.appTagline,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.primary.withValues(alpha: 0.92),
            fontSize: 14,
            fontWeight: FontWeight.w500,
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
      focusNode: _emailFocus,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
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
      focusNode: _passwordFocus,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.emailFirstPrompt)));
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
