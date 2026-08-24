#!/usr/bin/env ts-node
/**
 * scripts/db-bringup.ts
 *
 * Brings a fresh database to a working state for both migration owners in
 * this repo — the Prisma schema (root API) and the indexer's own SQL
 * migrations — against a single DATABASE_URL. See
 * docs/database-ownership.md for which tables each system owns and why this
 * order is used.
 *
 * Usage:
 *   DATABASE_URL=postgresql://user:pass@host:5432/dbname npm run db:bringup
 */
import { execFileSync } from 'child_process';
import * as path from 'path';

function run(command: string, args: string[], cwd?: string): void {
  console.log(`\n> ${command} ${args.join(' ')}${cwd ? ` (cwd: ${cwd})` : ''}`);
  execFileSync(command, args, {
    stdio: 'inherit',
    cwd,
    env: process.env,
    shell: process.platform === 'win32',
  });
}

function main(): void {
  if (!process.env.DATABASE_URL) {
    console.error('DATABASE_URL must be set. See docs/database-ownership.md.');
    process.exit(1);
  }

  const repoRoot = path.resolve(__dirname, '..');
  const indexerDir = path.join(repoRoot, 'indexer');

  run('npx', ['prisma', 'migrate', 'deploy']);
  run('node', ['src/migrate.js'], indexerDir);

  console.log('\nDatabase bring-up complete: Prisma schema + indexer migrations applied.');
}

main();
