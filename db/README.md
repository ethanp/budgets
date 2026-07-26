# budgets database

Source of truth for the budgets Postgres schema and PowerSync sync rules.

| Path | Purpose |
|---|---|
| `init.sql` | Full current schema (fresh DB bootstrap) |
| `migrations/` | Incremental numbered SQL migrations |
| `powersync.yaml` | PowerSync service config + sync rules |
| `bootstrap.sql` | Role setup (`budgets` login + replication) |
| `create_database.sql` | One-time `CREATE DATABASE` (superuser) |

## Migrations

From this app repo:

```bash
./scripts/migrate.sh migrations/NNN_description.sql
./scripts/migrate.sh --full migrations/NNN_description.sql   # after powersync.yaml changes
```

`--full` syncs this tree into `infra/budgets/` and redeploys before applying SQL.
