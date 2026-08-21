import 'package:flutter/material.dart';

import 'civic_section_screen.dart';

class ImpeachmentScreen extends StatelessWidget {
  const ImpeachmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CivicSectionScreen(
      title: 'استیضاح',
      description:
          'موضوعات پاسخ‌گویی را ثبت، بررسی و با مشارکت عمومی دنبال کنید.',
      icon: Icons.gavel_outlined,
      accent: const Color(0xFFC62828),
      activeCountLabel: '۲ استیضاح در حال بررسی است',
      actions: const [
        CivicSectionAction(
          title: 'درخواست استیضاح',
          subtitle: 'ثبت موضوع همراه با مستندات',
          icon: Icons.add_task_rounded,
          color: Color(0xFFC62828),
          emphasized: true,
        ),
        CivicSectionAction(
          title: 'مشاهده و شرکت در استیضاح',
          subtitle: 'بررسی موضوعات فعال و ثبت نظر',
          icon: Icons.groups_outlined,
          color: Color(0xFFC62828),
        ),
        CivicSectionAction(
          title: 'مشاهده استیضاح‌های پایان‌یافته',
          subtitle: 'سوابق پاسخ‌گویی و نتایج نهایی',
          icon: Icons.fact_check_outlined,
          color: Color(0xFFC62828),
        ),
      ],
    );
  }
}
