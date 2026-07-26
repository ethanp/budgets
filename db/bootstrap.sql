-- budgets role bootstrap
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'budgets') THEN
    CREATE ROLE budgets LOGIN;
  END IF;
END
$$;

ALTER ROLE budgets WITH REPLICATION;
