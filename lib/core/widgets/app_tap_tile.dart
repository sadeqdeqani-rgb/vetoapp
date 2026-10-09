import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Route tile with a strong idle accent and a lighter pressed state.
class AppTapTile extends StatefulWidget {
  const AppTapTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  State<AppTapTile> createState() => _AppTapTileState();
}

class _AppTapTileState extends State<AppTapTile> {
  bool _pressed = false;
  bool _activated = false;

  Future<void> _flashActivation() async {
    if (mounted) setState(() => _activated = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) setState(() => _activated = false);
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final faded = _pressed || _activated;
    final foreground = accent.withValues(alpha: faded ? 0.34 : 1);
    final background =
        faded
            ? accent.withValues(alpha: 0.025)
            : widget.highlighted
            ? accent.withValues(alpha: 0.12)
            : accent.withValues(alpha: 0.075);

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () {
          _flashActivation();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(alpha: faded ? 0.14 : 0.46),
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: foreground, size: 25),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: foreground,
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            faded
                                ? accent.withValues(alpha: 0.62)
                                : AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
