import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_tap_tile.dart';
import '../../../../core/theme/app_theme.dart';

class CivicSectionAction {
  const CivicSectionAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.emphasized = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final bool emphasized;
}

class CivicSectionScreen extends StatelessWidget {
  const CivicSectionScreen({
    super.key,
    required this.description,
    required this.accent,
    required this.actions,
    required this.activeCountLabel,
  });

  final String description;
  final Color accent;
  final List<CivicSectionAction> actions;
  final String activeCountLabel;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 18),
            Text(
              'مسیرهای اصلی',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 10),
            ...actions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppTapTile(
                  icon: action.icon,
                  title: action.title,
                  subtitle: action.subtitle,
                  accent: action.color,
                  highlighted: action.emphasized,
                  onTap: () => context.go(action.route),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _ActivityCard(label: activeCountLabel, accent: accent),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Icon(Icons.insights_rounded, color: accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
        ],
      ),
    );
  }
}
