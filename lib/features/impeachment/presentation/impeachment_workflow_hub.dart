import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_tap_tile.dart';
import '../domain/impeachment_office.dart';

class ImpeachmentWorkflowHub extends StatelessWidget {
  const ImpeachmentWorkflowHub({super.key, required this.office});
  final ImpeachmentOffice office;

  static const _items = <(String, String, IconData, String)>[
    (
      'درخواست استیضاح',
      'ثبت اولین درخواست برای مسئول این حوزه',
      Icons.add_task_outlined,
      'request',
    ),
    (
      'حمایت از استیضاح',
      'پیوستن به درخواست در حال کسب حدنصاب',
      Icons.volunteer_activism_outlined,
      'supporting',
    ),
    (
      'مشاهدهٔ زمان‌بندی',
      'درخواست‌هایی که در صف رأی اعتماد هستند',
      Icons.event_available_outlined,
      'scheduled',
    ),
    (
      'شرکت در رأی اعتماد',
      'رأی دربارهٔ برکناری یا ابقای مسئول',
      Icons.how_to_vote_outlined,
      'eligible',
    ),
    (
      'نتایج زندهٔ رأی اعتماد',
      'آمار رأی‌های در حال ثبت',
      Icons.sensors_outlined,
      'live',
    ),
    (
      'نتایج نهایی رأی اعتماد',
      'صندوق‌های نهایی و منتشرشده',
      Icons.fact_check_outlined,
      'finalized',
    ),
  ];

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
      children: [
        Text(
          office.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFFC62828),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'دامنهٔ شما: ${office.scopeLabel} · حدنصاب حمایت: ۲۰٪ از جمعیت ثبت‌شدهٔ دامنه',
        ),
        const SizedBox(height: 12),
        ..._items.map(
          (item) => AppTapTile(
            icon: item.$3,
            title: item.$1,
            subtitle: item.$2,
            accent: const Color(0xFFC62828),
            onTap: () => context.push('/impeachment/${office.code}/${item.$4}'),
          ),
        ),
      ],
    ),
  );
}
