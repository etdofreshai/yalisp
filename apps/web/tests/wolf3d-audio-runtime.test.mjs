import assert from "node:assert/strict";
import test from "node:test";
import { createWolf3dAudioRuntime } from "../src/examples/runtime/wolf3d-audio-runtime.ts";

function session({ exportsReady = true } = {}) {
  return {
    evaluated: [],
    evaluate(source) {
      this.evaluated.push(source);
      if (source.startsWith("(bound?")) return exportsReady ? "true" : "false";
      if (source === "app.runtime-started") return exportsReady ? "1" : "0";
      if (source.startsWith("(app.advance-audio-timer")) return "true";
      if (source === "(app.adlib-register-export)") return "(2 ((0 32 6)))";
      if (source === "(app.music-register-export)") return "(10 ((0 64 7)))";
      if (source === "(app.audio-host-event-export)") return "((1 3 1 2 1 0 0 0 0 test))";
      throw new Error(`unexpected form: ${source}`);
    },
    evaluateBytes(source) {
      this.evaluated.push(source);
      return new Uint8Array([0, 0, 1, 0]);
    },
  };
}

function host({ oplReady = true } = {}) {
  const drains = [];
  const plays = [];
  return {
    drains,
    plays,
    async openRegisterSink({ serviceRate }) {
      let cursorService = 0;
      return {
        ok: oplReady,
        status: oplReady ? "ready" : "opl-unavailable",
        get cursorService() { return cursorService; },
        drain(input) {
          drains.push({ serviceRate, ...input });
          cursorService = input.throughService;
          return { ok: true, status: "ok", frames: 2, pcm: new Int16Array(4) };
        },
        close() { return true; },
      };
    },
    async renderEvent(event) {
      return { ok: true, status: "ok", frames: 2, pcm: new Int16Array(4), event };
    },
    async play(rendered) {
      plays.push(rendered);
      return { ok: true, status: "playing" };
    },
  };
}

test("Wolf3D browser audio advances both OPL clocks and native PCM", async () => {
  const evaluator = session();
  const audioHost = host();
  const runtime = createWolf3dAudioRuntime(evaluator, audioHost);
  assert.equal(runtime.available, true);
  await runtime.start();
  await runtime.advance(6);
  assert.deepEqual(audioHost.drains, [
    { serviceRate: 140, registerEvents: [[0, 32, 6]], throughService: 2 },
    { serviceRate: 700, registerEvents: [[0, 64, 7]], throughService: 10 },
  ]);
  assert.equal(audioHost.plays.length, 3);
  assert.ok(evaluator.evaluated.includes("(app.pc-pcm-bytes 3)"));
});

test("Wolf3D browser audio fails closed for missing exports or OPL", async () => {
  const missing = createWolf3dAudioRuntime(session({ exportsReady: false }), host());
  assert.equal(missing.available, false);
  await assert.rejects(missing.start(), /exports are unavailable/);

  const unavailable = createWolf3dAudioRuntime(session(), host({ oplReady: false }));
  await assert.rejects(unavailable.start(), /opl-unavailable/);
});
