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
  bool _openingDemo = false;

  Future<void> _openInteractiveDemo() async {
    if (_openingDemo) return;
    setState(() => _openingDemo = true);
    await context.read<AuthCubit>().continueAsGuest();
    if (!mounted) return;
    if (context.read<AuthCubit>().state is Guest) {
      context.go('/');
      return;
    }
    setState(() => _openingDemo = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ورود به محیط تعاملی انجام نشد. دوباره تلاش کنید.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
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
            onTap: () => context.pushNamed('register-terms'),
          ),
          const SizedBox(height: 12),
          GatewayActionButton(
            title: 'ورود کاربر',
            onTap: () => context.go('/login'),
          ),
          const SizedBox(height: 12),
          GatewayActionButton(
            title: _openingDemo ? 'در حال ورود...' : 'مشاهده محیط سامانه',
            onTap: _openingDemo ? null : _openInteractiveDemo,
          ),
          // مسیر و اسلایدشوهای پیش‌نمایش برای استفادهٔ بعدی نگه داشته شده‌اند:
          // context.pushNamed('system-preview');
        ],
      ),
    ),
  );
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
    final enabled = widget.onTap != null;
    final color =
        !enabled
            ? AppTheme.divider
            : _isHovered
            ? AppTheme.primaryDark
            : AppTheme.primary;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: enabled ? (_) => setState(() => _isHovered = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: borderRadius,
          boxShadow:
              enabled
                  ? [
                    BoxShadow(
                      color: color.withValues(alpha: .35),
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
