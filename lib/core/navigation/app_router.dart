import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Auth pages
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/account_locked_page.dart';

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

class AppRoutes {
  static const login = '/login';
  static const accountLocked = '/account-locked';
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
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isAuthRoute =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.accountLocked;

      if (user == null && !isAuthRoute) return AppRoutes.login;
      if (user != null && state.matchedLocation == AppRoutes.login) {
        return AppRoutes.home;
      }
      return null;
    },
    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),
    routes: [
      // Auth
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.accountLocked,
        builder: (_, __) => const AccountLockedPage(),
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
            pageBuilder: (_, __) => const NoTransitionPage(child: TrainingsPage()),
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
            pageBuilder: (_, __) => const NoTransitionPage(child: CalendarPage()),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (_, __) => const NoTransitionPage(child: ProfilePage()),
            routes: [
              GoRoute(
                path: 'metrics',
                builder: (_, __) => const MetricsPage(),
              ),
            ],
          ),
        ],
      ),

      // Meal detail (no shell nav bar)
      GoRoute(
        path: '/meals/:id',
        builder: (_, state) =>
            MealDetailPage(mealId: state.pathParameters['id']!),
      ),

      // Modal routes (no shell)
      GoRoute(
        path: AppRoutes.challenges,
        builder: (_, __) => const ChallengesPage(),
      ),
      GoRoute(
        path: AppRoutes.recap,
        builder: (_, __) => const RecapPage(),
      ),
      GoRoute(
        path: AppRoutes.feedback,
        builder: (_, __) => const FeedbackPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.help,
        builder: (_, __) => const HelpPage(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
}

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    AppRoutes.home,
    AppRoutes.trainings,
    AppRoutes.diets,
    AppRoutes.calendar,
    AppRoutes.profile,
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexWhere((t) => location.startsWith(t));

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex < 0 ? 0 : currentIndex,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Entrena'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'Dieta'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendario'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

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
