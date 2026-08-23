import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../../../core/validation/digit_normalizer.dart';
import '../../domain/entities/otp_challenge.dart';
import '../cubit/otp_cubit.dart';

/// مرحلهٔ دریافت شمارهٔ تلفن همراه برای بازیابی رمز یا ثبت‌نام.
class ForgotPasswordPhonePage extends StatefulWidget {
  const ForgotPasswordPhonePage({super.key, this.isRegistration = false});

  /// اگر true باشد، صفحه در فلو ثبت‌نام استفاده می‌شود.
  final bool isRegistration;

  @override
  State<ForgotPasswordPhonePage> createState() =>
      _ForgotPasswordPhonePageState();
}

class _ForgotPasswordPhonePageState extends State<ForgotPasswordPhonePage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  static const _testRegistrationPhone = '0912345678';
  static const _legacyTestRegistrationPhone = '09123456789';

  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizePhoneNumber(String value) {
    var phone = normalizeDigits(value.trim()).replaceAll(RegExp(r'[\s-]'), '');

    if (phone.startsWith('+98')) {
      phone = '0${phone.substring(3)}';
    } else if (phone.startsWith('98') && phone.length == 12) {
      phone = '0${phone.substring(2)}';
    }

    return phone;
  }

  String? _validatePhoneNumber(String? value) {
    final phone = _normalizePhoneNumber(value ?? '');

    if (phone.isEmpty) {
      return 'شمارهٔ تلفن همراه را وارد کنید.';
    }

    final isFrontendTestPhone =
        phone == _testRegistrationPhone ||
        phone == _legacyTestRegistrationPhone;
    if (!RegExp(r'^09\d{9}$').hasMatch(phone) &&
        !(widget.isRegistration && isFrontendTestPhone)) {
      return 'شمارهٔ تلفن همراه معتبر نیست.';
    }

    if (widget.isRegistration && !isFrontendTestPhone) {
      return 'برای تست ثبت‌نام فقط شمارهٔ ۰۹۱۲۳۴۵۶۷۸ قابل استفاده است.';
    }

    return null;
  }

  Future<void> _continueToOtp() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid || _isLoading) {
      return;
    }

    final phoneNumber = _normalizePhoneNumber(_phoneController.text);

    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<OtpCubit>().request(
        phoneNumber: phoneNumber,
        purpose:
            widget.isRegistration
                ? OtpPurpose.registration
                : OtpPurpose.passwordRecovery,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      maxWidth: 520,
      onBack: _isLoading ? null : () => context.pop(),
      child: BlocListener<OtpCubit, OtpState>(
        listener: (context, state) {
          if (state is OtpRequested) {
            context.push(
              '/otp-verification',
              extra: <String, dynamic>{
                'phoneNumber': state.challenge.phoneNumber,
                'isPasswordRecovery': !widget.isRegistration,
                'isRegistration': widget.isRegistration,
              },
            );
          } else if (state is OtpError && mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: AuthFormCard(
          title: widget.isRegistration ? 'ثبت نام' : 'بازیابی رمز عبور',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.phone_android_outlined,
                  size: 56,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.isRegistration
                      ? 'برای شروع ثبت‌نام، شمارهٔ تلفن همراه خود را وارد کنید.'
                      : 'شمارهٔ تلفن همراه حساب خود را وارد کنید.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextFormField(
                    controller: _phoneController,
                    enabled: !_isLoading,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.left,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]')),
                      LengthLimitingTextInputFormatter(11),
                    ],
                    validator: _validatePhoneNumber,
                    onFieldSubmitted: (_) => _continueToOtp(),
                    decoration: InputDecoration(
                      labelText: 'شمارهٔ تلفن همراه',
                      hintText: '09123456789',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      filled: true,
                      fillColor: AppTheme.surface.withValues(alpha: 0.94),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppTheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AuthActionButton(
                  label: 'ارسال کد تأیید',
                  onPressed: _continueToOtp,
                  loading: _isLoading,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed:
                      _isLoading
                          ? null
                          : () => context.go(
                            widget.isRegistration
                                ? '/register/terms'
                                : '/login',
                          ),
                  child: Text(
                    widget.isRegistration
                        ? 'بازگشت به قوانین و مقررات'
                        : 'بازگشت به ورود',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
