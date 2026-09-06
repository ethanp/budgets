import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:spend_trends/domain/life_event.dart';
import 'package:spend_trends/domain/stay_chain.dart';
import 'package:spend_trends/features/trends/category_trend_series.dart';
import 'package:spend_trends/features/trends/chart_date_layout.dart';
import 'package:spend_trends/features/trends/trend_value_scale.dart';

/// Laid-out Trends chart: date axis, value scale, and drawable series.
class CategoryTrendPlot._({
  required final ChartDateLayout layout,
  required final TrendValueScale scale,
  required final List<CategoryTrendSeries> drawableSeries,
  final int? housingLane,
  final int? jobLane,
  final int? lifeEventLane,
}) {
  static const leftPadding = 48.0;
  static const rightPadding = 12.0;
  static const bottomPadding = 24.0;
  static const overlayLaneHeight = 34.0;
  static const _plotTopInset = 12.0;

  factory from({
    required Size size,
    required List<CategoryTrendSeries> seriesList,
    StayChain? housingChain,
    StayChain? jobChain,
    List<LifeEvent> lifeEvents = const [],
  }) {
    final drawableSeries = [
      for (final series in seriesList)
        if (series.canPlot) series,
    ];
    var nextLane = 0;
    final housingLane = housingChain != null && !housingChain.isEmpty
        ? nextLane++
        : null;
    final jobLane = jobChain != null && !jobChain.isEmpty ? nextLane++ : null;
    final lifeEventLane = lifeEvents.isNotEmpty ? nextLane++ : null;
    return CategoryTrendPlot._(
      layout: _dateRangeLayout(
        size,
        drawableSeries,
        overlayLaneCount: nextLane,
      ),
      scale: _niceScaleForSmoothedMax(drawableSeries),
      drawableSeries: drawableSeries,
      housingLane: housingLane,
      jobLane: jobLane,
      lifeEventLane: lifeEventLane,
    );
  }

  static ChartDateLayout _dateRangeLayout(
    Size size,
    List<CategoryTrendSeries> drawableSeries, {
    required int overlayLaneCount,
  }) {
    final firstDate = drawableSeries
        .map((series) => series.points.first.date)
        .reduce((earlier, later) => earlier.isBefore(later) ? earlier : later);
    final lastDate = drawableSeries
        .map((series) => series.points.last.date)
        .reduce((earlier, later) => earlier.isAfter(later) ? earlier : later);
    return ChartDateLayout(
      size: size,
      leftPadding: leftPadding,
      rightPadding: rightPadding,
      topPadding: overlayLaneCount == 0
          ? _plotTopInset
          : overlayLaneCount * overlayLaneHeight,
      bottomPadding: bottomPadding,
      minDate: firstDate,
      maxDate: lastDate,
    );
  }

  static TrendValueScale _niceScaleForSmoothedMax(
    List<CategoryTrendSeries> drawableSeries,
  ) {
    var highest = 0.0;
    for (final series in drawableSeries) {
      for (final point in series.points) {
        highest = math.max(highest, point.smoothedCents);
      }
    }
    return TrendValueScale.niceForMax(highest);
  }

  DateTime dateForX(double x) => layout.dateForX(x);
}
