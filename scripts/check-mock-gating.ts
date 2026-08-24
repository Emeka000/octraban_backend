/**
 * Mock/experimental data gating guard (Issue #7)
 *
 * Any src/api file that mentions "mock" (case-insensitive, in code or
 * comments) must import the shared gating framework from
 * src/config/mockData.ts. This keeps fabricated/experimental data from
 * leaking into API responses without going through the MOCK_DATA flag and
 * being explicitly annotated with `mock: true`.
 *
 * Usage:
 *   npx ts-node --transpile-only scripts/check-mock-gating.ts
 *   npm run check:mock-gating
 */

import * as fs from 'fs';
import * as path from 'path';

const API_DIR = path.resolve(__dirname, '../src/api');
const FRAMEWORK_IMPORT_RE = /config\/mockData/;
const MOCK_WORD_RE = /mock/i;

interface Violation {
  file: string;
  line: number;
  text: string;
}

/** Recursively collect all .ts files under a directory */
function collectTs(dir: string): string[] {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const files: string[] = [];
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) files.push(...collectTs(full));
    else if (entry.isFile() && entry.name.endsWith('.ts')) files.push(full);
  }
  return files;
}

/**
 * Any file under src/config/ is the framework itself (or a sibling config
 * module) and is exempt from having to import itself.
 */
function isExempt(file: string): boolean {
  return path.resolve(file) === path.resolve(API_DIR, '../config/mockData.ts');
}

export function findViolations(dir: string = API_DIR): Violation[] {
  const files = collectTs(dir);
  const violations: Violation[] = [];

  for (const file of files) {
    if (isExempt(file)) continue;

    const content = fs.readFileSync(file, 'utf-8');
    if (!MOCK_WORD_RE.test(content)) continue;
    if (FRAMEWORK_IMPORT_RE.test(content)) continue;

    content.split('\n').forEach((line, idx) => {
      if (MOCK_WORD_RE.test(line)) {
        violations.push({
          file: path.relative(process.cwd(), file),
          line: idx + 1,
          text: line.trim(),
        });
      }
    });
  }

  return violations;
}

if (require.main === module) {
  const violations = findViolations();

  console.log('\n═══════════════════════════════════════════════════');
  console.log('  Mock/Experimental Data Gating Check');
  console.log('═══════════════════════════════════════════════════\n');

  if (violations.length === 0) {
    console.log('✅ No ungated mock/fabricated data found in src/api\n');
    process.exit(0);
  }

  console.log(
    `❌ Found ${violations.length} reference(s) to "mock" data that do not import the shared gating framework (src/config/mockData.ts):\n`,
  );
  for (const v of violations) {
    console.log(`   • ${v.file}:${v.line}  ${v.text}`);
  }
  console.log(
    '\nEvery endpoint that returns synthetic/fabricated data must import\n' +
      '{ isMockDataEnabled, sendMockGated, annotateMock } from "../config/mockData"\n' +
      'and gate its response behind MOCK_DATA (see README.md "Experimental & Mock Data").\n' +
      'Fix the endpoint above, or if this is a legitimate false positive, reword the\n' +
      'identifier/comment so it no longer contains "mock".\n',
  );
  process.exit(1);
}
