import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../../../core/validation/digit_normalizer.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/registration_session.dart';
import '../../domain/repositories/registration_repository.dart';
import '../../domain/entities/otp_challenge.dart';
import '../cubit/otp_cubit.dart';

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

  static const _externalChannel = MethodChannel('vetoapp/external');

  bool _isLoading = false;
  RegistrationSession? _registrationSession;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizePhoneNumber(String value) {
    var phone = normalizeDigits(
      value.trim(),
    ).replaceAll(RegExp(r'[\s\-()]'), '');

    if (phone.startsWith('0098')) {
      phone = '0${phone.substring(4)}';
    } else if (phone.startsWith('+98')) {
      phone = '0${phone.substring(3)}';
    } else if (phone.startsWith('98') && phone.length == 12) {
      phone = '0${phone.substring(2)}';
    } else if (RegExp(r'^9\d{9}$').hasMatch(phone)) {
      phone = '0$phone';
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
      if (widget.isRegistration) {
        await _startRegistrationOtp(phoneNumber);
      } else {
        await context.read<OtpCubit>().request(
          phoneNumber: phoneNumber,
          purpose: OtpPurpose.passwordRecovery,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startRegistrationOtp(String phoneNumber) async {
    final repository = getIt<RegistrationRepository>();
    var session = _registrationSession;
    if (session == null) {
      final created = await repository.createServerDraft(
        phoneNumber: phoneNumber,
        idempotencyKey: 'app_${DateTime.now().microsecondsSinceEpoch}',
      );
      final failure = created.fold((value) => value, (_) => null);
      if (failure is RegistrationMobileAlreadyRegisteredFailure) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('شماره موبایل ثبت شده است'),
            content: Text(failure.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('متوجه شدم'),
              ),
            ],
          ),
        );

        return;
      }
      if (failure != null) throw Exception(failure.message);
      session = created.fold((_) => null, (value) => value)!;
      _registrationSession = session;
    }

    final previousStatus = await repository.registrationStatus(session);
    if (!mounted) return;
    final previousSession = previousStatus.fold((_) => null, (value) => value);
    if (previousSession?.telegramIdentityId != null) {
      _registrationSession = previousSession;
      await context.read<OtpCubit>().request(
        phoneNumber: phoneNumber,
        purpose: OtpPurpose.registration,
        registrationDraftId: session.draftId,
        telegramIdentityId: previousSession!.telegramIdentityId,
      );
      return;
    }

    final startUrl = session.telegramStartUrl;
    if (startUrl == null || startUrl.isEmpty) {
      throw Exception('نشانی بات روی سرور تنظیم نشده است.');
    }
    try {
      await _externalChannel.invokeMethod<void>('openUrl', {'url': startUrl});
    } on PlatformException {
      throw Exception('بازکردن بات تلگرام ممکن نشد. لینک بات را بررسی کنید.');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'در تلگرام «ارسال شماره موبایل» را بزنید؛ سپس به اپ برگردید.',
        ),
        duration: Duration(seconds: 6),
      ),
    );
    for (var attempt = 0; attempt < 30 && mounted; attempt++) {
      final result = await repository.registrationStatus(session);
      final updated = result.fold((_) => null, (value) => value);
      if (!mounted) return;
      if (updated?.telegramIdentityId != null) {
        _registrationSession = updated;
        await context.read<OtpCubit>().request(
          phoneNumber: phoneNumber,
          purpose: OtpPurpose.registration,
          registrationDraftId: session.draftId,
          telegramIdentityId: updated!.telegramIdentityId,
        );
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تأیید شماره در تلگرام دریافت نشد؛ پس از ارسال Contact دوباره تلاش کنید.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      maxWidth: 520,
      onBack: _isLoading ? null : () => context.pop(),
      child: BlocListener<OtpCubit, OtpState>(
        listener: (context, state) {
          if (state is OtpRequested) {
            context.push(
              '/otp-verification',
              extra: <String, dynamic>{
                'phoneNumber': state.challenge.phoneNumber,
                'isPasswordRecovery': !widget.isRegistration,
                'isRegistration': widget.isRegistration,
                'registrationDraftId': _registrationSession?.draftId,
                'telegramIdentityId': _registrationSession?.telegramIdentityId,
                'otpId': state.challenge.otpId,
              },
            );
          } else if (state is OtpError && mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: AuthFormCard(
          title: widget.isRegistration ? 'ثبت نام' : 'بازیابی رمز عبور',
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
                      ? 'برای شروع ثبت‌نام، شمارهٔ تلفن همراه خود را وارد کنید.'
                      : 'شمارهٔ تلفن همراه حساب خود را وارد کنید.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (widget.isRegistration) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'برای ثبت‌نام، شماره را در بات تلگرام هم تأیید کنید.',
                    textAlign: TextAlign.center,
                  ),
                ],
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
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9۰-۹٠-٩]'),
                      ),
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: _validatePhoneNumber,
                    onFieldSubmitted: (_) => _continueToOtp(),
                    decoration: InputDecoration(
                      labelText: 'شمارهٔ تلفن همراه',
                      prefixText: '+۹۸ ',
                      hintText: '۹xxxxxxxxx',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      filled: true,
                      fillColor: AppTheme.surface.withValues(alpha: 0.94),
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
                AuthActionButton(
                  label:
                      widget.isRegistration
                          ? 'تأیید در تلگرام و دریافت کد'
                          : 'ارسال کد تأیید',
                  onPressed: _continueToOtp,
                  loading: _isLoading,
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
      ),
    );
  }
}
