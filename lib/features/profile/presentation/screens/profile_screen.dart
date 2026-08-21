import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('حساب کاربری', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppTheme.divider),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.primaryLight,
                    child: Icon(
                      Icons.person_outline,
                      color: AppTheme.primary,
                      size: 32,
                    ),
                  ),
                  SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'کاربر وِتواَپ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'عضو فعال سامانه',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ProfileAction(
              icon: Icons.badge_outlined,
              title: 'اطلاعات حساب',
              subtitle: 'نام، شماره همراه و وضعیت حساب',
            ),
            _ProfileAction(
              icon: Icons.lock_outline_rounded,
              title: 'تغییر رمز عبور',
              subtitle: 'امنیت ورود به سامانه',
            ),
            _ProfileAction(
              icon: Icons.location_on_outlined,
              title: 'موقعیت جغرافیایی',
              subtitle: 'کشور، استان، شهرستان، شهر و روستا',
            ),
            _ProfileAction(
              icon: Icons.manage_accounts_outlined,
              title: 'مدیریت حساب',
              subtitle: 'خروج، حذف یا دریافت اطلاعات',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.logout_rounded),
              label: const Text('خروج از حساب'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () {},
        tileColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.divider),
        ),
        leading: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
        trailing: Icon(icon, color: AppTheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
