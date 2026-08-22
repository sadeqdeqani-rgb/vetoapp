import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';
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

  bool get _canContinue =>
      IranianNationalCodeValidator.normalize(
        _nationalCodeController.text,
      ).length ==
      10;

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

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    context.push(
      '/register/geography',
      extra: <String, dynamic>{
        'phoneNumber': widget.phoneNumber,
        'nationalCode': IranianNationalCodeValidator.normalize(
          _nationalCodeController.text,
        ),
      },
    );
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
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const AuthBrandHeader(),
                      const SizedBox(height: AppTheme.authLogoGap),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(24, 52, 24, 24),
                            decoration: BoxDecoration(
                              color: AppTheme.surface.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.shadow.withValues(
                                    alpha: 0.14,
                                  ),
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
                                  const SizedBox(height: 8),
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
                                      enabled: true,
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
                                      onChanged: (_) => setState(() {}),
                                      onFieldSubmitted: (_) => _continue(),
                                      decoration: InputDecoration(
                                        hintText: '۱۱۱۱۱۱۱۱۱۱',
                                        counterText: '',
                                        filled: true,
                                        fillColor:
                                            Theme.of(
                                              context,
                                            ).scaffoldBackgroundColor,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 36),
                                  AuthActionButton(
                                    label: 'بعدی',
                                    onPressed: _canContinue ? _continue : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Positioned(
                            top: -29,
                            left: 24,
                            right: 24,
                            child: FloatingAuthTitle(
                              title: 'ثبت نام در وِتواَپ',
                            ),
                          ),
                        ],
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
