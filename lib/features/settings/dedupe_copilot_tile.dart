import 'package:budgets/providers/budgets_providers.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:budgets/widgets/app_card.dart';
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Remove Copilot duplicates', style: AppText.headline.small),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'When the same card exists in both Copilot and SimpleFIN, '
            'delete Copilot rows that match a SimpleFIN charge '
            '(same day, amount, and similar merchant). Keeps SimpleFIN; '
            'copies Copilot categories onto uncategorized twins.',
            style: AppText.body.medium,
          ),
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_message!, style: AppText.body.small),
          ],
          const SizedBox(height: AppSpacing.md),
          CupertinoButton.filled(
            onPressed: _busy ? null : _run,
            child: Text(_busy ? 'Scanning…' : 'Remove duplicates'),
          ),
        ],
      ),
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
