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
    return Scaffold(
      backgroundColor: Colors.transparent,
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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex(context),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'کاربری'),
          BottomNavigationBarItem(
            icon: Icon(Icons.how_to_vote),
            label: 'صندوق',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.poll), label: 'مشارکت'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'خانه'),
        ],
        onTap: (index) => context.go(_locations[index]),
      ),
    );
  }
}
