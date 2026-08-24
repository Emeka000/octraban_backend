import { describe, it, expect, afterEach } from 'vitest';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { findViolations } from '../../scripts/check-mock-gating';

// ── Helpers ────────────────────────────────────────────────────────────────────

const tmpDirs: string[] = [];

function makeTmpDir(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mock-gating-test-'));
  tmpDirs.push(dir);
  return dir;
}

afterEach(() => {
  while (tmpDirs.length > 0) {
    const dir = tmpDirs.pop()!;
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

describe('check-mock-gating guard (Issue #7)', () => {
  it('fails on a deliberately added ungated mock response', () => {
    const dir = makeTmpDir();
    fs.writeFileSync(
      path.join(dir, 'ungated.ts'),
      [
        "import { Router } from 'express';",
        'export const router = Router();',
        'const mockPrice = 42; // fabricated, not gated',
        "router.get('/', (_req, res) => res.json({ price: mockPrice }));",
        '',
      ].join('\n'),
    );

    const violations = findViolations(dir);
    expect(violations.length).toBeGreaterThan(0);
    expect(violations[0].file).toContain('ungated.ts');
  });

  it('does not flag a file that imports the shared mock-data framework', () => {
    const dir = makeTmpDir();
    fs.writeFileSync(
      path.join(dir, 'gated.ts'),
      [
        "import { Router } from 'express';",
        "import { sendMockGated } from '../config/mockData';",
        'export const router = Router();',
        'const mockPrice = 42;',
        "router.get('/', (_req, res) => sendMockGated(res, { price: mockPrice }));",
        '',
      ].join('\n'),
    );

    expect(findViolations(dir)).toEqual([]);
  });

  it('ignores files with no mention of "mock"', () => {
    const dir = makeTmpDir();
    fs.writeFileSync(
      path.join(dir, 'clean.ts'),
      "export const answer = 42;\n",
    );

    expect(findViolations(dir)).toEqual([]);
  });

  it('passes with zero violations against the real src/api tree', () => {
    expect(findViolations()).toEqual([]);
  });
});
