# Budgets

Personal Copilot-style category budgeting for iPhone and macOS. Connect credit cards and bank accounts via [SimpleFIN Bridge](https://beta-bridge.simplefin.org/), pull transactions into on-device SQLite, assign them to budget categories, and track month spend against per-category limits.

This is a personal app (not a product). The repo is meant to be public: bank Access URLs, Setup Tokens, JWT secrets, and LLM tokens live only in a local `.env` (gitignored) and the device keychain — never in git.

## What it does

- **Bank sync (SimpleFIN)** — Claim a one-time Setup Token once; the app stores the claimed Access URL and pulls accounts + transactions (max ~44-day windows per SimpleFIN beta limits). Incremental pulls use the last successful sync time.
- **Month** — Dashboard of spend vs budget for the selected month, by category.
- **Activity** — Transaction list; recategorize with sticky merchant memory and optional rules.
- **Categories** — Manage categories and monthly budget amounts.
- **Settings** — Connect / sync SimpleFIN, CSV import fallback, optional ethan_sync status, optional LLM category suggestions.
- **CSV import** — Manual fallback when a bank is not on SimpleFIN.
- **LLM suggestions (optional)** — Home-server `llm-proxy` suggests categories for uncategorized merchants.
- **Multi-device sync (optional)** — Same schema via `ethan_sync` / PowerSync when JWT + host are configured.

## How it works

```
SimpleFIN Bridge ──HTTP──► App (claim + /accounts)
                              │
                              ▼
                     Local SQLite (budgets.db)
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
           Month UI      Activity UI    Categories UI
                              │
                    optional: ethan_sync
                    optional: llm-proxy
```

## Code layout

| Dir | Role |
|-----|------|
| `features/shell/` | `CupertinoApp` + tab shell |
| `features/*/` | Per-tab UI (Month, Activity, Categories, Settings) |
| `domain/` | Models + use cases (ingest, categorize, month rollup) |
| `services/` | SimpleFIN, SQLite, CSV, LLM, optional PowerSync |
| `providers/` | Riverpod wiring |
| `theme/` | Cupertino theme tokens (not the root app widget) |
| `widgets/`, `util/` | Shared UI/helpers |

1. You buy SimpleFIN Bridge (~$15/yr) and create a Setup Token in their UI.
2. In **Settings → Connect**, paste the Setup Token. The app claims it for an Access URL (`https://user:pass@…/simplefin`), saves that to keychain, and you should also put it in `.env` as `SIMPLEFIN_ACCESS_URL` so it survives reinstall.
3. Sync pulls accounts and transactions into local SQLite. Categorization uses sticky merchant → category memory plus explicit rules.
4. Month totals roll up posted transactions against your category budgets.

Local DB is the source of truth for day-to-day use. PowerSync is optional and only starts when `POWERSYNC_JWT_SECRET` and `SERVER_HOST_LAN` are set.

## Setup

Sibling path packages (same layout as your other Flutter apps):

- `../ethan_utils`
- `../ethan_sync`

```bash
cd ~/code/my-code/Active/Flutter/budgets
cp .env.example .env
# Fill SIMPLEFIN_ACCESS_URL after first Connect (or leave empty and claim in-app)
# Optional: POWERSYNC_JWT_SECRET, LLM_APP_SECRET, SERVER_HOST_LAN
flutter pub get
flutter run -d macos
# or
flutter run -d iphone
```

### `.env` keys

| Key | Required | Purpose |
|-----|----------|---------|
| `SIMPLEFIN_ACCESS_URL` | For sync after claim | Claimed Access URL (not Setup Token) |
| `SERVER_HOST_LAN` | For LLM / sync | Home server host |
| `POWERSYNC_JWT_SECRET` | Optional | Enables ethan_sync |
| `LLM_APP_NAME` | Optional | Usually `budgets` |
| `LLM_APP_SECRET` | Optional | Must match infra `LLM_BUDGETS_SECRET` |

`.env` is gitignored and listed as a Flutter asset (same pattern as your other apps). Keep real values only on your machine.

## Infra (optional)

Server pieces live in `../../infra/budgets/` (PowerSync **8083**, PostgREST **3006**). Register `LLM_BUDGETS_SECRET` on the shared llm-proxy for category suggestions.

## Icon

```bash
./scripts/generate_icon.sh
```

## Platforms

- **macOS** — primary; sandbox off for keychain + network (see Runner entitlements).
- **iOS** — supported target.
