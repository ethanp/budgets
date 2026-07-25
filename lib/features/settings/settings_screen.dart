import 'package:budgets/features/banks/banks_advanced_section.dart';
import 'package:budgets/features/settings/copilot_import_tile.dart';
import 'package:budgets/features/settings/csv_import_sheet.dart';
import 'package:budgets/features/settings/dedupe_copilot_tile.dart';
import 'package:budgets/features/settings/migrate_copilot_rules_tile.dart';
import 'package:budgets/features/settings/settings_section.dart';
import 'package:budgets/features/settings/sync_status_tile.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/widgets/sync_status_nav_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        leading: SyncStatusNavButton(),
        middle: Text('Settings'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            const BanksAdvancedSection(),
            VSpace.xl,
            const SettingsHairline(style: SettingsSectionStyle.banks),
            VSpace.xl,
            const SyncStatusTile(),
            VSpace.xl,
            const SettingsHairline(style: SettingsSectionStyle.sync),
            VSpace.xl,
            const SettingsSectionHeader(
              icon: CupertinoIcons.wrench,
              title: 'Maintenance',
              style: SettingsSectionStyle.maintenance,
            ),
            VSpace.lg,
            const CopilotImportTile(),
            VSpace.lg,
            const MigrateCopilotRulesTile(),
            VSpace.lg,
            const DedupeCopilotTile(),
            VSpace.lg,
            SettingsToolRow(
              icon: CupertinoIcons.doc_text,
              title: 'Import CSV',
              caption: 'Escape hatch when a bank connection is broken.',
              onAction: () => CsvImportSheet.show(context),
              style: SettingsSectionStyle.maintenance,
            ),
            VSpace.xl,
            const SettingsHairline(style: SettingsSectionStyle.maintenance),
            VSpace.lg,
            const Text(
              'Budgets — personal spending by category with SimpleFIN.',
              style: SettingsType.sectionMeta,
            ),
          ],
        ),
      ),
    );
  }
}
