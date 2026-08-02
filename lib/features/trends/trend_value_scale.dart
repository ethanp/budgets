import 'package:ethan_utils/ethan_utils.dart';
import 'package:spend_trends/features/trends/chart_date_layout.dart';

/// Y scale snapped to human-readable tick steps for the data max.
class TrendValueScale {
  const TrendValueScale({required this.maxCents, required this.tickCents});

  final double maxCents;
  final List<double> tickCents;

  factory TrendValueScale.niceForMax(double dataMaxCents) {
    const targetTickCount = 4;
    if (dataMaxCents <= 0) {
      return const TrendValueScale(
        maxCents: 10000,
        tickCents: [0, 2500, 5000, 7500, 10000],
      );
    }

    final roughStep = dataMaxCents / targetTickCount;
    final stepCents = roughStep.niceNumber(round: true);
    final niceMaxCents = (dataMaxCents / stepCents).ceil() * stepCents;
    final tickCents = <double>[];
    for (
      var tick = 0.0;
      tick <= niceMaxCents + stepCents * 0.001;
      tick += stepCents
    ) {
      tickCents.add(tick);
    }
    return TrendValueScale(maxCents: niceMaxCents, tickCents: tickCents);
  }

  double fractionFromBottom(double cents) => (cents / maxCents).clamp(0.0, 1.0);

  /// Y from the top of a fixed-height band (whisker strip).
  double yFromTop(double cents, double height) =>
      height * (1 - fractionFromBottom(cents));

  double yForCents(double cents, ChartDateLayout layout) {
    return layout.bottom - fractionFromBottom(cents) * layout.height;
  }
}
