import 'dart:io';

import 'package:exom_app/core/theme/exom_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/widgets/exom_animated_background.dart';
import 'package:exom_app/core/widgets/exom_brand_logo.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_kicker.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';
import 'package:exom_app/core/widgets/exom_sheet.dart';
import 'package:exom_app/core/widgets/exom_text_link.dart';
import 'package:exom_app/core/widgets/exom_two_line_headline.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import 'package:exom_app/core/api/api_error_helper.dart';
import '../bloc/auth_state.dart';
import '../widgets/social_login_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _googleLogoAsset = 'assets/images/google_logo.svg';
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  /// Raw message of the last failed access attempt (D14-8). It is localized
  /// when painted, stays until the next attempt starts and never touches the
  /// typed email.
  String? _errorMessage;

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
      // A new attempt starts: the previous error goes away at once.
      if (_errorMessage != null) setState(() => _errorMessage = null);
      context.read<AuthBloc>().add(
        AuthLoginRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  /// «Vincular acceso» (D17-1): a straight EXOM sheet that cannot be dismissed
  /// by tapping outside or dragging, like the dialog it replaces. The system
  /// back closes it as it closed the dialog, and that is the same outcome as
  /// «Cancelar» (no result, so `AuthLinkCancelled` once). If the router
  /// location changes while it is open the sheet closes without a result and
  /// nothing is submitted.
  Future<void> _showLinkPasswordSheet(
    BuildContext context, {
    required String email,
    required String provider,
  }) async {
    final controller = TextEditingController(text: _passwordController.text);
    final formKey = GlobalKey<FormState>();
    final l10n = AppLocalizations.of(context);

    final password = await showExomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      title: l10n.linkSocialTitle,
      body: l10n.linkSocialDescription(email, provider),
      builder: (sheetContext) => PopScope<String>(
        // `isDismissible: false` makes the route refuse every pop; the system
        // back is handed back here and closes the sheet like «Cancelar».
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(sheetContext).pop();
        },
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
          child: Form(
            key: formKey,
            child: TextFormField(
              key: const Key('link-password'),
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.passwordFieldLabel),
              errorBuilder: _fieldError,
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
                  Navigator.of(sheetContext).pop(controller.text);
                }
              },
            ),
          ),
        ),
      ),
      actions: [
        Builder(
          builder: (sheetContext) => ExomPrimaryButton(
            label: l10n.linkSocialConfirmButton,
            trailingIcon: ExomIcons.forward,
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(sheetContext).pop(controller.text);
              }
            },
          ),
        ),
        Builder(
          builder: (sheetContext) => ExomQuietButton(
            label: l10n.cancel,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ],
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

  /// Validation message with an icon, so the error never depends on colour
  /// alone (sketch estado a).
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(AppRoutes.home);
        } else if (state is AuthAccountLocked) {
          context.go(AppRoutes.accountLocked);
        } else if (state is AuthLinkPasswordRequired) {
          if (_errorMessage != null) setState(() => _errorMessage = null);
          _showLinkPasswordSheet(
            context,
            email: state.email,
            provider: state.provider,
          );
        } else if (state is AuthError) {
          setState(() => _errorMessage = state.message);
        } else if (state is AuthLoading) {
          // A new attempt starts: the previous error goes away.
          if (_errorMessage != null) setState(() => _errorMessage = null);
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isLoading = state is AuthLoading;
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
                          // `.pad`: 20 from each edge, as every L5 screen.
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 24,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildBranding(context),
                                const SizedBox(height: 24),
                                _buildEmailField(context, enabled: !isLoading),
                                const SizedBox(height: 16),
                                _buildPasswordField(
                                  context,
                                  enabled: !isLoading,
                                ),
                                const SizedBox(height: 4),
                                _buildForgotPassword(context),
                                const SizedBox(height: 16),
                                _buildSocialButtons(context, isLoading),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildFooter(context, isLoading),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBranding(BuildContext context) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExomBrandLogo(height: 48),
        const SizedBox(height: 24),
        ExomTwoLineHeadline(
          first: l10n.loginHeadlineFirst,
          second: l10n.loginHeadlineSecond,
          size: ExomHeadlineSize.screen,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.loginSubtitle,
          style: TextStyle(
            fontFamily: AppTheme.bodyFontFamily,
            fontSize: 16,
            height: 1.4,
            color: palette.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField(BuildContext context, {required bool enabled}) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return TextFormField(
      key: const Key('login-email'),
      controller: _emailController,
      focusNode: _emailFocus,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
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
    );
  }

  Widget _buildPasswordField(BuildContext context, {required bool enabled}) {
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    return TextFormField(
      key: const Key('login-password'),
      controller: _passwordController,
      focusNode: _passwordFocus,
      enabled: enabled,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _onLoginPressed(),
      style: TextStyle(color: palette.textPrimary),
      decoration: InputDecoration(
        labelText: l10n.passwordFieldLabel,
        suffixIcon: IconButton(
          tooltip: _obscurePassword
              ? l10n.passwordShowTooltip
              : l10n.passwordHideTooltip,
          icon: Icon(
            _obscurePassword
                ? ExomIcons.show
                : ExomIcons.hide,
            color: palette.textSecondary,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      errorBuilder: _fieldError,
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
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ExomTextLink(
        label: l10n.forgotPasswordButton,
        onTap: () => _onForgotPassword(context),
      ),
    );
  }

  void _onForgotPassword(BuildContext context) {
    final email = _emailController.text.trim();
    final uri = Uri(
      path: AppRoutes.forgotPassword,
      queryParameters: email.isEmpty ? null : {'email': email},
    );
    context.push(uri.toString());
  }

  /// Pinned footer (sketch `.foot`): the access error as an inline message
  /// right above the only lime button, which keeps its label while busy.
  Widget _buildFooter(BuildContext context, bool isLoading) {
    final l10n = AppLocalizations.of(context);
    final message = _errorMessage;
    return ExomPinnedFooter(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null) ...[
            ExomInlineMessage(
              key: const Key('login-error'),
              kind: ExomMessageKind.error,
              title: authErrorText(l10n, message),
            ),
            const SizedBox(height: 12),
          ],
          ExomPrimaryButton(
            key: const Key('login-submit'),
            label: l10n.loginButton,
            trailingIcon: ExomIcons.forward,
            busy: isLoading,
            onPressed: _onLoginPressed,
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButtons(BuildContext context, bool isLoading) {
    final isIOS = Platform.isIOS;
    final palette = context.exomPalette;
    final l10n = AppLocalizations.of(context);

    final googleButton = SocialLoginButton(
      icon: SvgPicture.asset(_googleLogoAsset, width: 20, height: 20),
      label: l10n.continueWithGoogle,
      isLoading: isLoading,
      onPressed: () =>
          context.read<AuthBloc>().add(const AuthGoogleLoginRequested()),
    );

    // «Continuar con Apple» only on iOS; elsewhere only Google is offered.
    final appleButton = isIOS
        ? SocialLoginButton(
            icon: Icon(ExomIcons.apple, size: 24, color: palette.textPrimary),
            label: l10n.continueWithApple,
            isLoading: isLoading,
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthAppleLoginRequested()),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ExomKicker(l10n.continueWithDivider),
        ),
        const SizedBox(height: 8),
        googleButton,
        if (appleButton != null) ...[const SizedBox(height: 8), appleButton],
      ],
    );
  }
}

/// Maps an [AuthError] message to localized text. Raw Firebase/server text is
/// never shown: unknown messages fall back to a generic localized one.
String authErrorText(AppLocalizations l10n, String message) {
  switch (message) {
    case AuthErrorMessages.userDisabled:
      return l10n.authUserDisabled;
    case AuthErrorMessages.credentialAlreadyInUse:
      return l10n.authCredentialAlreadyInUse;
    case AuthErrorMessages.noCurrentUser:
      return l10n.authNoCurrentUser;
    case AuthErrorMessages.invalidCredential:
      return l10n.authInvalidCredential;
    case AuthErrorMessages.linkRequestExpired:
      return l10n.authLinkRequestExpired;
    default:
      final provider = AuthErrorMessages.missingEmailProvider(message);
      if (provider != null) return l10n.authMissingEmailForLink(provider);
      return localizedErrorText(
        l10n,
        message,
        fallback: l10n.authOperationError,
      );
  }
}
