import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ورود به سامانه')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'شماره تلفن همراه',
                  hintText: '09123456789',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final phone = _phoneController.text.trim();
                  if (phone.isNotEmpty) {
                    context.push('/otp-verification', extra: phone);
                  }
                },
                child: const Text('دریافت کد تأیید (OTP)'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/login-credentials'),
                child: const Text('ورود با نام کاربری و رمز عبور'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
