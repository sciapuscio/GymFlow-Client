import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/connectivity_service.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/home/screens/no_membership_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/schedule/screens/schedule_screen.dart';
import 'features/checkin/screens/checkin_screen.dart';
import 'features/checkin/screens/checkin_result_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/schedule/screens/my_reservations_screen.dart';
import 'features/auth/screens/change_password_screen.dart';

final routerKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(AuthProvider auth) {
  return GoRouter(
    navigatorKey: routerKey,
    refreshListenable: auth,
    initialLocation: '/home',
    redirect: (context, state) {
      final status = auth.status;

      // Still initializing → stay on splash
      if (status == AuthStatus.unknown) return '/splash';

      // Splash min-duration not met yet → hold on splash
      if (!auth.splashReady && state.matchedLocation == '/splash') return '/splash';

      final isAuth = status == AuthStatus.authenticated;
      final loc = state.matchedLocation;

      // Splash must always redirect once auth is resolved AND splash is ready
      if (loc == '/splash') return isAuth ? '/home' : '/login';

      // Protect authenticated routes
      final isOnAuthPage = loc.startsWith('/login') || loc.startsWith('/register');
      if (!isAuth && !isOnAuthPage) return '/login';
      if (isAuth && isOnAuthPage) return '/home';

      // Force password change after temp PIN login
      if (isAuth && auth.mustChangePassword && loc != '/change-password') {
        return '/change-password';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (_, __) => const ChangePasswordScreen(),
      ),
      // ── Authenticated shell with bottom nav ──────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/schedule',
            builder: (_, __) => const ScheduleScreen(),
          ),
          GoRoute(
            path: '/checkin',
            builder: (_, __) => const CheckinScreen(),
          ),
          GoRoute(
            path: '/checkin/result',
            builder: (_, state) => CheckinResultScreen(
              data: state.extra as Map<String, dynamic>? ?? {},
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/my-reservations',
            builder: (_, __) => const MyReservationsScreen(),
          ),
        ],
      ),
    ],
  );
}

// _SplashScreen replaced by SplashScreen (features/auth/screens/splash_screen.dart)

/// Bottom navigation shell wrapper
class MainShell extends StatelessWidget {
  final String location;
  final Widget child;
  const MainShell({super.key, required this.location, required this.child});

  int get _selectedIndex {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/dashboard')) return 1;
    if (location.startsWith('/schedule')) return 2;
    if (location.startsWith('/checkin')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final member = auth.member;
    final membership = member?.membership;
    final hasActiveMembership = membership != null && membership.isActive;

    final conn = context.watch<ConnectivityService>();
    final isOnline = conn.isOnline;

    // Only show onboarding when member data is confirmed loaded and has no active membership
    if (auth.isAuthenticated && member != null && !auth.loadingMember && !hasActiveMembership) {
      return const NoMembershipScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      body: Stack(
        children: [
          child,
          // ── Offline banner ──────────────────────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            top: isOnline ? -60 : MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFFEF4444),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Sin conexión. Verificá tu internet.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => conn.recheck(),
                      child: const Text(
                        'Reintentar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF14141E),
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF00F5D4).withOpacity(0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/dashboard');
            case 2:
              context.go('/schedule');
            case 3:
              context.go('/checkin');
            case 4:
              context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF00F5D4)),
            label: 'Portada',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF00F5D4)),
            label: 'Mi Cuenta',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today, color: Color(0xFF00F5D4)),
            label: 'Grilla',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner, color: Color(0xFF00F5D4)),
            label: 'Check-in',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF00F5D4)),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
