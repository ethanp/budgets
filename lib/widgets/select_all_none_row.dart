import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';

/// Select all / Select none shortcuts for multi-select match lists.
class SelectAllNoneRow extends StatelessWidget {
  const SelectAllNoneRow({
    required this.onAllSelected,
    required this.onNoneSelected,
  });

  final VoidCallback onAllSelected;
  final VoidCallback onNoneSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ELayout.spaceMd,
      runSpacing: ELayout.spaceXs,
      children: [
        TextButton(
          onPressed: onAllSelected,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: ELayout.spaceSm),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('Select all'),
        ),
        TextButton(
          onPressed: onNoneSelected,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: ELayout.spaceSm),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('Select none'),
        ),
      ],
    );
  }
}
