import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

class GatewayPage extends StatefulWidget {
  const GatewayPage({super.key});

  @override
  State<GatewayPage> createState() => _GatewayPageState();
}

class _GatewayPageState extends State<GatewayPage> {
  bool _isContinuingAsGuest = false;

  Future<void> _continueAsGuest() async {
    if (_isContinuingAsGuest) {
      return;
    }

    setState(() => _isContinuingAsGuest = true);

    await context.read<AuthCubit>().continueAsGuest();

    if (!mounted) {
      return;
    }
    final succeeded = context.read<AuthCubit>().state is Guest;

    if (succeeded) {
      context.go('/');
      return;
    }

    setState(() => _isContinuingAsGuest = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ورود به حالت مهمان انجام نشد. دوباره تلاش کنید.'),
      ),
    );
  }

  void _showRegistrationMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('بخش ثبت‌نام هنوز در حال توسعه است.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        AppTheme.appLogo,
                        width: 130,
                        height: 130,
                        fit: BoxFit.contain,
                        errorBuilder:
                            (context, error, stackTrace) => const Icon(
                              Icons.account_balance,
                              size: 90,
                              color: AppTheme.primaryDark,
                            ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    GatewayActionButton(
                      title: 'ثبت نام',
                      onTap:
                          _isContinuingAsGuest
                              ? null
                              : _showRegistrationMessage,
                    ),
                    const SizedBox(height: 18),
                    GatewayActionButton(
                      title: 'ورود کاربر',
                      onTap:
                          _isContinuingAsGuest
                              ? null
                              : () => context.go('/login'),
                    ),
                    const SizedBox(height: 18),
                    GatewayActionButton(
                      title: _isContinuingAsGuest ? 'در حال ورود...' : 'مهمان',
                      onTap: _isContinuingAsGuest ? null : _continueAsGuest,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GatewayActionButton extends StatefulWidget {
  const GatewayActionButton({
    super.key,
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback? onTap;

  @override
  State<GatewayActionButton> createState() => _GatewayActionButtonState();
}

class _GatewayActionButtonState extends State<GatewayActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(28.0);
    final isEnabled = widget.onTap != null;

    final Color buttonColor =
        !isEnabled
            ? AppTheme.primaryRed.withValues(alpha: 0.45)
            : _isHovered
            ? AppTheme.primaryGreen
            : AppTheme.primaryRed;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: borderRadius,
          boxShadow:
              isEnabled
                  ? [
                    BoxShadow(
                      color: buttonColor.withValues(alpha: 0.35),
                      blurRadius: _isHovered ? 14 : 6,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: widget.onTap,
            child: Center(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
