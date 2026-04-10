import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exom_app/l10n/app_localizations.dart';
import 'package:exom_app/core/config/external_links.dart';
import 'package:exom_app/core/theme/app_theme.dart';
import 'package:exom_app/core/services/feature_gate_service.dart';
import 'package:exom_app/core/widgets/trial_banner.dart';
import 'package:exom_app/core/widgets/trial_expired_screen.dart';

// Auth pages
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/account_locked_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';

// Home pages
import '../../features/home/presentation/pages/home_page.dart';

// Training pages
import '../../features/trainings/presentation/pages/trainings_page.dart';
import '../../features/trainings/presentation/pages/training_detail_page.dart';

// Diet pages
import '../../features/diets/presentation/pages/diets_page.dart';

// Calendar pages
import '../../features/calendar/presentation/pages/calendar_page.dart';

// Profile pages
import '../../features/profile/presentation/pages/profile_page.dart';

// Metrics pages
import '../../features/metrics/presentation/pages/metrics_page.dart';

// Challenges pages
import '../../features/challenges/presentation/pages/challenges_page.dart';

// Recap pages
import '../../features/recap/presentation/pages/recap_page.dart';
import '../../features/recap/presentation/pages/recap_detail_page.dart';

// Feedback pages
import '../../features/feedback/presentation/pages/feedback_page.dart';

// Settings pages
import '../../features/settings/presentation/pages/settings_page.dart';

// Help pages
import '../../features/help/presentation/pages/help_page.dart';

// Onboarding pages
import '../../features/onboarding/presentation/pages/onboarding_page.dart';

// Storage
import '../../core/storage/local_storage.dart';
import '../../injection_container.dart';

class AppRoutes {
  static const login = '/login';
  static const accountLocked = '/account-locked';
  static const trialExpired = '/trial-expired';
  static const onboarding = '/onboarding';
  static const home = '/';
  static const trainings = '/trainings';
  static const trainingDetail = '/trainings/:id';
  static const diets = '/diets';
  static const calendar = '/calendar';
  static const profile = '/profile';
  static const metrics = '/metrics';
  static const challenges = '/challenges';
  static const recap = '/recap';
  static const recapDetailBase = '/recap';
  static const feedback = '/feedback';

  static String recapDetail(String id) => '/recap/$id';
  static const settings = '/settings';
  static const help = '/help';
}

class AppRouter {
  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  static final Listenable _refreshListenable = Listenable.merge([
    GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
    GetIt.I<FeatureGateService>(),
  ]);

  static Future<void> _openContact(BuildContext context) async {
    final launched = await launchUrl(
      ExternalLinks.supportPage,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la pagina de contacto.'),
        ),
      );
    }
  }

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final loc = state.matchedLocation;
      final isAuthRoute =
          loc == AppRoutes.login ||
          loc == AppRoutes.accountLocked ||
          loc == AppRoutes.trialExpired;

      if (user == null && !isAuthRoute) return AppRoutes.login;
      if (user != null && loc == AppRoutes.login) return AppRoutes.home;

      // Show onboarding to newly authenticated users who haven't seen it
      if (user != null && !isAuthRoute && loc != AppRoutes.onboarding) {
        final done = sl<LocalStorage>().isOnboardingComplete;
        if (!done) return AppRoutes.onboarding;
      }

      // Check trial expiration
      if (user != null && !isAuthRoute && loc != AppRoutes.trialExpired) {
        final gate = GetIt.I<FeatureGateService>();
        if (gate.isTrialExpired) {
          return AppRoutes.trialExpired;
        }
      }

      return null;
    },
    refreshListenable: _refreshListenable,
    routes: [
      // Auth
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.accountLocked,
        builder: (context, state) => const AccountLockedPage(),
      ),
      GoRoute(
        path: AppRoutes.trialExpired,
        builder: (context, state) => TrialExpiredScreen(
          onContactTrainer: () => _openContact(context),
          onLogout: () {
            context.read<AuthBloc>().add(const AuthLogoutRequested());
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),

      // Main shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomePage()),
          ),
          GoRoute(
            path: AppRoutes.trainings,
            pageBuilder: (_, state) => NoTransitionPage(
              child: TrainingsPage(
                selectedDate: state.uri.queryParameters['date'],
              ),
            ),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => TrainingDetailPage(
                  trainingId: state.pathParameters['id']!,
                  selectedDate: state.uri.queryParameters['date'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.diets,
            pageBuilder: (_, state) => NoTransitionPage(
              child: DietsPage(selectedDate: state.uri.queryParameters['date']),
            ),
          ),
          GoRoute(
            path: AppRoutes.calendar,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CalendarPage()),
          ),
          GoRoute(
            path: AppRoutes.challenges,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ChallengesPage()),
          ),
        ],
      ),

      // Profile (no shell nav bar — accessible from drawer)
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfilePage(),
        routes: [
          GoRoute(
            path: 'metrics',
            builder: (context, state) => const MetricsPage(),
          ),
        ],
      ),

      // Modal routes (no shell)
      GoRoute(
        path: AppRoutes.recap,
        builder: (context, state) => const RecapPage(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                RecapDetailPage(recapId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.feedback,
        builder: (_, state) {
          final extra = state.extra as Map<String, String?>?;
          return FeedbackPage(
            exerciseId: extra?['exerciseId'],
            exerciseName: extra?['exerciseName'],
          );
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.help,
        builder: (context, state) => const HelpPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          AppLocalizations.of(
            context,
          ).pageNotFoundError(state.error.toString()),
        ),
      ),
    ),
  );
}

// ─── Main Shell ────────────────────────────────────────────────────────────────

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  Widget _buildBodyWithTrialBanner(Widget child) {
    final gate = GetIt.I<FeatureGateService>();
    return AnimatedBuilder(
      animation: gate,
      builder: (context, _) {
        if (!gate.isTrial || gate.isTrialExpired) {
          return child;
        }

        return Column(
          children: [
            TrialBanner(
              daysRemaining: gate.trialDaysRemaining,
              onSubscribe: () => AppRouter._openContact(context),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }

  String _brandLogo(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? 'assets/images/logo_dark.svg'
        : 'assets/images/logo.svg';
  }

  // Tab order: Challenges, Trainings, Home (center), Diets, Calendar
  static const _tabs = [
    AppRoutes.challenges,
    AppRoutes.trainings,
    AppRoutes.home,
    AppRoutes.diets,
    AppRoutes.calendar,
  ];

  int _currentIndex(String location) {
    if (location == '/') return 2; // Home is center
    if (location.startsWith('/challenges')) return 0;
    if (location.startsWith('/trainings')) return 1;
    if (location.startsWith('/diets')) return 3;
    if (location.startsWith('/calendar')) return 4;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selected = _currentIndex(location);
    final palette = context.exomPalette;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // EXOM logo with text
                SvgPicture.asset(_brandLogo(context), height: 28),
                const Spacer(),
                IconButton(
                  onPressed: () => context.push(AppRoutes.profile),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: palette.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: palette.textPrimary,
                      size: 18,
                    ),
                  ),
                ),
                // Hamburger menu
                Builder(
                  builder: (ctx) => IconButton(
                    onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                    icon: Icon(
                      Icons.menu,
                      color: palette.textPrimary,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      endDrawer: const _AppDrawer(),
      body: _buildBodyWithTrialBanner(child),
      bottomNavigationBar: _ExomBottomNav(
        selectedIndex: selected,
        onTap: (i) => context.go(_tabs[i]),
      ),
    );
  }
}

// ─── App Drawer ────────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context);
    final name = user?.displayName ?? l10n.userDefaultName;
    final theme = Theme.of(context);
    final palette = context.exomPalette;

    return Drawer(
      backgroundColor: palette.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(color: palette.surfaceVariant),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SvgPicture.asset(
                    Theme.of(context).brightness == Brightness.light
                        ? 'assets/images/logo_dark.svg'
                        : 'assets/images/logo.svg',
                    height: 24,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: palette.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.exomMemberLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(
                    icon: Icons.person_outline,
                    label: l10n.profileMenuItem,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.profile);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.emoji_events_outlined,
                    label: l10n.challengesMenuItem,
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoutes.challenges);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.bar_chart_outlined,
                    label: l10n.weeklyRecapMenuItem,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.recap);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.feedback_outlined,
                    label: l10n.feedbackMenuItem,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.feedback);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: l10n.settingsMenuItem,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.settings);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.help_outline,
                    label: l10n.helpMenuItem,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.help);
                    },
                  ),
                  Divider(color: palette.divider, height: 24),
                  _DrawerItem(
                    icon: Icons.logout,
                    label: l10n.logOutMenuItem,
                    color: AppColors.error,
                    onTap: () {
                      Navigator.pop(context);
                      context.read<AuthBloc>().add(const AuthLogoutRequested());
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? context.exomPalette.textPrimary;
    return ListTile(
      leading: Icon(icon, color: itemColor, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: itemColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      horizontalTitleGap: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
    );
  }
}

// ─── Custom Bottom Navigation ──────────────────────────────────────────────────

class _ExomBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _ExomBottomNav({required this.selectedIndex, required this.onTap});

  static const _icons = [
    Icons.emoji_events_outlined,
    Icons.fitness_center,
    null, // center = EXOM logo
    Icons.restaurant,
    Icons.calendar_month,
  ];

  static const _circleSize = 64.0;
  static const _barHeight = 64.0;
  static const _circleOverlap = 10.0; // just slightly above bar top
  @override
  Widget build(BuildContext context) {
    final targetX = _slotCenterX(context, selectedIndex);
    final palette = context.exomPalette;
    final inactiveColor = palette.textDisabled;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: _barHeight + _circleOverlap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: targetX),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          builder: (context, centerX, _) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Flat bar — no notch
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _barHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.surface,
                      border: Border(
                        top: BorderSide(color: palette.borderSoft, width: 0.5),
                      ),
                    ),
                  ),
                ),

                // Green circle with glow
                Positioned(
                  left: centerX - _circleSize / 2,
                  bottom: _barHeight - _circleSize + _circleOverlap,
                  child: Container(
                    width: _circleSize,
                    height: _circleSize,
                    decoration: BoxDecoration(
                      color: palette.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.35),
                          blurRadius: 30,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _buildIcon(
                        selectedIndex,
                        true,
                        activeColor: palette.onPrimary,
                        inactiveColor: inactiveColor,
                      ),
                    ),
                  ),
                ),

                // Icon row (active slot hidden — rendered inside circle)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _barHeight,
                  child: Row(
                    children: List.generate(5, (i) {
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onTap(i),
                          child: Center(
                            child: i == selectedIndex
                                ? const SizedBox.shrink()
                                : _buildIcon(
                                    i,
                                    false,
                                    activeColor: palette.onPrimary,
                                    inactiveColor: inactiveColor,
                                  ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildIcon(
    int index,
    bool isActive, {
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final color = isActive ? activeColor : inactiveColor;
    final size = isActive ? 28.0 : 28.0;
    if (index == 2) {
      return SvgPicture.asset(
        'assets/images/logo_small.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Icon(_icons[index], size: size, color: color);
  }

  double _slotCenterX(BuildContext context, int index) {
    final w = MediaQuery.of(context).size.width;
    final slot = w / 5;
    return slot * index + slot / 2;
  }
}

// ─── GoRouter Refresh Stream ───────────────────────────────────────────────────

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
