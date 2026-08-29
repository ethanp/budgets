import 'package:flutter/material.dart';

/// Kind of a manually tracked owned asset (home, vehicle, other).
enum OwnedAssetKind {
  home(legendLabel: 'Home', lineColor: Color(0xFFF4A261)),
  vehicle(legendLabel: 'Vehicle', lineColor: Color(0xFFE76F51)),
  other(legendLabel: 'Other', lineColor: Color(0xFFE9A825));

  const OwnedAssetKind({required this.legendLabel, required this.lineColor});

  final String legendLabel;
  final Color lineColor;

  String get storageValue => name;

  static OwnedAssetKind fromStorage(String value) {
    return tryFromStorage(value) ?? OwnedAssetKind.other;
  }

  static OwnedAssetKind? tryFromStorage(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    for (final kind in OwnedAssetKind.values) {
      if (kind.name == trimmed) return kind;
    }
    return null;
  }
}
