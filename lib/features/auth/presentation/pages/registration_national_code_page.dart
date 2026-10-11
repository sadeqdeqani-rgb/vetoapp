import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/iranian_date.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../../../core/widgets/app_message_dialog.dart';
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
    return null;
  }

  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final code = IranianNationalCodeValidator.normalize(
      _nationalCodeController.text,
    );
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
        await _showMessage(
          result.fold(
            (failure) => failure.message,
            (_) => 'اعتبارسنجی کد ملی انجام نشد.',
          ),
        );
        return;
      }
      switch (payload['code']) {
        case 'invalid_national_code':
          await _showMessage(
            'این کد ملی نادرست است لطفا کد ملی درست و واقعی وارد کنید',
          );
          return;
        case 'national_code_already_registered':
          await _showMessage(
            'کاربری قبلا با شماره موبایل ${payload['mobile_number'] ?? ''} با این کد ملی در اَپ ثبت نام کرده است.',
          );
          return;
        case 'national_id_area_ineligible':
          await _showAgeEligibilityDialog(code);
          return;
      }
      if (payload['valid'] != true) {
        await _showMessage(
          'این کد ملی نادرست است لطفا کد ملی درست و واقعی وارد کنید',
        );
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

  Future<void> _showMessage(String message) => showAppMessageDialog<void>(
    context: context,
    message: message,
    tone: AppMessageTone.error,
    actions: [
      appDialogButton(
        context,
        label: 'متوجه شدم',
        primary: true,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );

  Future<void> _showAgeEligibilityDialog(String code) async {
    final report = await showAppMessageDialog<bool>(
      context: context,
      message:
          'سامانه شما را زیر ۱۸ سال تشخیص داده است و شما مجاز به ثبت نام نیستید. چنان‌که سامانه در ارزیابی خود خطا کرده باشد، می‌توانید با ارسال کد ملی و تاریخ تولد خود، مشکل خود در ثبت نام را به مدیران سامانه گزارش کنید.',
      tone: AppMessageTone.warning,
      actions: [
        appDialogButton(
          context,
          label: 'متوجه شدم',
          onPressed: () => Navigator.pop(context, false),
        ),
        appDialogButton(
          context,
          label: 'گزارش خطا',
          primary: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (report != true || !mounted) return;
    final dayController = TextEditingController();
    final yearController = TextEditingController();
    int? selectedMonth;
    final submit = await showAppMessageDialog<bool>(
      context: context,
      title: 'گزارش خطای تشخیص سن',
      message: 'کد ملی و تاریخ تولد خود را برای بررسی ارسال کنید.',
      tone: AppMessageTone.info,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            initialValue: code,
            readOnly: true,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(labelText: 'کد ملی'),
          ),
          const SizedBox(height: 14),
          StatefulBuilder(
            builder:
                (context, setDialogState) => Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: dayController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 2,
                        decoration: const InputDecoration(
                          labelText: 'روز',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedMonth,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'ماه'),
                        hint: const Text('انتخاب ماه'),
                        items: [
                          for (var i = 0; i < IranianDate.months.length; i++)
                            DropdownMenuItem(
                              value: i + 1,
                              child: Text(IranianDate.months[i]),
                            ),
                        ],
                        onChanged:
                            (month) =>
                                setDialogState(() => selectedMonth = month),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: yearController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 4,
                        decoration: const InputDecoration(
                          labelText: 'سال',
                          counterText: '',
                        ),
                      ),
                    ),
                  ],
                ),
          ),
        ],
      ),
      actions: [
        appDialogButton(
          context,
          label: 'انصراف',
          onPressed: () => Navigator.pop(context, false),
        ),
        appDialogButton(
          context,
          label: 'ارسال گزارش',
          primary: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (submit == true && mounted) {
      final day = int.tryParse(
        IranianNationalCodeValidator.normalize(dayController.text),
      );
      final year = int.tryParse(
        IranianNationalCodeValidator.normalize(yearController.text),
      );
      final birthDate =
          day == null || year == null || selectedMonth == null
              ? null
              : IranianDate.jalaliToGregorianIso(
                year: year,
                month: selectedMonth!,
                day: day,
              );
      if (birthDate == null) {
        await _showMessage('روز، ماه و سال تولد را به‌درستی انتخاب کنید.');
      } else {
        final result = await getIt<RegistrationRepository>()
            .submitAgeEligibilityReport(
              draftId: widget.draftId,
              nationalCode: code,
              birthDate: birthDate,
            );
        if (!mounted) return;
        await _showMessage(
          result.fold(
            (failure) => failure.message,
            (_) => 'گزارش شما ثبت شد و برای بررسی به مدیران سامانه ارسال شد.',
          ),
        );
      }
    }
    dayController.dispose();
    yearController.dispose();
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
