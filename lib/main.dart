import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/network/auth_session_events.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/auth_state.dart';
import 'features/auth/presentation/cubit/otp_cubit.dart';
import 'features/auth/presentation/cubit/registration_cubit.dart';
import 'features/profile/presentation/cubit/profile_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) usePathUrlStrategy();

  configureDependencies();

  final authCubit = getIt<AuthCubit>();
  getIt<AuthSessionExpiredNotifier>().addListener(authCubit.expireSession);
  await authCubit.checkAuthStatus();
  await _expireSessionAfterLongBackground(authCubit);

  final appRouter = createAppRouter(authCubit);

  runApp(VetoApp(authCubit: authCubit, appRouter: appRouter));
}

const _backgroundedAtStorageKey = 'auth_backgrounded_at_ms';
const _backgroundLogoutDelay = Duration(seconds: 120);

Future<void> _expireSessionAfterLongBackground(AuthCubit authCubit) async {
  final storage = getIt<SecureStorageService>();
  String? savedTimestamp;
  try {
    savedTimestamp = await storage.read(key: _backgroundedAtStorageKey);
  } catch (_) {
    return;
  }

  if (savedTimestamp == null) return;
  final timestamp = int.tryParse(savedTimestamp);
  if (authCubit.state is Authenticated && timestamp != null) {
    final backgroundedAt = DateTime.fromMillisecondsSinceEpoch(
      timestamp,
      isUtc: true,
    );
    final backgroundDuration = DateTime.now().toUtc().difference(
      backgroundedAt,
    );
    if (backgroundDuration >= _backgroundLogoutDelay) {
      try {
        await storage.delete(key: _backgroundedAtStorageKey);
      } catch (_) {
        // Logout still clears the saved user session if marker cleanup fails.
      }
      await authCubit.logout();
      return;
    }
  }

  // Starting the app means it is no longer minimized. Discard an unfinished
  // background interval so it cannot cause a later, unrelated logout.
  try {
    await storage.delete(key: _backgroundedAtStorageKey);
  } catch (_) {
    // Do not prevent app startup if secure storage is temporarily unavailable.
  }
}

class VetoApp extends StatefulWidget {
  const VetoApp({super.key, required this.authCubit, required this.appRouter});

  final AuthCubit authCubit;
  final GoRouter appRouter;

  @override
  State<VetoApp> createState() => _VetoAppState();
}

class _VetoAppState extends State<VetoApp> with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  Timer? _backgroundLogoutTimer;
  Future<void> _backgroundStorageOperation = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _startBackgroundLogoutTimer();
    } else if (state == AppLifecycleState.resumed) {
      _checkBackgroundDuration();
    }
  }

  void _startBackgroundLogoutTimer() {
    if (widget.authCubit.state is! Authenticated || _backgroundedAt != null) {
      return;
    }
    _backgroundedAt = DateTime.now();
    _queueBackgroundTimestampWrite(_backgroundedAt!);
    _backgroundLogoutTimer = Timer(
      _backgroundLogoutDelay,
      _logoutForLongBackground,
    );
  }

  void _checkBackgroundDuration() {
    final backgroundedAt = _backgroundedAt;
    if (backgroundedAt == null) return;
    if (DateTime.now().difference(backgroundedAt) >= _backgroundLogoutDelay) {
      _logoutForLongBackground();
      return;
    }
    _backgroundLogoutTimer?.cancel();
    _backgroundLogoutTimer = null;
    _backgroundedAt = null;
    unawaited(_clearBackgroundTimestamp());
  }

  void _logoutForLongBackground() {
    _backgroundLogoutTimer?.cancel();
    _backgroundLogoutTimer = null;
    _backgroundedAt = null;
    if (widget.authCubit.state is Authenticated) {
      unawaited(() async {
        await _clearBackgroundTimestamp();
        await widget.authCubit.logout();
      }());
    }
  }

  void _queueBackgroundTimestampWrite(DateTime backgroundedAt) {
    final timestamp = '${backgroundedAt.toUtc().millisecondsSinceEpoch}';
    _backgroundStorageOperation = _backgroundStorageOperation
        .catchError((_) {})
        .then(
          (_) => getIt<SecureStorageService>().write(
            key: _backgroundedAtStorageKey,
            value: timestamp,
          ),
        );
  }

  Future<void> _clearBackgroundTimestamp() {
    _backgroundStorageOperation = _backgroundStorageOperation
        .catchError((_) {})
        .then(
          (_) => getIt<SecureStorageService>().delete(
            key: _backgroundedAtStorageKey,
          ),
        );
    return _backgroundStorageOperation.catchError((_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundLogoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: widget.authCubit),
        BlocProvider<OtpCubit>(create: (_) => getIt<OtpCubit>()),
        BlocProvider<RegistrationCubit>(
          create: (_) => getIt<RegistrationCubit>(),
        ),
        BlocProvider<ProfileCubit>(create: (_) => getIt<ProfileCubit>()),
      ],
      child: MaterialApp.router(
        title: 'وِتواَپ',
        debugShowCheckedModeBanner: false,
        showPerformanceOverlay: false,
        checkerboardRasterCacheImages: false,
        checkerboardOffscreenLayers: false,
        theme: AppTheme.light,
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        routerConfig: widget.appRouter,
      ),
    );
  }
}
