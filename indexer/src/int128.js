/**
 * Helpers for parsing i128 and u128 ScVal values to BigInt.
 *
 * Both types are encoded in XDR as a hi/lo pair of 64-bit integers.
 * Combining them with bit-shift gives the full 128-bit value.
 */

/**
 * Parse a scvI128 ScVal to a BigInt.
 *
 * @param {import("@stellar/stellar-sdk").xdr.ScVal} scv  scvI128 ScVal
 * @returns {bigint}
 */
export function parseI128(scv) {
  const parts = scv.i128();
  const hi = BigInt(parts.hi().toString());
  const lo = BigInt(parts.lo().toString());
  return (hi << 64n) | lo;
}

/**
 * Parse a scvU128 ScVal to a BigInt.
 *
 * @param {import("@stellar/stellar-sdk").xdr.ScVal} scv  scvU128 ScVal
 * @returns {bigint}
 */
export function parseU128(scv) {
  const parts = scv.u128();
  const hi = BigInt(parts.hi().toString());
  const lo = BigInt(parts.lo().toString());
  return (hi << 64n) | lo;
}
