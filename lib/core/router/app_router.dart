import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/forgot_password_phone_page.dart';
import '../../features/auth/presentation/pages/login_credentials_page.dart';
import '../../features/auth/presentation/pages/otp_verification_page.dart';
import '../../features/ballot/presentation/screens/ballot_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/main_screen.dart';
import '../../features/participation/presentation/screens/participation_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/startup/presentation/pages/gateway_page.dart'
    as gateway_page;
import '../../features/startup/presentation/pages/splash_page.dart';

GoRouter createAppRouter(AuthCubit authCubit) {
  /// فعلاً AuthCubit در redirect استفاده نمی‌شود.
  /// با فعال شدن احراز هویت واقعی، redirect بر اساس state همین Cubit تکمیل می‌شود.
  final _ = authCubit;

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final location = state.matchedLocation;

      if (location == '/splash' ||
          location == '/gateway' ||
          location == '/login' ||
          location == '/forgot-password' ||
          location == '/otp-verification' ||
          location == '/forgot-password/reset') {
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/gateway',
        name: 'gateway',
        builder: (context, state) => const gateway_page.GatewayPage(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginCredentialsPage(),
      ),

      /// مرحلهٔ اول بازیابی رمز: دریافت شمارهٔ موبایل.
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPhonePage(),
      ),

      /// مرحلهٔ دوم: دریافت و تأیید OTP.
      GoRoute(
        path: '/otp-verification',
        name: 'otp-verification',
        builder: (context, state) {
          final args = state.extra;

          if (args is! Map<String, dynamic>) {
            return const ForgotPasswordPhonePage();
          }

          final phoneNumber = args['phoneNumber'] as String?;
          final isPasswordRecovery =
              args['isPasswordRecovery'] as bool? ?? false;

          if (phoneNumber == null || phoneNumber.trim().isEmpty) {
            return const ForgotPasswordPhonePage();
          }

          return OtpVerificationPage(
            phoneNumber: phoneNumber.trim(),
            isPasswordRecovery: isPasswordRecovery,
          );
        },
      ),

      /// مرحلهٔ سوم: تعیین رمز عبور جدید.
      ///
      /// شماره و verificationToken فقط از صفحهٔ OTP معتبر دریافت می‌شوند.
      GoRoute(
        path: '/forgot-password/reset',
        name: 'forgot-password-reset',
        builder: (context, state) {
          final args = state.extra;

          if (args is! Map<String, dynamic>) {
            return const ForgotPasswordPhonePage();
          }

          final phoneNumber = args['phoneNumber'] as String?;
          final verificationToken = args['verificationToken'] as String?;

          if (phoneNumber == null ||
              phoneNumber.trim().isEmpty ||
              verificationToken == null ||
              verificationToken.trim().isEmpty) {
            return const ForgotPasswordPhonePage();
          }

          return ForgotPasswordPage(
            phoneNumber: phoneNumber.trim(),
            verificationToken: verificationToken.trim(),
          );
        },
      ),

      ShellRoute(
        builder: (context, state, child) => MainScreen(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/participation',
            name: 'participation',
            builder: (context, state) => const ParticipationScreen(),
          ),
          GoRoute(
            path: '/ballot',
            name: 'ballot',
            builder: (context, state) => const BallotScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
}
