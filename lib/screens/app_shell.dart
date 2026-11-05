import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/local_store.dart';
import 'alert_preview_onboarding.dart';

import 'home_screen.dart';
import 'offline_hub_screen.dart';
import '../services/connection_monitor.dart';
import 'shelters_screen.dart';
import 'guidelines_screen.dart';
import 'readiness_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.monitor, this.store, this.showOnboarding});
  final ConnectionMonitor? monitor;
  final LocalStore? store;
  // Tests set this; otherwise the stored first-run flag decides.
  final bool? showOnboarding;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selected = 0;
  final _pages = List<Widget?>.filled(4, null);
  static const _onboardingFlag = 'alert_preview_seen';
  late bool _onboarding = widget.showOnboarding ?? false;
  late final _store = widget.store ?? LocalStore();

  Future<void> _finishOnboarding() async {
    setState(() => _onboarding = false);
    try {
      await _store.saveFlag(_onboardingFlag);
    } catch (_) {
      // Not saving the flag only means the preview may show once more.
    }
  }

  @override
  void initState() {
    super.initState();
    // The browser app has its own intro page.
    if (widget.showOnboarding == null && !kIsWeb) {
      _store.loadFlag(_onboardingFlag).then((seen) {
        if (mounted && !seen) setState(() => _onboarding = true);
      }, onError: (Object _) {});
    }
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
  Widget build(BuildContext context) => _onboarding
      ? AlertPreviewOnboarding(onDone: _finishOnboarding)
      : PopScope(
          canPop: _selected == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _select(0);
          },
          child: Scaffold(
            body: ValueListenableBuilder<LinkStatus>(
              valueListenable: widget.monitor ?? ConnectionMonitor.instance,
              builder: (context, status, _) => IndexedStack(
                index: _selected,
                children: [
                  if (status.needsOfflineTools)
                    OfflineHubScreen(monitor: widget.monitor)
                  else
                    _pages[0]!,
                  for (final page in _pages.skip(1)) page ?? const SizedBox(),
                ],
              ),
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
