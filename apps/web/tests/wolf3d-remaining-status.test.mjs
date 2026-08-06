import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { mountDeclaredAssets } from "../src/examples/runtime/asset-mount.ts";
import { createSeedSession } from "./seed-session.mjs";
import { loadWolf3d, wolf3dModules, wolf3dSources } from "./wolf3d-source.mjs";

const steam = new URL("../../../../wolf3d-typescript-monorepo-continuation/steam-release/base/", import.meta.url);
const sourceObject = new URL("../../../../wolf3d-typescript-monorepo-continuation/original-source/WOLFSRC/OBJ/", import.meta.url);
const mirror = new URL("../../../../wolf3d-typescript-monorepo-continuation/apps/wolf3d-yalisp/", import.meta.url);
const graphicsNames = ["VGAHEAD.WL6", "VGAGRAPH.WL6", "VGADICT.WL6"];
const graphics = Object.fromEntries(await Promise.all(graphicsNames.map(async (name) =>
  [name, new Uint8Array(await readFile(new URL(name, steam)))])));

const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");
const PICTURE_PLANAR_SHAS = new Map([
  [95, "e6ec164681b08cdadef15159ffee981b8787d36b9fa11106e474707236cfd1a1"],
  [96, "330bc5c0d7179130e94d9c5645a9f4e2a3e75291029e33c2d1c254c46ac0684b"],
  [97, "e1e00922e64ca9ea225700d543172e6533638fae80b06ed4aca1bb8526eb5fd1"],
  [98, "ab72bbe2a4e948f7e4dc7c224595fe1f6508da36749abde1dbec159567d2f792"],
  [99, "9db16e87cbecbd1c23da89efb53b9cf0146e8568646476c3e8c00e5f4e101e85"],
  [100, "9e6a57574e53a882efd6de28df3c5328747d4bd816b6f7a9608ebac6467db868"],
  [101, "81b6e04194a15e8eff908ffe8967b814e5b21c5adcc4da75935fcd82d6bcde7f"],
  [102, "aedc55804a9b57a722162d0b57efb3d68d848af15297dd80d1c89b36e42a6ad5"]
]);
const INITIAL_FRAME_SHA = "23856ce2b09cff2a863f91bd0df4883046efdb9cb004159681cd1a4e668004ee";
const INITIAL_STATUS_SHA = "fca493ed539487f2b9bf0dd8f0c1110f46b915cc167d10de03690d79b62fef63";
const LIVES_RECT_SHA = "16a45599818667808e17e861d185fa66fc1972bf5c619a42e9f8fbb867aa9c68";
const LEVEL_RECT_SHA = "791b99b19974b97e05e2789b708cb9baa005b92d1747855f7bce7d42bcd99dca";
const NO_KEY_RECT_SHA = "8a3030f2a12193f8cec659d09ecf5e10e364ea3c7641b60069f98581968fac3f";
const LIVES = { left: 14 * 8, top: 160 + 16, width: 8, height: 16 };
const LEVEL = { left: 2 * 8, top: 160 + 16, width: 16, height: 16 };
const GOLD_KEY = { left: 30 * 8, top: 160 + 4, width: 8, height: 16 };
const SILVER_KEY = { left: 30 * 8, top: 160 + 20, width: 8, height: 16 };

function rejectedDiagnostic(action) {
  try { action(); } catch (error) { return error.diagnostic ?? ""; }
  assert.fail("malformed remaining-status picture input was accepted");
}

function rectangle(frame, { left, top, width, height }) {
  const output = new Uint8Array(width * height);
  for (let y = 0; y < height; y += 1) {
    output.set(frame.subarray((top + y) * 320 + left, (top + y) * 320 + left + width), y * width);
  }
  return output;
}

function inside(rect, x, y) {
  return x >= rect.left && x < rect.left + rect.width &&
    y >= rect.top && y < rect.top + rect.height;
}

function assertOnlyRegionsChanged(before, after, regions, message) {
  let changed = 0;
  for (let index = 0; index < before.length; index += 1) {
    if (before[index] === after[index]) continue;
    const x = index % 320;
    const y = Math.floor(index / 320);
    assert.ok(regions.some((region) => inside(region, x, y)), `${message}: unexpected change at ${x},${y}`);
    changed += 1;
  }
  assert.ok(changed > 0, `${message}: expected at least one changed pixel`);
}

function graphicsOffset(chunk, head = graphics["VGAHEAD.WL6"]) {
  return head[chunk * 3] | (head[chunk * 3 + 1] << 8) | (head[chunk * 3 + 2] << 16);
}

async function decoderSession(overrides = {}) {
  const session = await createSeedSession();
  loadWolf3d(session);
  session.evaluate("(heap.reserve 2097152)");
  const files = graphicsNames.map((name) => overrides[name] ?? graphics[name]);
  session.evaluate(`(asset.reserve ${files.reduce((total, bytes) => total + bytes.length, 0)})`);
  for (const bytes of files) session.ingestBytes(bytes);
  session.evaluateQuietly(`(define test.pictable
    (vh.load-pictable (asset.ref 0) (asset.ref 1) (asset.ref 2)))`);
  return session;
}

function drawPictureForm(x, y, chunk) {
  return `(vh.status-draw-picture (asset.ref 0) (asset.ref 1) (asset.ref 2)
            test.pictable test.frame ${x} ${y} ${chunk})`;
}

async function originalFetcher(path) {
  const name = path.slice(path.lastIndexOf("/") + 1);
  const root = name === "GAMEPAL.OBJ" ? sourceObject : steam;
  return new Uint8Array(await readFile(new URL(name, root)));
}

async function mountedSession() {
  const session = await createSeedSession();
  loadWolf3d(session);
  const { failed } = await mountDeclaredAssets(session, originalFetcher);
  assert.deepEqual(failed, []);
  return session;
}

test("remaining status source chunks have exact dimensions and planar bytes", async () => {
  const session = await decoderSession();
  for (const [chunk, expected] of PICTURE_PLANAR_SHAS) {
    assert.equal(session.evaluate(`(list (vh.picture-width test.pictable ${chunk})
      (vh.picture-height test.pictable ${chunk}))`), "(8 16)", `chunk ${chunk} dimensions`);
    const planar = session.evaluateBytes(`
      (ca.expand-gr-chunk-exact (asset.ref 0) (asset.ref 1) (asset.ref 2) ${chunk} 128)`);
    assert.equal(sha256(planar), expected, `chunk ${chunk} planar bytes`);
  }
});

test("lives, level, and key selectors preserve source numeric and signed-bit behavior", async () => {
  const session = await createSeedSession();
  loadWolf3d(session);
  const chunks = (width, number) => session.evaluate(`(wl.latch-number-chunks ${width} ${number})`);

  assert.deepEqual([0, 3, 9, 10, 123, -1, -10, -123].map((number) => chunks(1, number)),
    ["(99)", "(102)", "(108)", "(99)", "(102)", "(100)", "(99)", "(102)"],
    "one-cell lives retain rightmost-character truncation, including dropped minus signs");

  const levels = [];
  for (const map of [0, 8, 9, 99, 123, -2, -11, -124]) {
    session.evaluateQuietly(`(set! wl.map ${map})`);
    levels.push(session.evaluate("(wl.level-latch-chunks)"));
  }
  assert.deepEqual(levels,
    ["(98 100)", "(98 108)", "(100 99)", "(99 99)", "(101 103)",
      "(96 100)", "(100 99)", "(101 102)"],
    "level uses the raw map+1 value and the original LatchNumber bugs");

  const pictures = (keys) => session.evaluate(`
    (list (wl.gold-key-picture ${keys}) (wl.silver-key-picture ${keys}))`);
  assert.deepEqual([0, 1, 2, 3, 4, 5, -1, -2, -3].map(pictures),
    ["(95 95)", "(96 95)", "(95 97)", "(96 97)", "(95 95)",
      "(96 95)", "(96 97)", "(95 97)", "(96 95)"],
    "only signed source bits zero and one select key pictures; higher bits are ignored");
});

test("remaining status pictures occupy exact source rectangles and reject visual substitutions", async () => {
  const session = await decoderSession();
  session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
  session.evaluateQuietly("(bytes.fill test.frame 0 64000 37)");
  for (const [x, y, chunk] of [[14, 16, 102], [2, 16, 98], [3, 16, 100], [30, 4, 95], [30, 20, 95]]) {
    session.evaluateQuietly(drawPictureForm(x, y, chunk));
  }
  const frame = session.evaluateBytes("test.frame");
  assert.equal(sha256(rectangle(frame, LIVES)), LIVES_RECT_SHA);
  assert.equal(sha256(rectangle(frame, LEVEL)), LEVEL_RECT_SHA);
  assert.equal(sha256(rectangle(frame, GOLD_KEY)), NO_KEY_RECT_SHA);
  assert.equal(sha256(rectangle(frame, SILVER_KEY)), NO_KEY_RECT_SHA);
  for (let y = 0; y < 200; y += 1) for (let x = 0; x < 320; x += 1) {
    if ([LIVES, LEVEL, GOLD_KEY, SILVER_KEY].some((region) => inside(region, x, y))) continue;
    assert.equal(frame[y * 320 + x], 37, `unexpected write at ${x},${y}`);
  }

  assert.notEqual(sha256(rectangle(frame, { ...LEVEL, left: LEVEL.left + 1 })), LEVEL_RECT_SHA,
    "a one-pixel level shift must fail parity");
  session.evaluateQuietly("(bytes.fill test.frame 0 64000 37)");
  session.evaluateQuietly(drawPictureForm(2, 16, 99));
  session.evaluateQuietly(drawPictureForm(3, 16, 99));
  assert.notEqual(sha256(rectangle(session.evaluateBytes("test.frame"), LEVEL)), LEVEL_RECT_SHA,
    "two zero pictures cannot replace blank-plus-one");

  const planar = session.evaluateBytes(`
    (ca.expand-gr-chunk-exact (asset.ref 0) (asset.ref 1) (asset.ref 2) 95 128)`);
  const reversed = new Uint8Array(128);
  for (let plane = 0; plane < 4; plane += 1) {
    reversed.set(planar.subarray(plane * 32, (plane + 1) * 32), (3 - plane) * 32);
  }
  const row = new Uint8Array(128);
  for (let y = 0; y < 16; y += 1) for (let x = 0; x < 8; x += 1) {
    row[y * 8 + x] = reversed[(x & 3) * 32 + y * 2 + (x >> 2)];
  }
  assert.notEqual(sha256(row), NO_KEY_RECT_SHA, "reversing the four VGA planes must fail key parity");
});

test("remaining status decoding rejects sparse, truncated, wrong-length, dimension, and bounds inputs", async (t) => {
  await t.test("sparse key chunk", async () => {
    const head = graphics["VGAHEAD.WL6"].slice();
    head.fill(255, 95 * 3, 95 * 3 + 3);
    const session = await decoderSession({ "VGAHEAD.WL6": head });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm(30, 4, 95))),
      /byte index out of range/);
  });

  await t.test("truncated level suffix", async () => {
    const head = graphics["VGAHEAD.WL6"].slice();
    const end = graphicsOffset(100) + 4;
    head.set([end & 255, (end >> 8) & 255, (end >> 16) & 255], 101 * 3);
    const session = await decoderSession({ "VGAHEAD.WL6": head });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm(3, 16, 100))),
      /byte index out of range/);
  });

  await t.test("wrong lives expanded length", async () => {
    const graph = graphics["VGAGRAPH.WL6"].slice();
    graph.set([127, 0, 0, 0], graphicsOffset(102));
    const session = await decoderSession({ "VGAGRAPH.WL6": graph });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm(14, 16, 102))),
      /byte index out of range/);
  });

  await t.test("wrong key STRUCTPIC dimensions", async () => {
    const session = await decoderSession();
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    session.evaluateQuietly("(u16! test.pictable (* (- 97 vh.STARTPICS) 4) 12)");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm(30, 20, 97))),
      /byte index out of range/);
  });

  await t.test("status-window bounds", async () => {
    const session = await decoderSession();
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm(40, 16, 102))),
      /byte index out of range/);
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm(30, 25, 95))),
      /byte index out of range/);
  });
});

test("DrawPlayScreen and tick refresh use exact remaining-status order, hashes, and caches", async () => {
  const unloaded = await createSeedSession();
  loadWolf3d(unloaded);
  assert.equal(unloaded.evaluate("(list app.drawn-lives app.drawn-level app.drawn-keys)"), "(nil nil nil)",
    "remaining caches start empty");

  const session = await mountedSession();
  assert.equal(session.evaluate(`(list app.drawn-face-picture app.drawn-health app.drawn-lives
    app.drawn-level app.drawn-ammo app.drawn-keys app.drawn-weapon-picture app.drawn-score)`),
    "(109 100 3 1 8 0 92 0)");
  assert.equal(session.evaluate("(wl.lives-latch-chunks)"), "(102)");
  assert.equal(session.evaluate("(wl.level-latch-chunks)"), "(98 100)");

  const appSource = wolf3dSources[wolf3dModules.indexOf("app")];
  const setup = appSource.slice(appSource.indexOf("(defn app.setup-tables"),
    appSource.indexOf("(defn app.cache-plane-hashes"));
  const refresh = appSource.slice(appSource.indexOf("(defn app.refresh-renderer-state"),
    appSource.indexOf("(defn app.refresh-face"));
  const ordered = ["face", "health", "lives", "level", "ammo", "keys", "weapon", "score"];
  for (const source of [setup, refresh]) {
    for (let index = 1; index < ordered.length; index += 1) {
      assert.ok(source.indexOf(`(app.refresh-${ordered[index - 1]})`) <
        source.indexOf(`(app.refresh-${ordered[index]})`),
      `${ordered[index - 1]} must precede ${ordered[index]}`);
    }
  }
  for (const cache of ["drawn-lives", "drawn-level", "drawn-keys"]) {
    assert.ok(setup.indexOf(`(set! app.${cache} nil)`) < setup.indexOf(`(app.refresh-${cache.slice(6)})`),
      `static statusbar resets ${cache} before drawing`);
  }

  const frame = session.evaluateBytes("(app.frame-bytes)");
  assert.equal(sha256(frame), INITIAL_FRAME_SHA);
  assert.equal(sha256(frame.subarray(320 * 160)), INITIAL_STATUS_SHA);
  assert.equal(sha256(rectangle(frame, LIVES)), LIVES_RECT_SHA);
  assert.equal(sha256(rectangle(frame, LEVEL)), LEVEL_RECT_SHA);
  assert.equal(sha256(rectangle(frame, GOLD_KEY)), NO_KEY_RECT_SHA);
  assert.equal(sha256(rectangle(frame, SILVER_KEY)), NO_KEY_RECT_SHA);

  for (const [region, refreshName] of [[LIVES, "lives"], [LEVEL, "level"], [GOLD_KEY, "keys"]]) {
    const index = region.top * 320 + region.left;
    const original = frame[index];
    session.evaluateQuietly(`(u8! app.frame-buffer ${index} 77)`);
    session.evaluateQuietly(`(app.refresh-${refreshName})`);
    assert.equal(session.evaluate(`(u8@ app.frame-buffer ${index})`), "77",
      `unchanged ${refreshName} skips redraw`);
    session.evaluateQuietly(`(u8! app.frame-buffer ${index} ${original})`);
  }

  let before = session.evaluateBytes("app.frame-buffer");
  session.evaluateQuietly("(begin (set! wl.lives 4) (app.refresh-lives))");
  let after = session.evaluateBytes("app.frame-buffer");
  assertOnlyRegionsChanged(before, after, [LIVES], "lives isolation");
  before = after;
  session.evaluateQuietly("(begin (set! wl.map 1) (app.refresh-level))");
  after = session.evaluateBytes("app.frame-buffer");
  assertOnlyRegionsChanged(before, after, [LEVEL], "level isolation");
  before = after;
  session.evaluateQuietly("(begin (set! wl.keys 1) (app.refresh-keys))");
  after = session.evaluateBytes("app.frame-buffer");
  assertOnlyRegionsChanged(before, after, [GOLD_KEY, SILVER_KEY], "keys isolation");
});

test("remaining-status failures preserve drawn prefixes and advance caches only after full success", async () => {
  const session = await mountedSession();

  let before = session.evaluateBytes("app.frame-buffer");
  let failureMark = Number(session.evaluate("(heap.used)"));
  session.evaluateQuietly("(u16! app.pictable (* (- 101 vh.STARTPICS) 4) 12)");
  session.evaluateQuietly("(set! wl.map 11)");
  assert.match(rejectedDiagnostic(() => session.evaluate("(app.refresh-level)")), /byte index out of range/);
  assert.equal(session.evaluate("app.drawn-level"), "1", "failed level suffix preserves its prior cache");
  let after = session.evaluateBytes("app.frame-buffer");
  assert.notDeepEqual(rectangle(after, { ...LEVEL, width: 8 }), rectangle(before, { ...LEVEL, width: 8 }),
    "the valid level prefix is drawn directly");
  assert.deepEqual(rectangle(after, { ...LEVEL, left: LEVEL.left + 8, width: 8 }),
    rectangle(before, { ...LEVEL, left: LEVEL.left + 8, width: 8 }), "the rejected level suffix is untouched");
  // YALisp deliberately has no recoverable errors or unwind protection. The
  // host catches this trap only so the test can inspect persistent prefix/cache
  // state; explicitly rewind its temporary allocations before reusing the raw
  // evaluator. This is test-harness recovery, not application behavior.
  session.evaluateQuietly(`(heap.release ${failureMark})`);
  session.evaluateQuietly("(u16! app.pictable (* (- 101 vh.STARTPICS) 4) 8)");
  session.evaluateQuietly("(app.refresh-level)");
  assert.equal(session.evaluate("app.drawn-level"), "12");

  before = session.evaluateBytes("app.frame-buffer");
  failureMark = Number(session.evaluate("(heap.used)"));
  session.evaluateQuietly("(u16! app.pictable (* (- 103 vh.STARTPICS) 4) 12)");
  session.evaluateQuietly("(set! wl.lives 4)");
  assert.match(rejectedDiagnostic(() => session.evaluate("(app.refresh-lives)")), /byte index out of range/);
  assert.equal(session.evaluate("app.drawn-lives"), "3", "failed lives picture preserves its prior cache");
  after = session.evaluateBytes("app.frame-buffer");
  assert.deepEqual(rectangle(after, LIVES), rectangle(before, LIVES), "rejected lives picture is untouched");
  session.evaluateQuietly(`(heap.release ${failureMark})`);
  session.evaluateQuietly("(u16! app.pictable (* (- 103 vh.STARTPICS) 4) 8)");
  session.evaluateQuietly("(app.refresh-lives)");
  assert.equal(session.evaluate("app.drawn-lives"), "4");

  before = session.evaluateBytes("app.frame-buffer");
  failureMark = Number(session.evaluate("(heap.used)"));
  session.evaluateQuietly("(u16! app.pictable (* (- 95 vh.STARTPICS) 4) 12)");
  session.evaluateQuietly("(set! wl.keys 1)");
  assert.match(rejectedDiagnostic(() => session.evaluate("(app.refresh-keys)")), /byte index out of range/);
  assert.equal(session.evaluate("app.drawn-keys"), "0", "failed lower key preserves the prior raw-bit cache");
  after = session.evaluateBytes("app.frame-buffer");
  assert.notDeepEqual(rectangle(after, GOLD_KEY), rectangle(before, GOLD_KEY),
    "the gold-key prefix is drawn before the lower key rejects");
  assert.deepEqual(rectangle(after, SILVER_KEY), rectangle(before, SILVER_KEY),
    "the rejected lower key is untouched");
  session.evaluateQuietly(`(heap.release ${failureMark})`);
  session.evaluateQuietly("(u16! app.pictable (* (- 95 vh.STARTPICS) 4) 8)");
  session.evaluateQuietly("(app.refresh-keys)");
  assert.equal(session.evaluate("app.drawn-keys"), "1");
});

test("ignored key-bit changes redraw both slots and repeated remaining-status refresh stays bounded", async () => {
  const session = await mountedSession();
  const initial = session.evaluateBytes("app.frame-buffer");
  session.evaluateQuietly("(begin (set! wl.keys 4) (app.refresh-keys))");
  assert.equal(session.evaluate("app.drawn-keys"), "4");
  assert.equal(sha256(rectangle(session.evaluateBytes("app.frame-buffer"), GOLD_KEY)), NO_KEY_RECT_SHA);
  assert.equal(sha256(rectangle(session.evaluateBytes("app.frame-buffer"), SILVER_KEY)), NO_KEY_RECT_SHA);

  const index = GOLD_KEY.top * 320 + GOLD_KEY.left;
  session.evaluateQuietly(`(u8! app.frame-buffer ${index} 77)`);
  session.evaluateQuietly("(app.refresh-keys)");
  assert.equal(session.evaluate(`(u8@ app.frame-buffer ${index})`), "77", "unchanged raw key bits skip redraw");
  session.evaluateQuietly("(begin (set! wl.keys 8) (app.refresh-keys))");
  assert.equal(session.evaluate("app.drawn-keys"), "8");
  assert.equal(session.evaluate(`(u8@ app.frame-buffer ${index})`), String(initial[index]),
    "a changed ignored bit still triggers both unconditional source selections");

  const before = Number(session.evaluate("(heap.used)"));
  for (let index = 0; index < 12; index += 1) {
    session.evaluateQuietly(`(begin
      (set! wl.lives ${index % 2 ? 3 : 4})
      (set! wl.map ${index % 2})
      (set! wl.keys ${index % 2 ? 0 : 3})
      (app.refresh-lives)
      (app.refresh-level)
      (app.refresh-keys))`);
  }
  const retained = Number(session.evaluate("(heap.used)")) - before;
  assert.ok(retained < 65536, `bounded remaining-status redraw retained ${retained} bytes`);
});

test("assigned mirrors, graphics reserve, and evaluator input capacity remain exact", async () => {
  for (const name of ["wl-agent.lisp", "app.lisp", "README.md"]) {
    const [expected, actual] = await Promise.all([
      readFile(new URL(`../src/examples/wolf3d/${name}`, import.meta.url)),
      readFile(new URL(name, mirror))
    ]);
    assert.deepEqual(actual, expected, `${name} differs between assigned mirrors`);
  }
  const LIMIT = 130048;
  for (const [index, source] of wolf3dSources.entries()) {
    assert.ok(Buffer.byteLength(source, "utf8") <= LIMIT,
      `${wolf3dModules[index]} exceeds ${LIMIT} UTF-8 bytes`);
  }
  assert.match(wolf3dSources[wolf3dModules.indexOf("app")],
    /\(define app\.GRAPHICS-HEAP-RESERVE 2097152\)/,
    "the graphics reserve must remain exactly 2 MiB");
});
