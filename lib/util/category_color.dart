import 'package:budgets/domain/category.dart';
import 'package:budgets/domain/special_category.dart';
import 'package:budgets/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';

/// Stable colors for category identity across Activity / Trends.
class CategoryColor {
  CategoryColor._();

  static const uncategorized = AppColors.textDim;
  static const housing = AppColors.housing;
  static const income = AppColors.success;
  static const transfer = AppColors.accentSecondary;

  /// Same palette as Trends series (readable on dark surfaces).
  static const palette = <Color>[
    Color(0xFF4CC9F0),
    Color(0xFFF4A261),
    Color(0xFFB5179E),
    Color(0xFF80ED99),
    Color(0xFFFFD166),
    Color(0xFF4361EE),
    Color(0xFFFF6B35),
    Color(0xFF9B5DE5),
    Color(0xFF2EC4B6),
    Color(0xFFF72585),
  ];

  static Color forCategoryId(String? categoryId, {String? categoryName}) {
    if (SpecialCategory.isHousingId(categoryId) ||
        SpecialCategory.isHousingName(categoryName)) {
      return housing;
    }
    if (categoryId == null || categoryId.isEmpty) return uncategorized;
    if (SpecialCategory.isIncomeId(categoryId)) return income;
    if (SpecialCategory.isTransferId(categoryId)) return transfer;
    return palette[_stableIndex(categoryId) % palette.length];
  }

  static Color forCategory(SpendCategory category) =>
      forCategoryId(category.id, categoryName: category.name);

  static int _stableIndex(String categoryId) {
    var hash = 0;
    for (final codeUnit in categoryId.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash;
  }
}
