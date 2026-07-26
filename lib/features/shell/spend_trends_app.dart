import 'package:spend_trends/features/shell/main_tab_screen.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;

class SpendTrendsApp extends StatelessWidget {
  const SpendTrendsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Spend Trends',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: const MainTabScreen(),
    );
  }
}
