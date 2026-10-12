import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/interactive_empty_tab_notice.dart';
import '../../features/admin/presentation/pages/admin_login_page.dart';
import '../../features/admin/presentation/pages/admin_page.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/forgot_password_phone_page.dart';
import '../../features/auth/presentation/pages/login_credentials_page.dart';
import '../../features/auth/presentation/pages/otp_verification_page.dart';
import '../../features/auth/presentation/pages/registration_geography_page.dart';
import '../../features/auth/presentation/pages/registration_national_code_page.dart';
import '../../features/auth/presentation/pages/registration_page.dart';
import '../../features/auth/presentation/pages/registration_password_page.dart';
import '../../features/auth/presentation/pages/registration_success_page.dart';
import '../../features/auth/presentation/pages/registration_terms_page.dart';
import '../../features/ballot/presentation/screens/ballot_screen.dart';
import '../../features/home/presentation/screens/about_detail_screen.dart';
import '../../features/home/presentation/screens/about_screen.dart';
import '../../features/home/presentation/screens/about_sections.dart';
import '../../features/home/presentation/screens/civic_detail_screen.dart';
import '../../features/home/presentation/screens/election_screen.dart';
import '../../features/election/presentation/election_voting_hub_screen.dart';
import '../../features/election/presentation/election_category_hub_screen.dart';
import '../../features/election/domain/election_category.dart';
import '../../features/election/presentation/election_process_list_screen.dart';
import '../../features/election/presentation/election_voting_detail_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/impeachment_screen.dart';
import '../../features/impeachment/domain/impeachment_office.dart';
import '../../features/impeachment/presentation/impeachment_workflow_hub.dart';
import '../../features/impeachment/presentation/impeachment_process_list_screen.dart';
import '../../features/impeachment/presentation/impeachment_request_screen.dart';
import '../../features/impeachment/presentation/impeachment_detail_screen.dart';
import '../../features/home/presentation/screens/main_screen.dart';
import '../../features/home/presentation/screens/referendum_screen.dart';
import '../../features/participation/presentation/screens/participation_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/referendum/presentation/screens/referendum_proposal_detail_screen.dart';
import '../../features/referendum/presentation/screens/referendum_proposals_screen.dart';
import '../../features/referendum/presentation/screens/referendum_voting_hub_screen.dart';
import '../../features/referendum/presentation/screens/referendum_process_list_screen.dart';
import '../../features/referendum/presentation/screens/referendum_voting_detail_screen.dart';
import '../../features/referendum/presentation/screens/interactive_referendum_samples_screen.dart';
import '../../features/startup/presentation/pages/gateway_page.dart'
    as gateway_page;
import '../../features/startup/presentation/pages/splash_page.dart';
import '../../features/startup/presentation/pages/system_preview_page.dart';

Widget _electionListRoute(GoRouterState state, ElectionListKind kind) {
  final category = ElectionCategory.fromCode(state.pathParameters['category']);
  return category == null
      ? const ElectionVotingHubScreen()
      : ElectionProcessListScreen(category: category, kind: kind);
}

Widget _impeachmentOfficeRoute(GoRouterState state) {
  final office = ImpeachmentOffice.fromCode(state.pathParameters['office']);
  return office == null
      ? const ImpeachmentScreen()
      : ImpeachmentWorkflowHub(office: office);
}

Widget _impeachmentListRoute(GoRouterState state, String kind) {
  final office = ImpeachmentOffice.fromCode(state.pathParameters['office']);
  return office == null
      ? const ImpeachmentScreen()
      : ImpeachmentProcessListScreen(office: office, kind: kind);
}

Widget _guestPreviewRoute(AuthCubit authCubit, Widget page) =>
    authCubit.state is Guest ? const InteractiveEmptyTabNotice() : page;

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
          location == '/system-preview' ||
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

      if (location == '/login' && authCubit.state is Authenticated) {
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
        path: '/system-preview',
        name: 'system-preview',
        builder: (context, state) => const SystemPreviewPage(),
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
          final draftId =
              args is Map<String, dynamic> ? args['draftId'] as String? : null;
          final identityId =
              args is Map<String, dynamic>
                  ? args['telegramIdentityId'] as String?
                  : null;

          if (phoneNumber == null ||
              phoneNumber.trim().isEmpty ||
              draftId == null ||
              identityId == null) {
            return const ForgotPasswordPhonePage(isRegistration: true);
          }

          return RegistrationNationalCodePage(
            phoneNumber: phoneNumber.trim(),
            draftId: draftId,
            telegramIdentityId: identityId,
          );
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
          final draftId =
              args is Map<String, dynamic> ? args['draftId'] as String? : null;
          final identityId =
              args is Map<String, dynamic>
                  ? args['telegramIdentityId'] as String?
                  : null;

          if (phoneNumber == null ||
              phoneNumber.trim().isEmpty ||
              nationalCode == null ||
              nationalCode.trim().isEmpty ||
              draftId == null ||
              identityId == null) {
            return const ForgotPasswordPhonePage(isRegistration: true);
          }

          return RegistrationGeographyPage(
            phoneNumber: phoneNumber.trim(),
            nationalCode: nationalCode.trim(),
            draftId: draftId,
            telegramIdentityId: identityId,
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
          final draftId = args['draftId'] as String?;
          final identityId = args['telegramIdentityId'] as String?;

          if (phoneNumber == null ||
              phoneNumber.trim().isEmpty ||
              nationalCode == null ||
              nationalCode.trim().isEmpty ||
              countryId == null ||
              provinceId == null ||
              countyId == null ||
              localityId == null ||
              draftId == null ||
              identityId == null) {
            return const ForgotPasswordPhonePage(isRegistration: true);
          }

          return RegistrationPasswordPage(
            phoneNumber: phoneNumber.trim(),
            nationalCode: nationalCode.trim(),
            countryId: countryId,
            provinceId: provinceId,
            countyId: countyId,
            localityId: localityId,
            draftId: draftId,
            telegramIdentityId: identityId,
          );
        },
      ),
      GoRoute(
        path: '/register/success',
        name: 'register-success',
        builder:
            (context, state) => RegistrationSuccessPage(
              biometricMessage:
                  state.extra is String ? state.extra as String : null,
            ),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPhonePage(),
      ),
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
          final draftId = args['registrationDraftId'] as String?;
          final identityId = args['telegramIdentityId'] as String?;
          final otpId = args['otpId'] as String?;

          if (phoneNumber == null || phoneNumber.trim().isEmpty) {
            return const ForgotPasswordPhonePage();
          }

          return OtpVerificationPage(
            phoneNumber: phoneNumber.trim(),
            isPasswordRecovery: isPasswordRecovery,
            isRegistration: isRegistration,
            registrationDraftId: draftId,
            telegramIdentityId: identityId,
            otpId: otpId,
          );
        },
      ),
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
            path: '/about/detail',
            name: 'about-detail',
            builder: (context, state) {
              final section = state.extra;
              return section is AboutSection
                  ? AboutDetailScreen(section: section)
                  : const AboutScreen();
            },
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
            path: '/elections/voting',
            builder: (context, state) => const ElectionVotingHubScreen(),
          ),
          GoRoute(
            path: '/elections/voting/:category',
            builder: (context, state) {
              final category = ElectionCategory.fromCode(
                state.pathParameters['category'],
              );
              return category == null
                  ? const ElectionVotingHubScreen()
                  : ElectionCategoryHubScreen(category: category);
            },
          ),
          GoRoute(
            path: '/elections/voting/:category/scheduled',
            builder:
                (context, state) => _guestPreviewRoute(
                  authCubit,
                  _electionListRoute(state, ElectionListKind.scheduled),
                ),
          ),
          GoRoute(
            path: '/elections/voting/:category/eligible',
            builder:
                (context, state) => _guestPreviewRoute(
                  authCubit,
                  _electionListRoute(state, ElectionListKind.eligible),
                ),
          ),
          GoRoute(
            path: '/elections/voting/:category/live-results',
            builder:
                (context, state) => _guestPreviewRoute(
                  authCubit,
                  _electionListRoute(state, ElectionListKind.live),
                ),
          ),
          GoRoute(
            path: '/elections/voting/:category/final-results',
            builder:
                (context, state) => _guestPreviewRoute(
                  authCubit,
                  _electionListRoute(state, ElectionListKind.finalized),
                ),
          ),
          GoRoute(
            path: '/elections/voting/:category/detail/:processId',
            builder: (context, state) {
              final category = ElectionCategory.fromCode(
                state.pathParameters['category'],
              );
              final processId = int.tryParse(
                state.pathParameters['processId'] ?? '',
              );
              final extra = state.extra;
              final voting = extra is Map && extra['voting'] == true;
              return _guestPreviewRoute(
                authCubit,
                category == null || processId == null
                    ? const ElectionVotingHubScreen()
                    : ElectionVotingDetailScreen(
                      category: category,
                      processId: processId,
                      voting: voting,
                    ),
              );
            },
          ),
          GoRoute(
            path: '/impeachment',
            name: 'impeachment',
            builder: (context, state) => const ImpeachmentScreen(),
          ),
          GoRoute(
            path: '/impeachment/:office',
            builder: (context, state) => _impeachmentOfficeRoute(state),
          ),
          GoRoute(
            path: '/impeachment/:office/request',
            builder: (context, state) {
              final office = ImpeachmentOffice.fromCode(
                state.pathParameters['office'],
              );
              return _guestPreviewRoute(
                authCubit,
                office == null
                    ? const ImpeachmentScreen()
                    : ImpeachmentRequestScreen(office: office),
              );
            },
          ),
          GoRoute(
            path: '/impeachment/:office/supporting',
            builder:
                (context, state) => _guestPreviewRoute(
                  authCubit,
                  _impeachmentListRoute(state, 'supporting'),
                ),
          ),
          GoRoute(
            path: '/impeachment/:office/scheduled',
            builder:
                (context, state) => _guestPreviewRoute(
                  authCubit,
                  _impeachmentListRoute(state, 'scheduled'),
                ),
          ),
          GoRoute(
            path: '/impeachment/:office/eligible',
            builder:
                (context, state) => _guestPreviewRoute(
                  authCubit,
                  _impeachmentListRoute(state, 'eligible'),
                ),
          ),
          GoRoute(
            path: '/impeachment/:office/live',
            builder:
                (context, state) => _guestPreviewRoute(
                  authCubit,
                  _impeachmentListRoute(state, 'live'),
                ),
          ),
          GoRoute(
            path: '/impeachment/:office/finalized',
            builder:
                (context, state) => _guestPreviewRoute(
                  authCubit,
                  _impeachmentListRoute(state, 'finalized'),
                ),
          ),
          GoRoute(
            path: '/impeachment/:office/detail/:processId',
            builder: (context, state) {
              final office = ImpeachmentOffice.fromCode(
                state.pathParameters['office'],
              );
              final id = int.tryParse(state.pathParameters['processId'] ?? '');
              final extra = state.extra;
              final kind =
                  extra is Map && extra['kind'] != null
                      ? extra['kind'].toString()
                      : 'live';
              return _guestPreviewRoute(
                authCubit,
                office == null || id == null
                    ? const ImpeachmentScreen()
                    : ImpeachmentDetailScreen(
                      office: office,
                      processId: id,
                      kind: kind,
                    ),
              );
            },
          ),
          GoRoute(
            path: '/referendum/propose',
            builder:
                (context, state) => _guestPreviewRoute(
                  authCubit,
                  const CivicDetailScreen(
                    title: 'پیشنهاد موضوع برای همه‌پرسی',
                    parentIcon: Icons.how_to_vote_outlined,
                    proposalForm: true,
                    accent: Color(0xFF2E7D32),
                    items: [],
                  ),
                ),
          ),
          GoRoute(
            path: '/referendum/supported',
            builder:
                (context, state) => authCubit.state is Guest
                    ? const InteractiveReferendumSamplesScreen(
                        kind: InteractiveReferendumSampleKind.supporting,
                      )
                    : const ReferendumProposalsScreen(),
          ),
          GoRoute(
            path: '/referendum/supported/:processId',
            builder: (context, state) {
              final processId = int.tryParse(
                state.pathParameters['processId'] ?? '',
              );
              return _guestPreviewRoute(
                authCubit,
                processId == null
                    ? const ReferendumProposalsScreen()
                    : ReferendumProposalDetailScreen(processId: processId),
              );
            },
          ),
          GoRoute(
            path: '/referendum/voting',
            builder: (context, state) => const ReferendumVotingHubScreen(),
          ),
          GoRoute(
            path: '/referendum/voting/scheduled',
            builder:
                (context, state) => authCubit.state is Guest
                    ? const InteractiveReferendumSamplesScreen(
                        kind: InteractiveReferendumSampleKind.scheduled,
                      )
                    : const ReferendumProcessListScreen(
                        kind: ReferendumListKind.scheduled,
                      ),
          ),
          GoRoute(
            path: '/referendum/voting/eligible',
            builder:
                (context, state) => authCubit.state is Guest
                    ? const InteractiveReferendumSamplesScreen(
                        kind: InteractiveReferendumSampleKind.eligible,
                      )
                    : const ReferendumProcessListScreen(
                        kind: ReferendumListKind.eligible,
                      ),
          ),
          GoRoute(
            path: '/referendum/voting/live-results',
            builder:
                (context, state) => authCubit.state is Guest
                    ? const InteractiveReferendumSamplesScreen(
                        kind: InteractiveReferendumSampleKind.liveResults,
                      )
                    : const ReferendumProcessListScreen(
                        kind: ReferendumListKind.liveResults,
                      ),
          ),
          GoRoute(
            path: '/referendum/voting/final-results',
            builder:
                (context, state) => authCubit.state is Guest
                    ? const InteractiveReferendumSamplesScreen(
                        kind: InteractiveReferendumSampleKind.finalResults,
                      )
                    : const ReferendumProcessListScreen(
                        kind: ReferendumListKind.finalResults,
                      ),
          ),
          GoRoute(
            path: '/referendum/voting/detail/:processId',
            builder: (context, state) {
              final processId = int.tryParse(
                state.pathParameters['processId'] ?? '',
              );
              return _guestPreviewRoute(
                authCubit,
                processId == null
                    ? const ReferendumProcessListScreen(
                      kind: ReferendumListKind.liveResults,
                    )
                    : ReferendumVotingDetailScreen(processId: processId),
              );
            },
          ),
          GoRoute(
            path: '/elections/participate',
            builder:
                (context, state) => const CivicDetailScreen(
                  title: 'شرکت در انتخابات',
                  parentIcon: Icons.how_to_vote_rounded,
                  accent: AppTheme.election,
                  items: [
                    CivicDetailItem(
                      title: 'انتخابات ریاست جمهوری',
                      icon: Icons.ballot_outlined,
                    ),
                    CivicDetailItem(
                      title: 'انتخابات استانداری یزد',
                      icon: Icons.ballot_outlined,
                    ),
                    CivicDetailItem(
                      title: 'انتخابات استانداری اصفهان',
                      icon: Icons.ballot_outlined,
                    ),
                    CivicDetailItem(
                      title: 'انتخابات استانداری فارس',
                      icon: Icons.ballot_outlined,
                    ),
                  ],
                ),
          ),
          GoRoute(
            path: '/elections/live',
            builder:
                (context, state) => const CivicDetailScreen(
                  title: 'نتایج زنده انتخابات',
                  parentIcon: Icons.show_chart_rounded,
                  accent: AppTheme.election,
                  items: [
                    CivicDetailItem(
                      title: 'انتخابات ریاست جمهوری',
                      status: 'در حال برگزاری',
                      statusIcon: Icons.sensors_rounded,
                    ),
                  ],
                ),
          ),
          GoRoute(
            path: '/elections/results',
            builder:
                (context, state) => const CivicDetailScreen(
                  title: 'نتایج انتخابات پایان‌یافته',
                  parentIcon: Icons.poll_outlined,
                  accent: AppTheme.election,
                  items: [
                    CivicDetailItem(title: 'انتخابات استانداری یزد'),
                    CivicDetailItem(title: 'انتخابات استانداری اصفهان'),
                    CivicDetailItem(title: 'انتخابات استانداری فارس'),
                  ],
                ),
          ),
        ],
      ),
    ],
  );
}
