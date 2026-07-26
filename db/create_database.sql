-- Run as postgres/viant superuser once to create the budgets database.
-- Example (after sync-app-db.sh, from infra/):
--   docker exec -i <postgres> psql -U viant -d postgres < budgets/create_database.sql
-- Source of truth: Flutter/budgets/db/create_database.sql

SELECT 'CREATE DATABASE budgets OWNER budgets'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'budgets')\gexec

GRANT ALL PRIVILEGES ON DATABASE budgets TO budgets;
