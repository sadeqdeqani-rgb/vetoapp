import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key, required this.child});

  final Widget child;

  static const _locations = <String>[
    '/',
    '/referendum',
    '/elections',
    '/impeachment',
    '/profile',
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _locations.indexOf(location);
    return index == -1 ? 0 : index;
  }

  Color _tabColor(int index) {
    return switch (index) {
      1 => AppTheme.success,
      2 => AppTheme.election,
      3 => AppTheme.danger,
      4 => AppTheme.profile,
      _ => AppTheme.primary,
    };
  }

  Future<void> _handleBack(BuildContext context) async {
    final location = GoRouterState.of(context).uri.path;
    if (location == '/') {
      await SystemNavigator.pop(animated: true);
      return;
    }

    if (location.startsWith('/referendum')) {
      context.go('/referendum');
    } else if (location.startsWith('/elections')) {
      context.go('/elections');
    } else if (location.startsWith('/impeachment')) {
      context.go('/impeachment');
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(context);
    final colors = Theme.of(context).colorScheme;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _handleBack(context),
      child: Scaffold(
        backgroundColor: colors.surface,
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Image.asset(
                    AppTheme.appLogo,
                    height: AppTheme.authLogoSize * 0.78,
                    fit: BoxFit.contain,
                    semanticLabel: 'وِتواَپ',
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    padding: const EdgeInsets.only(top: 4),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.24),
                        width: 1.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.46),
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.14),
                      blurRadius: 24,
                      spreadRadius: 1,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Row(
                    children: List.generate(_locations.length, (index) {
                      final isSelected = index == selectedIndex;
                      final icon = switch (index) {
                        0 => Icons.home_outlined,
                        1 => Icons.how_to_vote_outlined,
                        2 => Icons.how_to_vote_rounded,
                        3 => Icons.gavel_outlined,
                        _ => Icons.person_outline,
                      };
                      final label = switch (index) {
                        0 => 'خانه',
                        1 => 'همه‌پرسی',
                        2 => 'انتخابات',
                        3 => 'استیضاح',
                        _ => 'کاربری',
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
                            color: _tabColor(index),
                            onTap: () => context.go(_locations[index]),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
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
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_NavigationTab> createState() => _NavigationTabState();
}

class _NavigationTabState extends State<_NavigationTab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground =
        widget.selected
            ? Color.lerp(widget.color, colors.surface, 0.68)!
            : widget.color;
    final background =
        widget.selected
            ? widget.color.withValues(alpha: _pressed ? 0.16 : 0.08)
            : (_pressed
                ? widget.color.withValues(alpha: 0.16)
                : Colors.transparent);

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
          borderRadius: BorderRadius.circular(28),
        ),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: widget.selected ? 23 : 25,
                color: foreground,
              ),
              const SizedBox(height: 1),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 17,
                  fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
