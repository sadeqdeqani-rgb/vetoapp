import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../cubit/profile_cubit.dart';
import '../../domain/entities/profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProfileCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final profile =
            state is ProfileLoaded
                ? state.profile
                : const Profile(
                  nationalCode: 'در حال بارگذاری',
                  phoneNumber: 'در حال بارگذاری',
                );

        return Directionality(
          textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Text(
              'حساب کاربری',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 23,
                color: AppTheme.profile,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppTheme.profile.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.profile.withValues(alpha: 0.14),
                    child: const Icon(
                      Icons.person_outline,
                      color: AppTheme.profile,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'حساب کاربری',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ProfileAction(
              icon: Icons.badge_outlined,
              title: 'اطلاعات حساب',
              subtitle: 'کد ملی و شماره همراه',
              onTap: () => _showAccountDetails(context, profile),
            ),
            _ProfileAction(
              icon: Icons.lock_outline_rounded,
              title: 'تغییر رمز عبور',
              subtitle: 'امنیت ورود به سامانه',
            ),
            _ProfileAction(
              icon: Icons.fingerprint_rounded,
              title: 'مشخصات بیومتریک',
              subtitle: 'تعریف و تغییر اثر انگشت کاربر',
              onTap: () => _showBiometricDetails(context),
            ),
            _ProfileAction(
              icon: Icons.location_on_outlined,
              title: 'موقعیت جغرافیایی',
              subtitle: 'کشور، استان، شهرستان، شهر و روستا',
            ),
            _ProfileAction(
              icon: Icons.manage_accounts_outlined,
              title: 'مدیریت حساب',
              subtitle: 'بستن حساب',
            ),
            ],
          ),
          ),
        );
      },
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        tileColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.divider),
        ),
        leading: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
        trailing: Icon(icon, color: AppTheme.profile),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

void _showAccountDetails(BuildContext context, Profile profile) {
  showDialog<void>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('اطلاعات حساب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.badge_outlined),
                title: Text('کد ملی'),
                subtitle: Text(profile.nationalCode),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.phone_outlined),
                title: Text('شماره همراه'),
                subtitle: Text(profile.phoneNumber),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('بستن'),
            ),
          ],
        ),
  );
}

void _showBiometricDetails(BuildContext context) {
  showDialog<void>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('مشخصات بیومتریک'),
          content: const Text(
            'برای تعریف یا تغییر اثر انگشت کاربر، ابتدا دسترسی احراز هویت دستگاه را فعال کنید.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('بستن'),
            ),
          ],
        ),
  );
}
