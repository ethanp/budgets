import 'package:spend_trends/features/banks/banks_source_section.dart';
import 'package:spend_trends/theme/app_theme.dart';
import 'package:spend_trends/widgets/sync_status_nav_button.dart';
import 'package:flutter/cupertino.dart';

/// Everyday SimpleFIN connect / accounts / sync.
class BanksScreen extends StatelessWidget {
  const BanksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        leading: SyncStatusNavButton(),
        middle: Text('Banks'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: const [
            BanksSourceSection(),
          ],
        ),
      ),
    );
  }
}
