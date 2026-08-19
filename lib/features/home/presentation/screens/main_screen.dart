import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key, required this.child});

  final Widget child;

  static const _locations = <String>[
    '/',
    '/participation',
    '/ballot',
    '/profile',
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _locations.indexOf(location);

    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex(context),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'خانه'),
          BottomNavigationBarItem(icon: Icon(Icons.poll), label: 'مشارکت'),
          BottomNavigationBarItem(
            icon: Icon(Icons.how_to_vote),
            label: 'رأی‌گیری',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'پروفایل'),
        ],
        onTap: (index) => context.go(_locations[index]),
      ),
    );
  }
}
