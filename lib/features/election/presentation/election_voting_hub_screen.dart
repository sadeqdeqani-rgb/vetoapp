import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_tap_tile.dart';
import '../domain/election_category.dart';

class ElectionVotingHubScreen extends StatelessWidget {
  const ElectionVotingHubScreen({super.key});

  static const _icons = <ElectionCategory, IconData>{
    ElectionCategory.presidential: Icons.flag_outlined,
    ElectionCategory.governor: Icons.map_outlined,
    ElectionCategory.county: Icons.account_balance_outlined,
    ElectionCategory.local: Icons.location_city_outlined,
  };

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        const Text('نوع انتخابات مورد نظر را انتخاب کنید.'),
        const SizedBox(height: 16),
        ...ElectionCategory.values.map(
          (category) => AppTapTile(
            icon: _icons[category]!,
            title: category.title,
            subtitle: _scopeDescription(category),
            accent: AppTheme.election,
            onTap: () => context.push('/elections/voting/${category.code}'),
          ),
        ),
      ],
    ),
  );

  String _scopeDescription(ElectionCategory category) => switch (category) {
    ElectionCategory.presidential => 'دامنهٔ کشور',
    ElectionCategory.governor => 'دامنهٔ استان محل سکونت',
    ElectionCategory.county => 'دامنهٔ شهرستان محل سکونت',
    ElectionCategory.local => 'دامنهٔ شهر یا روستای محل سکونت',
  };
}
