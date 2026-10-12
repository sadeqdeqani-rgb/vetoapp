import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_handler_registry.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

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
    final index = _locations.indexOf(
      _parentLocation(_currentLocation(context)),
    );
    return index == -1 ? 0 : index;
  }

  String _currentLocation(BuildContext context) =>
      GoRouter.of(context).routeInformationProvider.value.uri.path;

  String _parentLocation(String location) {
    if (location.startsWith('/about')) return '/';
    if (location.startsWith('/referendum')) return '/referendum';
    if (location.startsWith('/elections')) return '/elections';
    if (location.startsWith('/impeachment')) return '/impeachment';
    if (location.startsWith('/profile')) return '/profile';
    return '/';
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

  Color _accentForLocation(String location) {
    if (location.startsWith('/referendum')) return AppTheme.success;
    if (location.startsWith('/elections')) return AppTheme.election;
    if (location.startsWith('/impeachment')) return AppTheme.danger;
    if (location.startsWith('/profile')) return AppTheme.profile;
    return AppTheme.primary;
  }

  void _handleBack(BuildContext context) {
    if (AppBackHandlerRegistry.handle()) return;
    final location = _currentLocation(context);
    if (location == '/') {
      SystemNavigator.pop(animated: true);
      return;
    }
    final parent = _parentLocation(location);
    context.go(location == parent ? '/' : parent);
  }

  void _handleNavigationTap(BuildContext context, int index) {
    final location = _locations[index];
    final isInteractiveGuest = context.read<AuthCubit>().state is Guest;
    context.go(location);

    if (!isInteractiveGuest || index < 1 || index > 3) return;
    final accent = _tabColor(index);
    final title = switch (index) {
      1 => 'همه‌پرسی',
      2 => 'انتخابات',
      _ => 'استیضاح',
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      showAppMessageDialog<void>(
        context: context,
        title: title,
        message:
            'تمامی مطالب و محتویات این بخش غیرواقعی بوده و صرفاً برای آشنایی کاربران با روش کار سامانه درج شده است.',
        accentColor: accent,
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: AppTheme.surface,
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('متوجه شدم'),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    return AnimatedBuilder(
      animation: router.routeInformationProvider,
      builder: (context, _) {
        final location = _currentLocation(context);
        final selectedIndex = _selectedIndex(context);
        final colors = Theme.of(context).colorScheme;
        final accent = _accentForLocation(location);
        final sectionTheme = Theme.of(context).copyWith(
          colorScheme: colors.copyWith(
            primary: accent,
            primaryContainer: accent.withValues(alpha: 0.14),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: AppTheme.surface,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: AppTheme.surface,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withValues(alpha: 0.72)),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: accent),
          ),
          inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: accent, width: 1.6),
              borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            ),
            floatingLabelStyle: TextStyle(color: accent),
          ),
          chipTheme: Theme.of(context).chipTheme.copyWith(
            selectedColor: accent.withValues(alpha: 0.18),
            secondarySelectedColor: accent.withValues(alpha: 0.18),
            side: BorderSide(color: accent.withValues(alpha: 0.48)),
          ),
        );
        return PopScope<void>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBack(context);
          },
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
                          borderRadius: BorderRadius.circular(
                            AppTheme.cardRadius,
                          ),
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
                        child: Theme(data: sectionTheme, child: child),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 7,
                    ),
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
                            2 => Icons.ballot_outlined,
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
                                onTap:
                                    () => _handleNavigationTap(context, index),
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
      },
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
    final foreground = widget.color.withValues(
      alpha:
          _pressed
              ? 0.16
              : widget.selected
              ? 0.3
              : 1,
    );
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 25, color: foreground),
              const SizedBox(height: 1),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 17,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.w700,
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
