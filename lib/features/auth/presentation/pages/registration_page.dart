import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/auth_card.dart';

/// مقصد مرحلهٔ بعد از پذیرش قوانین ثبت‌نام.
///
/// فرم کامل ثبت‌نام در گام بعدی این جریان تکمیل می‌شود.
class RegistrationPage extends StatelessWidget {
  const RegistrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBackButton: false,
      child: AuthFormCard(
        title: 'ثبت نام',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'قوانین پذیرفته شد. فرم ثبت‌نام در مرحلهٔ بعدی تکمیل می‌شود.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.pop(),
                child: const Text('بازگشت'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
