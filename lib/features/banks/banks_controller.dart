import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/services/simplefin/simplefin_access_store.dart';
import 'package:budgets/services/simplefin/simplefin_client.dart';
import 'package:budgets/services/simplefin/simplefin_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class BanksActionState {
  const BanksActionState({this.busy = false, this.actionError});

  final bool busy;
  final String? actionError;

  BanksActionState copyWith({bool? busy, String? actionError, bool clearError = false}) {
    return BanksActionState(
      busy: busy ?? this.busy,
      actionError: clearError ? null : (actionError ?? this.actionError),
    );
  }
}

final banksControllerProvider =
    NotifierProvider<BanksController, BanksActionState>(BanksController.new);

/// Shared SimpleFIN connect / sync / disconnect actions for Banks + Settings.
class BanksController extends Notifier<BanksActionState> {
  @override
  BanksActionState build() => const BanksActionState();

  Future<void> openSimpleFin() async {
    await launchUrl(
      Uri.parse(simpleFinCreateUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> openSimpleFinBridge() async {
    await launchUrl(
      Uri.parse(simpleFinBridgeUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Claims a Setup Token and pulls. Returns a new Access URL when claim created one.
  Future<Uri?> connect(String setupToken) async {
    Uri? claimedAccessUrl;
    await _runBusyAction(() async {
      final ingest = await ref.read(transactionIngestProvider.future);
      final result = await ingest.claimAndPull(setupToken);
      await _applyCategoryRules();
      ref.read(dataRevisionProvider.notifier).bump();
      claimedAccessUrl = result.claimedAccessUrl;
    });
    return claimedAccessUrl;
  }

  Future<void> syncLatest() async {
    await _runBusyAction(() async {
      final ingest = await ref.read(transactionIngestProvider.future);
      await ingest.pullAndUpsert();
      await _applyCategoryRules();
      ref.read(dataRevisionProvider.notifier).bump();
    });
  }

  Future<void> refreshFullHistory() async {
    await _runBusyAction(() async {
      final ingest = await ref.read(transactionIngestProvider.future);
      final result = await ingest.pullAndUpsert(fullHistory: true);
      await _applyCategoryRules();
      ref.read(dataRevisionProvider.notifier).bump();
      if (result.errors.isNotEmpty) {
        state = state.copyWith(
          actionError:
              'Pulled ${result.transactionCount} txs; '
              '${result.errors.length} bridge warning(s).',
        );
      }
    });
  }

  /// Returns false when disconnect is blocked (e.g. connection comes from `.env`).
  Future<bool> disconnect({required bool confirmed}) async {
    final fromEnv = ref.read(simpleFinAccessStoreProvider).isConfiguredInEnv;
    if (fromEnv) {
      state = state.copyWith(
        actionError:
            'Connection comes from .env. Remove '
            '${SimpleFinAccessStore.envAccessUrlKey} and restart to disconnect.',
      );
      return false;
    }
    if (!confirmed) return false;

    await _runBusyAction(() async {
      final ingest = await ref.read(transactionIngestProvider.future);
      await ingest.disconnect(wipeLocalData: true);
      ref.read(dataRevisionProvider.notifier).bump();
    });
    return true;
  }

  Future<void> _applyCategoryRules() async {
    final categorizer = await ref.read(categorizerProvider.future);
    await categorizer.applyRulesToUncategorized();
  }

  Future<void> _runBusyAction(Future<void> Function() action) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await action();
    } on SimpleFinClaimException catch (error) {
      state = state.copyWith(actionError: error.message);
    } on SimpleFinFetchException catch (error) {
      state = state.copyWith(actionError: error.message);
    } catch (error) {
      state = state.copyWith(actionError: '$error');
    } finally {
      state = state.copyWith(busy: false);
    }
  }
}

Future<void> promptPersistAccessUrl(
  BuildContext context,
  Uri accessUrl,
) async {
  await Clipboard.setData(ClipboardData(text: accessUrl.toString()));
  if (!context.mounted) return;
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

Future<bool> confirmDisconnectAndErase(BuildContext context) async {
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
  return confirmed == true;
}
