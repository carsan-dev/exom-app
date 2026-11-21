import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/navigation/app_router.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/theme/exom_type.dart';
import 'package:exom_app/core/widgets/exom_buttons.dart';
import 'package:exom_app/core/widgets/exom_coach_block.dart';
import 'package:exom_app/core/widgets/exom_inline_message.dart';
import 'package:exom_app/core/widgets/exom_pinned_footer.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class AccountLockedPage extends StatelessWidget {
  const AccountLockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // `/account-locked` is an access route, so the router redirect leaves it
    // in place once the session is gone (and with no Firebase user there is
    // not even a refresh). The page leaves on its own when the voluntary
    // logout it started has completed locally.
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => current is AuthUnauthenticated,
      listener: (context, state) => context.go(AppRoutes.login),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LockedHeadline(
                        first: l10n.accountLockedHeadlineFirst,
                        second: l10n.accountLockedHeadlineSecond,
                        label: l10n.accountLockedTitle,
                      ),
                      const SizedBox(height: 24),
                      ExomInlineMessage(
                        kind: ExomMessageKind.error,
                        title: l10n.accountLockedMessage,
                      ),
                      const SizedBox(height: 24),
                      ExomReplyBlock(
                        author: l10n.accountLockedCoachAuthor,
                        text: l10n.accountLockedCoachMessage,
                      ),
                    ],
                  ),
                ),
              ),
              ExomPinnedFooter(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: ExomSecondaryButton(
                  label: l10n.backToLoginButton,
                  onPressed: () {
                    context.read<AuthBloc>().add(const AuthLogoutRequested());
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-line headline of a system state: both lines in the text colour (the
/// sketch paints the second one in bone, `.d-sys`, because a lock is not a
/// figure of the client's data).
class _LockedHeadline extends StatelessWidget {
  const _LockedHeadline({
    required this.first,
    required this.second,
    required this.label,
  });

  final String first;
  final String second;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = ExomType.headline2Screen.copyWith(
      color: context.exomPalette.textPrimary,
    );
    return Semantics(
      header: true,
      label: label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(first.toUpperCase(), style: style),
          Text(second.toUpperCase(), style: style),
        ],
      ),
    );
  }
}
