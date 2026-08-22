import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// پوسته‌ی مشترک صفحات ورود، ثبت‌نام و درگاه احراز هویت.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key, this.size = AppTheme.authLogoSize});

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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding:
              title == null
                  ? _resolvedPadding
                  : _resolvedPadding.copyWith(top: _resolvedPadding.top + 34),
          decoration: AppTheme.authCardDecoration,
          child: child,
        ),
        if (title != null)
          Positioned(
            top: -29,
            left: 24,
            right: 24,
            child: Container(
              height: AppTheme.authHeaderHeight,
              alignment: Alignment.center,
              decoration: AppTheme.authHeaderDecoration,
              child: Text(
                title!,
                textAlign: TextAlign.center,
                style: AppTheme.authHeaderTextStyle,
              ),
            ),
          ),
      ],
    );
  }

  EdgeInsets get _resolvedPadding {
    if (padding is EdgeInsets) {
      return padding as EdgeInsets;
    }
    return const EdgeInsets.fromLTRB(24, 18, 24, 26);
  }
}

class FloatingAuthTitle extends StatelessWidget {
  const FloatingAuthTitle({
    super.key,
    required this.title,
    this.enabled = true,
  });

  final String title;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppTheme.authHeaderHeight,
      alignment: Alignment.center,
      decoration: AppTheme.authHeaderDecoration.copyWith(
        color:
            enabled
                ? AppTheme.primary
                : AppTheme.pressedTab,
        boxShadow:
            enabled
                ? AppTheme.authHeaderDecoration.boxShadow
                : const <BoxShadow>[],
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: AppTheme.authHeaderTextStyle.copyWith(
          color: enabled ? AppTheme.surface : AppTheme.textSecondary,
        ),
      ),
    );
  }
}

/// دکمهٔ اصلی مشترک در تمام مراحل فلوهای احراز هویت.
///
/// ارتفاع و شعاع این دکمه با عنوان شناور کارت یکسان است تا اجزای فلو
/// در همهٔ صفحات هم‌اندازه و هم‌تراز دیده شوند.
class AuthActionButton extends StatelessWidget {
  const AuthActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppTheme.authHeaderHeight,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: AppTheme.surface,
          disabledBackgroundColor: AppTheme.textSecondary,
          disabledForegroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppTheme.authHeaderHeight / 2,
            ),
          ),
        ),
        child:
            loading
                ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.surface,
                  ),
                )
                : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
      ),
    );
  }
}
