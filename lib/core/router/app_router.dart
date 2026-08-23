import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/forgot_password_phone_page.dart';
import '../../features/auth/presentation/pages/login_credentials_page.dart';
import '../../features/auth/presentation/pages/otp_verification_page.dart';
import '../../features/auth/presentation/pages/registration_page.dart';
import '../../features/auth/presentation/pages/registration_national_code_page.dart';
import '../../features/auth/presentation/pages/registration_geography_page.dart';
import '../../features/auth/presentation/pages/registration_password_page.dart';
import '../../features/auth/presentation/pages/registration_success_page.dart';
import '../../features/auth/presentation/pages/registration_terms_page.dart';
import '../../features/ballot/presentation/screens/ballot_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/about_screen.dart';
import '../../features/home/presentation/screens/main_screen.dart';
import '../../features/home/presentation/screens/referendum_screen.dart';
import '../../features/home/presentation/screens/election_screen.dart';
import '../../features/home/presentation/screens/impeachment_screen.dart';
import '../../features/participation/presentation/screens/participation_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/admin/presentation/pages/admin_page.dart';
import '../../features/admin/presentation/pages/admin_login_page.dart';
import '../../features/startup/presentation/pages/gateway_page.dart'
    as gateway_page;
import '../../features/startup/presentation/pages/splash_page.dart';

GoRouter createAppRouter(AuthCubit authCubit) {
  /// فعلاً AuthCubit در redirect استفاده نمی‌شود.
  /// با فعال شدن احراز هویت واقعی، redirect بر اساس state همین Cubit تکمیل می‌شود.
  final _ = authCubit;
  const startRoute = String.fromEnvironment(
    'VETO_START_ROUTE',
    defaultValue: '/splash',
  );

  return GoRouter(
    initialLocation: startRoute,
    redirect: (context, state) {
      final location = state.matchedLocation;

      if (location == '/splash' ||
          location == '/gateway' ||
          location == '/login' ||
          location == '/register/terms' ||
          location == '/register/phone' ||
          location == '/register/national-code' ||
          location == '/register/geography' ||
          location == '/register/password' ||
          location == '/register/success' ||
          location == '/register' ||
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
      GoRoute(
        path: '/register/terms',
        name: 'register-terms',
        builder: (context, state) => const RegistrationTermsPage(),
      ),
      GoRoute(
        path: '/register/phone',
        name: 'register-phone',
        builder:
            (context, state) =>
                const ForgotPasswordPhonePage(isRegistration: true),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegistrationPage(),
      ),
      GoRoute(
        path: '/register/national-code',
        name: 'register-national-code',
        builder: (context, state) {
          final args = state.extra;
          final phoneNumber =
              args is Map<String, dynamic>
                  ? args['phoneNumber'] as String?
                  : null;

          if (phoneNumber == null || phoneNumber.trim().isEmpty) {
            return const ForgotPasswordPhonePage(isRegistration: true);
          }

          return RegistrationNationalCodePage(phoneNumber: phoneNumber.trim());
        },
      ),
      GoRoute(
        path: '/register/geography',
        name: 'register-geography',
        builder: (context, state) {
          final args = state.extra;
          final phoneNumber =
              args is Map<String, dynamic>
                  ? args['phoneNumber'] as String?
                  : null;
          final nationalCode =
              args is Map<String, dynamic>
                  ? args['nationalCode'] as String?
                  : null;

          if (phoneNumber == null ||
              phoneNumber.trim().isEmpty ||
              nationalCode == null ||
              nationalCode.trim().isEmpty) {
            return const ForgotPasswordPhonePage(isRegistration: true);
          }

          return RegistrationGeographyPage(
            phoneNumber: phoneNumber.trim(),
            nationalCode: nationalCode.trim(),
          );
        },
      ),
      GoRoute(
        path: '/register/password',
        name: 'register-password',
        builder: (context, state) {
          final args = state.extra;
          if (args is! Map<String, dynamic>) {
            return const ForgotPasswordPhonePage(isRegistration: true);
          }

          final phoneNumber = args['phoneNumber'] as String?;
          final nationalCode = args['nationalCode'] as String?;
          final countryId = args['countryId'] as int?;
          final provinceId = args['provinceId'] as int?;
          final countyId = args['countyId'] as int?;
          final localityId = args['localityId'] as int?;

          if (phoneNumber == null ||
              phoneNumber.trim().isEmpty ||
              nationalCode == null ||
              nationalCode.trim().isEmpty ||
              countryId == null ||
              provinceId == null ||
              countyId == null ||
              localityId == null) {
            return const ForgotPasswordPhonePage(isRegistration: true);
          }

          return RegistrationPasswordPage(
            phoneNumber: phoneNumber.trim(),
            nationalCode: nationalCode.trim(),
            countryId: countryId,
            provinceId: provinceId,
            countyId: countyId,
            localityId: localityId,
          );
        },
      ),
      GoRoute(
        path: '/register/success',
        name: 'register-success',
        builder: (context, state) => const RegistrationSuccessPage(),
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
          final isRegistration = args['isRegistration'] as bool? ?? false;

          if (phoneNumber == null || phoneNumber.trim().isEmpty) {
            return const ForgotPasswordPhonePage();
          }

          return OtpVerificationPage(
            phoneNumber: phoneNumber.trim(),
            isPasswordRecovery: isPasswordRecovery,
            isRegistration: isRegistration,
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
      GoRoute(
        path: '/admin/login',
        name: 'admin-login',
        builder: (context, state) => const AdminLoginPage(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminPage(),
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
            path: '/about',
            name: 'about',
            builder: (context, state) => const AboutScreen(),
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
          GoRoute(
            path: '/referendum',
            name: 'referendum',
            builder: (context, state) => const ReferendumScreen(),
          ),
          GoRoute(
            path: '/elections',
            name: 'elections',
            builder: (context, state) => const ElectionScreen(),
          ),
          GoRoute(
            path: '/impeachment',
            name: 'impeachment',
            builder: (context, state) => const ImpeachmentScreen(),
          ),
        ],
      ),
    ],
  );
}
