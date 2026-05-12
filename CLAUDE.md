# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EveStatsCollector collects EVE Online statistics from the ESI API and makes them queryable via a Blazor web dashboard. The system has four components:

- **`EveStatsCollector.App`** — .NET Worker; collects ESI stats and imports the SDE into PostgreSQL.
- **PostgreSQL (`eve_stats`)** — data store for all collected stats and SDE universe reference data.
- **`EveStatsCollector.Api`** — ASP.NET Core Web API; read-only database access; serves the Blazor frontend.
- **`EveStatsCollector.Web`** — Blazor WASM SPA; the user-facing dashboard (planned — not yet created).

`EveStatsCollector.App` uses the standard .NET hosting model: dependency injection, `IHostedService` background workers, and Serilog (sink: Seq). Observability is wired through OpenTelemetry. Docker Compose is used for local development infrastructure.

## Solution layout

```
EveStatsCollector.slnx
EveStatsCollector.App/      # Worker — ESI collector + SDE import
EveStatsCollector.Api/      # Web API — read-only DB, serves Blazor
EveStatsCollector.Web/      # Blazor WASM SPA (planned)
db/
  migrations/               # DbUp scripts — source of truth
  schema/                   # hand-maintained reference
```
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

## Architecture

### Startup sequence

Startup is strictly ordered and must remain so:

1. **DbUp migrations** run synchronously in `Program.cs` before `builder.Build()`. The host does not start until all migrations succeed.
2. **`UniverseService.StartAsync`** runs next (overrides `BackgroundService.StartAsync`). It runs the SDE import check and loads all universe ID caches into memory before calling `base.StartAsync`. The host does not start any other `IHostedService` until this completes.
3. **All other hosted services** (`SystemJumpsService`, future collectors) start after `UniverseService` is fully initialised and the caches are populated.

**Registration order in `Program.cs` enforces step 2.** `UniverseService` must be registered before any collector service:

```csharp
builder.Services.AddSingleton<UniverseService>();
builder.Services.AddHostedService(sp => sp.GetRequiredService<UniverseService>());
// collector services registered after
builder.Services.AddSingleton<SystemJumpsCollector>();
builder.Services.AddHostedService<SystemJumpsService>();
```

The singleton + factory pattern (`AddSingleton<T>` + `AddHostedService(sp => sp.GetRequiredService<T>())`) is required for any hosted service that must also be injectable as a regular dependency.

### UniverseService

`UniverseService` is the single source of truth for static universe IDs. It owns the SDE import lifecycle and exposes in-memory caches that collectors use for FK filtering — no DB round-trip per collection tick.

- **Caches:** `SolarSystemIds`, `ConstellationIds`, `RegionIds` — each a `volatile FrozenSet<int>`.
- **Thread safety:** `volatile` ensures the reference swap is visible across threads immediately. `FrozenSet<int>` is immutable after construction, so readers always see a complete consistent snapshot.
- **Refresh cycle:** 24-hour `PeriodicTimer` in `ExecuteAsync` re-runs the SDE check and reloads caches.
- **Error isolation:** SDE import failures and cache load failures are caught and logged; the service continues running on stale data rather than crashing.

Collectors inject `UniverseService` directly and call `universeService.SolarSystemIds.Contains(id)`.

### Static data import — `StaticData/` namespace

The `StaticData` folder (namespace `EveStatsCollector.StaticData`) contains the full pipeline for importing EVE's Static Data Export (SDE). Register all services via the extension method:

```csharp
builder.Services.AddStaticData();
```

The pipeline is split across focused classes — one responsibility each:

| Class | Responsibility |
|---|---|
| `StaticDataBuildChecker` | Fetches `latest.jsonl` from the SDE API; compares build number against `sde_imports` in the DB |
| `StaticDataDownloader` | Streams the SDE zip archive to a local temp file |
| `StaticDataExtractor` | Extracts only the needed JSONL files from the zip (static class) |
| `StaticDataParser` | Deserialises JSONL lines into typed records (static class) |
| `StaticDataRepository` | Upserts factions, regions, constellations, solar systems, and records the import in `sde_imports` |
| `StaticDataImporter` | Orchestrates the pipeline; exposes `RunIfOutdatedAsync` consumed by `UniverseService` |

When adding new namespaces or service groups (e.g. `Esi/`, future `Market/`), follow the same pattern: an `IServiceCollection` extension method (e.g. `AddStaticData()`) that encapsulates all registrations for that group.

### ESI collectors

Each ESI endpoint gets a dedicated collector class (e.g. `SystemJumpsCollector`) and a `BackgroundService` wrapper (e.g. `SystemJumpsService`) that drives the scheduling loop. The service respects the ESI `Expires` header: it delays until `expires - now` after each collection rather than using a fixed `PeriodicTimer`.

### API project (`EveStatsCollector.Api`)

- Uses `ConnectionStrings:EveStatsReadonly` — `eve_stats_readonly` role, SELECT-only, never writes.
- No DbUp — read-only consumer; never runs migrations.
- Minimal API style (no controllers) with endpoint classes under `Endpoints/`.
- Serilog + OpenTelemetry wired identically to the collector app.
- CORS allowed origins read from `Cors:AllowedOrigins` in config.
- OpenAPI document generated by `Microsoft.AspNetCore.OpenApi`; Scalar UI served at `/scalar/v1` in Development.
- `DefaultTypeMap.MatchNamesWithUnderscores = true` enables Dapper to map PostgreSQL `snake_case` columns to C# `PascalCase` properties.
- JSON responses use camelCase (`JsonNamingPolicy.CamelCase`).

**Endpoints:**

| Route | Source | Notes |
|---|---|---|
| `GET /api/systems` | `v_solar_systems` | `?regionId=`, `?spaceType=` filters |
| `GET /api/systems/jumps` | `v_recent_system_jumps` | Latest snapshot; ordered by ship_jumps DESC |
| `GET /api/systems/kills` | `v_recent_system_kills` | Latest snapshot; ordered by total kills DESC |
| `GET /api/regions` | `regions` | For filter dropdowns |
| `GET /api/constellations` | `constellations` | `?regionId=` filter |

## Static Data Export (SDE)

The SDE is a snapshot of the EVE universe (items, ships, regions, systems, stations, etc.) that changes only on game patches. Import tooling lives in `EveStatsCollector.App/StaticData/` — see the Architecture section for the class breakdown. The import runs automatically on startup and every 24 hours thereafter via `UniverseService`.

### Localisation

The SDE provides names and descriptions in 8 languages. **Store English only** in all schema columns (`name`, `description`, etc.). If multi-language support is needed in future, add a JSONB translations column — do not change the existing column design.

### Reference build

The schema was designed against SDE build **3328718** (released 2026-05-01). The import tooling should record the build number in `sde_imports` on each successful run.

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

Use **Polly** (via `Microsoft.Extensions.Http.Resilience` — the .NET 10-recommended Polly v8 wrapper; `Microsoft.Extensions.Http.Polly` is deprecated) for all retry logic. Register policies through `IHttpClientBuilder` when wiring up the typed `HttpClient`.

Retry policy rules:
- Retry on transient failures: 5xx responses and network errors (`HttpRequestException`).
- Retry on **429**: read the `Retry-After` header and use it as the delay (not a fixed backoff).
- Retry on **420**: wait for `X-ESI-Error-Limit-Reset` seconds before retrying.
- **Do not retry 4xx** (other than 429/420) — they cost 5 tokens each and the error is a client-side bug.
- Use exponential backoff with jitter for 5xx retries to avoid thundering herd against ESI.

#### General request hygiene

- Distribute requests evenly over time — avoid bursting; spread calls across the cache window.
- Do not retry 4xx errors without fixing the underlying cause (each costs 5 tokens).

---

## Deferred — LLM / MCP access

**Status: paused as of 2026-05-12.** Local models (qwen2.5:14b, qwen3:14b) were unreliable at tool calling and reasoning on this hardware. This work is shelved until a more capable local model is available or an alternative approach is found.

Full notes on what was tried (chat UIs, models, MCP servers, chart rendering) are in the memory file `ai_stack_trials.md`.

### Schema design notes to keep in mind for future resumption

When LLM access is revisited, the database schema should already be LLM-friendly:

- Add `COMMENT ON TABLE` / `COMMENT ON COLUMN` to every non-obvious table and column in migrations.
- Prefer views for common join/calculation shapes — a view named `active_buy_orders_by_system` is more discoverable than a raw join.
- `SchemaVersions` (DbUp journal) and any credentials tables must be excluded from the readonly role or created in a separate schema.
- The `eve_stats_readonly` role (SELECT-only) is the intended MCP connection user.
