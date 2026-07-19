import 'package:budgets/features/trends/category_trend_point.dart';
import 'package:budgets/features/trends/category_trend_series.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';

/// Inclusive day-index span for a centered (or edge-tapered) year window.
class CenteredRollingWindow {
  const CenteredRollingWindow({
    required this.startIndex,
    required this.endIndex,
  });

  final int startIndex;
  final int endIndex;

  int get observedDays => endIndex - startIndex + 1;
}

/// Centered-year annualize + edge taper + CMA smoothing for Trends pace lines.
class CenteredYearPace {
  CenteredYearPace._();

  /// Full centered window length (`2 * rollingHalfDays + 1`).
  static const rollingDays = 365;
  static const rollingHalfDays = 182;

  /// Near chart tips, inward look grows from [rollingHalfDays] → this, then
  /// annualize to [rollingDays].
  static const edgeInwardMaxDays = 240;

  static const smoothingHalfWindow = 21;
  static const smoothingPassCount = 3;

  /// Scale a partial window up to a full-year pace.
  static double annualizePartialWindow({
    required double windowTotalCents,
    required int observedDays,
  }) {
    if (observedDays <= 0) return 0;
    if (observedDays >= rollingDays) return windowTotalCents;
    return windowTotalCents * rollingDays / observedDays;
  }

  /// Centered year window at [dayIndex], with tapered inward edges.
  ///
  /// Interior: `[D−182, D+182]`. Within 182 days of a tip, the outward side
  /// uses whatever remains and the inward side grows from 182 → 240.
  static CenteredRollingWindow centeredRollingWindow({
    required int dayIndex,
    required int historyStartIndex,
    required int lastDayIndex,
  }) {
    final availableDays = lastDayIndex - historyStartIndex + 1;
    if (availableDays <= 0) {
      return CenteredRollingWindow(
        startIndex: dayIndex,
        endIndex: dayIndex,
      );
    }
    if (availableDays < rollingDays) {
      return CenteredRollingWindow(
        startIndex: historyStartIndex,
        endIndex: lastDayIndex,
      );
    }

    final availablePast = dayIndex - historyStartIndex;
    final availableFuture = lastDayIndex - dayIndex;
    if (availablePast >= rollingHalfDays &&
        availableFuture >= rollingHalfDays) {
      return CenteredRollingWindow(
        startIndex: dayIndex - rollingHalfDays,
        endIndex: dayIndex + rollingHalfDays,
      );
    }

    if (availableFuture < rollingHalfDays) {
      final outward = availableFuture;
      final inward = _taperedInwardDays(
        outwardDays: outward,
        availableInward: availablePast,
      );
      return CenteredRollingWindow(
        startIndex: dayIndex - inward,
        endIndex: dayIndex + outward,
      );
    }

    final outward = availablePast;
    final inward = _taperedInwardDays(
      outwardDays: outward,
      availableInward: availableFuture,
    );
    return CenteredRollingWindow(
      startIndex: dayIndex - outward,
      endIndex: dayIndex + inward,
    );
  }

  /// Build a series: centered-year annualize each day, then CMA-smooth.
  static CategoryTrendSeries seriesFromDailyMap({
    required String id,
    required String name,
    required Color lineColor,
    required Map<DateTime, double> dailyCents,
    required List<DateTime> chartDates,
    required DateTime historyFloor,
    bool dotted = false,
    bool guide = false,
    bool percentileAreaFill = false,
  }) {
    final rawPoints = annualizedCenteredPoints(
      chartDates: chartDates,
      dailyCents: dailyCents,
      historyFloor: historyFloor,
    );
    return CategoryTrendSeries(
      id: id,
      name: name,
      lineColor: lineColor,
      dotted: dotted,
      guide: guide,
      percentileAreaFill: percentileAreaFill,
      points: smoothedPoints(rawPoints),
    );
  }

  /// O(n) centered-year totals via prefix sums (contiguous [chartDates]).
  static List<CategoryTrendPoint> annualizedCenteredPoints({
    required List<DateTime> chartDates,
    required Map<DateTime, double> dailyCents,
    required DateTime historyFloor,
  }) {
    if (chartDates.isEmpty) return const [];

    final dayCount = chartDates.length;
    final lastDayIndex = dayCount - 1;
    final prefixSums = List<double>.filled(dayCount + 1, 0);
    for (var dayIndex = 0; dayIndex < dayCount; dayIndex++) {
      prefixSums[dayIndex + 1] =
          prefixSums[dayIndex] + (dailyCents[chartDates[dayIndex]] ?? 0);
    }

    var historyStartIndex = 0;
    while (historyStartIndex < dayCount &&
        chartDates[historyStartIndex].isBefore(historyFloor)) {
      historyStartIndex++;
    }

    return List.generate(dayCount, (dayIndex) {
      if (dayIndex < historyStartIndex) {
        return CategoryTrendPoint(
          date: chartDates[dayIndex],
          rollingCents: 0,
          smoothedCents: 0,
        );
      }
      final window = centeredRollingWindow(
        dayIndex: dayIndex,
        historyStartIndex: historyStartIndex,
        lastDayIndex: lastDayIndex,
      );
      final windowTotal =
          prefixSums[window.endIndex + 1] - prefixSums[window.startIndex];
      return CategoryTrendPoint(
        date: chartDates[dayIndex],
        rollingCents: annualizePartialWindow(
          windowTotalCents: windowTotal,
          observedDays: window.observedDays,
        ),
        smoothedCents: 0,
      );
    });
  }

  static List<CategoryTrendPoint> smoothedPoints(
    List<CategoryTrendPoint> rawPoints,
  ) {
    var smoothedValues = rawPoints.mapL((point) => point.rollingCents);
    for (var pass = 0; pass < smoothingPassCount; pass++) {
      smoothedValues = centeredMovingAverage(smoothedValues);
    }
    return rawPoints.mapLWithIndex(
      (rawPoint, pointIndex) => CategoryTrendPoint(
        date: rawPoint.date,
        rollingCents: rawPoint.rollingCents,
        smoothedCents: smoothedValues[pointIndex],
      ),
    );
  }

  /// Centered moving average via prefix sums; full width shifts inward at tips.
  static List<double> centeredMovingAverage(
    List<double> values, {
    int halfWindow = smoothingHalfWindow,
  }) {
    if (values.isEmpty) return const [];
    final lastIndex = values.length - 1;
    final fullSpan = 2 * halfWindow + 1;
    final prefixSums = List<double>.filled(values.length + 1, 0);
    for (var index = 0; index < values.length; index++) {
      prefixSums[index + 1] = prefixSums[index] + values[index];
    }
    return List.generate(values.length, (index) {
      if (values.length < fullSpan) {
        return prefixSums[values.length] / values.length;
      }
      var firstIndex = index - halfWindow;
      var lastWindowIndex = index + halfWindow;
      if (firstIndex < 0) {
        firstIndex = 0;
        lastWindowIndex = fullSpan - 1;
      } else if (lastWindowIndex > lastIndex) {
        lastWindowIndex = lastIndex;
        firstIndex = lastWindowIndex - fullSpan + 1;
      }
      return (prefixSums[lastWindowIndex + 1] - prefixSums[firstIndex]) /
          (lastWindowIndex - firstIndex + 1);
    });
  }

  static int _taperedInwardDays({
    required int outwardDays,
    required int availableInward,
  }) {
    final edgeProgress = (rollingHalfDays - outwardDays) / rollingHalfDays;
    final tapered = rollingHalfDays +
        (edgeInwardMaxDays - rollingHalfDays) * edgeProgress;
    final inward = tapered.round();
    if (inward <= availableInward) return inward;
    return availableInward;
  }
}
