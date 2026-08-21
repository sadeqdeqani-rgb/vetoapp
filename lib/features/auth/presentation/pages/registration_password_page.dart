import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

class RegistrationPasswordPage extends StatefulWidget {
  const RegistrationPasswordPage({
    super.key,
    required this.phoneNumber,
    required this.nationalCode,
    required this.countryId,
    required this.provinceId,
    required this.countyId,
    required this.localityId,
  });

  final String phoneNumber;
  final String nationalCode;
  final int countryId;
  final int provinceId;
  final int countyId;
  final int localityId;

  @override
  State<RegistrationPasswordPage> createState() =>
      _RegistrationPasswordPageState();
}

class _RegistrationPasswordPageState extends State<RegistrationPasswordPage> {
  static const _registrationDraftKey = 'registration_draft';

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'رمز عبور خود را وارد کنید.';
    }

    if (password.length < 8) {
      return 'رمز عبور باید حداقل ۸ کاراکتر باشد.';
    }

    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value == null || value.isEmpty) {
      return 'تکرار رمز عبور را وارد کنید.';
    }

    if (value != _passwordController.text) {
      return 'تکرار رمز عبور با رمز عبور یکسان نیست.';
    }

    return null;
  }

  Future<void> _showWelcomeDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryDark],
                        ),
                      ),
                      child: const Text(
                        'خوش آمدید',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      child: Column(
                        children: [
                          const Text(
                            'به وتو اپ خوش آمدید',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.primaryDark,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'پس از این‌که اکثریت مردم ایران درخواست فعال‌سازی '
                            'وتو اپ را خواستند، شما می‌توانید از حق وتو و رأی '
                            'خود استفاده کنید.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.primaryDark,
                              fontSize: 18,
                              height: 1.9,
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primaryRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: const Text(
                                'تأیید و ورود به خانه',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final draft = <String, dynamic>{
        'phoneNumber': widget.phoneNumber,
        'nationalCode': widget.nationalCode,
        'countryId': widget.countryId,
        'provinceId': widget.provinceId,
        'countyId': widget.countyId,
        'localityId': widget.localityId,
        'password': _passwordController.text,
      };

      await _secureStorage.write(
        key: _registrationDraftKey,
        value: jsonEncode(draft),
      );

      if (!mounted) return;

      await _showWelcomeDialog();

      if (!mounted) return;
      context.go('/');
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ذخیرهٔ موقت اطلاعات ثبت‌نام انجام نشد.')),
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
                        height: 120,
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
                        padding: const EdgeInsets.all(24),
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
                              Icon(
                                Icons.lock_outline,
                                size: 56,
                                color: AppTheme.primaryGreen,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'تعیین رمز عبور',
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'برای حساب کاربری خود یک رمز عبور حداقل ۸ کاراکتری تعیین کنید.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 28),
                              TextFormField(
                                controller: _passwordController,
                                enabled: !_isLoading,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                validator: _validatePassword,
                                decoration: InputDecoration(
                                  labelText: 'رمز عبور',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    tooltip:
                                        _obscurePassword
                                            ? 'نمایش رمز'
                                            : 'پنهان کردن رمز',
                                    onPressed: () {
                                      setState(
                                        () =>
                                            _obscurePassword =
                                                !_obscurePassword,
                                      );
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _confirmationController,
                                enabled: !_isLoading,
                                obscureText: _obscureConfirmation,
                                textInputAction: TextInputAction.done,
                                validator: _validateConfirmation,
                                onFieldSubmitted: (_) => _continue(),
                                decoration: InputDecoration(
                                  labelText: 'تکرار رمز عبور',
                                  prefixIcon: const Icon(Icons.lock_reset),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    tooltip:
                                        _obscureConfirmation
                                            ? 'نمایش رمز'
                                            : 'پنهان کردن رمز',
                                    onPressed: () {
                                      setState(
                                        () =>
                                            _obscureConfirmation =
                                                !_obscureConfirmation,
                                      );
                                    },
                                    icon: Icon(
                                      _obscureConfirmation
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'راهنما: رمز عبور باید حداقل ۸ رقم باشد.',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _isLoading ? null : _continue,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
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
                                        : const Text('ثبت رمز و ادامه'),
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
