import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';

/// صفحهٔ قوانین و مقررات پیش از شروع ثبت‌نام.
class RegistrationTermsPage extends StatefulWidget {
  const RegistrationTermsPage({super.key});

  @override
  State<RegistrationTermsPage> createState() => _RegistrationTermsPageState();
}

class _RegistrationTermsPageState extends State<RegistrationTermsPage> {
  bool _hasAcceptedTerms = false;

  void _continue() {
    if (!_hasAcceptedTerms) {
      return;
    }

    context.pushNamed('register-phone');
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      maxWidth: 520,
      onBack: () => context.pop(),
      child: AuthFormCard(
        title: 'ثبت نام',
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'لطفاً پیش از ادامه، قوانین و مقررات استفاده '
              'از وِتواَپ را مطالعه کنید.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.divider),
              ),
              child: const Text(
                'با ثبت نام متعهد می‌شوید که:\n\n'
                '• سن قانونی کاربر بالای ۱۸ سال است.\n'
                '• از کد ملی و شماره همراه خود برای ثبت نام استفاده کرده‌اید.\n'
                '• مسئولیت اطلاعات ورود به عهده کاربر خواهد بود.\n'
                '• مسئولیت فعالیت‌های انجام‌شده در سامانه به عهده کاربر خواهد بود.',
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.9,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 0),
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                value: _hasAcceptedTerms,
                activeColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                onChanged:
                    (value) =>
                        setState(() => _hasAcceptedTerms = value ?? false),
                title: const Text(
                  'متن شرایط و قوانین را مطالعه کردم '
                  'و موافقم.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AuthActionButton(
              label: 'تأیید و ادامه',
              onPressed: _hasAcceptedTerms ? _continue : null,
            ),
          ],
        ),
      ),
    );
  }
}
