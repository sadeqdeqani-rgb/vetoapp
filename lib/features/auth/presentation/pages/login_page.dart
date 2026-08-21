import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/auth_card.dart';

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

  static final _iranPhoneRegex = RegExp(r'^09\d{9}$');

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhoneNumber(String? value) {
    final phoneNumber = value?.trim() ?? '';

    if (phoneNumber.isEmpty) {
      return 'شماره تلفن همراه را وارد کنید.';
    }

    if (!_iranPhoneRegex.hasMatch(phoneNumber)) {
      return 'شماره موبایل باید ۱۱ رقم و با 09 شروع شود.';
    }

    return null;
  }

  void _requestOtp() {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final phoneNumber = _phoneController.text.trim();

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

    return Scaffold(
      appBar: AppBar(
        title: Text(isPasswordRecovery ? 'بازیابی رمز عبور' : 'ورود به سامانه'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: AuthCard(
                  title:
                      isPasswordRecovery
                          ? 'بازیابی رمز عبور'
                          : 'ورود به وِتواَپ',
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
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          textAlign: TextAlign.left,
                          autofocus: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          validator: _validatePhoneNumber,
                          onFieldSubmitted: (_) => _requestOtp(),
                          decoration: const InputDecoration(
                            labelText: 'شماره تلفن همراه',
                            hintText: '09123456789',
                            prefixIcon: Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _requestOtp,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              isPasswordRecovery
                                  ? 'دریافت کد بازیابی رمز'
                                  : 'دریافت کد تأیید',
                            ),
                          ),
                        ),

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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
