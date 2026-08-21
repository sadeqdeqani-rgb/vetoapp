import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';
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

  static final RegExp _phoneRegex = RegExp(r'^09\d{9}$');

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
    final phone = value?.trim() ?? '';

    if (phone.isEmpty) {
      return 'شماره موبایل را وارد کنید.';
    }

    if (!_phoneRegex.hasMatch(phone)) {
      return 'شماره موبایل باید ۱۱ رقم و با 09 شروع شود.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

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

    context.read<AuthCubit>().login(
      username: _phoneController.text.trim(),
      password: _passwordController.text,
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
              child: Directionality(
                textDirection: TextDirection.rtl,
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطا: $message')),
                        );
                      },
                    );
                  },
                  child: BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is Loading;
                      final textColor = Theme.of(context).colorScheme.onSurface;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AuthBrandHeader(),
                          const SizedBox(height: 18),
                          AuthCard(
                            title: 'ورود به وتو اپ',
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: textColor),
                                  ),
                                  const SizedBox(height: 24),
                                  TextFormField(
                                    controller: _phoneController,
                                    enabled: !isLoading,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                    textAlign: TextAlign.right,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(11),
                                    ],
                                    validator: _validatePhone,
                                    decoration: InputDecoration(
                                      labelText:
                                          'شماره موبایل خود را وارد کنید:',
                                      hintText: '09xxxxxxxxx',
                                      filled: true,
                                      fillColor: AppTheme.surface.withValues(
                                        alpha: 0.85,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        borderSide: const BorderSide(
                                          color: AppTheme.primary,
                                          width: 2,
                                        ),
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
                                      fillColor: AppTheme.surface.withValues(
                                        alpha: 0.85,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        borderSide: const BorderSide(
                                          color: AppTheme.primary,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Center(
                                    child: TextButton(
                                      onPressed:
                                          isLoading
                                              ? null
                                              : () {
                                                context.pushNamed(
                                                  'forgot-password',
                                                );
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
                                                context.pushNamed(
                                                  'register-terms',
                                                );
                                              },
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.primary,
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: const Text(
                                        'ثبت نام در وتو اپ',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: isLoading ? null : _submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: AppTheme.surface,
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            26,
                                          ),
                                        ),
                                      ),
                                      child:
                                          isLoading
                                              ? const SizedBox(
                                                height: 24,
                                                width: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: AppTheme.surface,
                                                      strokeWidth: 2.5,
                                                    ),
                                              )
                                              : const Text(
                                                'ثبت',
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
                      );
                    },
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
