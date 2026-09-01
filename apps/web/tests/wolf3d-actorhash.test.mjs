import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { mountDeclaredAssets } from "../src/examples/runtime/asset-mount.ts";
import { parseLispValue } from "../src/examples/runtime/lisp-value.ts";
import { createSeedSession } from "./seed-session.mjs";
import { fromPublic, haveWolf3dOriginals, loadWolf3d, wolf3dSkipReason,
  wolf3dSources as sources } from "./wolf3d-source.mjs";
import {
  LONG_REPLAY_CAPACITY_BYTES,
  LONG_REPLAY_HEAP_BASE_BYTES,
  observeCleanHeapUsed,
  prepareLongReplay,
  replayTraceRecord,
} from "./wolf3d-replay.mjs";

const LIMIT = 130048;
const MIN_HEADROOM_BYTES = 64 * 1024 * 1024;
const mix = (hash, value) => (Math.imul(hash, 33) ^ value) >>> 0;
const hashValues = (values) => values.reduce(mix, 5381) >>> 0;
const route = JSON.parse(await readFile(
  new URL("./fixtures/wolf3d-r1-route-v3.json", import.meta.url), "utf8"));

async function session() {
  const value = await createSeedSession();
  loadWolf3d(value);
  return value;
}

async function application() {
  const value = await session();
  await mountDeclaredAssets(value, fromPublic);
  const reserve = prepareLongReplay(value);
  return { value, reserve };
}

const player = (x = 0x12345678) =>
  [1, 0, 1, 0, 4, 0, 0, x, -2, 7, 8, 359, 0, 0, 0, 0, 0];
const enemy = (x) =>
  [1, 7, 3, 58, 1, -65535, 4, x, 0x23456789, 6, 33, 0, 25, 512, 0, 0, 0];

function installSyntheticActors(value, firstX = 1, secondX = 2) {
  value.evaluateQuietly(`
    (begin
      (wl.player! wl.PLAYER-X ${player()[7]}) (wl.player! wl.PLAYER-Y -2)
      (wl.player! wl.PLAYER-TILEX 7) (wl.player! wl.PLAYER-TILEY 8)
      (wl.player! wl.PLAYER-ANGLE 359) (wl.player! wl.PLAYER-STATE 0)
      (wl.player! wl.PLAYER-FLAGS 4) (set! wl.actorcount 2)
      (u8! wl.actorclass 0 3) (u8! wl.actorclass 1 3)
      (wl.actor-phase! 0 0) (wl.actor-phase! 1 0)
      (wl.actor-active! 0 1) (wl.actor-active! 1 1)
      (wl.actor-ticcount! 0 7) (wl.actor-ticcount! 1 7)
      (wl.actor-flags! 0 1) (wl.actor-flags! 1 1)
      (wl.actor-distance! 0 -65535) (wl.actor-distance! 1 -65535)
      (wl.actor-dir! 0 4) (wl.actor-dir! 1 4)
      (wl.actor-x! 0 ${firstX}) (wl.actor-x! 1 ${secondX})
      (wl.actor-y! 0 ${enemy(0)[8]}) (wl.actor-y! 1 ${enemy(0)[8]})
      (wl.actor-tilex! 0 6) (wl.actor-tilex! 1 6)
      (wl.actor-tiley! 0 33) (wl.actor-tiley! 1 33)
      (wl.actor-hitpoints! 0 25) (wl.actor-hitpoints! 1 25)
      (u16! wl.actorspeed 0 512) (u16! wl.actorspeed 2 512)
      (wl.actor-temp2! 0 0) (wl.actor-temp2! 1 0)
      (wl.actor-aux-zero! 0) (wl.actor-aux-zero! 1)))`);
}

test("actorhash modules fit, evaluate in order, and derive every reached R1 shape transition", async () => {
  assert.ok(sources.every((source) => new TextEncoder().encode(source).length <= LIMIT));
  const value = await session();
  assert.equal(Number(value.evaluate("(bytes.length wl.actoraux)")), 900);
  assert.deepEqual(parseLispValue(value.evaluate(`(list
    (wl.u32-decimal 0 0) (wl.u32-decimal 0 999) (wl.u32-decimal 0 1000)
    (wl.u32-decimal 15 16959) (wl.u32-decimal 65535 65535))`)).map(Number),
    [0, 999, 1000, 999999, 4294967295]);
  const shapes = parseLispValue(value.evaluate(`
    (begin (set! wl.actorcount 1) (u8! wl.actorclass 0 3)
      (list
        (begin (wl.actor-phase! 0 wl.ACTOR-STAND) (wl.actor-shapenum 0))
        (begin (wl.actor-phase! 0 0) (wl.actor-shapenum 0))
        (begin (wl.actor-phase! 0 1) (wl.actor-shapenum 0))
        (begin (wl.actor-phase! 0 2) (wl.actor-shapenum 0))
        (begin (wl.actor-phase! 0 3) (wl.actor-shapenum 0))
        (begin (wl.actor-phase! 0 4) (wl.actor-shapenum 0))
        (begin (wl.actor-phase! 0 5) (wl.actor-shapenum 0))
        (begin (wl.actor-phase! 0 100) (wl.actor-shapenum 0))
        (begin (wl.actor-phase! 0 105) (wl.actor-shapenum 0))
        (begin (wl.actor-phase! 0 110) (wl.actor-shapenum 0))
        (begin (wl.actor-phase! 0 111) (wl.actor-shapenum 0))
        (begin (wl.actor-phase! 0 112) (wl.actor-shapenum 0))
        (begin (u8! wl.actorclass 0 6) (wl.actor-phase! 0 0) (wl.actor-shapenum 0))
        (begin (wl.actor-phase! 0 2) (wl.actor-shapenum 0))
        (begin (wl.actor-phase! 0 3) (wl.actor-shapenum 0))
        (begin (wl.actor-phase! 0 5) (wl.actor-shapenum 0))
        (begin (u8! wl.actorclass 0 2) (wl.actor-shapenum 0))))`)).map(Number);
  assert.deepEqual(shapes,
    [50, 58, 58, 66, 74, 74, 82, 58, 82, 96, 97, 98, 99, 107, 115, 123, 95]);
});

test("actorhash mixes player first, preserves actor order, and uses the full high half", async () => {
  const value = await session();
  installSyntheticActors(value);
  const canonical = hashValues([...player(), ...enemy(1), ...enemy(2)]);
  assert.equal(Number(value.evaluate("(wl.actor-hash-decimal)")), canonical);
  const reverse = hashValues([...player(), ...enemy(2), ...enemy(1)]);
  assert.notEqual(reverse, canonical);
  value.evaluateQuietly("(begin (wl.actor-x! 0 2) (wl.actor-x! 1 1))");
  assert.equal(Number(value.evaluate("(wl.actor-hash-decimal)")), reverse);

  value.evaluateQuietly("(wl.actor-x! 0 65537)");
  const highHalf = hashValues([...player(), ...enemy(65537), ...enemy(1)]);
  assert.equal(Number(value.evaluate("(wl.actor-hash-decimal)")), highHalf);
  assert.notEqual(highHalf, reverse, "same low u16 with a changed high u16 must change TraceMix");
});

test("angle/temp1/temp3 are live signed i16 operands and zero on init and reuse", async () => {
  const value = await session();
  installSyntheticActors(value);
  const baseline = Number(value.evaluate("(wl.actor-hash-decimal)"));
  value.evaluateQuietly("(wl.actor-angle! 0 5)");
  const angle = Number(value.evaluate("(wl.actor-hash-decimal)"));
  value.evaluateQuietly("(wl.actor-temp1! 0 -2)");
  const temp1 = Number(value.evaluate("(wl.actor-hash-decimal)"));
  value.evaluateQuietly("(wl.actor-temp3! 0 9)");
  const temp3 = Number(value.evaluate("(wl.actor-hash-decimal)"));
  assert.equal(new Set([baseline, angle, temp1, temp3]).size, 4);
  assert.deepEqual(parseLispValue(value.evaluate("(list (wl.actor-angle@ 0) (wl.actor-temp1@ 0) (wl.actor-temp3@ 0))")).map(Number), [5, -2, 9]);

  value.evaluateQuietly("(wl.init-actors)");
  assert.deepEqual(parseLispValue(value.evaluate("(list (wl.actor-angle@ 0) (wl.actor-temp1@ 0) (wl.actor-temp3@ 0))")).map(Number), [0, 0, 0]);
  value.evaluateQuietly(`(begin (define test.walls (bytes.alloc 8192))
    (wl.actor-angle! 0 7) (wl.actor-temp1! 0 8) (wl.actor-temp3! 0 9)
    (set! wl.level-walls test.walls) (wl.spawn-actor-base 0 0 0 3 512 1 0 1))`);
  assert.deepEqual(parseLispValue(value.evaluate("(list (wl.actor-angle@ 0) (wl.actor-temp1@ 0) (wl.actor-temp3@ 0))")).map(Number), [0, 0, 0]);
});

test("actorhash refresh is heap-bounded", async () => {
  const value = await session();
  installSyntheticActors(value);
  const before = Number(value.evaluate("(heap.used)"));
  for (let index = 0; index < 250; index += 1) value.evaluateQuietly("(wl.actor-hash-refresh)");
  const bounded = Number(value.evaluate("(heap.used)"));
  assert.ok(bounded - before < 8192, `marked refreshes retained ${bounded - before} bytes`);
  value.evaluateQuietly("(wl.actor-hash-at 0 0 0 5381)");
  const unmarked = Number(value.evaluate("(heap.used)"));
  assert.ok(unmarked - bounded > 200000,
    `unmarked negative control retained only ${unmarked - bounded} bytes`);
});

test("all 401 canonical R1 actorhash records match and a changed hash fails closed", async (t) => {
  if (!(await haveWolf3dOriginals())) return t.skip(wolf3dSkipReason);
  const { value, reserve } = await application();
  assert.equal(reserve.memoryBytes, LONG_REPLAY_CAPACITY_BYTES);
  const initialUsed = observeCleanHeapUsed(value, "R1 actorhash initial heap");
  let maxTransientUsed = initialUsed;
  const actual = [];
  for (const record of route.records) {
    const exported = replayTraceRecord(value, record);
    maxTransientUsed = Math.max(maxTransientUsed, exported.peak);
    const projected = Object.fromEntries(parseLispValue(
      exported.output,
    ).map(([name, field]) => [String(name), Number(field)]));
    actual.push(projected.actorhash);
  }
  const finalUsed = observeCleanHeapUsed(value, "R1 actorhash final heap");
  assert.ok(finalUsed >= initialUsed, "persistent replay ownership is monotonic");
  const minHeadroom = LONG_REPLAY_CAPACITY_BYTES - LONG_REPLAY_HEAP_BASE_BYTES
    - Math.max(finalUsed, maxTransientUsed);
  assert.ok(minHeadroom >= MIN_HEADROOM_BYTES,
    `R1 replay retained only ${minHeadroom} bytes of minimum headroom`);
  t.diagnostic(JSON.stringify({
    workload: "wolf3d-r1-actorhash-401",
    rows: route.records.length,
    memoryBytes: value.memoryBytes,
    initialUsed,
    finalUsed,
    maxTransientUsed,
    minHeadroom,
  }));
  const expected = route.records.map((record) => record.actorhash);
  assert.deepEqual(actual, expected);
  const changed = [...expected];
  changed[99] = (changed[99] + 1) >>> 0;
  assert.equal(changed.findIndex((hash, index) => hash !== actual[index]), 99);
});
