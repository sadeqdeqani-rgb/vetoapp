import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// پوسته‌ی مشترک صفحات ورود، ثبت‌نام و درگاه احراز هویت.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        AppTheme.appLogo,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder:
            (_, __, ___) => Icon(
              Icons.verified_user_outlined,
              size: size * 0.78,
              color: AppTheme.primary,
            ),
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.child,
    this.title,
    this.maxWidth = 520,
    this.padding = const EdgeInsets.fromLTRB(24, 18, 24, 26),
  });

  final Widget child;
  final String? title;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: padding,
      decoration: AppTheme.authCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Container(
              height: AppTheme.authHeaderHeight,
              alignment: Alignment.center,
              decoration: AppTheme.authHeaderDecoration,
              child: Text(
                title!,
                textAlign: TextAlign.center,
                style: AppTheme.authHeaderTextStyle,
              ),
            ),
            const SizedBox(height: 28),
          ],
          child,
        ],
      ),
    );
  }
}
