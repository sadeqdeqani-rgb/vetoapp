import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
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

                      return Form(
                        key: _formKey,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Image.asset(
                                  'assets/images/vetoapp.png',
                                  height: 120,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.verified_user_outlined,
                                      size: 96,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'به وتو آپ خوش آمدید',
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Container(
                                height: 56,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF3D3D),
                                      Color(0xFFFF1478),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'ورود به وتو اپ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
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
                                  labelText: 'شماره موبایل خود را وارد کنید:',
                                  hintText: '09xxxxxxxxx',
                                  filled: true,
                                  fillColor: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.85,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: const BorderSide(
                                      color: AppTheme.primaryColor,
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
                                  fillColor: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.85,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: const BorderSide(
                                      color: AppTheme.primaryColor,
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
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                  ),
                                  child:
                                      isLoading
                                          ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
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
