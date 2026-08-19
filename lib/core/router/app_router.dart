import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/ballot/presentation/screens/ballot_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/main_screen.dart';
import '../../features/participation/presentation/screens/participation_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/startup/presentation/pages/gateway_page.dart'
    as gateway_page;
import '../../features/startup/presentation/pages/splash_page.dart';

GoRouter createAppRouter(AuthCubit authCubit) {
  final _ = authCubit;

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      // Access guard will be added after inspecting AuthState.
      if (state.matchedLocation == '/splash' ||
          state.matchedLocation == '/gateway' ||
          state.matchedLocation == '/login') {
        return null;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(
        path: '/gateway',
        builder: (context, state) => const gateway_page.GatewayPage(),
      ),
      GoRoute(
        path: '/login',
        builder:
            (context, state) =>
                const Scaffold(body: Center(child: Text('Login placeholder'))),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScreen(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/participation',
            builder: (context, state) => const ParticipationScreen(),
          ),
          GoRoute(
            path: '/ballot',
            builder: (context, state) => const BallotScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
}
