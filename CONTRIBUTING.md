# Contributing to Octraban

Thanks for your interest in contributing! This project is part of the **Stellar Wave Program** on [Drips](https://www.drips.network/wave/stellar).

## Local Setup

### Prerequisites
- Node.js 20+
- PostgreSQL 16+ (or Docker)
- Git

### Steps

```bash
git clone https://github.com/<your-org>/octraban-backend
cd octraban-backend

cp .env.example .env
# Edit .env — at minimum set DATABASE_URL

npm install
npx prisma migrate dev --name init
npm run dev
```

With Docker (no local Postgres needed):
```bash
cp .env.example .env
docker compose up db -d        # start only the DB
npx prisma migrate dev --name init
npm run dev
```

### Running the indexer (separate terminal)
```bash
npm run index
```

This repo has two independent migration systems (Prisma for the API, a SQL runner for the
indexer) sharing one database. `npx prisma migrate dev` above only applies the Prisma side —
the indexer applies its own migrations automatically on startup. To bring a **fresh** database
to a working state for both in one step (e.g. in CI, or scripting a new environment), use:

```bash
DATABASE_URL=<your-db-url> npm run db:bringup
```

See [docs/database-ownership.md](./docs/database-ownership.md) for which tables each system
owns and why they're split this way.

### Running tests
```bash
npm test
```

## Project Structure

```
src/
├── api/          # Express route handlers
├── indexer/      # Soroban RPC polling + XDR decoder
├── config.ts     # Env config
├── db.ts         # Prisma client
└── index.ts      # App entry point
prisma/
├── schema.prisma # DB schema
└── seed.ts       # Known contract seed data
```

## How to Contribute

1. Find an open issue labeled `Stellar Wave` or `good first issue`.
2. Comment on the issue or apply via the Drips Wave app.
3. Fork the repo, create a branch: `git checkout -b fix/your-issue`.
4. Make your changes. Add or update tests where relevant.
5. Run `npm test` and ensure all tests pass.
6. Open a Pull Request against `main`. Reference the issue number.

## Code Style

- TypeScript strict mode is enabled — no `any` unless unavoidable.
- Keep functions small and focused.
- Add a comment if the logic isn't obvious.

## Async Error Handling — `asyncHandler`

All async Express route handlers **must** be wrapped with `asyncHandler` from
`src/middleware/asyncHandler.ts`. This forwards any unhandled promise rejection
to the global error handler automatically so you never forget a `try/catch`.

**❌ Don't do this:**
```ts
router.get('/foo', async (req, res, next) => {
  try {
    const data = await fetchData();
    res.json(data);
  } catch (err) {
    next(err);
  }
});
```

**✅ Do this instead:**
```ts
import { asyncHandler } from '../middleware/asyncHandler';

router.get('/foo', asyncHandler(async (req, res) => {
  const data = await fetchData();
  res.json(data);
}));
```

The `lint:error-handling` script (`npm run lint:error-handling`) enforces this
rule via the local `eslint-plugin-error-handling` and runs in CI.

### Migrating an existing handler

1. Add `import { asyncHandler } from '../middleware/asyncHandler';` at the top.
2. Replace `async (req, res) => { try { ... } catch (e) { next(e); } }` with
   `asyncHandler(async (req, res) => { ... })`.
3. Remove the surrounding `try/catch` — errors are caught for you.

## Structured Logging

Use the shared `logger` from `src/logger.ts` instead of `console.*`.

```ts
import { logger } from '../logger';

logger.info('contract indexed', { address, duration_ms: elapsed });
logger.warn('rpc timeout', { url, attempt });
logger.error('db write failed', { model: 'Transaction', error: String(err) });
logger.debug('cache hit', { key });
```

- In **development** logs are pretty-printed; in **production** they are JSON.
- Log level is controlled by the `LOG_LEVEL` env var (`debug | info | warn | error`).
- Each request automatically includes `requestId` and `duration_ms` via the
  `requestLoggerMiddleware` in `src/logger.ts`.
- Keep `console.error` only in `src/index.ts` as a last-resort startup fallback.

## Database Index Strategy

Every foreign-key field (fields ending in `Id`) **must** have a corresponding
`@@index` or `@@unique` in the Prisma schema. Without an index, any JOIN or
filter on that field causes a full table scan as data grows.

**Rule:** when you add a new FK field, also add `@@index([fieldName])` to the
same model block.

```prisma
model MyModel {
  id         String @id @default(cuid())
  parentId   String          // FK

  parent Parent @relation(fields: [parentId], references: [id])

  @@index([parentId])        // ← required
}
```

Run `npm run audit:indexes` locally before opening a PR. CI will fail if any
FK field lacks an index.

## Freeze Management System Architecture

The Octraban includes a robust CAP-0077 Consensus Asset-Freeze transaction interceptor and management system:
- **`FrozenLedgerKey` Model**: Maintains a registry of currently frozen ledger keys.
- **`FreezeViolation` Model**: Records transactions that touched frozen keys, along with a severity level (`low`, `medium`, `high`, `critical`).
- **`AuditLog` Model**: Stores an immutable event log for all freeze-related state changes (freezing, thawing, resolving violations).
- **Scanner (`src/indexer/freeze-scanner.ts`)**: In real-time, extracts the read/write footprint of transactions and checks against the in-memory cache of frozen keys. Critical violations trigger webhooks.
- **API (`src/api/freeze.ts`)**: Provides complete CRUD and aggregation operations for keys, violations, and audit logs.

## Indexer Type Checking

`indexer/` (the JS service the frontend actually talks to — see the
[two-service architecture](./README.md#two-service-architecture-api-on-3000-vs-indexer-on-3001)
in the README) predates the root API's TypeScript rewrite and is still plain
`.js`. Rather than a big-bang rewrite to `.ts`, it's being brought under type
checking incrementally using TypeScript's `checkJs` mode against JSDoc
annotations, so files gain type safety as they're touched instead of all at
once.

**How it's wired:**

- `indexer/tsconfig.json` sets `allowJs: true`, `checkJs: false` at the
  project level, `strict: true`, and `include`s all of `indexer/src`.
- Individual files opt in by adding `// @ts-check` as their first line. Only
  files with that pragma are type-checked; everything else is parsed (so
  checked files still get real inferred types when they import unchecked
  ones) but not diagnosed. This is the standard incremental-JS-migration
  pattern and means turning on checking for a new file never blocks on fixing
  every other file first.
- `useUnknownInCatchVariables` is turned off project-wide: the whole codebase
  uses `catch (e) { ... e.message ... }` as its error-handling idiom (see
  `asyncHandler` above), and narrowing `unknown` in every one of those blocks
  would be high-churn busywork with no real safety benefit.
- `npm run typecheck` (inside `indexer/`) runs `tsc -p tsconfig.json --noEmit`
  and must exit 0. It runs in CI as the **Indexer Type Check** job.

**Currently checked** (the highest-risk modules — request/response boundary,
config validation, and the DB layer the decoder writes through):
`decoder.js`, `decoderValidator.js`, `eventInserter.js`, `config.js`,
`api.js`, `db.js`.

**Migration plan for the rest of `indexer/src`:** when you touch a `.js` file
in the indexer, consider adding `// @ts-check` to it as part of that PR:

1. Add `// @ts-check` as the file's first line.
2. Run `npm run typecheck` from `indexer/` and fix what surfaces — mostly
   missing `@param`/`@returns` JSDoc on function signatures.
3. Where a value is genuinely dynamic (raw XDR/RPC payloads, `pg` query rows)
   prefer a narrow local type or an explicit `any`/`unknown` cast over
   fighting the type system — see `SorobanRpcEvent` and `DecodedEvent` in
   `decoder.js` for the pattern used for the RPC event shape.
4. Send it as its own PR (or a clearly separated commit) so a type-checking
   pass doesn't get tangled up with unrelated behavioral changes.

There's no fixed deadline for finishing the migration; the goal is that the
checked surface only grows over time, never shrinks.

## Questions?

Open a GitHub Discussion or ask in the [Stellar Discord](https://discord.gg/stellardev).
