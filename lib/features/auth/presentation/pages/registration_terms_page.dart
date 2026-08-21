import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

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
    return Scaffold(
      body: Container(
        decoration: AppTheme.pageBackground,
        child: SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'بازگشت',
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        children: [
                          Image.asset(
                            AppTheme.appLogo,
                            width: 112,
                            height: 112,
                            fit: BoxFit.contain,
                            errorBuilder:
                                (_, __, ___) => const Icon(
                                  Icons.how_to_vote_rounded,
                                  size: 96,
                                  color: AppTheme.primaryGreen,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'به وتو اپ خوش آمدید',
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              color: AppTheme.primaryDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.96),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  height: 56,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppTheme.primary,
                                        AppTheme.primaryDark,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: const Text(
                                    'ثبت نام در وتو اپ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'لطفاً پیش از ادامه، قوانین و مقررات استفاده '
                                  'از وتو اپ را مطالعه کنید.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.primaryDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 300,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppTheme.divider),
                                  ),
                                  child: const Text(
                                    'با ثبت‌نام در وتو اپ، می‌پذیرید که اطلاعات '
                                    'واردشده را صحیح و متعلق به خودتان ارائه '
                                    'کنید.\n\n'
                                    'استفاده از برنامه باید مطابق قوانین جاری '
                                    'کشور و با رعایت حقوق سایر کاربران انجام '
                                    'شود. مسئولیت حفظ اطلاعات ورود و هرگونه '
                                    'فعالیت انجام‌شده با حساب کاربری بر عهدهٔ '
                                    'کاربر است.\n\n'
                                    'وتو اپ می‌تواند برای بهبود خدمات، رفع خطا '
                                    'و ارائهٔ قابلیت‌های جدید، برنامه و شرایط '
                                    'استفاده را به‌روزرسانی کند. نسخهٔ جدید '
                                    'قوانین از طریق برنامه اطلاع‌رسانی خواهد شد.',
                                    textAlign: TextAlign.justify,
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.9,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                CheckboxListTile(
                                  value: _hasAcceptedTerms,
                                  activeColor: AppTheme.primaryGreen,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  onChanged:
                                      (value) => setState(
                                        () =>
                                            _hasAcceptedTerms = value ?? false,
                                      ),
                                  title: const Text(
                                    'متن شرایط و قوانین را مطالعه کردم '
                                    'و موافقم.',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed:
                                        _hasAcceptedTerms ? _continue : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      disabledBackgroundColor:
                                          AppTheme.textSecondary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                    ),
                                    child: const Text(
                                      'تأیید و ادامه',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
