import 'dart:math' as math;

import 'package:budgets/features/trends/category_trend_point.dart';
import 'package:budgets/features/trends/category_trend_series.dart';
import 'package:budgets/features/trends/hann_annual_pace_kernel.dart';
import 'package:flutter/cupertino.dart';

/// Inclusive index span where a kernel centered at a day has support.
class KernelSupportSpan {
  const KernelSupportSpan({
    required this.startIndex,
    required this.endIndex,
  });

  final int startIndex;
  final int endIndex;
}

/// Builds annualized `/ yr` pace series with a tapered [HannAnnualPaceKernel].
///
/// Pace at day D is `yearDays ×` weighted mean daily cents under the kernel
/// (renormalized at chart edges). No separate CMA pass — the kernel is the
/// low-pass.
class AnnualPaceSmoother {
  const AnnualPaceSmoother({
    this.kernel = const HannAnnualPaceKernel(),
  });

  static const standard = AnnualPaceSmoother();

  final HannAnnualPaceKernel kernel;

  /// Calendar-year length used for annualization / trailing-year helpers.
  int get yearDays => kernel.yearDays;

  int get halfWidthDays => kernel.halfWidthDays;

  /// Scale a trailing total up to a full-year pace (budget month rows, etc.).
  static double annualizeTrailingTotal({
    required double windowTotalCents,
    required int observedDays,
    int yearDays = HannAnnualPaceKernel.defaultYearDays,
  }) {
    if (observedDays <= 0) return 0;
    if (observedDays >= yearDays) return windowTotalCents;
    return windowTotalCents * yearDays / observedDays;
  }

  CategoryTrendSeries seriesFromDailyMap({
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
    return CategoryTrendSeries(
      id: id,
      name: name,
      lineColor: lineColor,
      dotted: dotted,
      guide: guide,
      percentileAreaFill: percentileAreaFill,
      points: pointsFromDailyMap(
        chartDates: chartDates,
        dailyCents: dailyCents,
        historyFloor: historyFloor,
      ),
    );
  }

  List<CategoryTrendPoint> pointsFromDailyMap({
    required List<DateTime> chartDates,
    required Map<DateTime, double> dailyCents,
    required DateTime historyFloor,
  }) {
    if (chartDates.isEmpty) return const [];

    final dayCount = chartDates.length;
    final lastDayIndex = dayCount - 1;
    final dailyByIndex = List<double>.generate(
      dayCount,
      (dayIndex) => dailyCents[chartDates[dayIndex]] ?? 0,
    );

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
      final paceCents = annualizedPaceAt(
        dailyByIndex: dailyByIndex,
        centerIndex: dayIndex,
        historyStartIndex: historyStartIndex,
        lastDayIndex: lastDayIndex,
      );
      return CategoryTrendPoint(
        date: chartDates[dayIndex],
        rollingCents: paceCents,
        smoothedCents: paceCents,
      );
    });
  }

  /// Annualized pace at [centerIndex] from a dense daily series.
  double annualizedPaceAt({
    required List<double> dailyByIndex,
    required int centerIndex,
    required int historyStartIndex,
    required int lastDayIndex,
  }) {
    final samples = kernel.normalizedSamples(
      centerIndex: centerIndex,
      historyStartIndex: historyStartIndex,
      lastDayIndex: lastDayIndex,
    );
    if (samples.isEmpty) return 0;

    var meanDailyCents = 0.0;
    for (final sample in samples) {
      meanDailyCents += sample.weight * dailyByIndex[sample.dayIndex];
    }
    return meanDailyCents * kernel.yearDays;
  }

  /// How much an impulse of [amountCents] on [impulseIndex] adds to pace at
  /// [tapIndex] (same kernel + edge renorm as [annualizedPaceAt]).
  double impulseContributionCents({
    required double amountCents,
    required int impulseIndex,
    required int tapIndex,
    required int historyStartIndex,
    required int lastDayIndex,
  }) {
    final samples = kernel.normalizedSamples(
      centerIndex: tapIndex,
      historyStartIndex: historyStartIndex,
      lastDayIndex: lastDayIndex,
    );
    for (final sample in samples) {
      if (sample.dayIndex == impulseIndex) {
        return sample.weight * amountCents * kernel.yearDays;
      }
    }
    return 0;
  }

  /// Inclusive day span where the kernel at [centerIndex] has support.
  KernelSupportSpan supportSpan({
    required int centerIndex,
    required int historyStartIndex,
    required int lastDayIndex,
  }) {
    return KernelSupportSpan(
      startIndex: math.max(
        historyStartIndex,
        centerIndex - kernel.halfWidthDays,
      ),
      endIndex: math.min(
        lastDayIndex,
        centerIndex + kernel.halfWidthDays,
      ),
    );
  }
}
