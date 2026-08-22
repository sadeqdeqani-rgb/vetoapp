import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';

/// مقصد مرحلهٔ بعد از پذیرش قوانین ثبت‌نام.
///
/// فرم کامل ثبت‌نام در گام بعدی این جریان تکمیل می‌شود.
class RegistrationPage extends StatelessWidget {
  const RegistrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.pageBackground,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AuthBrandHeader(),
                      const SizedBox(height: AppTheme.authLogoGap),
                      AuthCard(
                        title: 'ثبت نام در وِتواَپ',
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'قوانین پذیرفته شد. فرم ثبت‌نام در مرحلهٔ بعدی '
                              'تکمیل می‌شود.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () => context.pop(),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                ),
                                child: const Text('بازگشت'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
