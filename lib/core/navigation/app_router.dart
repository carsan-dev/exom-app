import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:exom_app/core/theme/app_theme.dart';

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
import '../../features/diets/presentation/pages/meal_detail_page.dart';

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
  static const onboarding = '/onboarding';
  static const home = '/';
  static const trainings = '/trainings';
  static const trainingDetail = '/trainings/:id';
  static const diets = '/diets';
  static const mealDetail = '/meals/:id';
  static const calendar = '/calendar';
  static const profile = '/profile';
  static const metrics = '/metrics';
  static const challenges = '/challenges';
  static const recap = '/recap';
  static const feedback = '/feedback';
  static const settings = '/settings';
  static const help = '/help';
}

class AppRouter {
  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final loc = state.matchedLocation;
      final isAuthRoute =
          loc == AppRoutes.login || loc == AppRoutes.accountLocked;

      if (user == null && !isAuthRoute) return AppRoutes.login;
      if (user != null && loc == AppRoutes.login) return AppRoutes.home;

      // Show onboarding to newly authenticated users who haven't seen it
      if (user != null && !isAuthRoute && loc != AppRoutes.onboarding) {
        final done = sl<LocalStorage>().isOnboardingComplete;
        if (!done) return AppRoutes.onboarding;
      }

      return null;
    },
    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),
    routes: [
      // Auth
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginPage()),
      GoRoute(
        path: AppRoutes.accountLocked,
        builder: (_, __) => const AccountLockedPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingPage(),
      ),

      // Main shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (_, __) => const NoTransitionPage(child: HomePage()),
          ),
          GoRoute(
            path: AppRoutes.trainings,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: TrainingsPage()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    TrainingDetailPage(trainingId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.diets,
            pageBuilder: (_, __) => const NoTransitionPage(child: DietsPage()),
          ),
          GoRoute(
            path: AppRoutes.calendar,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: CalendarPage()),
          ),
          GoRoute(
            path: AppRoutes.challenges,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ChallengesPage()),
          ),
        ],
      ),

      // Profile (no shell nav bar — accessible from drawer)
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const ProfilePage(),
        routes: [
          GoRoute(path: 'metrics', builder: (_, __) => const MetricsPage()),
        ],
      ),

      // Meal detail (no shell nav bar)
      GoRoute(
        path: '/meals/:id',
        builder: (_, state) =>
            MealDetailPage(mealId: state.pathParameters['id']!),
      ),

      // Modal routes (no shell)
      GoRoute(path: AppRoutes.recap, builder: (_, __) => const RecapPage()),
      GoRoute(
        path: AppRoutes.feedback,
        builder: (_, __) => const FeedbackPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsPage(),
      ),
      GoRoute(path: AppRoutes.help, builder: (_, __) => const HelpPage()),
    ],
    errorBuilder: (_, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.error}'))),
  );
}

// ─── Main Shell ────────────────────────────────────────────────────────────────

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // EXOM logo with text
                SvgPicture.asset('assets/images/logo.svg', height: 28),
                const Spacer(),
                // Hamburger menu
                Builder(
                  builder: (ctx) => IconButton(
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                    icon: const Icon(
                      Icons.menu,
                      color: AppColors.textPrimary,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      drawer: const _AppDrawer(),
      body: child,
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
    final name = user?.displayName ?? 'Usuario';

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: const BoxDecoration(color: AppColors.surfaceVariant),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SvgPicture.asset('assets/images/logo.svg', height: 24),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Miembro EXOM',
                    style: TextStyle(
                      color: AppColors.textSecondary,
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
                    label: 'Perfil',
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.profile);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.emoji_events_outlined,
                    label: 'Retos',
                    onTap: () {
                      Navigator.pop(context);
                      context.go(AppRoutes.challenges);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.bar_chart_outlined,
                    label: 'Recap Semanal',
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.recap);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.feedback_outlined,
                    label: 'Feedback',
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.feedback);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Ajustes',
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.settings);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.help_outline,
                    label: 'Ayuda',
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.help);
                    },
                  ),
                  const Divider(color: AppColors.divider, height: 24),
                  _DrawerItem(
                    icon: Icons.logout,
                    label: 'Cerrar Sesión',
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
    final itemColor = color ?? AppColors.textPrimary;
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
  static const _inactiveColor = Color(0xFFD5CCBF); // warm cream

  @override
  Widget build(BuildContext context) {
    final targetX = _slotCenterX(context, selectedIndex);

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
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        top: BorderSide(
                          color: AppColors.borderSoft,
                          width: 0.5,
                        ),
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
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 30,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: Center(child: _buildIcon(selectedIndex, true)),
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
                                : _buildIcon(i, false),
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

  Widget _buildIcon(int index, bool isActive) {
    final color = isActive ? AppColors.textOnPrimary : _inactiveColor;
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
