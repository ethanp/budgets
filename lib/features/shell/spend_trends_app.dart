import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:spend_trends/features/shell/main_tab_screen.dart';

class SpendTrendsApp extends StatelessWidget {
  const SpendTrendsApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spend Trends',
      theme: ETheme.build(),
      debugShowCheckedModeBanner: false,
      home: const MainTabScreen(),
    );
  }
}
