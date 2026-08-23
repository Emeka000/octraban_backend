// @ts-check
import { scValToNative } from "@stellar/stellar-sdk";
import { db } from "./db.js";
import { detectSac, detectSacAsset } from "./sac.js";
import { extractRoleAssignment } from "./roleTracker.js";
import { decodeRwaEvent } from "./rwaDecoder.js";
import { parseHeuristic } from "./heuristicParser.js";
import { parseTTLHostFunction, formatTTLExtension } from "./ttlExtensionParser.js";
import { parseZkHostFunctions, computeZkCostDelta } from "./zkHostFunctions.js";
import { decodeFallbackTotal } from "./metrics.js";

/**
 * Raw Soroban RPC event as received from the RPC poller. The `txMeta` field
 * carries an XDR `TransactionMeta` object whose shape depends on the protocol
 * version, so it — and other RPC-specific fields — are left loosely typed
 * rather than fully modeled against the XDR type definitions.
 * @typedef {object} SorobanRpcEvent
 * @property {string} contractId
 * @property {any[]} topic
 * @property {any} value
 * @property {number} ledger
 * @property {string} txHash
 * @property {string} [txResultCode]
 * @property {string} [resultCode]
 * @property {{ code?: string }} [result]
 * @property {string | number} [feeCharged]
 * @property {any} [txMeta]
 * @property {any} [hostFunction]
 * @property {any} [host_function]
 * @property {any} [operation]
 */

/**
 * The decoded event as produced by `decode()`. Downstream pipeline stages
 * (bloat/footprint/fee-bump/archival/upgrade detectors — outside this file)
 * enrich the object with additional optional fields before it reaches
 * `db.upsertEvent`, so those are modeled here too.
 * @typedef {object} DecodedEvent
 * @property {string} contract_id
 * @property {string} function
 * @property {number} ledger
 * @property {string} tx_hash
 * @property {string | null} description
 * @property {string[]} raw_topics
 * @property {string} raw_data
 * @property {string} [sac_asset]
 * @property {boolean} [is_clawback]
 * @property {boolean} [is_resource_limit_exceeded]
 * @property {number} [cpu_instructions]
 * @property {number} [mem_bytes]
 * @property {number} [fee_charged]
 * @property {unknown} [heuristic_params]
 * @property {unknown} [ttl_extension]
 * @property {boolean} [is_high_bloat_risk]
 * @property {unknown} [upgrade]
 * @property {unknown} [storage_tiers]
 * @property {boolean} [footprint_contention]
 * @property {unknown} [fee_bump]
 * @property {unknown} [archival_info]
 * @property {unknown} [zk_host_calls]
 * @property {boolean} [decoded]
 */

// Result codes that indicate the block compute budget was exhausted.
const RESOURCE_LIMIT_CODES = new Set([
  "tx_resource_limit_exceeded",
  "txResourceLimitExceeded",
  "RESOURCE_LIMIT_EXCEEDED",
]);

/**
 * Returns true when the transaction was dropped because the block's total
 * resource budget was full.
 * @param {SorobanRpcEvent} ev  Raw Soroban RPC event
 */
function isResourceLimitExceeded(ev) {
  const code = ev.txResultCode ?? ev.resultCode ?? ev.result?.code ?? "";
  return RESOURCE_LIMIT_CODES.has(String(code));
}

/**
 * Extract resource usage costs from the Soroban RPC event's transaction metadata.
 *
 * The Soroban RPC event object may carry a `feeCharged` field directly, and
 * the `txMeta` (TransactionMeta XDR) contains sorobanMeta with resource usage.
 * Fields:
 *   cpu_instructions — SorobanTransactionMeta.ext.v1.totalNonRefundableResourceFeeCharged
 *                      (non-refundable fees are proportional to CPU consumed)
 *   fee_charged      — SorobanTransactionMeta.ext.v1.totalRefundableResourceFeeCharged
 *   mem_bytes        — SorobanTransactionMeta.ext.v1.rentFeeCharged (rent ∝ memory)
 *
 * @param {SorobanRpcEvent} ev  Raw Soroban RPC event
 * @returns {{ cpu_instructions?: number, mem_bytes?: number, fee_charged?: number }}
 */
function extractGasCosts(ev) {
  /** @type {{ cpu_instructions?: number, mem_bytes?: number, fee_charged?: number }} */
  const result = {};

  try {
    if (ev.feeCharged != null) result.fee_charged = Number(ev.feeCharged);

    const meta = ev.txMeta;
    if (!meta) return result;

    let sorobanMeta = null;
    try {
      sorobanMeta = meta.v3?.().sorobanMeta?.() ?? null;
    } catch {
      /* not v3 */
    }

    if (!sorobanMeta) return result;

    try {
      const extV1 = sorobanMeta.ext?.().v1?.();
      if (extV1) {
        // Non-refundable fee is a proxy for CPU consumption
        if (extV1.totalNonRefundableResourceFeeCharged != null)
          result.cpu_instructions = Number(extV1.totalNonRefundableResourceFeeCharged);
        if (extV1.totalRefundableResourceFeeCharged != null)
          result.fee_charged = Number(extV1.totalRefundableResourceFeeCharged);
        // Rent fee is a proxy for memory/storage consumption
        if (extV1.rentFeeCharged != null)
          result.mem_bytes = Number(extV1.rentFeeCharged);
      }
    } catch {
      /* ext not v1 */
    }
  } catch {
    /* ignore all extraction errors */
  }

  return result;
}

// Native XLM Stellar Asset Contract IDs (testnet + mainnet)
const NATIVE_SAC_IDS = new Set([
  "CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC", // testnet
  "CAS3J7GYLGXMF6TDJBBYYSE3HQ6BBSMLNUQ34T6TZMYMW2EVH34XOWMA", // mainnet
]);

/** @param {string} fnName */
export function isDecodeFallback(fnName) {
  return fnName === "unknown";
}

/**
 * Record a decode fallback: increments the Prometheus counter (labeled by
 * contract) and emits a structured debug log for sampling/investigation.
 * @param {string} contractId
 * @param {{ ledger?: number, txHash?: string }} ev
 * @param {{ debug: (...args: any[]) => void }} [logger]
 */
export function recordDecodeFallback(contractId, ev, logger = console) {
  decodeFallbackTotal.inc({ contract_id: contractId });
  logger.debug(
    JSON.stringify({
      component: "decoder",
      event: "decode_fallback",
      contract_id: contractId,
      ledger: ev.ledger,
      tx_hash: ev.txHash,
    }),
  );
}

/**
 * Decode a raw Soroban RPC event into a human-readable record.
 * Uses the ABI template when available; falls back to a generic description.
 * @param {SorobanRpcEvent} ev
 * @returns {Promise<DecodedEvent>}
 */
export async function decode(ev) {
  const contractId = ev.contractId;
  const topics = ev.topic.map((t) => scValToNative(t));
  const data = scValToNative(ev.value);

  // First topic is typically the function name symbol
  const fnName = typeof topics[0] === "symbol" || typeof topics[0] === "string" ? String(topics[0]) : "unknown";
  if (isDecodeFallback(fnName)) {
    recordDecodeFallback(contractId, ev);
  }

  // Detect native XLM wrap/unwrap on the SAC contract
  if (NATIVE_SAC_IDS.has(contractId)) {
    const wrapUnwrap = nativeXlmDescription(fnName, topics.slice(1), data);
    if (wrapUnwrap) {
      return {
        contract_id: contractId,
        function: wrapUnwrap.function,
        ledger: ev.ledger,
        tx_hash: ev.txHash,
        description: wrapUnwrap.description,
        raw_topics: topics.map(String),
        raw_data: JSON.stringify(data),
        ...extractGasCosts(ev),
      };
    }
  }

  // Look up registered ABI for richer description
  // Use versioned lookup: find the ABI version active at the event's ledger
  const meta = await db
    .getContractMetaByLedger(contractId, ev.ledger)
    .catch(() => null) ?? await db.getContractMeta(contractId).catch(() => null);
  const fnAbi = meta?.functions?.find((/** @type {any} */ f) => f.name === fnName);

  // Check if this contract is a registered vault
  const vaultMeta = await db.getVault(contractId).catch(() => null);

  const { isSac, assetCode } = detectSac(contractId);
  detectSacAsset(contractId);
  const contractLabel = vaultMeta?.name
    ? `${vaultMeta.name} (Vault)`
    : isSac
      ? `${assetCode} (SAC:${contractId.slice(0, 8)}…)`
      : (meta?.name ?? contractId);

  // Try RWA decoder first
  let description = null;
  if (meta) {
    const tempDecoded = {
      contract_id: contractId,
      function: fnName,
      raw_topics: topics.map(String),
      raw_data: JSON.stringify(data),
    };
    description = decodeRwaEvent(tempDecoded, meta);
  }

  // Fall back to standard decoders
  if (!description) {
    description = vaultMeta
      ? vaultDescription(fnName, topics.slice(1), data, contractLabel, vaultMeta)
      : fnAbi
        ? buildDescription(fnName, topics.slice(1), data, contractLabel)
        : genericDescription(fnName, topics.slice(1), data, contractLabel);
  }

  // Attach heuristic params when no ABI was available
  const heuristicParams =
    !fnAbi && !vaultMeta && !meta ? parseHeuristic([...topics.slice(1), ...(data != null ? [data] : [])]) : undefined;

  const decoded = /** @type {DecodedEvent} */ ({
    contract_id: contractId,
    function: fnName,
    ledger: ev.ledger,
    tx_hash: ev.txHash,
    description,
    raw_topics: topics.map(String),
    raw_data: JSON.stringify(data),
    ...(isSac && { sac_asset: assetCode }),
    is_clawback: fnName === "clawback",
    is_resource_limit_exceeded: isResourceLimitExceeded(ev),
    ...extractGasCosts(ev),
    ...(heuristicParams && { heuristic_params: heuristicParams }),
  });

  // Protocol 26: detect TTL extension host function calls on this event
  const ttlExt = parseTTLHostFunction(ev.hostFunction ?? ev.host_function ?? ev.operation ?? null);
  if (ttlExt) {
    decoded.ttl_extension = ttlExt;
    decoded.description = formatTTLExtension(ttlExt);
  }

  // Protocol 26: detect CAP-0080 ZK host function calls
  const zkCalls = parseZkHostFunctions(ev);
  if (zkCalls) {
    decoded.zk_host_calls = {
      calls: zkCalls,
      delta: computeZkCostDelta(zkCalls),
    };
  }

  // Persist role assignment if this event carries one
  const roleAssignment = extractRoleAssignment(decoded);
  if (roleAssignment) {
    db.upsertRole({
      contract_id: contractId,
      ledger: ev.ledger,
      ...roleAssignment,
    }).catch((err) => console.error("[roleTracker] upsertRole failed:", err.message));
  }

  return decoded;
}

/**
 * Returns wrap/unwrap label and description for native XLM SAC events.
 * mint on native SAC = Classic XLM → Soroban (wrap)
 * burn on native SAC = Soroban → Classic XLM (unwrap)
 * @param {string} fnName
 * @param {any[]} args
 * @param {any} data
 * @returns {{ function: string, description: string } | null}
 */
export function nativeXlmDescription(fnName, args, data) {
  if (fnName === "mint") {
    const [to, amount] = args;
    const amt = amount ?? data;
    return {
      function: "wrap_native",
      description: `Wrapped ${fmtXlm(amt)} XLM (Classic → Soroban) to ${fmt(to)}`,
    };
  }
  if (fnName === "burn") {
    const [from, amount] = args;
    const amt = amount ?? data;
    return {
      function: "unwrap_native",
      description: `Unwrapped ${fmtXlm(amt)} XLM (Soroban → Classic) from ${fmt(from)}`,
    };
  }
  return null;
}

/**
 * @param {string} fn
 * @param {any[]} args
 * @param {any} data
 * @param {string} contractName
 * @param {{ name?: string, underlying_asset?: string }} vaultMeta
 * @returns {string}
 */
function vaultDescription(fn, args, data, contractName, vaultMeta) {
  const assetLabel = vaultMeta.underlying_asset
    ? `asset ${vaultMeta.underlying_asset.slice(0, 6)}…${vaultMeta.underlying_asset.slice(-4)}`
    : "underlying asset";
  switch (fn) {
    case "mint":
    case "deposit": {
      const [admin, to, amount, shares] = args;
      return `Deposited ${String(amount ?? data ?? "?")} ${assetLabel} → minted ${String(shares ?? "?")} shares to ${fmt(to ?? admin)} on ${contractName}`;
    }
    case "burn":
    case "withdraw": {
      const [admin, from, to, assets, shares] = args.length >= 4 ? args : [null, null, args[0], args[1], args[2]];
      const amt = assets ?? data;
      const shr = shares ?? "?";
      return `Burned ${String(shr)} shares → withdrew ${String(amt)} ${assetLabel} from ${fmt(from ?? admin ?? to)} on ${contractName}`;
    }
    default:
      return genericDescription(fn, args, data, contractName);
  }
}

/**
 * Build a human-readable description from decoded ABI-matched function arguments.
 *
 * SEP-41 transfer format:
 *   "Address {short-from} transferred {amount} {token} to {short-to} on {contractName}"
 * where short addresses are truncated to "AAAAAA…ZZZZ" (6 + 4 chars).
 * @param {string} fn
 * @param {any[]} args
 * @param {any} data
 * @param {string} contractName
 * @returns {string}
 */
export function buildDescription(fn, args, data, contractName) {
  switch (fn) {
    case "swap": {
      const [from, amtIn, tokenIn, amtOut, tokenOut] = args;
      return `Address ${fmt(from)} swapped ${amtIn} ${tokenIn} → ${amtOut} ${tokenOut} on ${contractName}`;
    }
    case "transfer": {
      const [from, to, amount, token] = args;
      return `Address ${fmt(from)} transferred ${amount} ${token ?? ""} to ${fmt(to)} on ${contractName}`;
    }
    case "mint": {
      const [to, amount, token] = args;
      return `${amount} ${token ?? ""} minted to ${fmt(to)} on ${contractName}`;
    }
    case "burn": {
      const [from, amount, token] = args;
      return `${amount} ${token ?? ""} burned from ${fmt(from)} on ${contractName}`;
    }
    case "clawback": {
      const [admin, from, amount, token] = args;
      return `CLAWBACK: ${amount} ${token ?? ""} recovered from ${fmt(from)} by authority ${fmt(admin)} on ${contractName}`;
    }
    default:
      return genericDescription(fn, args, data, contractName);
  }
}

/**
 * @param {string} fn
 * @param {any[]} args
 * @param {any} data
 * @param {string} contractId
 * @returns {string}
 */
function genericDescription(fn, args, data, contractId) {
  const argStr = args.map(String).join(", ");
  return `${fn}(${argStr}) called on ${contractId}`;
}

/** @param {any} addr */
function fmt(addr) {
  if (typeof addr !== "string" || addr.length < 10) return String(addr);
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
}

/** @param {any} amount */
function fmtXlm(amount) {
  if (amount == null) return "?";
  // SAC amounts are in stroops (1 XLM = 10_000_000 stroops)
  const n = Number(amount);
  return isNaN(n) ? String(amount) : (n / 1e7).toLocaleString(undefined, { maximumFractionDigits: 7 });
}
