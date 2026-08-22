import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../domain/entities/registration_draft.dart';
import '../cubit/registration_cubit.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _isLoading = false;

  bool get _passwordReady =>
      _passwordController.text.length >= 8 &&
      _confirmationController.text == _passwordController.text;

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
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 36,
              vertical: 36,
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.shadow.withValues(alpha: 0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                clipBehavior: Clip.none,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 36, 24, 14),
                      child: Column(
                        children: [
                          const Text(
                            'به وِتواَپ خوش آمدید',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.primaryDark,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'پس از این‌که اکثریت مردم ایران درخواست فعال‌سازی '
                            'وِتواَپ را خواستند، شما می‌توانید از حق وتو و رأی '
                            'خود استفاده کنید.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.primaryDark,
                              fontSize: 16,
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AuthActionButton(
                            label: 'تأیید و ورود به خانه',
                            onPressed:
                                () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Positioned(
                      top: -29,
                      left: 24,
                      right: 24,
                      child: FloatingAuthTitle(title: 'خوش آمدید'),
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

    await context.read<RegistrationCubit>().save(
      RegistrationDraft(
        phoneNumber: widget.phoneNumber,
        nationalCode: widget.nationalCode,
        countryId: widget.countryId,
        provinceId: widget.provinceId,
        countyId: widget.countyId,
        localityId: widget.localityId,
        password: _passwordController.text,
      ),
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
                  child: BlocListener<RegistrationCubit, RegistrationState>(
                    listener: (context, state) async {
                      if (state is RegistrationSaved && mounted) {
                        setState(() => _isLoading = false);
                        await _showWelcomeDialog();
                        if (context.mounted) context.go('/');
                      } else if (state is RegistrationError && mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(state.message)),
                        );
                      }
                    },
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
                                  Icon(
                                    Icons.lock_outline,
                                    size: 56,
                                    color: AppTheme.primary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'تعیین رمز عبور',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall?.copyWith(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
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
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      labelText: 'رمز عبور',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
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
                                    onChanged: (_) => setState(() {}),
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
                                  Text(
                                    'راهنما: رمز عبور باید حداقل ۸ رقم باشد.',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: AppTheme.textPrimary.withValues(
                                        alpha: 0.54,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  AuthActionButton(
                                    label: 'ثبت رمز و ادامه',
                                    onPressed: _passwordReady ? _continue : null,
                                    loading: _isLoading,
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
      ),
    );
  }
}
