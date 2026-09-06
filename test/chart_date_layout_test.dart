import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spend_trends/features/trends/chart_date_layout.dart';

void main() {
  group('ChartDateLayout.dateTicks', () {
    test('multi-year charts tick each January and skip mid-year months', () {
      final layout = _layout(
        minDate: DateTime(2021, 3, 1),
        maxDate: DateTime(2026, 9, 1),
        width: 720,
      );

      expect(layout.dateTicks(), [
        DateTime(2022),
        DateTime(2023),
        DateTime(2024),
        DateTime(2025),
        DateTime(2026),
      ]);
    });

    test('same-year multi-month charts keep quarter-month ticks', () {
      final layout = _layout(
        minDate: DateTime(2026, 2, 1),
        maxDate: DateTime(2026, 11, 1),
        width: 720,
      );

      expect(layout.dateTicks(), [
        DateTime(2026, 4, 1),
        DateTime(2026, 7, 1),
        DateTime(2026, 10, 1),
      ]);
    });
  });
}

ChartDateLayout _layout({
  required DateTime minDate,
  required DateTime maxDate,
  required double width,
}) {
  return ChartDateLayout(
    size: Size(width, 200),
    leftPadding: 48,
    rightPadding: 12,
    topPadding: 12,
    bottomPadding: 24,
    minDate: minDate,
    maxDate: maxDate,
  );
}
