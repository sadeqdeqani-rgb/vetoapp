import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_tap_tile.dart';

class ReferendumVotingHubScreen extends StatelessWidget {
  const ReferendumVotingHubScreen({super.key});

  static const _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        Text(
          'همه‌پرسی، زمان‌بندی، رأی‌دهی و نتایج',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _green,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'زمان‌بندی فرایندها را ببینید، در همه‌پرسی‌های حوزهٔ خود شرکت کنید و نتیجه‌ها را پیگیری کنید.',
        ),
        const SizedBox(height: 16),
        AppTapTile(
          title: 'مشاهدهٔ همه‌پرسی‌های زمان‌بندی‌شده',
          subtitle: 'فرایندهایی که در دورهٔ انتظار هستند',
          icon: Icons.event_available_outlined,
          accent: _green,
          onTap: () => context.push('/referendum/voting/scheduled'),
        ),
        AppTapTile(
          title: 'شرکت در همه‌پرسی‌های فعال',
          subtitle: 'رأی‌دهی در همه‌پرسی‌های واجد شرایط حوزهٔ شما',
          icon: Icons.how_to_vote_outlined,
          accent: _green,
          onTap: () => context.push('/referendum/voting/eligible'),
        ),
        AppTapTile(
          title: 'نتایج زندهٔ همه‌پرسی‌ها',
          subtitle: 'آمار رأی‌گیری‌های در حال انجام، با تازه‌سازی ده‌دقیقه‌ای',
          icon: Icons.sensors_outlined,
          accent: _green,
          onTap: () => context.push('/referendum/voting/live-results'),
        ),
        AppTapTile(
          title: 'نتایج همه‌پرسی‌های پایان‌یافته',
          subtitle: 'نتایج نهایی فرایندهای منتشرشده',
          icon: Icons.bar_chart_rounded,
          accent: _green,
          onTap: () => context.push('/referendum/voting/final-results'),
        ),
      ],
    ),
  );
}
