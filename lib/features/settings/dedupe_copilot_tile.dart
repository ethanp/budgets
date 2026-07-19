import 'package:budgets/features/settings/settings_section.dart';
import 'package:budgets/providers/budgets_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Removes Copilot transactions that duplicate SimpleFIN charges on the same
/// account (matched by last-4 mask).
class DedupeCopilotTile extends ConsumerStatefulWidget {
  const DedupeCopilotTile({super.key});

  @override
  ConsumerState<DedupeCopilotTile> createState() => _DedupeCopilotTileState();
}

class _DedupeCopilotTileState extends ConsumerState<DedupeCopilotTile> {
  bool _busy = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    return SettingsToolRow(
      icon: CupertinoIcons.square_stack_3d_up,
      title: 'Remove Copilot duplicates',
      caption:
          'Drop Copilot rows that match SimpleFIN (day, amount, merchant).',
      onAction: _run,
      style: SettingsSectionStyle.maintenance,
      busy: _busy,
      message: _message,
    );
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final deduper = await ref.read(copilotSimplefinDeduperProvider.future);
      final result = await deduper.removeCopilotDuplicates();
      ref.read(dataRevisionProvider.notifier).bump();
      setState(() {
        if (result.linkedAccountMasks == 0) {
          _message =
              'No overlapping Copilot + SimpleFIN accounts found '
              '(need matching last-4 digits).';
        } else {
          _message =
              'Removed ${result.deletedCopilotCount} Copilot duplicates '
              'across ${result.linkedAccountMasks} linked accounts'
              '${result.categoriesCopiedToSimplefin > 0 ? '; copied ${result.categoriesCopiedToSimplefin} categories' : ''}.';
        }
      });
    } catch (error) {
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
