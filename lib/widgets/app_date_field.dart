import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Tappable labeled date row that opens the app date picker flow.
class AppDateField extends StatelessWidget {
  const AppDateField({
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
        padding: const EdgeInsets.all(AppMetrics.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppMetrics.borderRadius(AppMetrics.radiusSm),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Text(label, style: AppText.body),
            const Spacer(),
            Text(
              DateFormat.yMMMd().format(date),
              style: AppText.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: AppMetrics.spaceSm),
            const Icon(
              Icons.calendar_today,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
