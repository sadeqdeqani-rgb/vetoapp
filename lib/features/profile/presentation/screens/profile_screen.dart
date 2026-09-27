import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/profile.dart';
import '../cubit/profile_cubit.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedAction = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProfileCubit>().load();
    });
  }

  void _selectPreview(int index) {
    setState(() => _selectedAction = index);
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ProfileCubit, ProfileState>(
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
                  color: AppTheme.profile,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Color(0x33FFFFFF),
                      child: Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'حساب کاربری',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ProfileAction(
                selected: _selectedAction == 0,
                icon: Icons.badge_outlined,
                title: 'اطلاعات حساب',
                subtitle: 'کد ملی و شماره همراه',
                onTap: () {
                  setState(() => _selectedAction = 0);
                  _showAccountDetails(context, profile);
                },
              ),
              _ProfileAction(
                selected: _selectedAction == 1,
                icon: Icons.lock_outline_rounded,
                title: 'تغییر رمز عبور',
                subtitle: 'امنیت ورود به سامانه',
                onTap: () => _selectPreview(1),
              ),
              _ProfileAction(
                selected: _selectedAction == 2,
                icon: Icons.fingerprint_rounded,
                title: 'مشخصات بیومتریک',
                subtitle: 'تعریف و تغییر اثر انگشت کاربر',
                onTap: () {
                  setState(() => _selectedAction = 2);
                  _showBiometricDetails(context);
                },
              ),
              _ProfileAction(
                selected: _selectedAction == 3,
                icon: Icons.location_on_outlined,
                title: 'موقعیت جغرافیایی',
                subtitle: 'کشور، استان، شهرستان، شهر و روستا',
                onTap: () => _selectPreview(3),
              ),
              _ProfileAction(
                selected: _selectedAction == 4,
                icon: Icons.manage_accounts_outlined,
                title: 'مدیریت حساب',
                subtitle: 'بستن حساب',
                onTap: () => _selectPreview(4),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? AppTheme.profile : AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppTheme.profile : AppTheme.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? Colors.white : AppTheme.profile),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: selected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            selected
                                ? Colors.white.withValues(alpha: .9)
                                : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: selected ? Colors.white : AppTheme.profile,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showAccountDetails(BuildContext context, Profile profile) =>
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
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('کد ملی'),
                  subtitle: Text(profile.nationalCode),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('شماره همراه'),
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

void _showBiometricDetails(BuildContext context) => showDialog<void>(
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
