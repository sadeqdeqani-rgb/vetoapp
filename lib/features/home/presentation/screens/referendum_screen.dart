import 'package:flutter/material.dart';

import 'civic_section_screen.dart';

class ReferendumScreen extends StatelessWidget {
  const ReferendumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CivicSectionScreen(
      title: 'همه‌پرسی',
      description:
          'موضوعات کلان کشور و محلی را برای همه‌پرسی پیشنهاد دهید، از طرح موضوعات حمایت کنید و رأی خود را به صندوق بیندازید.',
      icon: Icons.how_to_vote_outlined,
      accent: const Color(0xFF2E7D32),
      activeCountLabel: '۲ همه‌پرسی در حال برگزاری است',
      actions: const [
        CivicSectionAction(
          title: 'پیشنهاد موضوع',
          subtitle: 'ثبت یک موضوع برای بررسی عمومی',
          icon: Icons.add_circle_outline_rounded,
          color: Color(0xFF2E7D32),
          route: '/participation',
          emphasized: true,
        ),
        CivicSectionAction(
          title: 'مشاهده و حمایت از موضوعات پیشنهادی',
          subtitle: 'مرور موضوعات و ثبت حمایت',
          icon: Icons.volunteer_activism_outlined,
          color: Color(0xFF2E7D32),
          route: '/participation',
        ),
        CivicSectionAction(
          title: 'شرکت در همه‌پرسی',
          subtitle: 'مشاهده و ثبت رأی در موضوعات فعال',
          icon: Icons.how_to_vote_outlined,
          color: Color(0xFF2E7D32),
          route: '/ballot',
        ),
        CivicSectionAction(
          title: 'نتایج همه‌پرسی‌های پایان‌یافته',
          subtitle: 'بررسی نتایج و سوابق قبلی',
          icon: Icons.bar_chart_rounded,
          color: Color(0xFF2E7D32),
          route: '/ballot',
        ),
      ],
    );
  }
}
