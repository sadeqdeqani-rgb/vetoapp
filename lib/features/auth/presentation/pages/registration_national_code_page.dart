import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/validation/iranian_national_code_validator.dart';

/// مرحلهٔ دریافت کد ملی در فلو ثبت‌نام.
class RegistrationNationalCodePage extends StatefulWidget {
  const RegistrationNationalCodePage({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  State<RegistrationNationalCodePage> createState() =>
      _RegistrationNationalCodePageState();
}

class _RegistrationNationalCodePageState
    extends State<RegistrationNationalCodePage> {
  final _formKey = GlobalKey<FormState>();
  final _nationalCodeController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nationalCodeController.dispose();
    super.dispose();
  }

  String? _validateNationalCode(String? value) {
    final nationalCode = IranianNationalCodeValidator.normalize(value ?? '');

    if (nationalCode.isEmpty) return 'کد ملی خود را وارد کنید.';
    if (!RegExp(r'^\d{10}$').hasMatch(nationalCode)) {
      return 'کد ملی باید ۱۰ رقم باشد.';
    }
    if (!IranianNationalCodeValidator.isValid(
      nationalCode,
      allowTestCode: true,
    )) {
      return 'کد ملی واردشده معتبر نیست.';
    }

    return null;
  }

  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      context.push(
        '/register/geography',
        extra: <String, dynamic>{
          'phoneNumber': widget.phoneNumber,
          'nationalCode': IranianNationalCodeValidator.normalize(
            _nationalCodeController.text,
          ),
        },
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                            (_, __, ___) => const Icon(
                              Icons.how_to_vote_rounded,
                              size: 90,
                              color: AppTheme.primaryGreen,
                            ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
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
                              Container(
                                height: 56,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppTheme.primary,
                                      AppTheme.primaryDark,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: const Text(
                                  'ثبت نام در وتو اپ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 36),
                              Text(
                                'کد ملی خود را وارد کنید',
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  color: AppTheme.primaryDark,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: TextFormField(
                                  controller: _nationalCodeController,
                                  enabled: !_isLoading,
                                  autofocus: true,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  textAlign: TextAlign.center,
                                  maxLength: 10,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9۰-۹٠-٩]'),
                                    ),
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  validator: _validateNationalCode,
                                  onFieldSubmitted: (_) => _continue(),
                                  decoration: InputDecoration(
                                    hintText: '۱۱۱۱۱۱۱۱۱۱',
                                    counterText: '',
                                    filled: true,
                                    fillColor: AppTheme.background,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28),
                                      borderSide: const BorderSide(
                                        color: AppTheme.primaryGreen,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 36),
                              SizedBox(
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _continue,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryRed,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child:
                                      _isLoading
                                          ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : const Text(
                                            'بعدی',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
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
