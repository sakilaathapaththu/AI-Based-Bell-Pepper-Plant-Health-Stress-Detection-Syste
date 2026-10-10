import 'package:flutter/material.dart';
import 'package:bell_pepper_app/constants/app_colors.dart';
import 'package:bell_pepper_app/features/home/ui/tabs/home_tab.dart';
import 'package:bell_pepper_app/features/home/ui/widgets/app_bottom_nav.dart';
import 'package:bell_pepper_app/features/home/ui/widgets/coming_soon_tab.dart';
import 'package:bell_pepper_app/features/home/ui/widgets/home_top_bar.dart';
import 'package:bell_pepper_app/features/profile/ui/profile_screen.dart';

/// Signed-in app shell: shared top bar (brand + profile shortcut) and
/// floating bottom nav across the four main sections. Real dashboard
/// content (the RGB/thermal/environmental/recovery features) lands here
/// incrementally — Insights/Data/Settings are placeholders for now.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  static const _navItems = [
    AppNavItem(label: 'Home', icon: Icons.home_rounded),
    AppNavItem(label: 'Insights', icon: Icons.insights_rounded),
    AppNavItem(label: 'Data', icon: Icons.bar_chart_rounded),
    AppNavItem(label: 'Settings', icon: Icons.settings_rounded),
  ];

  static const _tabs = [
    HomeTab(),
    ComingSoonTab(
      icon: Icons.insights_rounded,
      title: 'Insights',
      message: 'Trends and alerts across your greenhouse are coming soon.',
    ),
    ComingSoonTab(
      icon: Icons.bar_chart_rounded,
      title: 'Data',
      message: 'Historical sensor and prediction data will live here.',
    ),
    ComingSoonTab(
      icon: Icons.settings_rounded,
      title: 'Settings',
      message: 'App preferences and account settings are coming soon.',
    ),
  ];

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 4),
              HomeTopBar(onProfileTap: _openProfile),
              const SizedBox(height: 16),
              Expanded(
                child: IndexedStack(index: _tabIndex, children: _tabs),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: _navItems,
        currentIndex: _tabIndex,
        onTap: (index) => setState(() => _tabIndex = index),
      ),
    );
  }
}
