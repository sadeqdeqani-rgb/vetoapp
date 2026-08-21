import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

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

  static const _testRegistrationPhone = '09123456789';

  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizePhoneNumber(String value) {
    var phone = value.trim().replaceAll(RegExp(r'[\s-]'), '');

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

    if (!RegExp(r'^09\d{9}$').hasMatch(phone)) {
      return 'شمارهٔ تلفن همراه معتبر نیست.';
    }

    if (widget.isRegistration && phone != _testRegistrationPhone) {
      return 'برای تست ثبت‌نام فقط شمارهٔ ۰۹۱۲۳۴۵۶۷۸۹ قابل استفاده است.';
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
      /// TODO: در اتصال واقعی Backend، درخواست ارسال OTP متناسب با فلو
      /// (ثبت‌نام یا بازیابی رمز) در اینجا فراخوانی می‌شود.
      await Future<void>.delayed(const Duration(milliseconds: 350));

      if (!mounted) {
        return;
      }

      context.push(
        '/otp-verification',
        extra: <String, dynamic>{
          'phoneNumber': phoneNumber,
          'isPasswordRecovery': !widget.isRegistration,
          'isRegistration': widget.isRegistration,
        },
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
                        AppTheme.appLogo,
                        width: 112,
                        height: 112,
                        fit: BoxFit.contain,
                        errorBuilder:
                            (_, __, ___) => Icon(
                              Icons.lock_reset_outlined,
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
                              const Icon(
                                Icons.phone_android_outlined,
                                size: 56,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.isRegistration
                                    ? 'ثبت نام در وِتواَپ'
                                    : 'بازیابی رمز عبور',
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
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(11),
                                  ],
                                  validator: _validatePhoneNumber,
                                  onFieldSubmitted: (_) => _continueToOtp(),
                                  decoration: InputDecoration(
                                    labelText: 'شمارهٔ تلفن همراه',
                                    hintText: '09123456789',
                                    prefixIcon: const Icon(
                                      Icons.phone_outlined,
                                    ),
                                    filled: true,
                                    fillColor: AppTheme.surface.withValues(
                                      alpha: 0.94,
                                    ),
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
                              FilledButton(
                                onPressed: _isLoading ? null : _continueToOtp,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: AppTheme.surface,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
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
                                        : const Text('ارسال کد تأیید'),
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
