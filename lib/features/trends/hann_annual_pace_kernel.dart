import 'dart:math' as math;

/// One day in a renormalized kernel support.
class KernelWeightSample {
  const KernelWeightSample({required this.dayIndex, required this.weight});

  final int dayIndex;

  /// Normalized weight (samples at a center sum to 1).
  final double weight;
}

/// Hann-tapered support for centered annualized pace.
///
/// Weights are 1 at the center and fall to 0 at ±[halfWidthDays], so large
/// deposits fade in/out instead of cliff-entering a hard box window.
class HannAnnualPaceKernel {
  const HannAnnualPaceKernel({
    this.halfWidthDays = defaultHalfWidthDays,
    this.yearDays = defaultYearDays,
  });

  /// ~36-month support (`2 * halfWidth + 1` ≈ 1095 days) so seasonal /
  /// bonus-scale lumps fade instead of drawing multi-month waves.
  static const defaultHalfWidthDays = 547;

  /// Annualize mean daily cents onto a year.
  static const defaultYearDays = 365;

  final int halfWidthDays;
  final int yearDays;

  int get supportDays => 2 * halfWidthDays + 1;

  /// Raw Hann weight for offset from center; 0 outside the support.
  double rawWeight(int offsetDays) {
    final absOffset = offsetDays.abs();
    if (absOffset > halfWidthDays) return 0;
    if (halfWidthDays == 0) return 1;
    return 0.5 * (1 + math.cos(math.pi * absOffset / halfWidthDays));
  }

  /// Weights over available history at [centerIndex], renormalized to sum to 1.
  List<KernelWeightSample> normalizedSamples({
    required int centerIndex,
    required int historyStartIndex,
    required int lastDayIndex,
  }) {
    if (centerIndex < historyStartIndex || centerIndex > lastDayIndex) {
      return const [];
    }

    final firstIndex = math.max(historyStartIndex, centerIndex - halfWidthDays);
    final lastIndex = math.min(lastDayIndex, centerIndex + halfWidthDays);

    final rawSamples = <KernelWeightSample>[];
    var weightSum = 0.0;
    for (var dayIndex = firstIndex; dayIndex <= lastIndex; dayIndex++) {
      final weight = rawWeight(dayIndex - centerIndex);
      if (weight <= 0) continue;
      rawSamples.add(KernelWeightSample(dayIndex: dayIndex, weight: weight));
      weightSum += weight;
    }
    if (weightSum <= 0) return const [];

    return [
      for (final sample in rawSamples)
        KernelWeightSample(
          dayIndex: sample.dayIndex,
          weight: sample.weight / weightSum,
        ),
    ];
  }
}
