import 'package:flutter/material.dart';

import 'civic_section_screen.dart';

class ReferendumScreen extends StatelessWidget {
  const ReferendumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CivicSectionScreen(
      description:
          'موضوعات کلان کشور و محلی را برای همه‌پرسی پیشنهاد دهید، از طرح موضوعات حمایت کنید و رأی خود را به صندوق بیندازید.',
      accent: const Color(0xFF2E7D32),
      activeCountLabel: '۲ همه‌پرسی در حال برگزاری است',
      actions: const [
        CivicSectionAction(
          title: 'پیشنهاد موضوع',
          subtitle: 'ثبت یک موضوع برای بررسی عمومی',
          icon: Icons.add_circle_outline_rounded,
          color: Color(0xFF2E7D32),
          route: '/referendum/propose',
          emphasized: true,
        ),
        CivicSectionAction(
          title: 'مشاهده و حمایت از موضوعات پیشنهادی',
          subtitle: 'مرور موضوعات و ثبت حمایت',
          icon: Icons.volunteer_activism_outlined,
          color: Color(0xFF2E7D32),
          route: '/referendum/supported',
        ),
        CivicSectionAction(
          title: 'همه‌پرسی، زمان‌بندی، رأی‌دهی و نتایج',
          subtitle: 'مرور برنامه‌ها، شرکت در رأی‌گیری و مشاهدهٔ نتایج',
          icon: Icons.ballot_outlined,
          color: Color(0xFF2E7D32),
          route: '/referendum/voting',
        ),
      ],
    );
  }
}
