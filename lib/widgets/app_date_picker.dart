import 'package:budgets/theme/app_theme.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' as material;

/// Picks a calendar date with a platform-appropriate UI.
///
/// Desktop (macOS / Windows / Linux) uses a Material calendar dialog — the
/// Cupertino wheel does not support pleasant mouse drag/fling. iOS / Android
/// keep the Cupertino wheel (with mouse drag enabled for trackpads).
Future<DateTime?> pickAppDate(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? minimumDate,
  DateTime? maximumDate,
}) async {
  final firstDate = (minimumDate ?? DateTime(1970)).startOfDay;
  final lastDate = (maximumDate ?? DateTime(2100)).startOfDay;
  var initial = initialDate.startOfDay;
  if (initial.isBefore(firstDate)) initial = firstDate;
  if (initial.isAfter(lastDate)) initial = lastDate;

  if (_prefersCalendarDatePicker) {
    return _pickCalendarDate(
      context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }
  return _pickCupertinoDate(
    context,
    initialDate: initial,
    minimumDate: minimumDate?.startOfDay,
    maximumDate: maximumDate?.startOfDay,
  );
}

bool get _prefersCalendarDatePicker {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.iOS:
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
      return false;
  }
}

Future<DateTime?> _pickCalendarDate(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return material.showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: (dialogContext, child) {
      return material.Theme(
        data: material.ThemeData(
          brightness: Brightness.dark,
          colorScheme: const material.ColorScheme.dark(
            primary: AppColors.accentPrimary,
            surface: AppColors.backgroundDepth2,
            onSurface: AppColors.textBright,
          ),
          dialogTheme: const material.DialogThemeData(
            backgroundColor: AppColors.backgroundDepth2,
          ),
        ),
        child: child!,
      );
    },
  ).then((picked) => picked?.startOfDay);
}

Future<DateTime?> _pickCupertinoDate(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? minimumDate,
  DateTime? maximumDate,
}) async {
  var draftDate = initialDate;
  final confirmed = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (pickerContext) {
      return Container(
        height: 280,
        decoration: const BoxDecoration(
          color: AppColors.backgroundDepth2,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(pickerContext).pop(false),
                  child: const Text('Cancel'),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.of(pickerContext).pop(true),
                  child: const Text('Done'),
                ),
              ],
            ),
            Expanded(
              child: ScrollConfiguration(
                behavior: const _MouseDragScrollBehavior(),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  minimumDate: minimumDate,
                  maximumDate: maximumDate,
                  onDateTimeChanged: (date) => draftDate = date,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  if (confirmed != true) return null;
  return draftDate.startOfDay;
}

class _MouseDragScrollBehavior extends CupertinoScrollBehavior {
  const _MouseDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.mouse,
      };
}
