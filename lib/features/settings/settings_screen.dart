import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spend_trends/features/banks/banks_advanced_section.dart';
import 'package:spend_trends/features/settings/copilot_import_tile.dart';
import 'package:spend_trends/features/settings/csv_import_sheet.dart';
import 'package:spend_trends/features/settings/remove_duplicate_transactions_tile.dart';
import 'package:spend_trends/features/settings/unlock_copilot_categories_tile.dart';
import 'package:spend_trends/features/settings/settings_section.dart';
import 'package:spend_trends/features/settings/sync_status_tile.dart';
import 'package:spend_trends/widgets/sync_status_nav_button.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const SyncStatusNavButton(),
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.spaceLg,
            AppMetrics.spaceMd,
            AppMetrics.spaceLg,
            32,
          ),
          children: [
            const BanksAdvancedSection(),
            const SizedBox(height: AppMetrics.spaceXl),
            const SettingsHairline(style: SettingsSectionStyle.banks),
            const SizedBox(height: AppMetrics.spaceXl),
            const SyncStatusTile(),
            const SizedBox(height: AppMetrics.spaceXl),
            const SettingsHairline(style: SettingsSectionStyle.sync),
            const SizedBox(height: AppMetrics.spaceXl),
            const SettingsSectionHeader(
              icon: Icons.build,
              title: 'Maintenance',
              style: SettingsSectionStyle.maintenance,
            ),
            const SizedBox(height: AppMetrics.spaceLg),
            const CopilotImportTile(),
            const SizedBox(height: AppMetrics.spaceLg),
            const UnlockCopilotCategoriesTile(),
            const SizedBox(height: AppMetrics.spaceLg),
            const RemoveDuplicateTransactionsTile(),
            const SizedBox(height: AppMetrics.spaceLg),
            SettingsToolRow(
              icon: Icons.description,
              title: 'Import CSV',
              caption: 'Escape hatch when a bank connection is broken.',
              onAction: () => CsvImportSheet.show(context),
              style: SettingsSectionStyle.maintenance,
            ),
            const SizedBox(height: AppMetrics.spaceXl),
            const SettingsHairline(style: SettingsSectionStyle.maintenance),
            const SizedBox(height: AppMetrics.spaceLg),
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
