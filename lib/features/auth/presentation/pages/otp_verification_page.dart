import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../../../core/validation/digit_normalizer.dart';
import '../../domain/entities/otp_challenge.dart';
import '../cubit/otp_cubit.dart';

class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({
    super.key,
    required this.phoneNumber,
    this.isPasswordRecovery = false,
    this.isRegistration = false,
  });

  final String phoneNumber;
  final bool isPasswordRecovery;
  final bool isRegistration;

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  static const _testRegistrationOtp = '123456';

  bool _isLoading = false;
  int _remainingSeconds = 120;
  Timer? _timer;

  bool get _otpComplete => _otpController.text.trim().length == 6;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remainingSeconds = 120);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _remainingSeconds == 0) {
        timer.cancel();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  String? _validateOtp(String? value) {
    final otp = normalizeDigits(value?.trim() ?? '');

    if (otp.isEmpty) {
      return 'کد تأیید را وارد کنید.';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      return 'کد تأیید باید ۶ رقم باشد.';
    }

    if (widget.isRegistration && otp != _testRegistrationOtp) {
      return 'برای تست ثبت‌نام فقط کد ۱۲۳۴۵۶ قابل استفاده است.';
    }

    return null;
  }

  Future<void> _verifyOtp() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await context.read<OtpCubit>().verify(
      phoneNumber: widget.phoneNumber,
      code: normalizeDigits(_otpController.text.trim()),
      purpose:
          widget.isPasswordRecovery
              ? OtpPurpose.passwordRecovery
              : widget.isRegistration
              ? OtpPurpose.registration
              : OtpPurpose.login,
    );
  }

  void _resendOtp() {
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'کد تأیید مجدداً به ${widget.phoneNumber} ارسال خواهد شد.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.isPasswordRecovery
            ? 'تأیید بازیابی رمز'
            : widget.isRegistration
            ? 'تأیید شمارهٔ ثبت‌نام'
            : 'تأیید کد ورود';

    final description =
        widget.isPasswordRecovery
            ? 'کد بازیابی ارسال‌شده به شمارهٔ زیر را وارد کنید.'
            : widget.isRegistration
            ? 'کد تأیید ارسال‌شده به شمارهٔ زیر را وارد کنید.'
            : 'کد تأیید ارسال‌شده به شمارهٔ زیر را وارد کنید.';

    return AuthScaffold(
      maxWidth: 520,
      onBack: _isLoading ? null : () => context.pop(),
      child: BlocListener<OtpCubit, OtpState>(
        listener: (context, state) {
          if (state is OtpVerified) {
            if (widget.isPasswordRecovery) {
              context.push(
                '/forgot-password/reset',
                extra: <String, dynamic>{
                  'phoneNumber': widget.phoneNumber,
                  'verificationToken': state.challenge.verificationToken ?? '',
                },
              );
            } else if (widget.isRegistration) {
              context.push(
                '/register/national-code',
                extra: <String, dynamic>{'phoneNumber': widget.phoneNumber},
              );
            } else {
              context.go('/');
            }
          } else if (state is OtpError && mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: AuthFormCard(
          title: title,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  widget.isPasswordRecovery
                      ? Icons.lock_reset_outlined
                      : Icons.verified_user_outlined,
                  size: 56,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    widget.phoneNumber,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _otpController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]')),
                    LengthLimitingTextInputFormatter(6),
                  ],
                  validator: _validateOtp,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _verifyOtp(),
                  decoration: const InputDecoration(
                    labelText: 'کد تأیید ۶ رقمی',
                    hintText: '123456',
                    counterText: '',
                    prefixIcon: Icon(Icons.password_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'زمان باقی‌مانده: '
                  '${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:'
                  '${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        _remainingSeconds == 0
                            ? AppTheme.danger
                            : AppTheme.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _isLoading ? null : _resendOtp,
                  child: Text(
                    'ارسال مجدد کد',
                    style: TextStyle(color: AppTheme.primary),
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : () => context.pop(),
                  child: Text(
                    'ویرایش شمارهٔ تلفن همراه',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                AuthActionButton(
                  label:
                      widget.isRegistration
                          ? 'تأیید و ادامه ثبت‌نام'
                          : 'تأیید و ادامه',
                  onPressed: _otpComplete && !_isLoading ? _verifyOtp : null,
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
