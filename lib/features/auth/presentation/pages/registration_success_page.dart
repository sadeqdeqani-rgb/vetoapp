import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';

/// صفحهٔ مستقل پایان موفق ثبت‌نام.
class RegistrationSuccessPage extends StatelessWidget {
  const RegistrationSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBackButton: false,
      maxWidth: 520,
      child: AuthFormCard(
        title: 'خوش آمدید',
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ثبت‌نام شما با موفقیت انجام شد.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppTheme.primary),
            ),
            const SizedBox(height: 12),
            const Text(
              'اکنون می‌توانید وارد خانه شوید و از امکانات وِتواَپ استفاده کنید.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AuthActionButton(
              label: 'متوجه شدم',
              onPressed: () => context.go('/'),
            ),
          ],
        ),
      ),
    );
  }
}
