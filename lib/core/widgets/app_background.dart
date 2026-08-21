import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: AppTheme.pageBackground,
      child: child,
    );
  }
}
