import { describe, it, expect } from 'vitest';
import { en } from '../../src/i18n/locales/en';
import { es } from '../../src/i18n/locales/es';
import { ko } from '../../src/i18n/locales/ko';

describe('i18n locale key parity', () => {
  it('es should have the same keys as en', () => {
    const enKeys = Object.keys(en).sort();
    const esKeys = Object.keys(es).sort();
    expect(esKeys).toEqual(enKeys);
  });

  it('ko should have the same keys as en', () => {
    const enKeys = Object.keys(en).sort();
    const koKeys = Object.keys(ko).sort();
    expect(koKeys).toEqual(enKeys);
  });
});
