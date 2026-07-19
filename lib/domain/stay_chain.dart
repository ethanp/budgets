import 'package:budgets/theme/app_theme.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

/// Which life-chain timeline a stay belongs to.
enum LifeChainKind {
  housing,
  job;

  String get screenTitle => switch (this) {
        LifeChainKind.housing => 'Housing',
        LifeChainKind.job => 'Job',
      };

  String get emptyHeroCaption => switch (this) {
        LifeChainKind.housing => 'No housing yet',
        LifeChainKind.job => 'No job yet',
      };

  String get currentCaption => switch (this) {
        LifeChainKind.housing => 'Current home',
        LifeChainKind.job => 'Current job',
      };

  String get addCta => switch (this) {
        LifeChainKind.housing => 'Add place',
        LifeChainKind.job => 'Add job',
      };

  String get labelPlaceholder => switch (this) {
        LifeChainKind.housing => 'Place name',
        LifeChainKind.job => 'Employer or role',
      };

  String get startDateLabel => switch (this) {
        LifeChainKind.housing => 'Moved in',
        LifeChainKind.job => 'Started',
      };

  IconData get icon => switch (this) {
        LifeChainKind.housing => CupertinoIcons.house_fill,
        LifeChainKind.job => CupertinoIcons.briefcase_fill,
      };

  /// Base Trends band color for this chain (distinct from life-event gold).
  Color get trendBandColor => switch (this) {
        LifeChainKind.housing => AppColors.housing,
        LifeChainKind.job => AppColors.success,
      };

  /// Mild per-era accent for labels/edges — same lightness family, tiny hue nudge.
  ///
  /// Era fills are differentiated by gradient *style* in the Trends painter, not
  /// by getting progressively brighter.
  Color trendEraAccent(int eraIndex) {
    final base = HSLColor.fromColor(trendBandColor);
    final hueShift = switch (eraIndex % 5) {
      0 => -8.0,
      1 => 0.0,
      2 => 10.0,
      3 => -4.0,
      _ => 5.0,
    };
    final hue = (base.hue + hueShift) % 360.0;
    return base.withHue(hue < 0 ? hue + 360.0 : hue).toColor();
  }
}

class ChainStay {
  const ChainStay({
    required this.id,
    required this.label,
    required this.startedOn,
    this.note,
  });

  final String id;
  final String label;
  final DateTime startedOn;
  final String? note;
}

/// One link in a [StayChain] with a computed residence/employment range.
class ChainStaySegment {
  const ChainStaySegment({
    required this.stay,
    required this.rangeStart,
    required this.rangeEnd,
    required this.isCurrent,
  });

  final ChainStay stay;
  final DateTime rangeStart;

  /// Null when this is the open-ended current stay.
  final DateTime? rangeEnd;
  final bool isCurrent;

  String get dateCaption {
    final formatter = DateFormat.yMMMd();
    final startLabel = formatter.format(rangeStart);
    if (isCurrent || rangeEnd == null) return '$startLabel – present';
    return '$startLabel – ${formatter.format(rangeEnd!)}';
  }

  bool intersectsChart({
    required DateTime chartMinDate,
    required DateTime chartMaxDate,
  }) {
    final start = rangeStart.startOfDay;
    final end = (rangeEnd ?? chartMaxDate).startOfDay;
    final minDate = chartMinDate.startOfDay;
    final maxDate = chartMaxDate.startOfDay;
    return !start.isAfter(maxDate) && !end.isBefore(minDate);
  }

  DateTime effectiveEndOn(DateTime chartMaxDate) {
    return (rangeEnd ?? chartMaxDate).startOfDay;
  }
}

class StayChain {
  StayChain(List<ChainStay> stays)
      : segments = _segmentsFor(
          [...stays]..sort(
              (firstStay, secondStay) =>
                  firstStay.startedOn.compareTo(secondStay.startedOn),
            ),
        );

  final List<ChainStaySegment> segments;

  bool get isEmpty => segments.isEmpty;

  ChainStaySegment? get current =>
      segments.isEmpty ? null : segments.last;

  ChainStaySegment? get oldest =>
      segments.isEmpty ? null : segments.first;

  static List<ChainStaySegment> _segmentsFor(List<ChainStay> sortedStays) {
    return [
      for (var index = 0; index < sortedStays.length; index++)
        ChainStaySegment(
          stay: sortedStays[index],
          rangeStart: sortedStays[index].startedOn.startOfDay,
          rangeEnd: index + 1 < sortedStays.length
              ? sortedStays[index + 1]
                  .startedOn
                  .startOfDay
                  .subtract(const Duration(days: 1))
              : null,
          isCurrent: index == sortedStays.length - 1,
        ),
    ];
  }
}
