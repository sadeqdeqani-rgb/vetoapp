import 'package:flutter/material.dart';

import 'civic_section_screen.dart';

class ImpeachmentScreen extends StatelessWidget {
  const ImpeachmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CivicSectionScreen(
      title: 'استیضاح',
      description: 'هر مسئولی را می‌توانید به توضیح و پاسخ وادار کنید.',
      icon: Icons.gavel_outlined,
      accent: const Color(0xFFC62828),
      activeCountLabel: '۲ استیضاح در حال بررسی است',
      actions: const [
        CivicSectionAction(
          title: 'درخواست استیضاح',
          subtitle: 'درخواست استیضاح یک مسئول ملی یا محلی',
          icon: Icons.add_task_rounded,
          color: Color(0xFFC62828),
          route: '/participation',
          emphasized: true,
        ),
        CivicSectionAction(
          title: 'مشاهده و شرکت در استیضاح',
          subtitle: 'شرکت در فرآیند رأی اعتماد و ثبت رأی',
          icon: Icons.groups_outlined,
          color: Color(0xFFC62828),
          route: '/participation',
        ),
        CivicSectionAction(
          title: 'مشاهده استیضاح‌های پایان‌یافته',
          subtitle: 'نتایج استیضاح‌های انجام‌شده و اطلاعات و آمار نهایی',
          icon: Icons.fact_check_outlined,
          color: Color(0xFFC62828),
          route: '/participation',
        ),
      ],
    );
  }
}
