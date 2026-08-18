/**
 * Low-level XDR decoder for Soroban ContractEvent blobs.
 *
 * Accepts a base64-encoded ContractEvent XDR string (as returned by the
 * Soroban RPC `getEvents` endpoint) and returns a plain JS object with
 * decoded `topics` and `value` fields.
 *
 * Used by the test suite to validate ScVal decoding in isolation from the
 * higher-level `decode()` pipeline in decoder.js (which requires a live DB).
 */

import { xdr as StellarXdr, StrKey } from "@stellar/stellar-sdk";

/**
 * Decode a single ScVal to a native JavaScript value.
 *
 * Integer types wider than 32 bits are returned as strings to avoid
 * precision loss (Number can only safely represent integers up to 2^53).
 *
 * @param {StellarXdr.ScVal} val
 * @returns {*}
 */
function scValToNative(val) {
  if (!val) return null;

  const type = val.switch().name;

  switch (type) {
    case "scvBool":
      return val.b();

    case "scvVoid":
      return null;

    case "scvError":
      return { error: val.error().toString() };

    case "scvU32":
      return val.u32();

    case "scvI32":
      return val.i32();

    // 64-bit integers: return as string to preserve precision
    case "scvU64":
      return val.u64().toString();

    case "scvI64":
      return val.i64().toString();

    case "scvTimepoint":
      return val.timepoint().toString();

    case "scvDuration":
      return val.duration().toString();

    // 128-bit integers: return as string
    case "scvU128": {
      const u = val.u128();
      const result = (BigInt(u.hi().toString()) << 64n) | BigInt(u.lo().toString());
      return result.toString();
    }

    case "scvI128": {
      const i = val.i128();
      const result = (BigInt(i.hi().toString()) << 64n) | BigInt(i.lo().toString());
      return result.toString();
    }

    // 256-bit integers: return as string
    case "scvU256": {
      const u = val.u256();
      const result =
        (BigInt(u.hiHi().toString()) << 192n) |
        (BigInt(u.hiLo().toString()) << 128n) |
        (BigInt(u.loHi().toString()) << 64n) |
        BigInt(u.loLo().toString());
      return result.toString();
    }

    case "scvI256": {
      const i = val.i256();
      const result =
        (BigInt(i.hiHi().toString()) << 192n) |
        (BigInt(i.hiLo().toString()) << 128n) |
        (BigInt(i.loHi().toString()) << 64n) |
        BigInt(i.loLo().toString());
      return result.toString();
    }

    case "scvBytes":
      return Buffer.from(val.bytes()).toString("hex");

    case "scvString":
      return val.str().toString();

    case "scvSymbol":
      return val.sym().toString();

    case "scvVec":
      return (val.vec() ?? []).map(scValToNative);

    case "scvMap": {
      const obj = {};
      for (const entry of val.map() ?? []) {
        const k = scValToNative(entry.key());
        obj[String(k)] = scValToNative(entry.val());
      }
      return obj;
    }

    case "scvAddress": {
      const addr = val.address();
      const addrType = addr.switch().name;
      if (addrType === "scAddressTypeAccount") {
        const accountId = addr.accountId();
        // accountId() may be a PublicKey (with .ed25519()) or raw bytes
        const raw =
          typeof accountId.ed25519 === "function"
            ? accountId.ed25519()
            : accountId;
        return StrKey.encodeEd25519PublicKey(raw);
      }
      if (addrType === "scAddressTypeContract") {
        return StrKey.encodeContract(addr.contractId());
      }
      return addr.toString();
    }

    case "scvLedgerKeyContractInstance":
      return { type: "ledgerKeyContractInstance" };

    case "scvLedgerKeyNonce":
      return {
        type: "ledgerKeyNonce",
        nonce: BigInt(val.nonceKey().nonce().toString()),
      };

    case "scvContractInstance":
      return { type: "contractInstance" };

    default:
      return String(val);
  }
}

/**
 * Decode a base64-encoded Soroban ContractEvent XDR blob.
 *
 * Throws for invalid or truncated XDR.
 *
 * @param {string} base64Xdr  Base64-encoded ContractEvent
 * @returns {{ topics: Array<*>, value: * }}
 */
export function decodeContractEvent(base64Xdr) {
  const event = StellarXdr.ContractEvent.fromXDR(base64Xdr, "base64");

  const body = event.body().value();
  const topics = (body.topics() ?? []).map(scValToNative);
  const value = scValToNative(body.data());

  return { topics, value };
}
