import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/validation/digit_normalizer.dart';
import '../../../../core/validation/iranian_mobile_input_formatter.dart';
import '../../../../core/validation/iranian_mobile_number.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/registration_session.dart';
import '../../domain/repositories/registration_repository.dart';
import '../../domain/entities/otp_challenge.dart';
import '../../domain/repositories/telegram_password_recovery_repository.dart';
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
  bool _waitingForTelegram = false;
  RegistrationSession? _registrationSession;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizePhoneNumber(String value) {
    return normalizeIranianMobileNumber(value);
  }

  String? _validatePhoneNumber(String? value) {
    final digits = normalizeDigits(value?.trim() ?? '');
    if (digits.isEmpty) {
      return 'شمارهٔ تلفن همراه را وارد کنید.';
    }

    if (!RegExp(r'^9\d{9}$').hasMatch(digits)) {
      return '۱۰ رقم معتبر شمارهٔ همراه را پس از پیش‌شمارهٔ +۹۸ وارد کنید.';
    }

    return null;
  }

  Future<void> _continueToOtp() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid || _isLoading) {
      return;
    }

    final phoneNumber = _normalizePhoneNumber(_phoneController.text);
    final consented = await _confirmPhoneUse();
    if (!consented || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.isRegistration) {
        await _startRegistrationOtp(phoneNumber);
      } else {
        await _startPasswordRecovery(phoneNumber);
      }
    } catch (error) {
      if (mounted) {
        await showAppMessageDialog<void>(
          context: context,
          message: error.toString().replaceFirst('Exception: ', ''),
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
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _waitingForTelegram = false;
        });
      }
    }
  }

  Future<bool> _confirmPhoneUse() async {
    final isRegistration = widget.isRegistration;
    final result = await showAppMessageDialog<bool>(
      context: context,
      title: isRegistration ? 'تأیید شماره برای ثبت‌نام' : 'بازیابی رمز عبور',
      message:
          isRegistration
              ? 'شماره‌ای که وارد کرده‌اید برای آغاز ثبت‌نام به سرور وتواپ فرستاده می‌شود. اگر این درخواست به تأیید تلگرام نیاز داشته باشد، بات باز می‌شود و فقط با زدن دکمهٔ اشتراک‌گذاری، تلگرام شمارهٔ حساب شما را برای تطبیق به بات می‌فرستد. شماره در حساب ثبت‌نامی شما نگهداری می‌شود و کد یک‌بارمصرف ثبت‌نام در گفت‌وگوی بات ارسال خواهد شد. اگر موافق نیستید، انصراف را بزنید.'
              : 'شماره‌ای که وارد کرده‌اید برای آغاز درخواست بازیابی به سرور وتواپ فرستاده می‌شود. در تلگرام، فرستادن شماره اختیاری است؛ با زدن دکمهٔ اشتراک‌گذاری، شمارهٔ حساب تلگرام برای تطبیق به بات وتواپ می‌رسد و در صورت تأیید، کد یک‌بارمصرف بازیابی در همان گفتگو ارسال می‌شود. برای حفظ حریم خصوصی، نتیجهٔ درخواست اطلاعاتی دربارهٔ وجود حساب افشا نمی‌کند. اگر موافق نیستید، انصراف را بزنید.',
      tone: AppMessageTone.info,
      barrierDismissible: false,
      actions: [
        appDialogButton(
          context,
          label: 'انصراف',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        appDialogButton(
          context,
          label: 'ادامه',
          primary: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    return result ?? false;
  }

  Future<void> _startPasswordRecovery(String phoneNumber) async {
    final repository = getIt<TelegramPasswordRecoveryRepository>();
    final startResult = await repository.start(phoneNumber: phoneNumber);
    final challenge = startResult.fold(
      (failure) => throw Exception(failure.message),
      (value) => value,
    );

    if (!mounted) return;
    setState(() => _waitingForTelegram = true);
    try {
      await _externalChannel.invokeMethod<void>('openUrl', {
        'url': challenge.telegramStartUrl,
      });
    } on PlatformException {
      throw Exception('بازکردن ربات تلگرام ممکن نشد. دوباره تلاش کنید.');
    }

    if (!mounted) return;
    while (mounted && DateTime.now().isBefore(challenge.expiresAt)) {
      final statusResult = await repository.status(nonce: challenge.nonce);
      final recoveryStatus = statusResult.fold(
        (failure) => throw Exception(failure.message),
        (value) => value,
      );

      if (recoveryStatus.state == 'OtpIssued' && recoveryStatus.otpId != null) {
        if (!mounted) return;
        context.push(
          '/otp-verification',
          extra: <String, dynamic>{
            'phoneNumber': phoneNumber,
            'isPasswordRecovery': true,
            'otpId': recoveryStatus.otpId,
          },
        );
        return;
      }

      if (recoveryStatus.state == 'Rejected') {
        if (!mounted) return;
        await showAppMessageDialog<void>(
          context: context,
          message:
              'درخواست از طریق تلگرام تأیید نشد. شمارهٔ واردشده در اپ و شمارهٔ حساب تلگرام را بررسی کنید و اگر لازم است، از اپ درخواست تازه‌ای بسازید.',
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
        return;
      }

      if (!mounted) return;
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    if (mounted) {
      await showAppMessageDialog<void>(
        context: context,
        message:
            'تأیید بازیابی در تلگرام دریافت نشد یا مهلت پیوند تمام شد. دوباره درخواست بازیابی بدهید.',
        tone: AppMessageTone.warning,
        actions: [
          appDialogButton(
            context,
            label: 'متوجه شدم',
            primary: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
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
        await showAppMessageDialog<void>(
          context: context,
          title: 'شماره موبایل ثبت شده است',
          message: failure.message,
          tone: AppMessageTone.warning,
          actions: [
            appDialogButton(
              context,
              label: 'متوجه شدم',
              primary: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
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

    if (!mounted) return;
    setState(() => _waitingForTelegram = true);

    try {
      await _externalChannel.invokeMethod<void>('openUrl', {'url': startUrl});
    } on PlatformException {
      throw Exception('بازکردن بات تلگرام ممکن نشد. لینک بات را بررسی کنید.');
    }

    if (!mounted) return;
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
      await showAppMessageDialog<void>(
        context: context,
        message:
            'تأیید شماره در تلگرام دریافت نشد. اگر مایلید، دوباره تلاش کنید و در بات گزینهٔ «اشتراک‌گذاری شماره برای تأیید» را بزنید.',
        tone: AppMessageTone.warning,
        actions: [
          appDialogButton(
            context,
            label: 'متوجه شدم',
            primary: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      maxWidth: 520,
      onBack: _isLoading && !_waitingForTelegram ? null : () => context.pop(),
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
            showAppMessageDialog<void>(
              context: context,
              message: state.message,
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
                if (_waitingForTelegram && !widget.isRegistration) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'در انتظار تأیید درخواست در ربات تلگرام…',
                    textAlign: TextAlign.center,
                  ),
                ],
                if (widget.isRegistration) ...[
                  const SizedBox(height: 8),
                  Text(
                    _waitingForTelegram
                        ? 'در انتظار تأیید شماره در تلگرام… پس از تأیید، کد به‌طور خودکار ارسال می‌شود.'
                        : 'اگر تأیید تلگرام لازم باشد، اشتراک‌گذاری شماره در بات با انتخاب شما انجام می‌شود.',
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  const Text(
                    'برای بازیابی رمز، شمارهٔ حساب را در بات تلگرام وتواپ به‌صورت اختیاری برای تطبیق بفرستید.',
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
                    textDirection: TextDirection.ltr,
                    inputFormatters: [IranianMobileInputFormatter()],
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
                          : 'دریافت کد از ربات تلگرام',
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
