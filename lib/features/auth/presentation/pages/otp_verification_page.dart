import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

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

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  String? _validateOtp(String? value) {
    final otp = value?.trim() ?? '';

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

    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));

      if (!mounted) {
        return;
      }

      if (widget.isPasswordRecovery) {
        const verificationToken = 'temporary-token-for-ui-test';

        context.push(
          '/forgot-password/reset',
          extra: <String, dynamic>{
            'phoneNumber': widget.phoneNumber,
            'verificationToken': verificationToken,
          },
        );
        return;
      }

      if (widget.isRegistration) {
        context.push(
          '/register/national-code',
          extra: <String, dynamic>{'phoneNumber': widget.phoneNumber},
        );
        return;
      }

      context.go('/');
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تأیید کد با خطا مواجه شد. دوباره تلاش کنید.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resendOtp() {
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

    return Scaffold(
      body: Container(
        decoration: AppTheme.pageBackground,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'بازگشت',
                          onPressed: _isLoading ? null : () => context.pop(),
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Image.asset(
                        'assets/images/vetoapp.png',
                        height: 120,
                        fit: BoxFit.contain,
                        errorBuilder:
                            (_, __, ___) => Icon(
                              Icons.how_to_vote_rounded,
                              size: 90,
                              color: AppTheme.primary,
                            ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.shadow.withValues(alpha: 0.14),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
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
                                title,
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.copyWith(
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
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                validator: _validateOtp,
                                onFieldSubmitted: (_) => _verifyOtp(),
                                decoration: const InputDecoration(
                                  labelText: 'کد تأیید ۶ رقمی',
                                  hintText: '123456',
                                  counterText: '',
                                  prefixIcon: Icon(Icons.password_rounded),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _isLoading ? null : _verifyOtp,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: AppTheme.surface,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child:
                                    _isLoading
                                        ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.surface,
                                          ),
                                        )
                                        : Text(
                                          widget.isPasswordRecovery
                                              ? 'تأیید و ادامه'
                                              : widget.isRegistration
                                              ? 'تأیید و ادامه ثبت‌نام'
                                              : 'تأیید و ورود',
                                        ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _isLoading ? null : _resendOtp,
                                child: Text(
                                  'ارسال مجدد کد',
                                  style: TextStyle(color: AppTheme.primary),
                                ),
                              ),
                              TextButton(
                                onPressed:
                                    _isLoading ? null : () => context.pop(),
                                child: Text(
                                  'ویرایش شمارهٔ تلفن همراه',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
