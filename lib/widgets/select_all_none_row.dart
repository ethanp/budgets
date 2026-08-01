import 'package:spend_trends/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';

/// Select all / Select none shortcuts for multi-select match lists.
class SelectAllNoneRow extends StatelessWidget {
  const SelectAllNoneRow({
    super.key,
    required this.onSelectAll,
    required this.onSelectNone,
  });

  final VoidCallback onSelectAll;
  final VoidCallback onSelectNone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onSelectAll,
          child: const Text('Select all'),
        ),
        HSpace.md,
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onSelectNone,
          child: const Text('Select none'),
        ),
      ],
    );
  }
}
