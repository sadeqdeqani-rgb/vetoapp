import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_credentials_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_verification_page.dart';
import '../../features/startup/presentation/pages/gateway_page.dart';
import '../../features/startup/presentation/pages/splash_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (BuildContext context, GoRouterState state) {
        return const SplashPage();
      },
    ),
    GoRoute(
      path: '/gateway',
      name: 'gateway',
      builder: (BuildContext context, GoRouterState state) {
        return const GatewayPage();
      },
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginPage();
      },
    ),
    GoRoute(
      path: '/login-credentials',
      name: 'login-credentials',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginCredentialsPage();
      },
    ),
    GoRoute(
      path: '/otp-verification',
      name: 'otp-verification',
      builder: (BuildContext context, GoRouterState state) {
        final phoneNumber = state.extra as String? ?? '';
        return OtpVerificationPage(phoneNumber: phoneNumber);
      },
    ),
  ],
);
