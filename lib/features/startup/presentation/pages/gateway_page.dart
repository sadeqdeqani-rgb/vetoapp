import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../../../core/di/injection.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

const _gatewayAccent = AppTheme.primary;
const _gatewayAccentDark = AppTheme.primaryDark;

const _defaultGatewayIntroduction =
    'وتواپ بستری برای پیشنهاد و حمایت از موضوعات همه‌پرسی، مشارکت در انتخابات و درخواست استیضاح است. در نسخهٔ تعاملی می‌توانید با شیوهٔ کار بخش‌های مختلف آشنا شوید و درخواست فعال‌سازی سامانه را ثبت کنید.';

class GatewayPage extends StatefulWidget {
  const GatewayPage({super.key});

  @override
  State<GatewayPage> createState() => _GatewayPageState();
}

class _GatewayPageState extends State<GatewayPage> {
  bool _openingDemo = false;
  bool _introDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showGatewayIntroduction(),
    );
  }

  Future<void> _showGatewayIntroduction() async {
    if (!mounted || _introDialogShown) return;
    var title = 'آشنایی با وتواپ';
    var body = _defaultGatewayIntroduction;
    try {
      final response = await getIt<Dio>().get<Map<String, dynamic>>(
        '/api/v1/home/gateway-introduction',
      );
      final content = response.data?['data'];
      if (content is Map) {
        title =
            content['title']?.toString().trim().isNotEmpty == true
                ? content['title'].toString()
                : title;
        body =
            content['body_text']?.toString().trim().isNotEmpty == true
                ? content['body_text'].toString()
                : body;
      }
    } catch (_) {
      // Keep the introductory notice available when the content endpoint is unreachable.
    }
    if (!mounted) return;
    setState(() => _introDialogShown = true);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(title, textAlign: TextAlign.center),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: Text(body, textAlign: TextAlign.center),
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('متوجه شدم'),
              ),
            ],
          ),
    );
  }

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

  Future<void> _showActivationNotice() => showDialog<void>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text(
            'ثبت‌نام و ورود',
            style: TextStyle(color: _gatewayAccentDark),
          ),
          content: const Text(
            'ثبت‌نام و احراز هویت کاربران هنوز آغاز نشده است. ابتدا گزینهٔ «آشنایی با وتواپ و ثبت درخواست فعالسازی سامانه» را انتخاب کنید و درخواست خود را ثبت کنید.',
            style: TextStyle(fontWeight: FontWeight.w700, height: 1.6),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('متوجه شدم'),
            ),
          ],
        ),
  );

  @override
  Widget build(BuildContext context) => AbsorbPointer(
    absorbing: !_introDialogShown,
    child: AuthScaffold(
      showBackButton: false,
      maxWidth: 520,
      child: AuthFormCard(
        title: 'ورود',
        titleColor: _gatewayAccent,
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
              accent: _gatewayAccent,
              onTap: _showActivationNotice,
            ),
            const SizedBox(height: 12),
            GatewayActionButton(
              title: 'ورود کاربر',
              accent: _gatewayAccent,
              onTap: _showActivationNotice,
            ),
            const SizedBox(height: 12),
            GatewayActionButton(
              title:
                  _openingDemo
                      ? 'در حال ورود...'
                      : 'آشنایی با وتواپ و ثبت درخواست فعالسازی سامانه',
              accent: _gatewayAccent,
              onTap: _openingDemo ? null : _openInteractiveDemo,
            ),
            // مسیر و اسلایدشوهای پیش‌نمایش برای استفادهٔ بعدی نگه داشته شده‌اند:
            // context.pushNamed('system-preview');
          ],
        ),
      ),
    ),
  );
}

class GatewayActionButton extends StatefulWidget {
  const GatewayActionButton({
    super.key,
    required this.title,
    this.accent = AppTheme.primary,
    required this.onTap,
  });
  final String title;
  final Color accent;
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
            ? _gatewayAccentDark
            : widget.accent;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: enabled ? (_) => setState(() => _isHovered = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 52),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Center(
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  maxLines: 3,
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
      ),
    );
  }
}
