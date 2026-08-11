import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HomeBottomNavigation extends StatelessWidget {
  const HomeBottomNavigation({super.key, this.onSettingsTap});

  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: 0,
      onDestinationSelected: (index) {
        if (index == 2) onSettingsTap?.call();
      },
      backgroundColor: AppColors.surface,
      indicatorColor: const Color(0xFFE5F5EB),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'ホーム',
        ),
        NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          label: '振り返り',
        ),
        NavigationDestination(icon: Icon(Icons.settings_outlined), label: '設定'),
      ],
    );
  }
}
