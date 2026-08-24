/**
 * Unit tests for the decode-fallback metric (indexer/src/decoder.js).
 *
 * Covers issue #51: decoding an unrecognized event must increment
 * soroban_decode_fallback_total (labeled by contract) and emit a structured
 * debug log; decoding a known event must not.
 */
import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { isDecodeFallback, recordDecodeFallback } from "../src/decoder.js";
import { decodeFallbackTotal } from "../src/metrics.js";

async function counterValue(contractId) {
  const { values } = await decodeFallbackTotal.get();
  const match = values.find((v) => v.labels.contract_id === contractId);
  return match ? match.value : 0;
}

describe("isDecodeFallback", () => {
  it("is true for the unrecognized-function sentinel", () => {
    assert.equal(isDecodeFallback("unknown"), true);
  });

  it("is false for a recognized function name", () => {
    assert.equal(isDecodeFallback("transfer"), false);
  });
});

describe("recordDecodeFallback", () => {
  it("increments the fallback counter for an unrecognized event", async () => {
    const contractId = "CFALLBACKTEST0000000000000000000000000000000000000001";
    const before = await counterValue(contractId);

    recordDecodeFallback(contractId, { ledger: 12345, txHash: "deadbeef" });

    const after = await counterValue(contractId);
    assert.equal(after, before + 1);
  });

  it("labels the counter by contract so unrelated contracts stay isolated", async () => {
    const contractA = "CFALLBACKTEST0000000000000000000000000000000000000002";
    const contractB = "CFALLBACKTEST0000000000000000000000000000000000000003";

    recordDecodeFallback(contractA, { ledger: 1, txHash: "aa" });

    assert.equal(await counterValue(contractA), 1);
    assert.equal(await counterValue(contractB), 0);
  });

  it("does not increment for a known event (decode() only calls it when isDecodeFallback is true)", async () => {
    const contractId = "CFALLBACKTEST0000000000000000000000000000000000000004";
    // Mirrors the gate in decode(): a known fnName never reaches recordDecodeFallback.
    const fnName = "transfer";
    if (isDecodeFallback(fnName)) {
      recordDecodeFallback(contractId, { ledger: 1, txHash: "bb" });
    }
    assert.equal(await counterValue(contractId), 0);
  });

  it("emits a structured debug log with contract, ledger, and tx hash", () => {
    const calls = [];
    const stubLogger = { debug: (...args) => calls.push(args) };
    const contractId = "CFALLBACKTEST0000000000000000000000000000000000000005";

    recordDecodeFallback(contractId, { ledger: 999, txHash: "cafebabe" }, stubLogger);

    assert.equal(calls.length, 1);
    const logged = JSON.parse(calls[0][0]);
    assert.equal(logged.component, "decoder");
    assert.equal(logged.event, "decode_fallback");
    assert.equal(logged.contract_id, contractId);
    assert.equal(logged.ledger, 999);
    assert.equal(logged.tx_hash, "cafebabe");
  });
});
