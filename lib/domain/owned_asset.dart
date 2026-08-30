import 'package:ethan_utils/ethan_utils.dart';
import 'package:spend_trends/domain/owned_asset_kind.dart';

class const OwnedAsset({
  required final String id,
  required final String name,
  required final OwnedAssetKind kind,
  final String? note,
}) {
  OwnedAsset copyWith({
    String? id,
    String? name,
    OwnedAssetKind? kind,
    String? note,
    bool clearNote = false,
  }) {
    return OwnedAsset(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      note: clearNote ? null : (note ?? this.note),
    );
  }
}

class const OwnedAssetValuation({
  required final String id,
  required final String ownedAssetId,
  required final int valueCents,
  required final DateTime valuedOn,
});

/// An owned asset plus its valuation snapshots, newest [valuedOn] first.
class OwnedAssetWithValuations({
  required final OwnedAsset asset,
  required List<OwnedAssetValuation> valuations,
}) {
  final List<OwnedAssetValuation> valuations = _newestFirst(valuations);

  int get currentValueCents {
    if (valuations.isEmpty) return 0;
    return valuations.first.valueCents;
  }

  DateTime? get currentValuedOn {
    if (valuations.isEmpty) return null;
    return valuations.first.valuedOn;
  }

  /// Latest snapshot on or before [day]; 0 before the first valuation.
  int valueCentsOn(DateTime day) {
    final target = day.startOfDay;
    for (final valuation in valuations) {
      if (!valuation.valuedOn.startOfDay.isAfter(target)) {
        return valuation.valueCents;
      }
    }
    return 0;
  }

  List<double> dailyCents(List<DateTime> chartDates) {
    return [for (final day in chartDates) valueCentsOn(day).toDouble()];
  }

  static List<OwnedAssetValuation> _newestFirst(
    List<OwnedAssetValuation> valuations,
  ) {
    final sorted = [...valuations];
    sorted.sort((left, right) {
      final byDate = right.valuedOn.compareTo(left.valuedOn);
      if (byDate != 0) return byDate;
      return right.id.compareTo(left.id);
    });
    return sorted;
  }
}
