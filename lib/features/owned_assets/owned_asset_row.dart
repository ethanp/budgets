import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:spend_trends/domain/owned_asset.dart';

/// Name, kind, and current value for one owned asset in the Banks list.
class OwnedAssetRow extends StatelessWidget {
  const OwnedAssetRow({
    required this.ownedAsset,
    required this.amountColumnWidth,
    this.selected = false,
    this.onActivated,
  });

  final OwnedAssetWithValuations ownedAsset;
  final double amountColumnWidth;
  final bool selected;
  final VoidCallback? onActivated;

  @override
  Widget build(BuildContext context) {
    final amountStyle = ownedAsset.currentValueCents == 0
        ? EText.body.medium.copyWith(color: EColors.textMuted)
        : EText.body.medium.copyWith(fontWeight: FontWeight.w600);
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ownedAsset.asset.name,
                style: EText.body.medium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: ELayout.spaceXs),
              Text(
                ownedAsset.asset.kind.legendLabel,
                style: EText.caption.copyWith(color: EColors.textMuted),
              ),
            ],
          ),
        ),
        SizedBox(
          width: amountColumnWidth,
          child: Text(
            formatCents(ownedAsset.currentValueCents),
            style: amountStyle,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );

    final padded = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      child: body,
    );
    final decorated = selected
        ? ESurface(
            kind: ESurfaceKind.tinted,
            accent: ownedAsset.asset.kind.lineColor,
            padding: const EdgeInsets.symmetric(
              horizontal: ELayout.spaceSm,
              vertical: ELayout.spaceXs,
            ),
            borderRadius: ELayout.borderRadiusSm,
            child: body,
          )
        : padded;

    if (onActivated == null) return decorated;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onActivated,
      child: decorated,
    );
  }
}
