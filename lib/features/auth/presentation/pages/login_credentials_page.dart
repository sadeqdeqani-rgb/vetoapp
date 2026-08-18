import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/security/screen_protection.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';

class LoginCredentialsPage extends StatefulWidget {
  const LoginCredentialsPage({super.key});

  @override
  State<LoginCredentialsPage> createState() => _LoginCredentialsPageState();
}

class _LoginCredentialsPageState extends State<LoginCredentialsPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    ScreenProtection.enable();
  }

  @override
  void dispose() {
    ScreenProtection.disable();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<LoginCubit>().login(
        phoneNumber: _phoneController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: BlocListener<LoginCubit, LoginState>(
          listener: (context, state) {
            state.mapOrNull(
              success: (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ورود با موفقیت انجام شد.')),
                );
              },
              failure: (failure) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(failure.message),
                      backgroundColor: const Color(0xFFB00020),
                    ),
                  );
              },
            );
          },
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF239F40), Colors.white, Color(0xFFDA0000)],
          stops: [0, 0.45, 1],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 24),
              _buildLogo(),
              const SizedBox(height: 12),
              const Text(
                'به وتو اَپ خوش آمدید',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 32),
              _buildCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Image.asset(
          'assets/images/vetoapp.png',
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.how_to_vote_outlined,
            color: Colors.white,
            size: 48,
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFDA0000), Color(0xFFFF6B6B)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: const Text(
              'ورود به وتو اَپ',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildPhoneField(),
                  const SizedBox(height: 20),
                  _buildPasswordField(),
                  const SizedBox(height: 28),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'شماره موبایل خود را وارد کنید:',
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneController,
          focusNode: _phoneFocus,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: _inputDecoration(),
          onFieldSubmitted: (_) {
            FocusScope.of(context).requestFocus(_passwordFocus);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'شماره موبایل را وارد کنید.';
            }

            if (!RegExp(r'^09\d{9}$').hasMatch(value)) {
              return 'شماره موبایل معتبر نیست.';
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'رمز عبور خود را وارد کنید:',
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          obscureText: _obscurePassword,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          decoration: _inputDecoration().copyWith(
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'نمایش رمز' : 'پنهان کردن رمز',
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
          onFieldSubmitted: (_) => _submit(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'رمز عبور را وارد کنید.';
            }

            if (value.length < 8) {
              return 'رمز عبور باید حداقل ۸ کاراکتر داشته باشد.';
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return BlocBuilder<LoginCubit, LoginState>(
      builder: (context, state) {
        final isLoading = state is LoginLoading;

        return SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDA0000),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0x99DA0000),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'ثبت',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF4F4F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDA0000), width: 1.5),
      ),
    );
  }
}
