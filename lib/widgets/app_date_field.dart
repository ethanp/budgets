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
        padding: const EdgeInsets.all(ELayout.spaceMd),
        decoration: BoxDecoration(
          color: EColors.surface,
          borderRadius: ELayout.borderRadius(ELayout.radiusSm),
          border: Border.all(color: EColors.border),
        ),
        child: Row(
          children: [
            Text(label, style: EText.body),
            const Spacer(),
            Text(
              DateFormat.yMMMd().format(date),
              style: EText.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: ELayout.spaceSm),
            const Icon(
              Icons.calendar_today,
              size: 18,
              color: EColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
