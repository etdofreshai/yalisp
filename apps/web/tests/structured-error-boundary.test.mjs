import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import * as seedHarness from "./seed-session.mjs";

test("an intentional unbound-name failure is a typed language error", async () => {
  assert.equal(typeof seedHarness.SeedLanguageError, "function");
  const session = await seedHarness.createSeedSession({ boot: false });
  assert.throws(() => session.evaluate("m3.missing"), (error) => {
    assert.ok(error instanceof seedHarness.SeedLanguageError);
    assert.equal(error.category, "unbound-name");
    assert.equal(error.categoryCode, 1);
    assert.equal(error.diagnostic, "unbound: m3.missing");
    assert.equal(error.data, "m3.missing");
    assert.equal(error.recoverable, true);
    assert.equal(error.sessionDiscarded, false);
    assert.ok(error.cause instanceof WebAssembly.RuntimeError);
    return true;
  });
});

test("recoverable language errors retain state while unsafe failures discard", async () => {
  const recoverable = await seedHarness.createSeedSession({ boot: false });
  recoverable.evaluateQuietly("(define m3.saved 41)");
  assert.throws(() => recoverable.evaluate("m3.missing"), (error) => {
    assert.ok(error instanceof seedHarness.SeedLanguageError);
    assert.equal(error.recoverable, true);
    assert.equal(error.sessionDiscarded, false);
    return true;
  });
  assert.equal(recoverable.evaluate("(+ m3.saved 1)"), "42");

  const exhausted = await seedHarness.createSeedSession({ boot: false });
  assert.throws(() => exhausted.evaluate("(heap.reserve 1073741823)"), (error) => {
    assert.ok(error instanceof seedHarness.SeedLanguageError);
    assert.equal(error.category, "resource-exhausted");
    assert.equal(error.recoverable, false);
    assert.equal(error.sessionDiscarded, true);
    return true;
  });
  assert.throws(() => exhausted.evaluate("42"), (error) => {
    assert.ok(error instanceof seedHarness.SeedSessionDiscardedError);
    return true;
  });
});

test("an unclassified raw Wasm fault remains a runtime fault", async () => {
  assert.equal(typeof seedHarness.classifySeedTrap, "function");
  const bytes = await readFile(new URL("../public/yalisp/seed.wasm", import.meta.url));
  let memory;
  const { instance } = await WebAssembly.instantiate(bytes, {
    host: {
      write() {},
      bytes_write() {},
    },
  });
  memory = instance.exports.memory;
  assert.ok(memory instanceof WebAssembly.Memory);
  instance.exports.init();
  assert.equal(instance.exports.error_kind(), 0);
  assert.equal(instance.exports.error_data_length(), 0);
  assert.throws(() => instance.exports.asset_commit(), WebAssembly.RuntimeError);
  assert.equal(instance.exports.error_kind(), 10);

  assert.throws(() => instance.exports.eval_print(0x7fff_ffff, 1), (error) => {
    assert.ok(error instanceof WebAssembly.RuntimeError);
    assert.equal(instance.exports.error_kind(), 0);
    assert.equal(instance.exports.error_data_length(), 0);
    assert.equal(seedHarness.classifySeedTrap(error, 0, ""), error);
    return true;
  });
});

test("intentional seed diagnostics expose stable category records", async () => {
  for (const fixture of [
    { category: "reader", code: 2, diagnostic: "read error", data: "read error", method: "read", source: ")" },
    { category: "arity", code: 3, diagnostic: "unquote expected", data: "unquote", source: "(quasiquote (unquote))" },
    { category: "type", code: 4, diagnostic: "string expected", data: "string expected", source: "(string.length 1)" },
    { category: "apply", code: 5, diagnostic: "cannot apply", data: "cannot apply", source: "(1 2)" },
    {
      category: "arithmetic", code: 6, diagnostic: "value exceeds fixnum range", data: "value exceeds fixnum range",
      source: "(begin (define m3.word (bytes.alloc 4)) (u8! m3.word 3 64) (i32@ m3.word 0))",
    },
    { category: "bounds", code: 7, diagnostic: "byte index out of range", data: "byte index out of range", source: "(u8@ (bytes.alloc 1) 1)" },
    { category: "resource-exhausted", code: 8, diagnostic: "memory limit reached", data: "memory limit reached", source: "(heap.reserve 1073741823)" },
  ]) {
    const session = await seedHarness.createSeedSession({ boot: false });
    assert.throws(() => session[fixture.method ?? "evaluate"](fixture.source), (error) => {
      assert.ok(error instanceof seedHarness.SeedLanguageError, fixture.category);
      assert.equal(error.category, fixture.category);
      assert.equal(error.categoryCode, fixture.code);
      assert.equal(error.diagnostic, fixture.diagnostic);
      assert.equal(error.data, fixture.data);
      return true;
    });
  }

  const immutable = await seedHarness.createSeedSession({ boot: false });
  immutable.evaluateQuietly("(asset.reserve 1)");
  immutable.ingestBytes(Uint8Array.of(0));
  assert.throws(() => immutable.evaluate("(u8! (asset.ref 0) 0 1)"), (error) => {
    assert.ok(error instanceof seedHarness.SeedLanguageError);
    assert.equal(error.category, "mutation");
    assert.equal(error.categoryCode, 9);
    assert.equal(error.diagnostic, "immutable byte buffer");
    assert.equal(error.data, "immutable byte buffer");
    return true;
  });
});

test("host-ingest protocol failures have a seed-owned category", async () => {
  const bytes = await readFile(new URL("../public/yalisp/seed.wasm", import.meta.url));
  const { instance } = await WebAssembly.instantiate(bytes, {
    host: { write() {}, bytes_write() {} },
  });
  instance.exports.init();
  assert.throws(() => instance.exports.asset_commit(), (error) => {
    const classified = seedHarness.classifySeedTrap(
      error, instance.exports.error_kind(), "asset ingest protocol", "asset ingest protocol",
    );
    assert.ok(classified instanceof seedHarness.SeedLanguageError);
    assert.equal(classified.category, "host-contract");
    assert.equal(classified.categoryCode, 10);
    assert.equal(classified.data, "asset ingest protocol");
    return true;
  });
});
