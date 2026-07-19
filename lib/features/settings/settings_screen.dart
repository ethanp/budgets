import 'package:budgets/services/simplefin/simplefin_access_store.dart';
import 'package:budgets/services/simplefin/simplefin_client.dart';
import 'package:budgets/services/simplefin/simplefin_models.dart';
import 'package:budgets/features/settings/bank_connection_panel.dart';
import 'package:budgets/features/settings/copilot_import_tile.dart';
import 'package:budgets/features/settings/csv_import_sheet.dart';
import 'package:budgets/features/settings/dedupe_copilot_tile.dart';
import 'package:budgets/features/settings/migrate_copilot_rules_tile.dart';
import 'package:budgets/features/settings/settings_section.dart';
import 'package:budgets/features/settings/sync_status_tile.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/widgets/sync_status_nav_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _busy = false;
  String? _actionError;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionAsync = ref.watch(connectionStatusProvider);

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
            const SettingsSectionHeader(
              icon: CupertinoIcons.building_2_fill,
              title: 'Banks',
              style: SettingsSectionStyle.banks,
            ),
            VSpace.md,
            connectionAsync.when(
              data: _banksBody,
              loading: () => const CupertinoActivityIndicator(),
              error: (error, _) => SelectableText(
                '$error',
                style: AppText.body.medium.error,
              ),
            ),
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
            _csvToolRow(),
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

  Widget _banksBody(ConnectionStatus status) {
    if (!status.isConnected) return _disconnectedBody();
    return BankConnectionPanel(
      status: status,
      busy: _busy,
      actionError: _actionError,
      onRefresh: _refresh,
      onRefreshFullHistory: _refreshFullHistory,
      onAddAccount: _openSimpleFinBridge,
      onDisconnect: _disconnect,
      style: SettingsSectionStyle.banks,
    );
  }

  Widget _disconnectedBody() {
    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(
        primaryColor: SettingsSectionStyle.banks.accent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paste a Setup Token from SimpleFIN, or set '
            '${SimpleFinAccessStore.envAccessUrlKey} in .env.',
            style: SettingsType.sectionMeta,
          ),
          VSpace.md,
          CupertinoButton.filled(
            onPressed: _busy ? null : _openSimpleFin,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.arrow_up_right_square, size: 18),
                HSpace.sm,
                Text('Open SimpleFIN'),
              ],
            ),
          ),
          VSpace.md,
          CupertinoTextField(
            controller: _tokenController,
            placeholder: 'Paste Setup Token',
            maxLines: 4,
            minLines: 3,
            padding: const EdgeInsets.all(AppSpacing.md),
            style: AppText.body.medium.bright,
          ),
          if (_actionError != null) ...[
            VSpace.sm,
            SelectableText(_actionError!, style: AppText.body.small.error),
          ],
          VSpace.md,
          CupertinoButton.filled(
            onPressed: _busy ? null : _connect,
            child: _busy
                ? const CupertinoActivityIndicator()
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.link, size: 18),
                      HSpace.sm,
                      Text('Connect'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _csvToolRow() {
    return SettingsToolRow(
      icon: CupertinoIcons.doc_text,
      title: 'Import CSV',
      caption: 'Escape hatch when a bank connection is broken.',
      onAction: () => CsvImportSheet.show(context),
      style: SettingsSectionStyle.maintenance,
    );
  }

  Future<void> _openSimpleFin() async {
    final uri = Uri.parse(simpleFinCreateUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openSimpleFinBridge() async {
    final uri = Uri.parse(simpleFinBridgeUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _applyCategoryRules() async {
    final categorizer = await ref.read(categorizerProvider.future);
    await categorizer.applyRulesToUncategorized();
  }

  Future<void> _runBusyAction(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await action();
    } on SimpleFinClaimException catch (error) {
      setState(() => _actionError = error.message);
    } on SimpleFinFetchException catch (error) {
      setState(() => _actionError = error.message);
    } catch (error) {
      setState(() => _actionError = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    await _runBusyAction(() async {
      final ingest = await ref.read(transactionIngestProvider.future);
      final result = await ingest.claimAndPull(_tokenController.text);
      await _applyCategoryRules();
      _tokenController.clear();
      ref.read(dataRevisionProvider.notifier).bump();
      final accessUrl = result.claimedAccessUrl;
      if (accessUrl != null && mounted) {
        await _promptPersistAccessUrl(accessUrl);
      }
    });
  }

  Future<void> _promptPersistAccessUrl(Uri accessUrl) async {
    await Clipboard.setData(ClipboardData(text: accessUrl.toString()));
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Save Access URL to .env'),
          content: const Text(
            'Setup Tokens are one-time. The Access URL was copied to the clipboard.\n\n'
            'Add this line to budgets/.env so reconnects survive reinstall:\n\n'
            '${SimpleFinAccessStore.envAccessUrlKey}=<paste>\n\n'
            'Then hot-restart or rebuild the app.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _refresh() async {
    await _runBusyAction(() async {
      final ingest = await ref.read(transactionIngestProvider.future);
      await ingest.pullAndUpsert();
      await _applyCategoryRules();
      ref.read(dataRevisionProvider.notifier).bump();
    });
  }

  Future<void> _refreshFullHistory() async {
    await _runBusyAction(() async {
      final ingest = await ref.read(transactionIngestProvider.future);
      final result = await ingest.pullAndUpsert(fullHistory: true);
      await _applyCategoryRules();
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted && result.errors.isNotEmpty) {
        setState(
          () => _actionError =
              'Pulled ${result.transactionCount} txs; '
              '${result.errors.length} bridge warning(s).',
        );
      }
    });
  }

  Future<void> _disconnect() async {
    final fromEnv = ref.read(simpleFinAccessStoreProvider).isConfiguredInEnv;
    if (fromEnv) {
      setState(() {
        _actionError =
            'Connection comes from .env. Remove '
            '${SimpleFinAccessStore.envAccessUrlKey} and restart to disconnect.';
      });
      return;
    }

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Disconnect & erase local data?'),
          content: const Text(
            'Removes the SimpleFIN connection and deletes all local accounts '
            'and transactions. If device sync is enabled, those deletes can '
            'propagate to your server. Reconnect later with a new Setup Token.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Disconnect & erase'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    await _runBusyAction(() async {
      final ingest = await ref.read(transactionIngestProvider.future);
      await ingest.disconnect(wipeLocalData: true);
      ref.read(dataRevisionProvider.notifier).bump();
    });
  }
}
