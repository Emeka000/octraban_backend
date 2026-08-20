# Database Ownership: Prisma vs. Indexer Migrations

## Background

This repo runs two independent Node processes against the **same** per-network
Postgres database (`db-testnet`, `db-mainnet`, `db-devnet` in `docker-compose.yml`,
each backing both `*_DATABASE_URL` and the plain `DATABASE_URL` the two services
read):

- The **API service** (`src/`) uses **Prisma** (`prisma/schema.prisma`,
  `prisma/migrations/`) and applies its migrations with `prisma migrate deploy`
  (see the `api-*` service `command:` in `docker-compose.yml`).
- The **indexer service** (`indexer/`) uses a small hand-rolled SQL runner
  (`indexer/src/migrate.js`) that applies every `*.sql` file in
  `indexer/migrations/`, tracked in its own `schema_migrations` table. It runs
  automatically on every `db.init()` call (indexer startup, and the handlers/tests
  listed in `indexer/src/index.js`, `indexer/src/api.js`, etc.).

Because two systems write DDL to one physical database with no documented
ownership boundary, it was previously unclear which system owned which tables,
what order they needed to run in, or how to bring up a fresh database for both
at once. This document is the source of truth for that boundary.

## Decision: enforce a boundary, don't consolidate

Consolidating onto a single migration system was considered and rejected for
this change: the Prisma schema has ~190 models backing the API/GraphQL/billing
surface, and the indexer's raw-SQL tables are written and read through
hand-tuned queries (full-text search, keyset pagination, partitioned audit
tables) that don't map cleanly onto Prisma's query builder. A rewrite of either
side is a separate, much larger effort with its own risk profile.

Instead, this change **documents and enforces a non-overlapping table
boundary**: each system owns a fixed, disjoint set of tables in the same
database, and neither may create a table the other owns.

## Table ownership

### Prisma-owned (source of truth: `prisma/schema.prisma`)

Every model in `prisma/schema.prisma` — all ~190 of them — is Prisma-owned.
Models without an explicit `@@map(...)` get their physical table named after
the model itself (e.g. `Contract`, `Event`, `Ledger`, `Transaction`), which
Prisma always double-quotes, making them case-sensitive identifiers distinct
from any lowercase, unquoted name the indexer could create. Models **with**
`@@map(...)` use that literal lowercase name instead — see the full list
below, since those are the ones that could actually collide with an indexer
table.

Prisma also owns its own migration bookkeeping table, `_prisma_migrations`.

Models with an explicit `@@map`:

```
abi_community_contributions   archival_appeals        archival_epochs
archival_nodes                archival_slashes        auth_events
auth_sessions                 auth_webhooks            bridge_alerts
bridge_transactions           bridge_volumes           call_graph_edges
call_graph_vertices            contract_risk_scores     data_retrievals
monitored_addresses            multisig_wallets         nl_alerts
nl_embeddings                  nl_queries               nl_query_contexts
nl_query_templates              nl_report_history        nl_reports
nl_sessions                    oauth_apps               oauth_codes
reentrancy_alerts               reentrancy_findings      reentrancy_stats
saved_queries                  sla_acceptances           sla_offers
storage_challenges              wallet_users              wasm_abi_extracts
```

### Indexer-owned (source of truth: `indexer/migrations/*.sql`)

Only `*.sql` files in `indexer/migrations/` are live — `indexer/src/migrate.js`
reads and applies exactly that set, ordered by filename, and nothing else. The
tables they create:

| Table | Created by |
| --- | --- |
| `sandboxes` | `001_create_sandboxes.sql` |
| `events`, `contracts`, `ledger_hashes`, `daemon_state` | `002_core_schema.sql` |
| `sub_invocations`, `source_verifications`, `storage_state_diffs`, `quorum_freezes` | `003_invocations_and_verifications.sql` |
| `vaults`, `vault_snapshots`, `token_holders`, `privileged_roles`, `wasm_build_metadata` | `004_vaults_and_tokens.sql` |
| `api_keys`, `api_key_usage_daily`, `api_audit_log` (+ its monthly partitions) | `005_api_auth_rate_limiting.sql` |
| `contract_versions` | `006_abi_versioning.sql` |

(`005_add_contract_version.sql`, `005_performance_indexes.sql` and
`006_decoder_validation_constraints.sql` only `ALTER TABLE` / add indexes on
tables above — no new tables.)

The indexer also owns its own migration bookkeeping table,
`schema_migrations`.

### The boundary rule

**No table name may be owned by both systems.** Concretely:

- Before adding `@@map("some_name")` to a Prisma model, check it isn't in the
  indexer table list above.
- Before adding a `CREATE TABLE` to a new `indexer/migrations/*.sql` file,
  check it isn't in the Prisma `@@map` list above (or a bare Prisma model
  name, though those are quoted/PascalCase and effectively can't collide with
  the indexer's lowercase, unquoted names).

This is a manual, documented rule rather than an automated check — the two
systems have no shared schema-introspection point to check against
automatically without one system depending on the other's tooling.

### Out of scope for this change

`IndexerState` (Prisma) and `daemon_state` (indexer SQL) are two *separate*
tables that both track "last indexed ledger" for their respective
process — one for the in-process TS indexer under `src/indexer/`, one for the
standalone `indexer/` service. They don't collide physically, but the
duplication is a pre-existing design overlap between the "two-service
architecture" described in the README, not a migration-ownership problem, and
is left untouched here.

## Bring-up order

Within one database, apply migrations in this order:

1. **Prisma** — `npx prisma migrate deploy` (creates every Prisma-owned table
   plus `_prisma_migrations`).
2. **Indexer** — `node indexer/src/migrate.js` (creates every indexer-owned
   table plus `schema_migrations`).

The two systems don't have foreign keys into each other's tables, so this
order isn't strictly required for correctness today, but it's the order both
`docker-compose.yml` (Prisma runs in each `api-*` container's `command:`
before the indexer container starts serving traffic) and CI use, and keeps
bring-up deterministic.

## Single bring-up command

```bash
DATABASE_URL=postgresql://user:pass@host:5432/dbname npm run db:bringup
```

This runs `scripts/db-bringup.ts`, which performs both steps above against
one `DATABASE_URL` and fails fast (non-zero exit) if either step fails. The
script takes no flags — it only reads `DATABASE_URL` from the environment.

## CI enforcement

The `db-bringup` job in `.github/workflows/ci.yml` starts a fresh Postgres
16 service container and runs `npm run db:bringup` against it on every push
and pull request, so a schema change that breaks fresh bring-up for either
system fails CI.
