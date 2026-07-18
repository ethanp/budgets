import 'package:budgets/domain/special_category.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';

const _log = ELogger('SpecialCategories');

/// Ensures Income/Transfer exist, then migrates type-based / duplicate rows onto them.
Future<void> ensureSpecialCategoriesMigrated(PowerSyncDatabase database) async {
  await _upsertSpecialCategories(database);
  await _backfillFromTransactionType(database);
  await _mergeDuplicateNamedCategories(database);
}

Future<void> _upsertSpecialCategories(PowerSyncDatabase database) async {
  for (final special in SpecialCategory.values) {
    await database.upsert('categories', {
      'id': special.id,
      'name': special.name,
      'sort_order': special.sortOrder,
      'archived': 0,
      'color_token': null,
    });
  }
}

Future<void> _backfillFromTransactionType(PowerSyncDatabase database) async {
  await database.execute(
    '''
    UPDATE transactions
    SET user_category_id = ?
    WHERE lower(trim(coalesce(transaction_type, ''))) = 'income'
      AND (user_category_id IS NULL OR trim(user_category_id) = '')
    ''',
    [SpecialCategory.income.id],
  );
  await database.execute(
    '''
    UPDATE transactions
    SET user_category_id = ?
    WHERE lower(trim(coalesce(transaction_type, ''))) IN (
      'transfer',
      'internal transfer'
    )
      AND (user_category_id IS NULL OR trim(user_category_id) = '')
    ''',
    [SpecialCategory.transfer.id],
  );
  _log.log('Backfilled special categories from transaction_type');
}

Future<void> _mergeDuplicateNamedCategories(PowerSyncDatabase database) async {
  for (final special in SpecialCategory.values) {
    final duplicateRows = await database.getAll(
      '''
      SELECT id FROM categories
      WHERE lower(trim(name)) = ?
        AND id != ?
      ''',
      [special.name.toLowerCase(), special.id],
    );
    for (final row in duplicateRows) {
      final duplicateId = row['id'] as String;
      await database.execute(
        'UPDATE transactions SET user_category_id = ? WHERE user_category_id = ?',
        [special.id, duplicateId],
      );
      await database.execute(
        '''
        UPDATE transactions
        SET suggested_category_id = ?
        WHERE suggested_category_id = ?
        ''',
        [special.id, duplicateId],
      );
      await database.execute(
        'UPDATE categorization_rules SET category_id = ? WHERE category_id = ?',
        [special.id, duplicateId],
      );
      await database.execute(
        'DELETE FROM categories WHERE id = ?',
        [duplicateId],
      );
      _log.log(
        'Merged duplicate "${special.name}" ($duplicateId) → ${special.id}',
      );
    }
  }
}
