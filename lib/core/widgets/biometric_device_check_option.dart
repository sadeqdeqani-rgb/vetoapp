import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/data/services/biometric_auth_service.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';
import '../di/injection.dart';
import '../theme/app_theme.dart';

class BiometricDeviceCheckOption extends StatefulWidget {
  const BiometricDeviceCheckOption({super.key, this.showErrors = false});

  final bool showErrors;

  @override
  State<BiometricDeviceCheckOption> createState() =>
      _BiometricDeviceCheckOptionState();
}

class _BiometricDeviceCheckOptionState
    extends State<BiometricDeviceCheckOption> {
  bool? _configured;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    try {
      final configured =
          await getIt<BiometricAuthService>().isConfiguredLocally;
      if (mounted) setState(() => _configured = configured);
    } catch (_) {
      if (mounted) setState(() => _configured = false);
    }
  }

  Future<void> _login() async {
    final success = await context.read<AuthCubit>().loginWithBiometrics();
    if (!mounted || success || !widget.showErrors) return;
    final message = context.read<AuthCubit>().state.whenOrNull(
      error: (value) => value,
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message ?? 'ورود بیومتریک انجام نشد.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final isLoading = state is Loading || _configured == null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: isLoading || _configured != true ? null : _login,
              icon:
                  isLoading
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.fingerprint_rounded),
              label: Text(
                _configured == true
                    ? 'ورود با اثر انگشت'
                    : _configured == null
                    ? 'در حال بررسی ورود بیومتریک'
                    : 'ورود با اثر انگشت فعال نشده است',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            if (_configured == false) ...[
              const SizedBox(height: 6),
              Text(
                'پس از ورود، از بخش «مشخصات بیومتریک» آن را برای این دستگاه فعال کنید.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        );
      },
    );
  }
}
