import 'package:ethan_utils/ethan_utils.dart';
import 'package:spend_trends/features/trends/chart_date_layout.dart';

/// Y scale snapped to human-readable tick steps for the data max.
class const TrendValueScale({
  required final double maxCents,
  required final List<double> tickCents,
}) {
  factory niceForMax(double dataMaxCents) {
    final scale = NiceValueScale.forMax(dataMaxCents, fallbackMax: 10000);
    return TrendValueScale(maxCents: scale.max, tickCents: scale.ticks);
  }

  double fractionFromBottom(double cents) => (cents / maxCents).clamp(0.0, 1.0);

  /// Y from the top of a fixed-height band (whisker strip).
  double yFromTop(double cents, double height) =>
      height * (1 - fractionFromBottom(cents));

  double yForCents(double cents, ChartDateLayout layout) {
    return layout.bottom - fractionFromBottom(cents) * layout.height;
  }
}
