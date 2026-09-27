import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../../../core/validation/iranian_national_code_validator.dart';
import '../../domain/repositories/registration_repository.dart';

/// مرحلهٔ دریافت کد ملی در فلو ثبت‌نام.
class RegistrationNationalCodePage extends StatefulWidget {
  const RegistrationNationalCodePage({
    super.key,
    required this.phoneNumber,
    required this.draftId,
    required this.telegramIdentityId,
  });

  final String phoneNumber;
  final String draftId;
  final String telegramIdentityId;

  @override
  State<RegistrationNationalCodePage> createState() =>
      _RegistrationNationalCodePageState();
}

class _RegistrationNationalCodePageState
    extends State<RegistrationNationalCodePage> {
  final _formKey = GlobalKey<FormState>();
  final _nationalCodeController = TextEditingController();
  bool _isLoading = false;

  bool get _canContinue =>
      IranianNationalCodeValidator.normalize(_nationalCodeController.text)
          .length ==
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
    return null;
  }

  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final code = IranianNationalCodeValidator.normalize(_nationalCodeController.text);
    try {
      final result = await getIt<RegistrationRepository>().validateNationalCode(
        draftId: widget.draftId,
        nationalCode: code,
      );
      if (!mounted) return;
      final payload = result.fold<Map<String, dynamic>?>(
        (failure) => null,
        (value) => value,
      );
      if (payload == null) {
        await _showMessage(result.fold((failure) => failure.message, (_) => 'اعتبارسنجی کد ملی انجام نشد.'));
        return;
      }
      switch (payload['code']) {
        case 'invalid_national_code':
          await _showMessage('این کد ملی نادرست است لطفا کد ملی درست و واقعی وارد کنید');
          return;
        case 'national_code_already_registered':
          await _showMessage('کاربری قبلا با شماره موبایل ${payload['mobile_number'] ?? ''} با این کد ملی در اَپ ثبت نام کرده است.');
          return;
        case 'national_id_area_ineligible':
          await _showAgeEligibilityDialog(code);
          return;
      }
      if (payload['valid'] != true) {
        await _showMessage('این کد ملی نادرست است لطفا کد ملی درست و واقعی وارد کنید');
        return;
      }
      await context.push(
        '/register/geography',
        extra: <String, dynamic>{
          'phoneNumber': widget.phoneNumber,
          'draftId': widget.draftId,
          'telegramIdentityId': widget.telegramIdentityId,
          'nationalCode': code,
        },
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showMessage(String message) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(message, textAlign: TextAlign.center),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('متوجه شدم'))],
    ),
  );

  Future<void> _showAgeEligibilityDialog(String code) async {
    final report = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text('سامانه شما را زیر ۱۸ سال تشخیص داده است و شما مجاز به ثبت نام نیستید. چنان‌که سامانه در ارزیابی خود خطا کرده باشد، می‌توانید با ارسال کد ملی و تاریخ تولد خود، مشکل خود در ثبت نام را به مدیران سامانه گزارش کنید.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('متوجه شدم')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('گزارش خطا')),
        ],
      ),
    );
    if (report != true || !mounted) return;
    final dateController = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('گزارش خطای تشخیص سن'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(initialValue: code, readOnly: true, decoration: const InputDecoration(labelText: 'کد ملی')),
          TextField(controller: dateController, keyboardType: TextInputType.datetime, decoration: const InputDecoration(labelText: 'تاریخ تولد (YYYY-MM-DD)', hintText: '۱۳۸۰-۰۱-۰۱')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('ارسال گزارش')),
        ],
      ),
    );
    if (submit == true && mounted) {
      final birthDate = IranianNationalCodeValidator.normalize(dateController.text);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(birthDate)) {
        await _showMessage('تاریخ تولد را با قالب سال-ماه-روز وارد کنید.');
      } else {
        final result = await getIt<RegistrationRepository>().submitAgeEligibilityReport(
          draftId: widget.draftId,
          nationalCode: code,
          birthDate: birthDate,
        );
        if (!mounted) return;
        await _showMessage(result.fold((failure) => failure.message, (_) => 'گزارش شما ثبت شد و برای بررسی به مدیران سامانه ارسال شد.'));
      }
    }
    dateController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      maxWidth: 520,
      onBack: _isLoading ? null : () => context.pop(),
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
                  enabled: !_isLoading,
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
                onPressed: _canContinue && !_isLoading ? _continue : null,
                loading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
