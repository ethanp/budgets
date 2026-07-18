# Budgets

Personal Copilot-style category budgeting for **macOS and iPhone** only. Connect credit cards and bank accounts via [SimpleFIN Bridge](https://beta-bridge.simplefin.org/), pull transactions into a PowerSync local store, assign them to budget categories, and track month spend against per-category limits.

This is a personal app (not a product). The repo is public-safe: bank Access URLs, Setup Tokens, JWT secrets, and LLM tokens live only in a local `.env` (gitignored) and the device keychain — never in git.

## What it does

- **Bank sync (SimpleFIN)** — Claim a one-time Setup Token once; the app stores the claimed Access URL and pulls accounts + transactions (max ~44-day windows per SimpleFIN beta limits). Incremental pulls use the last successful sync time; **Settings → Refresh full history** walks back ~2 years.
- **Month** — Dashboard of spend vs budget for the selected month, by category.
- **Activity** — Transaction list; recategorize with sticky merchant memory and optional rules.
- **Categories** — Manage categories and monthly budget amounts (defaults seeded on first launch).
- **Settings** — Connect / refresh SimpleFIN, force-refresh history, CSV import, ethan_sync status, optional LLM suggestions.
- **CSV import** — Manual fallback when a bank is not on SimpleFIN.
- **LLM suggestions (optional)** — Home-server `llm-proxy` suggests categories for uncategorized merchants.
- **Multi-device sync** — `ethan_sync` / PowerSync is the local store and syncs to home-server Postgres (ports **8083** / **3006**).

## How it works

```
SimpleFIN Bridge ──HTTP──► App (claim + /accounts)
                              │
                              ▼
              PowerSync DB (budgets_powersync.db)
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
           Month UI      Activity UI    Categories UI
                              │
                    ethan_sync ↔ Postgres
                    optional: llm-proxy
```

1. Buy SimpleFIN Bridge (~$15/yr) and create a Setup Token in their UI.
2. Set `POWERSYNC_JWT_SECRET` + `SERVER_HOST_LAN` in `.env` (required), then run the app.
3. In **Settings → Connect**, paste the Setup Token. The app claims an Access URL (`https://user:pass@…/simplefin`), saves it to keychain, and you should also put it in `.env` as `SIMPLEFIN_ACCESS_URL` so it survives reinstall.
4. Sync pulls accounts/transactions into PowerSync. Categorization uses sticky merchant → category memory plus explicit rules.
5. Month totals roll up posted transactions against your category budgets. Changes upload via PostgREST and download on other devices.

## Code layout

| Dir | Role |
|-----|------|
| `features/shell/` | `CupertinoApp` + tab shell |
| `features/*/` | Per-tab UI (Month, Activity, Categories, Settings) |
| `domain/` | Models + use cases (ingest, categorize, month rollup) |
| `services/` | SimpleFIN, PowerSync repos, CSV, LLM, ethan_sync config |
| `providers/` | Riverpod wiring |
| `theme/` | Cupertino theme tokens |
| `widgets/`, `util/` | Shared UI/helpers |

## Setup

Sibling path packages (same layout as your other Flutter apps):

- `../ethan_utils`
- `../ethan_sync`

```bash
cd ~/code/my-code/Active/Flutter/budgets
cp .env.example .env
# Required: POWERSYNC_JWT_SECRET, SERVER_HOST_LAN
# Optional: SIMPLEFIN_ACCESS_URL (after first Connect), LLM_APP_SECRET
flutter pub get
flutter run -d macos
# or
flutter run -d iphone
```

### `.env` keys

| Key | Required | Purpose |
|-----|----------|---------|
| `SERVER_HOST_LAN` | Yes | Home server host |
| `POWERSYNC_JWT_SECRET` | Yes | ethan_sync JWT (raw secret; infra `BUDGETS_POWERSYNC_JWT_KEY` is its base64url form) |
| `SIMPLEFIN_ACCESS_URL` | After claim | Claimed Access URL (not Setup Token) |
| `LLM_APP_NAME` | Optional | Usually `budgets` |
| `LLM_APP_SECRET` | Optional | Must match infra `LLM_BUDGETS_SECRET` |

`.env` is gitignored and listed as a Flutter asset (same pattern as your other apps). Keep real values only on your machine.

## Infra

Server pieces live in `../../infra/budgets/` (PowerSync **8083**, PostgREST **3006**). Schema + publication migrations are under `infra/budgets/migrations/`. Register `LLM_BUDGETS_SECRET` on the shared llm-proxy for category suggestions.

## Icon

```bash
./scripts/generate_icon.sh
```

## Platforms

- **macOS** — primary; sandbox off for keychain + network (see Runner entitlements).
- **iOS** — supported.
- **Android** — not a target (personal Apple-device app).
