import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/biometric_device_check_option.dart';
import '../../../../core/validation/digit_normalizer.dart';
import '../../../../core/validation/iranian_mobile_input_formatter.dart';
import '../../../../core/validation/iranian_mobile_number.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

/// صفحه ورود با شماره موبایل و رمز عبور.
class LoginCredentialsPage extends StatefulWidget {
  const LoginCredentialsPage({super.key});

  @override
  State<LoginCredentialsPage> createState() => _LoginCredentialsPageState();
}

class _LoginCredentialsPageState extends State<LoginCredentialsPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;

  static final RegExp _phoneRegex = RegExp(r'^9\d{9}$');

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final phone = normalizeDigits(value?.trim() ?? '');

    if (phone.isEmpty) {
      return 'شماره موبایل را وارد کنید.';
    }

    if (!_phoneRegex.hasMatch(phone)) {
      return '۱۰ رقم شمارهٔ همراه را پس از پیش‌شمارهٔ +۹۸ وارد کنید.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final password = normalizeDigits(value ?? '');

    if (password.isEmpty) {
      return 'رمز عبور را وارد کنید.';
    }

    if (password.length < 8) {
      return 'رمز عبور باید حداقل ۸ کاراکتر باشد.';
    }

    return null;
  }

  void _submit() {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final phoneNumber = normalizeIranianMobileNumber(_phoneController.text);
    context.read<AuthCubit>().login(
      username: phoneNumber,
      password: normalizeDigits(_passwordController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      maxWidth: 520,
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          state.whenOrNull(
            authenticated: () {
              context.go('/');
            },
            guest: () {
              context.go('/');
            },
            error: (message) {
              showAppMessageDialog<void>(
                context: context,
                message: 'خطا: $message',
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
            },
          );
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final isLoading = state is Loading;
            final textColor = Theme.of(context).colorScheme.onSurface;

            return AuthFormCard(
              title: 'ورود',
              maxWidth: 520,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'شماره همراه و رمز عبور خود را وارد کنید',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: textColor),
                    ),
                    const SizedBox(height: 24),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextFormField(
                        controller: _phoneController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        textAlign: TextAlign.left,
                        textDirection: TextDirection.ltr,
                        inputFormatters: [IranianMobileInputFormatter()],
                        validator: _validatePhone,
                        decoration: InputDecoration(
                          labelText: 'شماره موبایل خود را وارد کنید:',
                          hintText: '۹xxxxxxxxx',
                          prefixText: '+۹۸ ',
                          filled: true,
                          fillColor: AppTheme.surface.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !isLoading,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      textAlign: TextAlign.right,
                      onFieldSubmitted: (_) => _submit(),
                      validator: _validatePassword,
                      decoration: InputDecoration(
                        labelText: 'رمز عبور خود را وارد کنید',
                        filled: true,
                        fillColor: AppTheme.surface.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed:
                            isLoading
                                ? null
                                : () {
                                  context.pushNamed('forgot-password');
                                },
                        style: TextButton.styleFrom(
                          foregroundColor: textColor,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          'فراموشی رمز عبور',
                          style: TextStyle(
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                            decorationThickness: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton(
                        onPressed:
                            isLoading
                                ? null
                                : () {
                                  context.pushNamed('register-terms');
                                },
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          'ثبت نام',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AuthActionButton(
                      label: 'ورود',
                      onPressed: isLoading ? null : _submit,
                      loading: isLoading,
                    ),
                    const SizedBox(height: 12),
                    const BiometricDeviceCheckOption(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
