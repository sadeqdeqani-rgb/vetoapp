import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vetoapp_demo/core/di/injection.dart' as demo_di;
import 'package:vetoapp_demo/features/ballot/presentation/screens/ballot_screen.dart'
    as demo;
import 'package:vetoapp_demo/features/home/presentation/screens/about_detail_screen.dart'
    as demo;
import 'package:vetoapp_demo/features/home/presentation/screens/about_screen.dart'
    as demo;
import 'package:vetoapp_demo/features/home/presentation/screens/about_sections.dart'
    as demo;
import 'package:vetoapp_demo/features/home/presentation/screens/civic_detail_screen.dart'
    as demo;
import 'package:vetoapp_demo/features/home/presentation/screens/election_screen.dart'
    as demo;
import 'package:vetoapp_demo/features/home/presentation/screens/home_screen.dart'
    as demo;
import 'package:vetoapp_demo/features/home/presentation/screens/impeachment_screen.dart'
    as demo;
import 'package:vetoapp_demo/features/home/presentation/screens/main_screen.dart'
    as demo;
import 'package:vetoapp_demo/features/home/presentation/screens/referendum_screen.dart'
    as demo;
import 'package:vetoapp_demo/core/theme/app_theme.dart' as demo;
import 'package:vetoapp_demo/features/participation/presentation/screens/participation_screen.dart'
    as demo;
import 'package:vetoapp_demo/features/profile/presentation/cubit/profile_cubit.dart'
    as demo;
import 'package:vetoapp_demo/features/profile/presentation/screens/profile_screen.dart'
    as demo;

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';
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
import 'package:vetoapp_demo/core/theme/app_theme.dart';
import 'package:vetoapp_demo/features/home/presentation/screens/civic_detail_screen.dart';

class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter createAppRouter(AuthCubit authCubit) {
  /// فعلاً AuthCubit در redirect استفاده نمی‌شود.
  /// با فعال شدن احراز هویت واقعی، redirect بر اساس state همین Cubit تکمیل می‌شود.
  final _ = authCubit;
  demo_di.configureDependencies();
  const startRoute = String.fromEnvironment(
    'VETO_START_ROUTE',
    defaultValue: '/splash',
  );

  return GoRouter(
    initialLocation: startRoute,
    refreshListenable: _AuthRouterRefresh(authCubit.stream),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isPublic =
          location == '/splash' ||
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
          location == '/forgot-password/reset' ||
          location == '/admin/login' ||
          location == '/admin';
      final isAuthenticated =
          authCubit.state is Authenticated || authCubit.state is Guest;

      if (!isPublic && !isAuthenticated) {
        return '/gateway';
      }

      if (location == '/login' && isAuthenticated) {
        return '/';
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
        builder: (context, state, child) {
          if (authCubit.state is Guest) {
            return BlocProvider<demo.ProfileCubit>(
              create: (_) => demo_di.getIt<demo.ProfileCubit>(),
              child: demo.MainScreen(child: child),
            );
          }
          return MainScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder:
                (context, state) =>
                    authCubit.state is Guest
                        ? const demo.HomeScreen()
                        : const HomeScreen(),
          ),
          GoRoute(
            path: '/about',
            name: 'about',
            builder:
                (context, state) =>
                    authCubit.state is Guest
                        ? const demo.AboutScreen()
                        : const AboutScreen(),
          ),
          GoRoute(
            path: '/about/detail',
            name: 'about-detail',
            builder: (context, state) {
              if (authCubit.state is Guest) {
                final section = state.extra;
                return section is demo.AboutSection
                    ? demo.AboutDetailScreen(section: section)
                    : const demo.AboutScreen();
              }
              return const AboutScreen();
            },
          ),
          GoRoute(
            path: '/participation',
            name: 'participation',
            builder:
                (context, state) =>
                    authCubit.state is Guest
                        ? const demo.ParticipationScreen()
                        : const ParticipationScreen(),
          ),
          GoRoute(
            path: '/ballot',
            name: 'ballot',
            builder:
                (context, state) =>
                    authCubit.state is Guest
                        ? const demo.BallotScreen()
                        : const BallotScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder:
                (context, state) =>
                    authCubit.state is Guest
                        ? const demo.ProfileScreen()
                        : const ProfileScreen(),
          ),
          GoRoute(
            path: '/referendum',
            name: 'referendum',
            builder:
                (context, state) =>
                    authCubit.state is Guest
                        ? const demo.ReferendumScreen()
                        : const ReferendumScreen(),
          ),
          GoRoute(
            path: '/elections',
            name: 'elections',
            builder:
                (context, state) =>
                    authCubit.state is Guest
                        ? const demo.ElectionScreen()
                        : const ElectionScreen(),
          ),
          GoRoute(
            path: '/impeachment',
            name: 'impeachment',
            builder:
                (context, state) =>
                    authCubit.state is Guest
                        ? const demo.ImpeachmentScreen()
                        : const ImpeachmentScreen(),
          ),
          GoRoute(
            path: '/referendum/propose',
            builder:
                (context, state) => authCubit.state is Guest
                    ? const demo.CivicDetailScreen(
                        title: 'پیشنهاد موضوع برای همه‌پرسی',
                        parentIcon: Icons.how_to_vote_outlined,
                        proposalForm: true,
                        accent: Color(0xFF2E7D32),
                        items: [],
                      )
                    : const CivicDetailScreen(
                        title: 'پیشنهاد موضوع برای همه‌پرسی',
                        parentIcon: Icons.how_to_vote_outlined,
                        proposalForm: true,
                        accent: Color(0xFF2E7D32),
                        items: [],
                      ),
          ),
          GoRoute(
            path: '/referendum/supported',
            builder:
                (context, state) => authCubit.state is Guest
                    ? const demo.CivicDetailScreen(
                        title: 'مرور موضوعات و ثبت حمایت',
                        parentIcon: Icons.how_to_vote_outlined,
                        accent: Color(0xFF2E7D32),
                        items: [
                          demo.CivicDetailItem(
                            title: 'قرارداد ۲۵ ساله با چین',
                            count: '۳۷۸۹۰',
                          ),
                          demo.CivicDetailItem(
                            title: 'تعطیلی ایران خودرو',
                            count: '۳۴۵۶۷۸۹',
                          ),
                        ],
                      )
                    : const CivicDetailScreen(
                        title: 'مرور موضوعات و ثبت حمایت',
                        parentIcon: Icons.how_to_vote_outlined,
                        accent: Color(0xFF2E7D32),
                        items: [],
                      ),
          ),
          GoRoute(
            path: '/referendum/active',
            builder:
                (context, state) => authCubit.state is Guest
                    ? const demo.CivicDetailScreen(
                        title: 'مشاهده و ثبت رای در موضوعات فعال',
                        parentIcon: Icons.how_to_vote_outlined,
                        accent: Color(0xFF2E7D32),
                        items: [
                          demo.CivicDetailItem(title: 'انحلال جمهوری'),
                          demo.CivicDetailItem(title: 'محو اسراییل'),
                          demo.CivicDetailItem(title: 'بستن تنگه هرمز'),
                          demo.CivicDetailItem(title: 'غنی سازی اورانیوم'),
                        ],
                      )
                    : const CivicDetailScreen(
                        title: 'مشاهده و ثبت رای در موضوعات فعال',
                        parentIcon: Icons.how_to_vote_outlined,
                        accent: Color(0xFF2E7D32),
                        items: [],
                      ),
          ),
          GoRoute(
            path: '/referendum/results',
            builder:
                (context, state) => authCubit.state is Guest
                    ? const demo.CivicDetailScreen(
                        title: 'بررسی نتایج و سوابق قبلی',
                        parentIcon: Icons.home_outlined,
                        accent: Color(0xFF2E7D32),
                        items: [
                          demo.CivicDetailItem(title: 'حجاب اجباری'),
                          demo.CivicDetailItem(title: 'مذاکره با آمریکا'),
                          demo.CivicDetailItem(title: 'نظارت استصوابی'),
                        ],
                      )
                    : const CivicDetailScreen(
                        title: 'بررسی نتایج و سوابق قبلی',
                        parentIcon: Icons.home_outlined,
                        accent: Color(0xFF2E7D32),
                        items: [],
                      ),
          ),
          GoRoute(
            path: '/elections/participate',
            builder:
                (context, state) => authCubit.state is Guest
                    ? const demo.CivicDetailScreen(
                        title: 'شرکت در انتخابات',
                        parentIcon: Icons.how_to_vote_rounded,
                        accent: demo.AppTheme.election,
                        items: [
                          demo.CivicDetailItem(title: 'انتخابات ریاست جمهوری'),
                          demo.CivicDetailItem(title: 'انتخابات استانداری یزد'),
                          demo.CivicDetailItem(title: 'انتخابات استانداری اصفهان'),
                          demo.CivicDetailItem(title: 'انتخابات استانداری فارس'),
                        ],
                      )
                    : const CivicDetailScreen(
                        title: 'شرکت در انتخابات',
                        parentIcon: Icons.how_to_vote_rounded,
                        accent: AppTheme.election,
                        items: [],
                      ),
          ),
          GoRoute(
            path: '/elections/live',
            builder:
                (context, state) => authCubit.state is Guest
                    ? const demo.CivicDetailScreen(
                        title: 'نتایج زنده انتخابات',
                        parentIcon: Icons.show_chart_rounded,
                        accent: demo.AppTheme.election,
                        items: [
                          demo.CivicDetailItem(
                            title: 'انتخابات ریاست جمهوری',
                            status: 'در حال برگزاری',
                          ),
                        ],
                      )
                    : const CivicDetailScreen(
                        title: 'نتایج زنده انتخابات',
                        parentIcon: Icons.show_chart_rounded,
                        accent: AppTheme.election,
                        items: [],
                      ),
          ),
          GoRoute(
            path: '/elections/results',
            builder:
                (context, state) => authCubit.state is Guest
                    ? const demo.CivicDetailScreen(
                        title: 'نتایج انتخابات پایان‌یافته',
                        parentIcon: Icons.poll_outlined,
                        accent: demo.AppTheme.election,
                        items: [
                          demo.CivicDetailItem(title: 'انتخابات استانداری یزد'),
                          demo.CivicDetailItem(title: 'انتخابات استانداری اصفهان'),
                          demo.CivicDetailItem(title: 'انتخابات استانداری فارس'),
                        ],
                      )
                    : const CivicDetailScreen(
                        title: 'نتایج انتخابات پایان‌یافته',
                        parentIcon: Icons.poll_outlined,
                        accent: AppTheme.election,
                        items: [],
                      ),
          ),
          GoRoute(
            path: '/impeachment/request',
            builder:
                (context, state) => authCubit.state is Guest
                    ? const demo.CivicDetailScreen(
                        title: 'درخواست استیضاح یک مسول ملی یا محلی',
                        parentIcon: Icons.gavel_outlined,
                        accent: demo.AppTheme.danger,
                        items: [
                          demo.CivicDetailItem(
                            title: 'حوزه کاربری شما',
                            subtitle:
                                'کشور: ایران / استان: فارس / شهرستان: نورآباد ممسنی / شهر / روستا: دهگپ محمودی',
                          ),
                          demo.CivicDetailItem(title: 'ثبت درخواست استیضاح رییس جمهور'),
                          demo.CivicDetailItem(
                            title: 'ثبت درخواست استیضاح استاندار / فارس',
                          ),
                        ],
                      )
                    : const CivicDetailScreen(
                        title: 'درخواست استیضاح یک مسول ملی یا محلی',
                        parentIcon: Icons.gavel_outlined,
                        accent: AppTheme.danger,
                        items: [],
                      ),
          ),
          GoRoute(
            path: '/impeachment/active',
            builder:
                (context, state) => authCubit.state is Guest
                    ? const demo.CivicDetailScreen(
                        title: 'شرکت در فرآیند رای اعتماد و ثبت رای',
                        parentIcon: Icons.gavel_outlined,
                        accent: demo.AppTheme.danger,
                        items: [
                          demo.CivicDetailItem(
                            title: 'رای اعتماد به رییس جمهور',
                            status: 'در حال برگزاری',
                          ),
                        ],
                      )
                    : const CivicDetailScreen(
                        title: 'شرکت در فرآیند رای اعتماد و ثبت رای',
                        parentIcon: Icons.gavel_outlined,
                        accent: AppTheme.danger,
                        items: [],
                      ),
          ),
          GoRoute(
            path: '/impeachment/results',
            builder:
                (context, state) => authCubit.state is Guest
                    ? const demo.CivicDetailScreen(
                        title: 'نتایج استیضاح های انجام شده و اطلاعات و آمار نهایی',
                        parentIcon: Icons.gavel_outlined,
                        accent: demo.AppTheme.danger,
                        items: [
                          demo.CivicDetailItem(
                            title: 'استاندار کرمان',
                            status: 'برکنار شد',
                          ),
                          demo.CivicDetailItem(
                            title: 'استاندار اصفهان',
                            status: 'برکنار شد',
                          ),
                          demo.CivicDetailItem(
                            title: 'استاندار یزد',
                            status: 'ابقا شد',
                          ),
                          demo.CivicDetailItem(
                            title: 'استاندار فارس',
                            status: 'به حد نصاب نرسید',
                          ),
                        ],
                      )
                    : const CivicDetailScreen(
                        title: 'نتایج استیضاح های انجام شده و اطلاعات و آمار نهایی',
                        parentIcon: Icons.gavel_outlined,
                        accent: AppTheme.danger,
                        items: [],
                      ),
          ),
        ],
      ),
    ],
  );
}
