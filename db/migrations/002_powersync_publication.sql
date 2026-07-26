-- PowerSync logical-replication publication for the budgets database.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync') THEN
    CREATE PUBLICATION powersync FOR TABLE
      accounts,
      categories,
      transactions,
      category_budgets,
      categorization_rules,
      sync_state;
  END IF;
END
$$;
