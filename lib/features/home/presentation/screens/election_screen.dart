import 'package:flutter/material.dart';

import 'civic_section_screen.dart';

class ElectionScreen extends StatelessWidget {
  const ElectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CivicSectionScreen(
      title: 'انتخابات',
      description:
          'در انتخابات شرکت کنید و نتیجه‌ی رأی‌گیری را شفاف دنبال کنید.',
      icon: Icons.how_to_vote_rounded,
      accent: const Color(0xFFC77C00),
      activeCountLabel: '۲ انتخابات در حال رأی‌گیری است',
      actions: const [
        CivicSectionAction(
          title: 'شرکت در انتخابات',
          subtitle: 'مشاهده حوزه‌ها و ثبت رأی',
          icon: Icons.ballot_outlined,
          color: Color(0xFFC77C00),
          emphasized: true,
        ),
        CivicSectionAction(
          title: 'نتایج زنده',
          subtitle: 'مشاهده‌ی آمار رأی‌ها به‌صورت لحظه‌ای',
          icon: Icons.show_chart_rounded,
          color: Color(0xFFC77C00),
        ),
        CivicSectionAction(
          title: 'نتایج انتخابات پایان‌یافته',
          subtitle: 'جست‌وجو و مقایسه‌ی نتایج قبلی',
          icon: Icons.poll_outlined,
          color: Color(0xFFC77C00),
        ),
      ],
    );
  }
}
