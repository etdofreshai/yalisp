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
    assert.equal(error.recoverable, false);
    assert.equal(error.sessionDiscarded, true);
    assert.ok(error.cause instanceof WebAssembly.RuntimeError);
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

  assert.throws(() => instance.exports.eval_print(0x7fff_ffff, 1), (error) => {
    assert.ok(error instanceof WebAssembly.RuntimeError);
    assert.equal(instance.exports.error_kind(), 0);
    assert.equal(seedHarness.classifySeedTrap(error, 0, ""), error);
    return true;
  });
});
