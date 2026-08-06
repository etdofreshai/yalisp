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
const SCORE_RECT_SHA = "e808bf7db3924b1688a0896521a101411d07dee72d0661863825d269bf4175cf";
const INITIAL_STATUS_SHA = "fca493ed539487f2b9bf0dd8f0c1110f46b915cc167d10de03690d79b62fef63";
const FACE_ROW_SHA = "6d82bbd886150478be5960d7f2f4682bf013331585da6fd7c2eb17d3fc1bcb57";
const HEALTH_ROW_SHA = "63fc8b795e664bc13ce7074c5d026cc9ec3637ec74a09621677d0f6cf3446c66";
const WEAPON_ROW_SHA = "f4c288d41497cc63e170901e3f1246c4cdb9bb5943da2a9d814c50a0fd741d06";
const SCORE_LEFT = 6 * 8;
const SCORE_TOP = 160 + 16;
const SCORE_WIDTH = 48;
const SCORE_HEIGHT = 16;

function rejectedDiagnostic(action) {
  try { action(); } catch (error) { return error.diagnostic ?? ""; }
  assert.fail("malformed score picture input was accepted");
}

function rectangle(frame, left = SCORE_LEFT, top = SCORE_TOP,
  width = SCORE_WIDTH, height = SCORE_HEIGHT) {
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

function drawPictureForm(x = 6, y = 16, chunk = 99) {
  return `(vh.status-draw-picture (asset.ref 0) (asset.ref 1) (asset.ref 2)
            test.pictable test.frame ${x} ${y} ${chunk})`;
}

async function originalFetcher(path) {
  const name = path.slice(path.lastIndexOf("/") + 1);
  const root = name === "GAMEPAL.OBJ" ? sourceObject : steam;
  return new Uint8Array(await readFile(new URL(name, root)));
}

test("score latch chunks 98 through 108 have exact dimensions and planar bytes", async () => {
  const session = await decoderSession();
  for (let chunk = 98; chunk <= 108; chunk += 1) {
    assert.equal(session.evaluate(`(list (vh.picture-width test.pictable ${chunk})
      (vh.picture-height test.pictable ${chunk}))`), "(8 16)");
    const planar = session.evaluateBytes(`
      (ca.expand-gr-chunk-exact (asset.ref 0) (asset.ref 1) (asset.ref 2) ${chunk} 128)`);
    assert.equal(sha256(planar), NUMBER_PLANAR_SHAS[chunk - 98], `chunk ${chunk}`);
  }
});

test("six-cell LatchNumber preserves zero, padding, truncation, and raw minus arithmetic", async () => {
  const session = await createSeedSession();
  loadWolf3d(session);
  const chunks = (number) => session.evaluate(`(wl.latch-number-chunks 6 ${number})`);

  assert.deepEqual([chunks(0), chunks(7), chunks(12), chunks(123456)], [
    "(98 98 98 98 98 99)", "(98 98 98 98 98 106)",
    "(98 98 98 98 100 101)", "(100 101 102 103 104 105)"
  ]);
  assert.deepEqual([chunks(1234567), chunks(-1), chunks(-12), chunks(-12345), chunks(-123456)], [
    "(101 102 103 104 105 106)", "(98 98 98 98 96 100)",
    "(98 98 98 96 100 101)", "(96 100 101 102 103 104)",
    "(100 101 102 103 104 105)"
  ]);

  session.evaluateQuietly("(set! wl.score 0)");
  assert.equal(session.evaluate("(wl.score-latch-chunks)"), "(98 98 98 98 98 99)");
});

test("DrawScore places score 0 at physical 48,176 with exact source bytes", async () => {
  const session = await decoderSession();
  session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
  session.evaluateQuietly("(bytes.fill test.frame 0 64000 37)");
  for (let x = 6; x < 11; x += 1) session.evaluateQuietly(drawPictureForm(x, 16, 98));
  session.evaluateQuietly(drawPictureForm(11, 16, 99));
  const frame = session.evaluateBytes("test.frame");
  assert.equal(sha256(rectangle(frame)), SCORE_RECT_SHA);
  assert.equal(frame[SCORE_TOP * 320 + SCORE_LEFT - 1], 37);
  assert.equal(frame[SCORE_TOP * 320 + SCORE_LEFT + SCORE_WIDTH], 37);
  assert.equal(frame[(SCORE_TOP - 1) * 320 + SCORE_LEFT], 37);
  assert.equal(frame[(SCORE_TOP + SCORE_HEIGHT) * 320 + SCORE_LEFT], 37);
});

test("shifted, substituted, and reversed-plane score controls fail parity", async () => {
  const session = await decoderSession();
  session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
  session.evaluateQuietly("(bytes.fill test.frame 0 64000 37)");
  for (let x = 6; x < 11; x += 1) session.evaluateQuietly(drawPictureForm(x, 16, 98));
  session.evaluateQuietly(drawPictureForm(11, 16, 99));
  const frame = session.evaluateBytes("test.frame");
  assert.notEqual(sha256(rectangle(frame, SCORE_LEFT + 1, SCORE_TOP, SCORE_WIDTH, SCORE_HEIGHT)), SCORE_RECT_SHA);

  session.evaluateQuietly("(bytes.fill test.frame 0 64000 37)");
  for (let x = 6; x < 12; x += 1) session.evaluateQuietly(drawPictureForm(x, 16, 99));
  assert.notEqual(sha256(rectangle(session.evaluateBytes("test.frame"))), SCORE_RECT_SHA,
    "zero pictures cannot replace blank padding");

  const planar = session.evaluateBytes(`
    (ca.expand-gr-chunk-exact (asset.ref 0) (asset.ref 1) (asset.ref 2) 99 128)`);
  const reversed = new Uint8Array(128);
  for (let plane = 0; plane < 4; plane += 1) {
    reversed.set(planar.subarray(plane * 32, (plane + 1) * 32), (3 - plane) * 32);
  }
  const row = new Uint8Array(128);
  for (let y = 0; y < 16; y += 1) for (let x = 0; x < 8; x += 1) {
    row[y * 8 + x] = reversed[(x & 3) * 32 + y * 2 + (x >> 2)];
  }
  assert.notEqual(sha256(row), sha256(rectangle(frame, SCORE_LEFT + 40, SCORE_TOP, 8, 16)),
    "reversing the four VGA planes must fail parity");
});

test("score StatusDrawPic rejects sparse, truncated, wrong-length, dimension, and bounds inputs", async (t) => {
  await t.test("sparse score chunk", async () => {
    const head = graphics["VGAHEAD.WL6"].slice();
    head.fill(255, 99 * 3, 99 * 3 + 3);
    const session = await decoderSession({ "VGAHEAD.WL6": head });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm())), /byte index out of range/);
  });

  await t.test("truncated score chunk", async () => {
    const head = graphics["VGAHEAD.WL6"].slice();
    const end = graphicsOffset(99) + 4;
    head.set([end & 255, (end >> 8) & 255, (end >> 16) & 255], 100 * 3);
    const session = await decoderSession({ "VGAHEAD.WL6": head });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm())), /byte index out of range/);
  });

  await t.test("wrong expanded length", async () => {
    const graph = graphics["VGAGRAPH.WL6"].slice();
    graph.set([127, 0, 0, 0], graphicsOffset(99));
    const session = await decoderSession({ "VGAGRAPH.WL6": graph });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm())), /byte index out of range/);
  });

  await t.test("wrong STRUCTPIC dimensions", async () => {
    const session = await decoderSession();
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    session.evaluateQuietly("(u16! test.pictable (* (- 99 vh.STARTPICS) 4) 12)");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm())), /byte index out of range/);
  });

  await t.test("status-window bounds", async () => {
    const session = await decoderSession();
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm(40, 16))), /byte index out of range/);
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawPictureForm(6, 25))), /byte index out of range/);
  });
});

test("DrawPlayScreen and tick refresh preserve the complete source status order and score cache", async () => {
  const session = await createSeedSession();
  loadWolf3d(session);
  assert.equal(session.evaluate("app.drawn-score"), "nil", "numeric cache starts empty");
  const { failed } = await mountDeclaredAssets(session, originalFetcher);
  assert.deepEqual(failed, []);
  assert.equal(session.evaluate("app.drawn-face-picture"), "109");
  assert.equal(session.evaluate("app.drawn-health"), "100");
  assert.equal(session.evaluate("app.drawn-lives"), "3");
  assert.equal(session.evaluate("app.drawn-level"), "1");
  assert.equal(session.evaluate("app.drawn-ammo"), "8");
  assert.equal(session.evaluate("app.drawn-keys"), "0");
  assert.equal(session.evaluate("app.drawn-weapon-picture"), "92");
  assert.equal(session.evaluate("app.drawn-score"), "0");
  assert.equal(session.evaluate("(wl.score-latch-chunks)"), "(98 98 98 98 98 99)");

  const appSource = wolf3dSources[wolf3dModules.indexOf("app")];
  const setup = appSource.slice(appSource.indexOf("(defn app.setup-tables"), appSource.indexOf("(defn app.cache-plane-hashes"));
  const refresh = appSource.slice(appSource.indexOf("(defn app.refresh-renderer-state"), appSource.indexOf("(defn app.refresh-face"));
  const ordered = ["face", "health", "lives", "level", "ammo", "keys", "weapon", "score"];
  for (const source of [setup, refresh]) for (let index = 1; index < ordered.length; index += 1) {
    assert.ok(source.indexOf(`(app.refresh-${ordered[index - 1]})`) <
      source.indexOf(`(app.refresh-${ordered[index]})`));
  }

  const initial = session.evaluateBytes("(app.frame-bytes)");
  assert.equal(sha256(initial.subarray(320 * 160)), INITIAL_STATUS_SHA);
  assert.equal(sha256(rectangle(initial)), SCORE_RECT_SHA);
  assert.equal(sha256(rectangle(initial, 17 * 8, 164, 24, 32)), FACE_ROW_SHA);
  assert.equal(sha256(rectangle(initial, 21 * 8, 176, 24, 16)), HEALTH_ROW_SHA);
  assert.equal(sha256(rectangle(initial, 32 * 8, 168, 48, 24)), WEAPON_ROW_SHA);

  session.evaluateQuietly(`(u8! app.frame-buffer ${SCORE_TOP * 320 + SCORE_LEFT} 77)`);
  session.evaluateQuietly("(app.refresh-score)");
  assert.equal(session.evaluate(`(u8@ app.frame-buffer ${SCORE_TOP * 320 + SCORE_LEFT})`), "77",
    "unchanged score skips redraw");

  session.evaluateQuietly("(set! wl.score 1)");
  session.evaluateQuietly("(app.refresh-score)");
  assert.equal(session.evaluate("app.drawn-score"), "1");
  const changed = session.evaluateBytes("app.frame-buffer");
  assert.notEqual(sha256(rectangle(changed)), SCORE_RECT_SHA);
  assert.equal(sha256(rectangle(changed, 17 * 8, 164, 24, 32)), FACE_ROW_SHA);
  assert.equal(sha256(rectangle(changed, 21 * 8, 176, 24, 16)), HEALTH_ROW_SHA);
  assert.equal(sha256(rectangle(changed, 32 * 8, 168, 48, 24)), WEAPON_ROW_SHA);

  const beforeFailure = changed.slice();
  session.evaluateQuietly("(u16! app.pictable (* (- 101 vh.STARTPICS) 4) 12)");
  session.evaluateQuietly("(set! wl.score 12)");
  assert.match(rejectedDiagnostic(() => session.evaluate("(app.refresh-score)")), /byte index out of range/);
  assert.equal(session.evaluate("app.drawn-score"), "1", "failed suffix preserves the prior cache");
  const afterFailure = session.evaluateBytes("app.frame-buffer");
  assert.notDeepEqual(rectangle(afterFailure, SCORE_LEFT, SCORE_TOP, 40, 16),
    rectangle(beforeFailure, SCORE_LEFT, SCORE_TOP, 40, 16), "the source-shaped prefix was drawn");
  assert.deepEqual(rectangle(afterFailure, SCORE_LEFT + 40, SCORE_TOP, 8, 16),
    rectangle(beforeFailure, SCORE_LEFT + 40, SCORE_TOP, 8, 16), "the rejected suffix was untouched");

  session.evaluateQuietly("(u16! app.pictable (* (- 101 vh.STARTPICS) 4) 8)");
  session.evaluateQuietly("(app.refresh-score)");
  assert.equal(session.evaluate("app.drawn-score"), "12");

  const before = Number(session.evaluate("(heap.used)"));
  for (let index = 0; index < 12; index += 1) {
    session.evaluateQuietly(`(begin (set! wl.score ${index % 2}) (app.refresh-score))`);
  }
  const retained = Number(session.evaluate("(heap.used)")) - before;
  assert.ok(retained < 65536, `bounded score redraw retained ${retained} bytes`);
});

test("every ordered Wolf3D module remains below the unchanged evaluator input capacity", () => {
  const LIMIT = 130048;
  for (const [index, source] of wolf3dSources.entries()) {
    assert.ok(Buffer.byteLength(source, "utf8") <= LIMIT,
      `${wolf3dModules[index]} exceeds ${LIMIT} UTF-8 bytes`);
  }
});
