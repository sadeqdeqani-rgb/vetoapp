import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'civic_section_screen.dart';

class ElectionScreen extends StatelessWidget {
  const ElectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CivicSectionScreen(
      title: 'انتخابات',
      description:
          'در انتخابات آزادانه شرکت کنید، آزادانه انتخاب شوید و رأی‌گیری شفاف را دنبال کنید.',
      icon: Icons.how_to_vote_rounded,
      accent: AppTheme.election,
      activeCountLabel: '۲ انتخابات در حال رأی‌گیری است',
      actions: const [
        CivicSectionAction(
          title: 'شرکت در انتخابات',
          subtitle: 'مشاهده حوزه‌ها و ثبت رأی',
          icon: Icons.ballot_outlined,
          color: AppTheme.election,
          route: '/ballot',
          emphasized: true,
        ),
        CivicSectionAction(
          title: 'نتایج زنده',
          subtitle: 'مشاهده‌ی آمار رأی‌ها به‌صورت لحظه‌ای',
          icon: Icons.show_chart_rounded,
          color: AppTheme.election,
          route: '/ballot',
        ),
        CivicSectionAction(
          title: 'نتایج انتخابات پایان‌یافته',
          subtitle: 'جست‌وجو و مشاهده نتایج انتخابات‌های پیشین',
          icon: Icons.poll_outlined,
          color: AppTheme.election,
          route: '/ballot',
        ),
      ],
    );
  }
}
