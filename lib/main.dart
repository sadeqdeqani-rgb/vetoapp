import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/otp_cubit.dart';
import 'features/auth/presentation/cubit/registration_cubit.dart';
import 'features/profile/presentation/cubit/profile_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  configureDependencies();

  final authCubit = getIt<AuthCubit>();
  await authCubit.checkAuthStatus();

  final appRouter = createAppRouter(authCubit);

  runApp(VetoApp(authCubit: authCubit, appRouter: appRouter));
}

class VetoApp extends StatelessWidget {
  const VetoApp({super.key, required this.authCubit, required this.appRouter});

  final AuthCubit authCubit;
  final GoRouter appRouter;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<OtpCubit>(create: (_) => getIt<OtpCubit>()),
        BlocProvider<RegistrationCubit>(
          create: (_) => getIt<RegistrationCubit>(),
        ),
        BlocProvider<ProfileCubit>(create: (_) => getIt<ProfileCubit>()),
      ],
      child: MaterialApp.router(
          title: 'VetoApp',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: appRouter,
      ),
    );
  }
}
