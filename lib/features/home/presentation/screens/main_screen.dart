import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key, required this.child});

  final Widget child;

  static const _locations = <String>[
    '/profile',
    '/ballot',
    '/participation',
    '/',
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _locations.indexOf(location);

    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Image.asset(
                  AppTheme.appLogo,
                  height: 76,
                  fit: BoxFit.contain,
                  semanticLabel: 'VetoApp',
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.divider),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A263238),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_locations.length, (index) {
              final isSelected = index == selectedIndex;
              final icon = switch (index) {
                0 => Icons.person_outline,
                1 => Icons.account_balance_wallet_outlined,
                2 => Icons.how_to_vote_outlined,
                _ => Icons.home_outlined,
              };
              final label = switch (index) {
                0 => 'کاربری',
                1 => 'صندوق',
                2 => 'مشارکت',
                _ => 'خانه',
              };

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: isSelected,
                  label: label,
                  child: _NavigationTab(
                    icon: icon,
                    label: label,
                    selected: isSelected,
                    onTap: () => context.go(_locations[index]),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavigationTab extends StatefulWidget {
  const _NavigationTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavigationTab> createState() => _NavigationTabState();
}

class _NavigationTabState extends State<_NavigationTab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final foreground =
        widget.selected
            ? (_pressed ? AppTheme.primaryDark : AppTheme.primary)
            : AppTheme.textSecondary;
    final background =
        widget.selected
            ? (_pressed ? AppTheme.pressedTab : AppTheme.primaryLight)
            : (_pressed ? AppTheme.pressedTab : Colors.transparent);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 25, color: foreground),
            const SizedBox(height: 2),
            Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'B Mitra',
                fontSize: 17,
                fontWeight:
                    widget.selected || _pressed
                        ? FontWeight.w700
                        : FontWeight.w400,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
