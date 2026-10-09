import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_tap_tile.dart';
import '../domain/impeachment_office.dart';

class ImpeachmentOfficeHub extends StatelessWidget {
  const ImpeachmentOfficeHub({super.key});

  static const _icons = <ImpeachmentOffice, IconData>{
    ImpeachmentOffice.president: Icons.flag_outlined,
    ImpeachmentOffice.governor: Icons.map_outlined,
    ImpeachmentOffice.county: Icons.account_balance_outlined,
    ImpeachmentOffice.local: Icons.location_city_outlined,
  };

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        const Text(
          'مسئولی را انتخاب کنید که در دامنهٔ کاربری شما با رأی شما انتخاب شده است.',
        ),
        const SizedBox(height: 16),
        ...ImpeachmentOffice.values.map(
          (office) => AppTapTile(
            icon: _icons[office]!,
            title: office.title,
            subtitle: office.scopeLabel,
            accent: const Color(0xFFC62828),
            onTap: () => context.push('/impeachment/${office.code}'),
          ),
        ),
      ],
    ),
  );
}
