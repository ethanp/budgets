import 'package:powersync/powersync.dart';

/// Mirrors [infra/budgets] Postgres tables. PowerSync adds `id` automatically.
const Schema budgetsSchema = Schema([
  Table('accounts', [
    Column.text('external_id'),
    Column.text('name'),
    Column.text('currency'),
    Column.integer('balance_cents'),
    Column.integer('balance_as_of'),
    Column.text('conn_id'),
    Column.text('conn_name'),
    Column.integer('last_synced_at'),
    Column.text('status'),
    Column.text('status_message'),
  ]),
  Table('category_groups', [
    Column.text('name'),
    Column.integer('sort_order'),
  ]),
  Table('categories', [
    Column.text('name'),
    Column.integer('sort_order'),
    Column.integer('archived'),
    Column.text('color_token'),
    Column.text('group_id'),
  ]),
  Table('transactions', [
    Column.text('account_id'),
    Column.text('external_id'),
    Column.integer('posted_at'),
    Column.integer('amount_cents'),
    Column.text('raw_description'),
    Column.text('normalized_merchant'),
    Column.integer('pending'),
    Column.text('user_category_id'),
    Column.text('suggested_category_id'),
    Column.text('note'),
    Column.text('transaction_type'),
    Column.integer('excluded'),
    Column.text('recurring_series'),
    Column.integer('imported_at'),
  ]),
  Table('categorization_rules', [
    Column.text('match_type'),
    Column.text('pattern'),
    Column.text('category_id'),
    Column.integer('priority'),
  ]),
  Table('life_events', [
    Column.text('title'),
    Column.integer('started_on'),
    Column.integer('ended_on'),
    Column.text('note'),
  ]),
  Table('homebase_stays', [
    Column.text('label'),
    Column.integer('started_on'),
    Column.text('note'),
  ]),
  Table('job_stays', [
    Column.text('label'),
    Column.integer('started_on'),
    Column.text('note'),
  ]),
  Table('sync_state', [
    Column.text('key'),
    Column.text('value'),
  ]),
]);
