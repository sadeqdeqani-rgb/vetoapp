import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class LoginCredentialsPage extends StatefulWidget {
  const LoginCredentialsPage({super.key});

  @override
  State<LoginCredentialsPage> createState() => _LoginCredentialsPageState();
}

class _LoginCredentialsPageState extends State<LoginCredentialsPage> {
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ورود')),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          state.whenOrNull(
            authenticated: () {
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

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'نام کاربری',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'رمز عبور',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              context.read<AuthCubit>().login(
                                    username: _usernameController.text,
                                    password: _passwordController.text,
                                  );
                            },
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('ورود'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              context.read<AuthCubit>().continueAsGuest();
                            },
                      child: const Text('ادامه به‌عنوان مهمان'),
                    ),
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
