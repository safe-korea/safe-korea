import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'shelters_screen.dart';
import 'guidelines_screen.dart';
import 'readiness_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selected = 0;
  final _pages = List<Widget?>.filled(4, null);
  @override
  void initState() {
    super.initState();
    _pages[0] = HomeScreen(
      onShelters: () => _select(1),
      onGuidelines: () => _select(2),
      onReadiness: () => _select(3),
    );
  }

  void _select(int index) {
    setState(() {
      _pages[index] ??= switch (index) {
        1 => const SheltersScreen(),
        2 => const GuidelinesScreen(),
        3 => const ReadinessScreen(),
        _ => _pages[0]!,
      };
      _selected = index;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _selected == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _select(0);
    },
    child: Scaffold(
      body: IndexedStack(
        index: _selected,
        children: [for (final page in _pages) page ?? const SizedBox()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.near_me_outlined),
            selectedIcon: Icon(Icons.near_me),
            label: '대피소',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '행동강령',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: '나의 준비',
          ),
        ],
      ),
    ),
  );
}
