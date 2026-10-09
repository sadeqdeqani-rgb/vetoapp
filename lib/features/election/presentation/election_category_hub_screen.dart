import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_tap_tile.dart';
import '../domain/election_category.dart';

class ElectionCategoryHubScreen extends StatelessWidget {
  const ElectionCategoryHubScreen({super.key, required this.category});

  final ElectionCategory category;

  static const _workflows = [
    (
      'مشاهدهٔ انتخابات زمان‌بندی‌شده',
      'انتخابات‌های در دورهٔ انتظار',
      Icons.event_available_outlined,
      'scheduled',
    ),
    (
      'شرکت در انتخابات فعال',
      'رأی‌دادن در انتخابات حوزهٔ شما',
      Icons.how_to_vote_outlined,
      'eligible',
    ),
    (
      'نتایج زندهٔ انتخابات',
      'آمار انتخابات‌های در حال رأی‌گیری',
      Icons.sensors_outlined,
      'live-results',
    ),
    (
      'نتایج انتخابات پایان‌یافته',
      'نتایج نهایی و منتشرشده',
      Icons.bar_chart_rounded,
      'final-results',
    ),
  ];

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        Text(
          category.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.election,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text('دامنهٔ این دسته: ${_scopeDescription(category)}'),
        const SizedBox(height: 6),
        const Text(
          'نامزد مورد نظر را خودتان روی برگ رأی می‌نویسید؛ نام‌های مشابه برای بررسی و انتخاب نمایش داده می‌شوند.',
        ),
        const SizedBox(height: 16),
        ..._workflows.map(
          (item) => AppTapTile(
            icon: item.$3,
            title: item.$1,
            subtitle: item.$2,
            accent: AppTheme.election,
            onTap:
                () => context.push(
                  '/elections/voting/${category.code}/${item.$4}',
                ),
          ),
        ),
      ],
    ),
  );

  String _scopeDescription(ElectionCategory category) => switch (category) {
    ElectionCategory.presidential => 'کشور',
    ElectionCategory.governor => 'استان محل سکونت شما',
    ElectionCategory.county => 'شهرستان محل سکونت شما',
    ElectionCategory.local => 'شهر یا روستای محل سکونت شما',
  };
}
