# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EveStatsCollector collects and processes universe information and statistics from EVE Online via the ESI (EVE Swagger Interface) API.

Built with C# 10 on .NET Core as a long-running hosted application using the standard .NET hosting model: dependency injection, `IHostedService` background workers, and structured logging via Serilog (sink: Seq). Observability is wired through OpenTelemetry. Data is persisted to PostgreSQL. Docker Compose is used for local development infrastructure.
## Commands

<!-- TODO: Replace with actual commands once the project is set up -->

```bash
# Install dependencies
# e.g. pip install -r requirements.txt  OR  npm install

# Run the collector
# e.g. python main.py  OR  npm start

# Run tests
# e.g. pytest  OR  npm test

# Run a single test
# e.g. pytest tests/test_collector.py::test_name

# Lint
# e.g. ruff check .  OR  eslint src/
```

## Database migrations — DbUp

Use **DbUp** to apply migrations on startup. DbUp runs each script exactly once and journals applied scripts in a `SchemaVersions` table.

### Directory layout

```
db/
  migrations/   # numbered SQL scripts — DbUp's source of truth
                # e.g. 0001_initial_schema.sql, 0002_add_market_table.sql
  schema/       # hand-maintained SQL files — for visual schema tools, never executed by DbUp
                # e.g. tables/solar_systems.sql, functions/get_system_count.sql
```

### Keeping schema and migrations in sync

Every database change requires two edits:

1. **Add a migration** — a new numbered script in `db/migrations/` describing the change (e.g. `ALTER TABLE`, `CREATE INDEX`).
2. **Update the schema file** — edit the corresponding file in `db/schema/` so it reflects the new current state.

The schema files are the human-readable reference; the migrations are what DbUp executes. They must always agree.

### Migration smoke-test (optional)

A PowerShell script could spin up a clean Docker Compose Postgres, run all migrations via DbUp, and then tear down — useful for verifying a migration sequence applies cleanly without manual setup. This has not been written yet; add it to `tools/Test-Migrations.ps1` if needed.

### DbUp registration

Register DbUp in the hosted application startup so migrations run before the application begins serving work. Two connection strings are required: a superuser one for DbUp (which creates the database and the `eve_stats_app` role) and the app-user one for the running application.

Migrations use DbUp variable substitution for secrets — `$AppPassword$` and `$ReadonlyPassword$` are replaced at runtime with values read from config. DbUp variable names contain only word characters, so they never conflict with PostgreSQL `$$` dollar-quoting.

```csharp
var migrationsConnStr  = config.GetConnectionString("EveStatsMigrations");
var appPassword        = config["DbMigrations:AppPassword"];
var readonlyPassword   = config["DbMigrations:ReadonlyPassword"];

EnsureDatabase.For.PostgresqlDatabase(migrationsConnStr);

DeployChanges.To
    .PostgresqlDatabase(migrationsConnStr)
    .WithScriptsFromFileSystem("db/migrations")
    .WithVariable("AppPassword",      appPassword)
    .WithVariable("ReadonlyPassword", readonlyPassword)
    .WithTransaction()
    .LogToConsole()
    .Build()
    .PerformUpgrade();
```

---

## LLM data access — MCP

End users will query and analyse EVE stats via an LLM connected to the database through Microsoft's generic SQL MCP server. The MCP server connects as `eve_stats_readonly` (SELECT-only, no write access).

### Design guidance

Because an LLM reads the schema to reason about queries, every migration that adds a table or non-obvious column should also add SQL comments:

```sql
COMMENT ON TABLE  market_orders         IS 'Open and recently filled market orders scraped from ESI.';
COMMENT ON COLUMN market_orders.is_buy  IS 'True = buy order, false = sell order.';
```

Prefer views over raw tables when the natural query shape involves a join or calculation — a view named `active_buy_orders_by_system` is far more discoverable than a join the LLM has to invent. Add these views as part of the same migration that creates the underlying tables, and add a corresponding file under `db/schema/views/`.

### What NOT to expose

`SchemaVersions` (DbUp's internal journal) and any secrets or credentials tables should be excluded from the MCP server's connection or hidden behind a view that omits them. The `eve_stats_readonly` role grants SELECT on all public schema objects by default privilege, so if a table should not be queryable by the LLM, create it in a separate schema and do not grant access to `eve_stats_readonly`.

---

## Architecture

<!-- TODO: Fill in once structure is established -->

Key components to document here:
- **ESI client** — how API authentication (OAuth2/SSO) and rate limiting are handled
- **Data models** — schema for stats stored/processed
- **Storage layer** — where and how data is persisted (DB, files, etc.)
- **Scheduler** — how periodic collection is triggered (cron, APScheduler, etc.)

## Static Data Export (SDE)

The SDE is a snapshot of the EVE universe (items, ships, regions, systems, stations, etc.) that changes only on game patches. This project will include tooling to fetch the latest SDE and populate the PostgreSQL database from it. The exact shape of that tooling is TBD.

Documentation: `https://developers.eveonline.com/docs/services/static-data/`

### Download URLs

| Resource | URL |
|---|---|
| Latest JSONL (shorthand) | `https://developers.eveonline.com/static-data/eve-online-static-data-latest-jsonl.zip` |
| Current build metadata | `https://developers.eveonline.com/static-data/tranquility/latest.jsonl` |
| Specific build archive | `https://developers.eveonline.com/static-data/tranquility/eve-online-static-data-<build>-jsonl.zip` |
| Changes for a build | `https://developers.eveonline.com/static-data/tranquility/changes/<build>.jsonl` |
| Schema changelog | `https://developers.eveonline.com/static-data/tranquility/schema-changelog.yaml` |

### Checking for updates (automation)

1. Fetch `tranquility/latest.jsonl` — the current build number is in the record with key `sde`.
2. Compare against the last-imported build number stored in the database.
3. If different, download `tranquility/eve-online-static-data-<build>-jsonl.zip` and re-import.
4. Optionally fetch `tranquility/changes/<build>.jsonl` to see what changed; the `_meta` record in that file contains `lastBuildNumber` (the previous build).
5. All SDE resources support `ETag` and `Last-Modified` headers — use `If-None-Match` to avoid re-downloading unchanged content. Non-static metadata endpoints cache for 5 minutes.

### Format

JSONL (JSON Lines): one JSON object per line. Integer-keyed maps are represented as a list of `{ "_key": <int>, "_value": <obj> }` pairs.

### Localisation

Names and descriptions are available in 8 languages: English, Chinese, French, German, Japanese, Korean, Russian, and Spanish.

---

## ESI API

Base URL: `https://esi.evetech.net/latest/`

Auth uses EVE SSO (OAuth2); access tokens must be refreshed before expiry.

### HttpClient middleware (DelegatingHandlers)

All ESI rules below must be enforced in the HttpClient pipeline via composed `DelegatingHandler` layers — not scattered through business logic.

#### User-Agent (required)

Every request must carry a `User-Agent` header. CCP uses this to contact developers when issues arise; omitting it can result in blocks.

Format: `AppName/version (contact@email.com; +https://source-url)`

Set this once as a default header on the `HttpClient` instance.

#### Caching

ESI returns three caching headers — all must be respected:

| Header | Usage |
|---|---|
| `Expires` | Do not re-request the resource before this time. Store the cached body and return it directly until expiry. |
| `ETag` | On repeat requests send `If-None-Match: <etag>`. A `304 Not Modified` response means use the cached body; a `304` costs only 1 rate-limit token vs. 2 for a full `200`. |
| `Last-Modified` | For paginated endpoints, all pages must share the same `Last-Modified` value — if they differ, the data changed mid-fetch and the full set must be re-fetched. |

**Circumventing ESI caching is a bannable offence.**

#### Rate limiting — bucket limit

ESI uses a floating-window token bucket. Token cost per response:

| Status | Cost |
|---|---|
| 2xx | 2 |
| 3xx | 1 (reward for conditional requests) |
| 4xx | 5 (penalty for client errors) |
| 5xx | 0 (server fault, no penalty) |

Bucket key:
- Authenticated routes: `applicationID:characterID`
- Unauthenticated routes: `sourceIP` (or `sourceIP:applicationID` if a token is provided)

Response headers to read:
- `X-Ratelimit-Remaining` — tokens left in the current window
- `X-Ratelimit-Limit` — total allowance (e.g. `150/15m`)
- `X-Ratelimit-Used` — tokens consumed by the last request
- `X-Ratelimit-Group` — which route group the bucket belongs to

When the bucket is exhausted ESI returns **429** with a `Retry-After: <seconds>` header. The handler must honour this delay before retrying.

#### Rate limiting — error limit

A separate global error rate limit applies across all routes: a maximum of **100 non-2xx/3xx responses per minute**. Headers:

- `X-ESI-Error-Limit-Remain` — errors remaining before the limit triggers
- `X-ESI-Error-Limit-Reset` — seconds until the error window resets

When this limit is exceeded ESI returns **420**. The middleware must back off immediately and wait for `X-ESI-Error-Limit-Reset` seconds before resuming. Sustained violations can result in an application ban.

#### Retries — Polly

Use **Polly** (via `Microsoft.Extensions.Http.Polly`) for all retry logic. Register policies through `IHttpClientBuilder` when wiring up the typed `HttpClient`.

Retry policy rules:
- Retry on transient failures: 5xx responses and network errors (`HttpRequestException`).
- Retry on **429**: read the `Retry-After` header and use it as the delay (not a fixed backoff).
- Retry on **420**: wait for `X-ESI-Error-Limit-Reset` seconds before retrying.
- **Do not retry 4xx** (other than 429/420) — they cost 5 tokens each and the error is a client-side bug.
- Use exponential backoff with jitter for 5xx retries to avoid thundering herd against ESI.

#### General request hygiene

- Distribute requests evenly over time — avoid bursting; spread calls across the cache window.
- Do not retry 4xx errors without fixing the underlying cause (each costs 5 tokens).
