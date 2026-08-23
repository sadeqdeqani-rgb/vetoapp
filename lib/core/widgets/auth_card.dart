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

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.maxWidth = 520,
    this.showBackButton = true,
    this.onBack,
  });

  final Widget child;
  final double maxWidth;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.pageBackground,
        child: SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                AuthPageHeader(showBackButton: showBackButton, onBack: onBack),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.pageHorizontalPadding,
                      0,
                      AppTheme.pageHorizontalPadding,
                      20,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: child,
                    ),
                  ),
                ),
                const AuthPageFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// هدر ثابت تمام صفحات احراز هویت؛ ارتفاع آن مستقل از محتوای کارت است.
class AuthPageHeader extends StatelessWidget {
  const AuthPageHeader({super.key, this.showBackButton = true, this.onBack});

  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child:
              showBackButton
                  ? Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'بازگشت',
                      onPressed:
                          onBack ?? () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  )
                  : const SizedBox.shrink(),
        ),
        SizedBox(
          height: 160,
          child: Column(
            children: [
              const SizedBox(
                height: AppTheme.authLogoSize,
                child: AuthBrandHeader(),
              ),
              Text('وِتواَپ', style: AppTheme.getTitleStyle(fontSize: 20)),
              const SizedBox(height: 2),
              Text(
                'همه‌پرسی · انتخابات · استیضاح',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.authLogoGap),
      ],
    );
  }
}

class AuthPageFooter extends StatelessWidget {
  const AuthPageFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'VetoApp',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Referendum. Election. Impeachment.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthFormCard extends StatelessWidget {
  const AuthFormCard({
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
      padding: _resolvedPadding,
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.primary,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 20),
          ],
          child,
        ],
      ),
    );
  }

  EdgeInsets get _resolvedPadding {
    if (padding is EdgeInsets) {
      return padding as EdgeInsets;
    }
    return const EdgeInsets.fromLTRB(24, 18, 24, 26);
  }
}

/// سازگاری موقت برای صفحاتی که هنوز در حال انتقال هستند.
class AuthCard extends AuthFormCard {
  const AuthCard({
    super.key,
    required super.child,
    super.title,
    super.maxWidth,
    super.padding,
  });
}

class FloatingAuthTitle extends StatelessWidget {
  const FloatingAuthTitle({
    super.key,
    required this.title,
    this.enabled = true,
    this.onPressed,
  });

  final String title;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppTheme.authHeaderHeight,
      alignment: Alignment.center,
      decoration: AppTheme.authHeaderDecoration.copyWith(
        color: enabled ? AppTheme.primary : AppTheme.primaryLight,
        boxShadow:
            enabled
                ? AppTheme.authHeaderDecoration.boxShadow
                : const <BoxShadow>[],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          child: Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTheme.authHeaderTextStyle.copyWith(
                color: enabled ? AppTheme.surface : AppTheme.textSecondary,
              ),
            ),
          ),
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
            borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
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
