import assert from "node:assert/strict";
import test from "node:test";
import { loadLegacyOplDevice } from "../src/examples/runtime/legacy-opl-loader.ts";

test("legacy Emscripten OPL initialization settles without assimilating its Module thenable", async () => {
  const writes = [];
  const generated = [];
  let located;
  class OPL {
    constructor(sampleRate, channels, bufferBytes) {
      assert.deepEqual([sampleRate, channels, bufferBytes], [44_100, 2, 2048]);
      this.buffer = new Int16Array(1024);
      this.buffer[0] = 321;
    }
    getBuffer() { return this.buffer; }
    write(register, value) { writes.push([register, value]); }
    generate(frames) { generated.push(frames); }
  }
  const module = { OPL };
  // This deliberately returns itself, matching the legacy Emscripten Module.
  // Awaiting it directly would assimilate forever.
  const thenable = {
    then(callback) { queueMicrotask(() => callback(module)); return thenable; },
  };
  const loader = ({ locateFile }) => {
    located = [locateFile("opl.wasm"), locateFile("other.data")];
    return thenable;
  };

  const device = await Promise.race([
    loadLegacyOplDevice(loader, "/assets/opl-hash.wasm", 44_100, 2),
    new Promise((_, reject) => setTimeout(() => reject(new Error("loader did not settle")), 100)),
  ]);
  device.write(32, 7);
  const pcm = device.generate(2, Int16Array);
  assert.deepEqual(located, ["/assets/opl-hash.wasm", "other.data"]);
  assert.deepEqual(writes, [[32, 7]]);
  assert.deepEqual(generated, [2]);
  assert.equal(pcm.length, 4);
  assert.equal(pcm[0], 321);
});

test("legacy OPL initialization rejects fail-closed on abort, rejection, and timeout", async () => {
  const never = { then() { return never; } };
  const abortingLoader = (options) => {
    queueMicrotask(() => options.onAbort("fetch failed"));
    return never;
  };
  await assert.rejects(
    loadLegacyOplDevice(abortingLoader, "/assets/opl.wasm", 44_100, 2, { timeoutMs: 100 }),
    /initialization aborted: fetch failed/,
  );

  const rejection = new Error("compile failed");
  const rejecting = {
    then(_resolve, reject) { queueMicrotask(() => reject(rejection)); return rejecting; },
  };
  await assert.rejects(
    loadLegacyOplDevice(() => rejecting, "/assets/opl.wasm", 44_100, 2, { timeoutMs: 100 }),
    /initialization rejected: compile failed/,
  );

  await assert.rejects(
    loadLegacyOplDevice(() => never, "/assets/opl.wasm", 44_100, 2, { timeoutMs: 10 }),
    /timed out after 10 ms/,
  );
});
