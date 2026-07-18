import 'package:budgets/services/simplefin/simplefin_access_store.dart';
import 'package:budgets/services/simplefin/simplefin_client.dart';
import 'package:budgets/services/simplefin/simplefin_models.dart';
import 'package:budgets/domain/account.dart';
import 'package:budgets/features/settings/copilot_import_tile.dart';
import 'package:budgets/features/settings/csv_import_sheet.dart';
import 'package:budgets/features/settings/dedupe_copilot_tile.dart';
import 'package:budgets/features/settings/sync_status_tile.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/util/money_format.dart';
import 'package:budgets/widgets/app_card.dart';
import 'package:budgets/widgets/sync_status_nav_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            connectionAsync.when(
              data: _connectionCard,
              loading: () => const AppCard(
                child: CupertinoActivityIndicator(),
              ),
              error: (error, _) => AppCard(
                child: SelectableText(
                  '$error',
                  style: AppText.body.medium.error,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SyncStatusTile(),
            const SizedBox(height: AppSpacing.lg),
            const CopilotImportTile(),
            const SizedBox(height: AppSpacing.lg),
            const DedupeCopilotTile(),
            const SizedBox(height: AppSpacing.lg),
            _csvEscapeHatchCard(),
            const SizedBox(height: AppSpacing.lg),
            _aboutCard(),
          ],
        ),
      ),
    );
  }

  Widget _csvEscapeHatchCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Import', style: AppText.headline.small),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Generic CSV escape hatch when a bank connection is broken.',
            style: AppText.body.medium,
          ),
          const SizedBox(height: AppSpacing.md),
          CupertinoButton.filled(
            onPressed: () => CsvImportSheet.show(context),
            child: const Text('Import CSV'),
          ),
        ],
      ),
    );
  }

  Widget _aboutCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About', style: AppText.headline.small),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Budgets — personal spending by category with SimpleFIN.',
            style: AppText.body.medium,
          ),
        ],
      ),
    );
  }

  Widget _connectionCard(ConnectionStatus status) {
    if (!status.isConnected) return _disconnectedCard();
    return _connectedCard(status);
  }

  Widget _disconnectedCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bank connection', style: AppText.headline.small),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Paste a one-time Setup Token, or put the claimed Access URL in '
            '.env as ${SimpleFinAccessStore.envAccessUrlKey} (survives reinstall).',
            style: AppText.body.medium,
          ),
          const SizedBox(height: AppSpacing.md),
          CupertinoButton.filled(
            onPressed: _busy ? null : _openSimpleFin,
            child: const Text('Open SimpleFIN'),
          ),
          const SizedBox(height: AppSpacing.md),
          CupertinoTextField(
            controller: _tokenController,
            placeholder: 'Paste Setup Token',
            maxLines: 4,
            minLines: 3,
            padding: const EdgeInsets.all(AppSpacing.md),
            style: AppText.body.medium.primary,
          ),
          if (_actionError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SelectableText(_actionError!, style: AppText.body.small.error),
          ],
          const SizedBox(height: AppSpacing.md),
          CupertinoButton.filled(
            onPressed: _busy ? null : _connect,
            child: _busy
                ? const CupertinoActivityIndicator()
                : const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Widget _connectedCard(ConnectionStatus status) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Bank connection', style: AppText.headline.small),
              const Spacer(),
              Text(
                status.fromEnv ? 'Connected (.env)' : 'Connected',
                style: AppText.body.small.success.semibold,
              ),
            ],
          ),
          if (status.fromEnv) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Using ${SimpleFinAccessStore.envAccessUrlKey} from .env',
              style: AppText.body.small,
            ),
          ],
          if (status.lastSyncedAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Updated ${_formatRelative(status.lastSyncedAt!)}',
              style: AppText.body.small,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ...status.accounts.map(_accountRow),
          if (status.errors.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ...status.errors.map(
              (error) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: SelectableText(
                  error.message,
                  style: AppText.body.small.error,
                ),
              ),
            ),
          ],
          if (_actionError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SelectableText(_actionError!, style: AppText.body.small.error),
          ],
          const SizedBox(height: AppSpacing.md),
          _connectionActions(),
        ],
      ),
    );
  }

  Widget _connectionActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CupertinoButton.filled(
              onPressed: _busy ? null : _refresh,
              child: _busy
                  ? const CupertinoActivityIndicator()
                  : const Text('Refresh now'),
            ),
            const SizedBox(width: AppSpacing.sm),
            CupertinoButton(
              onPressed: _busy ? null : _disconnect,
              child: Text('Disconnect', style: AppText.body.medium.error),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        CupertinoButton(
          onPressed: _busy ? null : _refreshFullHistory,
          child: Text(
            'Refresh full history',
            style: AppText.body.medium,
          ),
        ),
      ],
    );
  }

  Widget _accountRow(Account account) {
    final needsRelink = account.status == AccountStatus.needsRelink;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name, style: AppText.body.large.semibold),
                Text(
                  needsRelink ? 'Needs re-link' : account.status.name,
                  style: needsRelink
                      ? AppText.body.small.warning
                      : AppText.body.small,
                ),
              ],
            ),
          ),
          Text(
            formatCents(account.balanceCents),
            style: AppText.body.medium.semibold,
          ),
        ],
      ),
    );
  }

  Future<void> _openSimpleFin() async {
    final uri = Uri.parse(simpleFinCreateUrl);
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
    await _runBusyAction(() async {
      final fromEnv =
          ref.read(simpleFinAccessStoreProvider).isConfiguredInEnv;
      if (fromEnv) {
        setState(() {
          _actionError =
              'Connection comes from .env. Remove '
              '${SimpleFinAccessStore.envAccessUrlKey} and restart to disconnect.';
        });
        return;
      }
      final ingest = await ref.read(transactionIngestProvider.future);
      await ingest.disconnect(wipeLocalData: true);
      ref.read(dataRevisionProvider.notifier).bump();
    });
  }

  String _formatRelative(DateTime time) {
    final local = time.toLocal();
    final difference = DateTime.now().difference(local);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat.MMMd().format(local);
  }
}
