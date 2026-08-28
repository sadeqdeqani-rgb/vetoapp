import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';
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
        content: Text('ورود به حالت مشاهده محیط سامانه انجام نشد. دوباره تلاش کنید.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBackButton: false,
      maxWidth: 520,
      child: AuthFormCard(
        title: 'ورود',
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'برای ادامه، روش ورود خود را انتخاب کنید',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            GatewayActionButton(
              title: 'ثبت نام',
              onTap:
                  _isContinuingAsGuest
                      ? null
                      : () => context.pushNamed('register-terms'),
            ),
            const SizedBox(height: 12),
            GatewayActionButton(
              title: 'ورود کاربر',
              onTap: _isContinuingAsGuest ? null : () => context.go('/login'),
            ),
            const SizedBox(height: 12),
            GatewayActionButton(
              title:
                  _isContinuingAsGuest
                      ? 'در حال ورود...'
                      : 'مشاهده محیط سامانه',
              onTap: _isContinuingAsGuest ? null : _continueAsGuest,
            ),
          ],
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
    final borderRadius = BorderRadius.circular(AppTheme.buttonRadius);
    final isEnabled = widget.onTap != null;

    final Color buttonColor =
        !isEnabled
            ? AppTheme.divider
            : _isHovered
            ? AppTheme.primaryDark
            : AppTheme.primary;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
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
                  color: AppTheme.surface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
