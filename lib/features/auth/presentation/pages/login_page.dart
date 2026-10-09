import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/validation/digit_normalizer.dart';
import '../../../../core/validation/iranian_mobile_number.dart';
import '../../../../core/validation/iranian_mobile_input_formatter.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../../../core/widgets/biometric_device_check_option.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.isPasswordRecovery = false});

  /// false: ورود عادی با OTP
  /// true: شروع فلو فراموشی/بازیابی رمز عبور
  final bool isPasswordRecovery;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  static final _iranPhoneRegex = RegExp(r'^9\d{9}$');

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhoneNumber(String? value) {
    final phoneNumber = normalizeDigits(value?.trim() ?? '');

    if (phoneNumber.isEmpty) {
      return 'شماره تلفن همراه را وارد کنید.';
    }

    if (!_iranPhoneRegex.hasMatch(phoneNumber)) {
      return '۱۰ رقم شمارهٔ همراه را پس از پیش‌شمارهٔ +۹۸ وارد کنید.';
    }

    return null;
  }

  void _requestOtp() {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final phoneNumber = normalizeIranianMobileNumber(_phoneController.text);

    /// در گام بعد، OtpVerificationPage این داده را دریافت می‌کند.
    ///
    /// isPasswordRecovery تعیین می‌کند که:
    /// - بعد از OTP کاربر وارد سامانه شود؛ یا
    /// - به صفحهٔ ثبت رمز جدید هدایت شود.
    context.push(
      '/otp-verification',
      extra: <String, dynamic>{
        'phoneNumber': phoneNumber,
        'isPasswordRecovery': widget.isPasswordRecovery,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPasswordRecovery = widget.isPasswordRecovery;

    return AuthScaffold(
      showBackButton: false,
      child: AuthFormCard(
        title: isPasswordRecovery ? 'بازیابی رمز عبور' : 'ورود',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                isPasswordRecovery
                    ? Icons.lock_reset_outlined
                    : Icons.phone_android_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                isPasswordRecovery
                    ? 'شماره همراه حساب کاربری خود را وارد کنید.'
                    : 'برای ورود، شماره همراه خود را وارد کنید.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 28),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.left,
                  textDirection: TextDirection.ltr,
                  autofocus: true,
                  inputFormatters: [IranianMobileInputFormatter()],
                  validator: _validatePhoneNumber,
                  onFieldSubmitted: (_) => _requestOtp(),
                  decoration: const InputDecoration(
                    labelText: 'شماره تلفن همراه',
                    hintText: '۹xxxxxxxxx',
                    prefixIcon: Icon(Icons.phone_outlined),
                    prefixText: '+۹۸ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AuthActionButton(
                onPressed: _requestOtp,
                label:
                    isPasswordRecovery
                        ? 'دریافت کد بازیابی رمز'
                        : 'دریافت کد تأیید',
              ),
              if (!isPasswordRecovery) ...[
                const SizedBox(height: 12),
                const BiometricDeviceCheckOption(showErrors: true),
              ],

              /// در فلو بازیابی رمز، این لینک ضرورتی ندارد.
              if (!isPasswordRecovery) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    context.push('/login-credentials');
                  },
                  child: const Text('ورود با نام کاربری و رمز عبور'),
                ),
              ],

              /// کاربر در فلو بازیابی بتواند به صفحهٔ ورود
              /// با نام کاربری و رمز برگردد.
              if (isPasswordRecovery) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    context.push('/login-credentials');
                  },
                  child: const Text('بازگشت به صفحهٔ ورود'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
