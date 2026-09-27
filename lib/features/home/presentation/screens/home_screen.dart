import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isGuest = context.select<AuthCubit, bool>(
      (cubit) => cubit.state is Guest,
    );
    return isGuest ? const _PreviewHomeScreen() : const _ServerHomeScreen();
  }
}

class _ServerHomeScreen extends StatefulWidget {
  const _ServerHomeScreen();

  @override
  State<_ServerHomeScreen> createState() => _ServerHomeScreenState();
}

class _ServerHomeScreenState extends State<_ServerHomeScreen> {
  late Future<Map<String, dynamic>> _summary;

  @override
  void initState() {
    super.initState();
    _summary = _loadSummary();
  }

  Future<Map<String, dynamic>> _loadSummary() async {
    final response = await getIt<Dio>().get<Map<String, dynamic>>(
      '/api/v1/dashboard/summary',
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('پاسخ نمای کلی سامانه معتبر نیست.');
    }
    return data;
  }

  String _persianNumber(Object? value) {
    final text = (value is num ? value.toInt() : 0).toString();
    final grouped = text.replaceAllMapped(
      RegExp(r'(?=(\d{3})+(?!\d))'),
      (_) => '٬',
    );
    return grouped.replaceAllMapped(RegExp(r'\d'), (match) {
      return String.fromCharCode(match.group(0)!.codeUnitAt(0) + 1728);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: () async => setState(() => _summary = _loadSummary()),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text('نمای کلی سامانه', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, dynamic>>(
              future: _summary,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return _ServerDashboardCard(
                    icon: Icons.cloud_off_outlined,
                    title: 'دریافت آمار از سرور انجام نشد',
                    message: 'اتصال را بررسی کنید و صفحه را دوباره به‌روزرسانی کنید.',
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _summary = _loadSummary()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('تلاش دوباره'),
                    ),
                  );
                }
                return _ServerDashboardCard(
                  icon: Icons.people_alt_outlined,
                  title: 'کاربران فعال ثبت‌نام‌شده',
                  message: '${_persianNumber(snapshot.data!['active_user_count'])} نفر',
                  child: const SizedBox.shrink(),
                );
              },
            ),
            const SizedBox(height: 14),
            const _ServerDashboardCard(
              icon: Icons.info_outline_rounded,
              title: 'همه‌پرسی، انتخابات و استیضاح',
              message:
                  'اطلاعات رویدادهای زنده هنوز در سرویس سرور ثبت و ارائه نمی‌شود. با آماده‌شدن این بخش، رویدادهای واقعی همین‌جا نمایش داده می‌شوند.',
              child: SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerDashboardCard extends StatelessWidget {
  const _ServerDashboardCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(message, style: Theme.of(context).textTheme.bodyLarge),
        if (child is! SizedBox) ...[const SizedBox(height: 12), child],
      ],
    ),
  );
}

class _PreviewHomeScreen extends StatefulWidget {
  const _PreviewHomeScreen();

  @override
  State<_PreviewHomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_PreviewHomeScreen> {
  final _random = Random();
  late final String _countryCount;
  late final Map<String, String> _provinceCounts;
  late final Map<String, String> _countyCounts;
  late final Map<String, String> _settlementCounts;
  String _province = 'اصفهان';

  static const _counties = {
    'اصفهان': 'شهرضا',
    'فارس': 'نورآباد ممسنی',
    'یزد': 'یزد',
  };
  static const _settlements = {
    'اصفهان': 'منظریه',
    'فارس': 'دهگپ محمودی',
    'یزد': 'یزد',
  };

  @override
  void initState() {
    super.initState();
    _countryCount = _number(10000, 90000);
    _provinceCounts = {
      'اصفهان': _number(900, 9000),
      'فارس': _number(900, 9000),
      'یزد': _number(900, 9000),
    };
    _countyCounts = {
      'اصفهان': _number(120, 2200),
      'فارس': _number(120, 2200),
      'یزد': _number(120, 2200),
    };
    _settlementCounts = {
      'اصفهان': _number(20, 900),
      'فارس': _number(20, 900),
      'یزد': _number(20, 900),
    };
  }

  String _number(int min, int max) => (min + _random.nextInt(max - min))
      .toString()
      .replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (_) => '٬');

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SystemIntroduction(),
            const SizedBox(height: 16),
            const _UserCountCard(),
            const SizedBox(height: 12),
            _LocationFilter(
              province: _province,
              countryCount: '$_countryCount نفر',
              provinceCount: '${_provinceCounts[_province]} نفر',
              countyCount: '${_countyCounts[_province]} نفر',
              settlementCount: '${_settlementCounts[_province]} نفر',
              county: _counties[_province]!,
              settlement: _settlements[_province]!,
              onProvinceChanged: (value) {
                if (value != null) setState(() => _province = value);
              },
            ),
            const SizedBox(height: 20),
            Text(
              'آخرین رویدادهای وِتواَپ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const _ActivityRow(
              icon: Icons.how_to_vote_outlined,
              title: '۳ همه‌پرسی در حال برگزاری',
              color: AppTheme.success,
            ),
            const SizedBox(height: 10),
            const _ActivityRow(
              icon: Icons.ballot_outlined,
              title: '۲ انتخابات در حال رأی‌گیری',
              color: AppTheme.election,
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemIntroduction extends StatelessWidget {
  const _SystemIntroduction();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'معرفی سامانه',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 6),
        const Text(
          'برای آشنایی با هدف و سازندگان سامانه، یکی از بخش‌های زیر را انتخاب کنید.',
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => context.go('/about?tab=goals'),
          icon: const Icon(Icons.flag_outlined),
          label: const Text('اهداف سامانه'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.go('/about?tab=creators'),
          icon: const Icon(Icons.people_outline_rounded),
          label: const Text('سازندگان سامانه'),
        ),
      ],
    ),
  );
}

class _UserCountCard extends StatelessWidget {
  const _UserCountCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppTheme.primary, AppTheme.primaryDark],
      ),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Row(
      children: [
        const Icon(Icons.people_alt_outlined, color: Colors.white, size: 30),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تعداد کاربران مورد نیاز برای فعال شدن بخش همه پرسی:',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                '۴۴۰۰۰۰۰۰ نفر',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LocationFilter extends StatelessWidget {
  const _LocationFilter({
    required this.province,
    required this.countryCount,
    required this.provinceCount,
    required this.county,
    required this.countyCount,
    required this.settlement,
    required this.settlementCount,
    required this.onProvinceChanged,
  });
  final String province;
  final String countryCount;
  final String provinceCount;
  final String county;
  final String countyCount;
  final String settlement;
  final String settlementCount;
  final ValueChanged<String?> onProvinceChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('گسترهٔ کاربران', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _LocationRow(label: 'کشور', value: 'ایران', count: countryCount),
        const SizedBox(height: 8),
        _LocationDropdown(
          key: ValueKey(province),
          label: 'استان',
          value: province,
          count: provinceCount,
          items: const ['اصفهان', 'فارس', 'یزد'],
          onChanged: onProvinceChanged,
        ),
        const SizedBox(height: 8),
        _LocationDropdown(
          key: ValueKey('$province-county'),
          label: 'شهرستان',
          value: county,
          count: countyCount,
          items: [county],
          onChanged: (_) {},
        ),
        const SizedBox(height: 8),
        _LocationDropdown(
          key: ValueKey('$province-settlement'),
          label: 'شهر / روستا',
          value: settlement,
          count: settlementCount,
          items: [settlement],
          onChanged: (_) {},
        ),
      ],
    ),
  );
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.label,
    required this.value,
    required this.count,
  });
  final String label;
  final String value;
  final String count;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppTheme.primaryLight.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label: $value',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          Text(count, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    ),
  );
}

class _LocationDropdown extends StatelessWidget {
  const _LocationDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.count,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final String value;
  final String count;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    items:
        items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: '$label: $value',
      suffixText: count,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.title,
    required this.color,
  });
  final IconData icon;
  final String title;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}
