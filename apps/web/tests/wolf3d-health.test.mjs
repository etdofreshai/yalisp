import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { mountDeclaredAssets } from "../src/examples/runtime/asset-mount.ts";
import { createSeedSession } from "./seed-session.mjs";
import { loadWolf3d, wolf3dModules, wolf3dSources } from "./wolf3d-source.mjs";

const steam = new URL("../../../../wolf3d-typescript-monorepo-continuation/steam-release/base/", import.meta.url);
const sourceObject = new URL("../../../../wolf3d-typescript-monorepo-continuation/original-source/WOLFSRC/OBJ/", import.meta.url);
const graphicsNames = ["VGAHEAD.WL6", "VGAGRAPH.WL6", "VGADICT.WL6"];
const graphics = Object.fromEntries(await Promise.all(graphicsNames.map(async (name) =>
  [name, new Uint8Array(await readFile(new URL(name, steam)))])));

const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");
const NUMBER_PLANAR_SHAS = [
  "ab72bbe2a4e948f7e4dc7c224595fe1f6508da36749abde1dbec159567d2f792",
  "9db16e87cbecbd1c23da89efb53b9cf0146e8568646476c3e8c00e5f4e101e85",
  "9e6a57574e53a882efd6de28df3c5328747d4bd816b6f7a9608ebac6467db868",
  "81b6e04194a15e8eff908ffe8967b814e5b21c5adcc4da75935fcd82d6bcde7f",
  "aedc55804a9b57a722162d0b57efb3d68d848af15297dd80d1c89b36e42a6ad5",
  "6bb6215a3e673a5c0194f89acf1712d056974dceae106584d6a632cd10649468",
  "e8636956a30690f902e232368d4aceade54b7a2be833e98b66b9cf73b9a86ea9",
  "733024d865dd0d3f9268bd62f817f88f98c1e8c54a126bbb4691c7649d24a6d2",
  "4d6513f6d7e06415bdc1d2c99905d1e640b651dcd7a91869db060241a9fcd76a",
  "b87e8a2ab40afe16f7c7031f6d4ecb0b5280f0c9dbc3e61d590585306dcba906",
  "9776c0cf2e5c845c2ca5fbcdae90e62e21a79116f3bb896217f0e53f5d784986"
];
const HEALTH_RECT_SHA = "63fc8b795e664bc13ce7074c5d026cc9ec3637ec74a09621677d0f6cf3446c66";
const INITIAL_STATUS_SHA = "a087739f8046a23c852315d2f671defd3c7929e013e1b53f1280f166b96d5c06";
const FACE_ROW_SHA = "6d82bbd886150478be5960d7f2f4682bf013331585da6fd7c2eb17d3fc1bcb57";
const WEAPON_ROW_SHA = "f4c288d41497cc63e170901e3f1246c4cdb9bb5943da2a9d814c50a0fd741d06";
const HEALTH_LEFT = 21 * 8;
const HEALTH_TOP = 160 + 16;
const HEALTH_WIDTH = 24;
const HEALTH_HEIGHT = 16;

function rejectedDiagnostic(action) {
  try { action(); } catch (error) { return error.diagnostic ?? ""; }
  assert.fail("malformed health picture input was accepted");
}

function rectangle(frame, left = HEALTH_LEFT, top = HEALTH_TOP,
  width = HEALTH_WIDTH, height = HEALTH_HEIGHT) {
  const output = new Uint8Array(width * height);
  for (let y = 0; y < height; y += 1) {
    output.set(frame.subarray((top + y) * 320 + left, (top + y) * 320 + left + width), y * width);
  }
  return output;
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

function drawPictureForm(x = 21, y = 16, chunk = 100) {
  return `(vh.status-draw-picture (asset.ref 0) (asset.ref 1) (asset.ref 2)
            test.pictable test.frame ${x} ${y} ${chunk})`;
}

async function originalFetcher(path) {
  const name = path.slice(path.lastIndexOf("/") + 1);
  const root = name === "GAMEPAL.OBJ" ? sourceObject : steam;
  return new Uint8Array(await readFile(new URL(name, root)));
}

test("number latch chunks 98 through 108 have exact dimensions and planar bytes", async () => {
  const session = await decoderSession();
  for (let chunk = 98; chunk <= 108; chunk += 1) {
    assert.equal(session.evaluate(`(list (vh.picture-width test.pictable ${chunk})
      (vh.picture-height test.pictable ${chunk}))`), "(8 16)");
    const planar = session.evaluateBytes(`
      (ca.expand-gr-chunk-exact (asset.ref 0) (asset.ref 1) (asset.ref 2) ${chunk} 128)`);
    assert.equal(sha256(planar), NUMBER_PLANAR_SHAS[chunk - 98], `chunk ${chunk}`);
  }
});

test("LatchNumber numeric helpers preserve padding, truncation, and raw minus arithmetic", async () => {
  const session = await createSeedSession();
  loadWolf3d(session);
  const chunks = (number, width = 3) =>
    session.evaluate(`(wl.latch-number-chunks ${width} ${number})`);

  assert.deepEqual([chunks(0), chunks(7), chunks(12), chunks(100)],
    ["(98 98 99)", "(98 98 106)", "(98 100 101)", "(100 99 99)"]);
  assert.deepEqual([chunks(123), chunks(1234), chunks(98765)],
    ["(100 101 102)", "(101 102 103)", "(106 105 104)"]);
  assert.deepEqual([chunks(-1), chunks(-12), chunks(-123), chunks(-1234)],
    ["(98 96 100)", "(96 100 101)", "(100 101 102)", "(101 102 103)"]);
  assert.equal(chunks(42, 5), "(98 98 98 103 101)");
});

test("DrawHealth places 100 at physical 168,176 and rejects shifted or substituted output", async () => {
  const session = await decoderSession();
  session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
  session.evaluateQuietly("(bytes.fill test.frame 0 64000 37)");
  for (const [cell, chunk] of [100, 99, 99].entries()) {
    session.evaluateQuietly(drawPictureForm(21 + cell, 16, chunk));
  }
  const frame = session.evaluateBytes("test.frame");
  assert.equal(sha256(rectangle(frame)), HEALTH_RECT_SHA);

  for (let y = 0; y < 200; y += 1) for (let x = 0; x < 320; x += 1) {
    if (x >= HEALTH_LEFT && x < HEALTH_LEFT + HEALTH_WIDTH &&
        y >= HEALTH_TOP && y < HEALTH_TOP + HEALTH_HEIGHT) continue;
    assert.equal(frame[y * 320 + x], 37, `unexpected write at ${x},${y}`);
  }

  session.evaluateQuietly("(bytes.fill test.frame 0 64000 37)");
  for (const [cell, chunk] of [100, 99, 99].entries()) {
    session.evaluateQuietly(drawPictureForm(22 + cell, 16, chunk));
  }
  assert.notEqual(sha256(rectangle(session.evaluateBytes("test.frame"))), HEALTH_RECT_SHA,
    "a one-cell horizontal shift must fail parity");

  session.evaluateQuietly("(bytes.fill test.frame 0 64000 37)");
  session.evaluateQuietly(drawPictureForm(21, 16, 99));
  session.evaluateQuietly(drawPictureForm(22, 16, 99));
  session.evaluateQuietly(drawPictureForm(23, 16, 99));
  assert.notEqual(sha256(rectangle(session.evaluateBytes("test.frame"))), HEALTH_RECT_SHA,
    "the adjacent zero picture cannot replace the selected one picture");

  const planar = session.evaluateBytes(`
    (ca.expand-gr-chunk-exact (asset.ref 0) (asset.ref 1) (asset.ref 2) 100 128)`);
  const reversed = new Uint8Array(128);
  for (let plane = 0; plane < 4; plane += 1) {
    reversed.set(planar.subarray(plane * 32, (plane + 1) * 32), (3 - plane) * 32);
  }
  const row = new Uint8Array(128);
  for (let y = 0; y < 16; y += 1) for (let x = 0; x < 8; x += 1) {
    row[y * 8 + x] = reversed[(x & 3) * 32 + y * 2 + (x >> 2)];
  }
  assert.notEqual(sha256(row), sha256(rectangle(frame, HEALTH_LEFT, HEALTH_TOP, 8, 16)),
    "reversing the four VGA planes must fail parity");
});

test("number StatusDrawPic rejects sparse, truncated, wrong-length, dimension, and bounds inputs", async (t) => {
  await t.test("sparse number chunk", async () => {
    const head = graphics["VGAHEAD.WL6"].slice();
    head.fill(255, 100 * 3, 100 * 3 + 3);
    const session = await decoderSession({ "VGAHEAD.WL6": head });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm())), /byte index out of range/);
  });

  await t.test("truncated number chunk", async () => {
    const head = graphics["VGAHEAD.WL6"].slice();
    const end = graphicsOffset(100) + 4;
    head.set([end & 255, (end >> 8) & 255, (end >> 16) & 255], 101 * 3);
    const session = await decoderSession({ "VGAHEAD.WL6": head });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm())), /byte index out of range/);
  });

  await t.test("wrong expanded length", async () => {
    const graph = graphics["VGAGRAPH.WL6"].slice();
    graph.set([127, 0, 0, 0], graphicsOffset(100));
    const session = await decoderSession({ "VGAGRAPH.WL6": graph });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm())), /byte index out of range/);
  });

  await t.test("wrong STRUCTPIC dimensions", async () => {
    const session = await decoderSession();
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    session.evaluateQuietly("(u16! test.pictable (* (- 100 vh.STARTPICS) 4) 12)");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm())), /byte index out of range/);
  });

  await t.test("status-window bounds", async () => {
    const session = await decoderSession();
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm(40, 16))), /byte index out of range/);
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm(21, 25))), /byte index out of range/);
  });
});

test("DrawPlayScreen and tick refresh preserve face-health-weapon order and cache semantics", async () => {
  const session = await createSeedSession();
  loadWolf3d(session);
  const { failed } = await mountDeclaredAssets(session, originalFetcher);
  assert.deepEqual(failed, []);
  assert.equal(session.evaluate("app.drawn-face-picture"), "109");
  assert.equal(session.evaluate("app.drawn-health"), "100");
  assert.equal(session.evaluate("app.drawn-weapon-picture"), "92");
  assert.equal(session.evaluate("(wl.health-latch-chunks)"), "(100 99 99)");

  const appSource = wolf3dSources[wolf3dModules.indexOf("app")];
  const setup = appSource.slice(appSource.indexOf("(defn app.setup-tables"), appSource.indexOf("(defn app.cache-plane-hashes"));
  const refresh = appSource.slice(appSource.indexOf("(defn app.refresh-renderer-state"), appSource.indexOf("(defn app.refresh-face"));
  for (const source of [setup, refresh]) {
    assert.ok(source.indexOf("(app.refresh-face)") < source.indexOf("(app.refresh-health)"));
    assert.ok(source.indexOf("(app.refresh-health)") < source.indexOf("(app.refresh-weapon)"));
  }

  const initial = session.evaluateBytes("(app.frame-bytes)");
  assert.equal(sha256(initial.subarray(320 * 160)), INITIAL_STATUS_SHA);
  assert.equal(sha256(rectangle(initial)), HEALTH_RECT_SHA);
  assert.equal(sha256(rectangle(initial, 17 * 8, 164, 24, 32)), FACE_ROW_SHA);
  assert.equal(sha256(rectangle(initial, 32 * 8, 168, 48, 24)), WEAPON_ROW_SHA);

  session.evaluateQuietly(`(u8! app.frame-buffer ${HEALTH_TOP * 320 + HEALTH_LEFT} 77)`);
  session.evaluateQuietly("(app.refresh-health)");
  assert.equal(session.evaluate(`(u8@ app.frame-buffer ${HEALTH_TOP * 320 + HEALTH_LEFT})`), "77",
    "unchanged health skips redraw");

  session.evaluateQuietly("(set! wl.health 99)");
  session.evaluateQuietly("(app.refresh-health)");
  assert.equal(session.evaluate("app.drawn-health"), "99");
  const changed = session.evaluateBytes("app.frame-buffer");
  assert.notEqual(sha256(rectangle(changed)), HEALTH_RECT_SHA);
  assert.equal(sha256(rectangle(changed, 17 * 8, 164, 24, 32)), FACE_ROW_SHA);
  assert.equal(sha256(rectangle(changed, 32 * 8, 168, 48, 24)), WEAPON_ROW_SHA);

  const beforeFailure = changed.slice();
  session.evaluateQuietly("(u16! app.pictable (* (- 101 vh.STARTPICS) 4) 12)");
  session.evaluateQuietly("(set! wl.health 12)");
  assert.match(rejectedDiagnostic(() => session.evaluate("(app.refresh-health)")), /byte index out of range/);
  assert.equal(session.evaluate("app.drawn-health"), "99", "failed suffix preserves the prior cache");
  const afterFailure = session.evaluateBytes("app.frame-buffer");
  assert.notDeepEqual(rectangle(afterFailure, HEALTH_LEFT, HEALTH_TOP, 16, 16),
    rectangle(beforeFailure, HEALTH_LEFT, HEALTH_TOP, 16, 16), "the source-shaped prefix was drawn");
  assert.deepEqual(rectangle(afterFailure, HEALTH_LEFT + 16, HEALTH_TOP, 8, 16),
    rectangle(beforeFailure, HEALTH_LEFT + 16, HEALTH_TOP, 8, 16), "the rejected suffix was untouched");

  session.evaluateQuietly("(u16! app.pictable (* (- 101 vh.STARTPICS) 4) 8)");
  session.evaluateQuietly("(app.refresh-health)");
  assert.equal(session.evaluate("app.drawn-health"), "12");

  const before = Number(session.evaluate("(heap.used)"));
  for (let index = 0; index < 12; index += 1) {
    session.evaluateQuietly(`(begin (set! wl.health ${index % 2 ? 99 : 100}) (app.refresh-health))`);
  }
  const retained = Number(session.evaluate("(heap.used)")) - before;
  assert.ok(retained < 65536, `bounded health redraw retained ${retained} bytes`);
});

test("every ordered Wolf3D module remains below the unchanged evaluator input capacity", () => {
  const LIMIT = 130048;
  for (const [index, source] of wolf3dSources.entries()) {
    assert.ok(Buffer.byteLength(source, "utf8") <= LIMIT,
      `${wolf3dModules[index]} exceeds ${LIMIT} UTF-8 bytes`);
  }
});
