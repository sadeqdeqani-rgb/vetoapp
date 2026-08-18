import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';

class GatewayPage extends StatelessWidget {
  const GatewayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // لوگوی رسمی — بالاتر از قبل
                    Center(
                      child: Image.asset(
                        AppTheme.appLogo,
                        width: 130,
                        height: 130,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.account_balance,
                          size: 90,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ۱. ثبت نام
                    GatewayActionButton(
                      title: 'ثبت نام',
                      onTap: () {
                        // TODO: هدایت به صفحه ثبت‌نام
                      },
                    ),
                    const SizedBox(height: 18),

                    // ۲. ورود کاربر
                    GatewayActionButton(
                      title: 'ورود کاربر',
                      onTap: () {
                        // TODO: هدایت به لاگین
                      },
                    ),
                    const SizedBox(height: 18),

                    // ۳. مهمان
                    GatewayActionButton(
                      title: 'مهمان',
                      onTap: () {
                        // TODO: هدایت به صفحه مهمان
                      },
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
  final String title;
  final VoidCallback onTap;

  const GatewayActionButton({
    super.key,
    required this.title,
    required this.onTap,
  });

  @override
  State<GatewayActionButton> createState() => _GatewayActionButtonState();
}

class _GatewayActionButtonState extends State<GatewayActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(28.0);
    final Color buttonColor = _isHovered ? AppTheme.primaryGreen : AppTheme.primaryRed;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: buttonColor.withValues(alpha: 0.35),
              blurRadius: _isHovered ? 14 : 6,
              offset: const Offset(0, 4),
            ),
          ],
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
