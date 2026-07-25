import 'package:budgets/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';

/// Series ids, colors, and shared Trends chart constants.
class TrendChartCatalog {
  TrendChartCatalog._();

  static const allSpendSeriesId = '__all__';
  static const uncategorizedSeriesId = '__uncategorized__';
  static const incomeSeriesId = '__income__';
  static const spendingSeriesId = '__spending__';
  static const transferSeriesId = '__transfer__';
  static const savingsSeriesId = '__savings__';
  static const netWorthSeriesId = '__net_worth__';
  static const housingAffordabilitySeriesId = '__housing_30__';
  static const fireSavingsGuideSeriesId = '__savings_25__';
  static const groupSeriesIdPrefix = 'group:';
  static const accountSeriesIdPrefix = 'account:';

  static String groupSeriesId(String groupId) => '$groupSeriesIdPrefix$groupId';

  static String accountSeriesId(String accountId) =>
      '$accountSeriesIdPrefix$accountId';

  /// Housing ≤ this share of income (bank income ≈ net).
  static const housingIncomeShareCap = 0.30;

  /// FIRE rule of thumb: save at least this share of income.
  static const fireSavingsIncomeShare = 0.25;

  /// History before this date is incomplete enough to distort trends.
  static final chartHistoryStart = DateTime(2021, 3, 1);

  static const allSpendLineColor = Color(0xFF8B1E2D);
  static const uncategorizedLineColor = Color(0xFF9AA0A6);
  static const incomeLineColor = Color(0xFF3FB37F);
  static const spendingLineColor = AppColors.housing;
  static const transferLineColor = Color(0xFF7B8CDE);
  static const savingsLineColor = Color(0xFF56CCF2);
  static const netWorthLineColor = Color(0xFFE9C46A);

  static final housingAffordabilityLineColor = Color.lerp(
        AppColors.housing,
        const Color(0xFFE53935),
        0.3,
      )!;

  static final fireSavingsGuideLineColor = Color.lerp(
        savingsLineColor,
        AppColors.success,
        0.45,
      )!;
}
