import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:spend_trends/app_identity.dart';
import 'package:spend_trends/features/shell/main_tab_screen.dart';

class const SpendTrendsApp() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppIdentity.displayName,
      theme: ETheme.build(),
      debugShowCheckedModeBanner: false,
      home: const MainTabScreen(),
    );
  }
}
