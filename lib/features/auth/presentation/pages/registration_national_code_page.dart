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
    return AuthScaffold(
      maxWidth: 520,
      onBack: () => context.pop(),
      child: AuthFormCard(
        title: 'ثبت نام',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'کد ملی خود را وارد کنید',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]')),
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: _validateNationalCode,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _continue(),
                  decoration: InputDecoration(
                    hintText: '۱۱۱۱۱۱۱۱۱۱',
                    counterText: '',
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
    );
  }
}
