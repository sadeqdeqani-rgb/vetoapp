import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/validation/digit_normalizer.dart';
import '../../domain/entities/registration_draft.dart';
import '../../data/services/biometric_auth_service.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/registration_cubit.dart';

class RegistrationPasswordPage extends StatefulWidget {
  const RegistrationPasswordPage({
    super.key,
    required this.phoneNumber,
    required this.nationalCode,
    required this.countryId,
    required this.provinceId,
    required this.countyId,
    required this.localityId,
    required this.draftId,
    required this.telegramIdentityId,
  });

  final String phoneNumber;
  final String nationalCode;
  final int countryId;
  final int provinceId;
  final int countyId;
  final int localityId;
  final String draftId;
  final String telegramIdentityId;

  @override
  State<RegistrationPasswordPage> createState() =>
      _RegistrationPasswordPageState();
}

class _RegistrationPasswordPageState extends State<RegistrationPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _isLoading = false;
  bool _skipBiometricSetup = true;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await getIt<BiometricAuthService>().canAuthenticate;
    if (mounted) setState(() => _biometricAvailable = available);
  }

  bool get _passwordReady =>
      normalizeDigits(_passwordController.text).length >= 8 &&
      normalizeDigits(_confirmationController.text) ==
          normalizeDigits(_passwordController.text);

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    final password = normalizeDigits(value ?? '');

    if (password.isEmpty) {
      return 'رمز عبور خود را وارد کنید.';
    }

    if (password.length < 8) {
      return 'رمز عبور باید حداقل ۸ کاراکتر باشد.';
    }

    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value == null || value.isEmpty) {
      return 'تکرار رمز عبور را وارد کنید.';
    }

    if (normalizeDigits(value) != normalizeDigits(_passwordController.text)) {
      return 'تکرار رمز عبور با رمز عبور یکسان نیست.';
    }

    return null;
  }

  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    await context.read<RegistrationCubit>().save(
      RegistrationDraft(
        draftId: widget.draftId,
        telegramIdentityId: widget.telegramIdentityId,
        phoneNumber: widget.phoneNumber,
        nationalCode: widget.nationalCode,
        countryId: widget.countryId,
        provinceId: widget.provinceId,
        countyId: widget.countyId,
        localityId: widget.localityId,
        password: normalizeDigits(_passwordController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      maxWidth: 520,
      onBack: _isLoading ? null : () => context.pop(),
      child: BlocListener<RegistrationCubit, RegistrationState>(
        listener: (context, state) async {
          if (state is RegistrationSaved && mounted) {
            final authCubit = context.read<AuthCubit>();
            final router = GoRouter.of(context);
            setState(() => _isLoading = false);
            String? biometricMessage;
            if (!_skipBiometricSetup) {
              final signedIn = await authCubit.login(
                username: widget.phoneNumber,
                password: normalizeDigits(_passwordController.text),
              );
              if (signedIn) {
                try {
                  await getIt<BiometricAuthService>().enable(
                    widget.phoneNumber,
                  );
                  biometricMessage = 'ورود با اثر انگشت در این دستگاه فعال شد.';
                } catch (_) {
                  biometricMessage =
                      'ثبت‌نام انجام شد، اما فعال‌سازی اثر انگشت کامل نشد. بعداً از بخش کاربری دوباره تلاش کنید.';
                }
              } else {
                biometricMessage =
                    'ثبت‌نام انجام شد، اما ورود بیومتریک تنظیم نشد. با رمز عبور وارد شوید و بعداً از بخش کاربری فعالش کنید.';
              }
            }
            if (mounted) {
              router.go('/register/success', extra: biometricMessage);
            }
          } else if (state is RegistrationError && mounted) {
            setState(() => _isLoading = false);
            showAppMessageDialog<void>(
              context: context,
              message: state.message,
              tone: AppMessageTone.error,
              actions: [
                appDialogButton(
                  context,
                  label: 'متوجه شدم',
                  primary: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          }
        },
        child: AuthFormCard(
          title: 'ثبت نام',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lock_outline, size: 56, color: AppTheme.primary),
                const SizedBox(height: 16),
                Text(
                  'تعیین رمز عبور',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'برای حساب کاربری خود یک رمز عبور حداقل ۸ کاراکتری تعیین کنید.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  validator: _validatePassword,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'رمز عبور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip:
                          _obscurePassword ? 'نمایش رمز' : 'پنهان کردن رمز',
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmationController,
                  enabled: !_isLoading,
                  obscureText: _obscureConfirmation,
                  textInputAction: TextInputAction.done,
                  validator: _validateConfirmation,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _continue(),
                  decoration: InputDecoration(
                    labelText: 'تکرار رمز عبور',
                    prefixIcon: const Icon(Icons.lock_reset),
                    suffixIcon: IconButton(
                      tooltip:
                          _obscureConfirmation ? 'نمایش رمز' : 'پنهان کردن رمز',
                      onPressed: () {
                        setState(
                          () => _obscureConfirmation = !_obscureConfirmation,
                        );
                      },
                      icon: Icon(
                        _obscureConfirmation
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'راهنما: رمز عبور باید حداقل ۸ رقم باشد.',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppTheme.textPrimary.withValues(alpha: 0.54),
                    fontSize: 13,
                  ),
                ),
                if (_biometricAvailable) ...[
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _skipBiometricSetup,
                    onChanged:
                        _isLoading
                            ? null
                            : (value) => setState(
                              () => _skipBiometricSetup = value ?? true,
                            ),
                    title: const Text(
                      'بعداً مشخصات بیومتریک را تعریف می‌کنم',
                      textAlign: TextAlign.right,
                    ),
                    subtitle: const Text(
                      'با برداشتن این تیک، پس از ثبت‌نام ورود با اثر انگشت این گوشی تنظیم می‌شود.',
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                AuthActionButton(
                  label: 'ثبت رمز و ادامه',
                  onPressed: _passwordReady ? _continue : null,
                  loading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
