import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/forgot_password_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/home/account_page.dart';
import '../../features/home/history_page.dart';
import '../../features/home/home_page.dart';
import '../../features/home/vehicles_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/start/start_page.dart';
import '../app_controller.dart';

GoRouter createAppRouter(AppController controller) {
  const publicPaths = <String>{
    '/start',
    '/onboarding',
    '/login',
    '/register',
    '/forgot-password',
  };

  return GoRouter(
    initialLocation: '/start',
    refreshListenable: controller,
    redirect: (context, state) {
      final path = state.uri.path;

      if (path == '/start') {
        if (controller.isAuthenticated) {
          return '/home';
        }
        return controller.onboardingCompleted ? '/login' : '/onboarding';
      }

      if (controller.isAuthenticated) {
        if (publicPaths.contains(path)) {
          return '/home';
        }
        return null;
      }

      if (!controller.onboardingCompleted) {
        if (path != '/onboarding') {
          return '/onboarding';
        }
        return null;
      }

      if (path == '/onboarding') {
        return '/login';
      }

      if (!publicPaths.contains(path)) {
        return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/start', builder: (context, state) => const StartPage()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingPage(controller: controller),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/vehicles',
        builder: (context, state) => const VehiclesPage(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryPage(),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountPage(),
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Cette page est introuvable.\n${state.uri}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    },
  );
}
