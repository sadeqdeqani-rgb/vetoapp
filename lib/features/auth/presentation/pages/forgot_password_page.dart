import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    required this.phoneNumber,
    required this.verificationToken,
  });

  final String phoneNumber;
  final String verificationToken;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

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
      return 'رمز عبور جدید را وارد کنید.';
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
      return 'تکرار رمز عبور با رمز جدید یکسان نیست.';
    }

    return null;
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid || _isLoading) {
      return;
    }

    if (widget.verificationToken.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('نشست بازیابی رمز معتبر نیست. دوباره تلاش کنید.'),
        ),
      );
      context.go('/forgot-password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      /// TODO: در اتصال به Backend:
      /// AuthCubit.resetPassword(
      ///   phoneNumber: widget.phoneNumber,
      ///   verificationToken: widget.verificationToken,
      ///   newPassword: _passwordController.text,
      /// );
      await Future<void>.delayed(const Duration(milliseconds: 600));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رمز عبور با موفقیت تغییر کرد. اکنون وارد شوید.'),
        ),
      );

      context.go('/login');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                        'assets/images/vetoapp.png',
                        height: 120,
                        fit: BoxFit.contain,
                        errorBuilder:
                            (_, __, ___) => Icon(
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
                                Icons.lock_reset_outlined,
                                size: 56,
                                color: AppTheme.primaryGreen,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'تعیین رمز عبور جدید',
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'برای شمارهٔ ${widget.phoneNumber} یک رمز عبور جدید تعیین کنید.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 28),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                validator: _validatePassword,
                                decoration: InputDecoration(
                                  labelText: 'رمز عبور جدید',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    tooltip:
                                        _obscurePassword
                                            ? 'نمایش رمز'
                                            : 'پنهان کردن رمز',
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
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
                                obscureText: _obscureConfirmation,
                                textInputAction: TextInputAction.done,
                                validator: _validateConfirmation,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'تکرار رمز عبور جدید',
                                  prefixIcon: const Icon(Icons.lock_reset),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    tooltip:
                                        _obscureConfirmation
                                            ? 'نمایش رمز'
                                            : 'پنهان کردن رمز',
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmation =
                                            !_obscureConfirmation;
                                      });
                                    },
                                    icon: Icon(
                                      _obscureConfirmation
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _isLoading ? null : _submit,
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
                                        : const Text('ثبت رمز جدید'),
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
