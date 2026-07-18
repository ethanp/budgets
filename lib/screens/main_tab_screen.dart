import 'package:budgets/features/activity/activity_screen.dart';
import 'package:budgets/features/categories/categories_screen.dart';
import 'package:budgets/features/month/month_screen.dart';
import 'package:budgets/features/settings/settings_screen.dart';
import 'package:flutter/cupertino.dart';

class MainTab {
  const MainTab({
    required this.icon,
    required this.label,
    required this.screen,
  });

  final IconData icon;
  final String label;
  final Widget screen;

  BottomNavigationBarItem get navigationItem =>
      BottomNavigationBarItem(icon: Icon(icon), label: label);
}

const mainTabs = <MainTab>[
  MainTab(
    icon: CupertinoIcons.chart_bar,
    label: 'Month',
    screen: MonthScreen(),
  ),
  MainTab(
    icon: CupertinoIcons.list_bullet,
    label: 'Activity',
    screen: ActivityScreen(),
  ),
  MainTab(
    icon: CupertinoIcons.tag,
    label: 'Categories',
    screen: CategoriesScreen(),
  ),
  MainTab(
    icon: CupertinoIcons.gear,
    label: 'Settings',
    screen: SettingsScreen(),
  ),
];

class MainTabScreen extends StatelessWidget {
  const MainTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: mainTabs.map((tab) => tab.navigationItem).toList(),
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) => mainTabs[index].screen,
        );
      },
    );
  }
}
