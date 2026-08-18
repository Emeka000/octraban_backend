import { defineConfig } from 'vitest/config';
import { DB_INTEGRATION_SUITES } from './vitest.config.js';

// Runs only the suites that need a real, reachable PostgreSQL database.
// Requires DATABASE_URL or TEST_DATABASE_URL to point at that database —
// see CONTRIBUTING.md. Deliberately NOT a merge of vitest.config.js: that
// config's `exclude` covers exactly these suites, and vitest/vite merge
// array options by concatenation rather than override, which would leave
// them excluded here too.
export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: DB_INTEGRATION_SUITES,
    testTimeout: 30_000,
    hookTimeout: 30_000,
    fileParallelism: false,
  },
});
