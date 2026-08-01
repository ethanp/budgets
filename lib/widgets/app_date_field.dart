import 'package:spend_trends/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

/// Tappable labeled date row that opens the app date picker flow.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.borderDepth1),
        ),
        child: Row(
          children: [
            Text(label, style: AppText.body.medium),
            const Spacer(),
            Text(
              DateFormat.yMMMd().format(date),
              style: AppText.body.medium.semibold,
            ),
            HSpace.sm,
            const Icon(
              CupertinoIcons.calendar,
              size: 18,
              color: AppColors.textSupport,
            ),
          ],
        ),
      ),
    );
  }
}
