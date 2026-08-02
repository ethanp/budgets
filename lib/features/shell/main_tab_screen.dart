import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:spend_trends/features/activity/activity_screen.dart';
import 'package:spend_trends/features/banks/banks_screen.dart';
import 'package:spend_trends/features/categories/categories_screen.dart';
import 'package:spend_trends/features/life_events/life_events_screen.dart';
import 'package:spend_trends/features/settings/settings_screen.dart';
import 'package:spend_trends/features/trends/trends_screen.dart';

class MainTab {
  const MainTab({
    required this.icon,
    required this.label,
    required this.screen,
  });

  final IconData icon;
  final String label;
  final Widget screen;

  BottomNavigationBarItem get navigationItem => BottomNavigationBarItem(
        icon: Icon(icon, size: 26),
        label: label,
      );
}

const mainTabs = <MainTab>[
  MainTab(
    icon: Icons.bar_chart,
    label: 'Trends',
    screen: TrendsScreen(),
  ),
  MainTab(
    icon: Icons.account_balance,
    label: 'Banks',
    screen: BanksScreen(),
  ),
  MainTab(
    icon: Icons.flag,
    label: 'Life Events',
    screen: LifeEventsScreen(),
  ),
  MainTab(
    icon: Icons.list,
    label: 'Activity',
    screen: ActivityScreen(),
  ),
  MainTab(
    icon: Icons.label,
    label: 'Categories',
    screen: CategoriesScreen(),
  ),
  MainTab(
    icon: Icons.settings,
    label: 'Settings',
    screen: SettingsScreen(),
  ),
];

class MainTabScreen extends StatefulWidget {
  const MainTabScreen();

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (var index = 0; index < mainTabs.length; index++)
            Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                settings: settings,
                builder: (context) => _TabChrome(
                  child: mainTabs[index].screen,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.frostFill,
        selectedItemColor: AppColors.accentGlow,
        unselectedItemColor: AppColors.textMuted,
        items: mainTabs.map((tab) => tab.navigationItem).toList(),
      ),
    );
  }
}

class _TabChrome extends StatelessWidget {
  const _TabChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.scaffoldGradient,
          ),
        ),
        const Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 200,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.ambientGlowGradient,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
