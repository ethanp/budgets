/// Fresh installs have an empty `categories` table. The app assumes a fixed set
/// of default spend buckets (Groceries, Dining, …) plus built-ins (Housing,
/// Income, Transfer, Investments) so Copilot import mapping and Trends series
/// have somewhere to land.
///
/// This runs once at PowerSync startup when `categories` is empty. It is a no-op
/// after the first seed (or after sync has already pulled categories).
library;

import 'package:spend_trends/domain/special_category.dart';
import 'package:spend_trends/migrations/migrate_special_categories.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';

const _log = ELogger('SeedDefaultCategories');

Future<void> seedDefaultCategoriesIfNeeded(PowerSyncDatabase database) async {
  final countRow = await database.getOptional(
    'SELECT COUNT(*) AS c FROM categories',
  );
  final count = (countRow?['c'] as Object?).asIntOrNull() ?? 0;
  if (count > 0) return;

  await ensureIncomeCategoryGroup(database);

  const spendDefaults = [
    'Groceries',
    'Dining',
    'Transport',
    'Utilities',
    'Entertainment',
    'Shopping',
    'Health',
    'Travel',
    'Other',
  ];
  for (var index = 0; index < spendDefaults.length; index++) {
    final name = spendDefaults[index];
    await database.upsert('categories', {
      'id': 'cat_${name.toLowerCase()}',
      'name': name,
      'sort_order': index >= 3 ? index + 1 : index,
      'archived': 0,
      'color_token': null,
      'group_id': null,
    });
  }
  for (final special in SpecialCategory.values) {
    await database.upsert('categories', {
      'id': special.id,
      'name': special.name,
      'sort_order': special.sortOrder,
      'archived': 0,
      'color_token': null,
      'group_id': special.defaultGroupId,
    });
  }
  _log.log(
    'Seeded ${spendDefaults.length + SpecialCategory.values.length} '
    'default categories',
  );
}
