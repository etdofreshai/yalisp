import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { mountDeclaredAssets } from "../src/examples/runtime/asset-mount.ts";
import { createSeedSession } from "./seed-session.mjs";
import { loadWolf3d } from "./wolf3d-source.mjs";

const steam = new URL("../../../../wolf3d-typescript-monorepo-continuation/steam-release/base/", import.meta.url);
const sourceObject = new URL("../../../../wolf3d-typescript-monorepo-continuation/original-source/WOLFSRC/OBJ/", import.meta.url);
const graphicsNames = ["VGAHEAD.WL6", "VGAGRAPH.WL6", "VGADICT.WL6"];
const graphics = Object.fromEntries(await Promise.all(graphicsNames.map(async (name) =>
  [name, new Uint8Array(await readFile(new URL(name, steam)))])));

const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");
const WEAPON_PLANAR_SHA = "3d2a9dc2a8f74ea4cacd1ed763ab636f3a15481757d5680ae67e1bb0e4bb1482";
const WEAPON_ROW_SHA = "f4c288d41497cc63e170901e3f1246c4cdb9bb5943da2a9d814c50a0fd741d06";
const CHAINGUN_ROW_SHA = "0a0abf52d4f62452e6536170024a20e7d2fae210eb26cc72e3598089165bd11e";
const FACE_ROW_SHA = "6d82bbd886150478be5960d7f2f4682bf013331585da6fd7c2eb17d3fc1bcb57";
const INITIAL_STATUS_SHA = "95cfa2986609a97df4556441bff224ad48def406199448f5c3ff130218ee4290";
const WEAPON_LEFT = 32 * 8;
const WEAPON_TOP = 160 + 8;
const WEAPON_WIDTH = 48;
const WEAPON_HEIGHT = 24;

function rejectedDiagnostic(action) {
  try { action(); } catch (error) { return error.diagnostic ?? ""; }
  assert.fail("malformed weapon picture input was accepted");
}

function rectangle(frame, left = WEAPON_LEFT, top = WEAPON_TOP,
  width = WEAPON_WIDTH, height = WEAPON_HEIGHT) {
  const output = new Uint8Array(width * height);
  for (let y = 0; y < height; y += 1) {
    output.set(frame.subarray((top + y) * 320 + left, (top + y) * 320 + left + width), y * width);
  }
  return output;
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

function drawWeaponForm(x = 32, y = 8, chunk = 92) {
  return `(vh.status-draw-picture (asset.ref 0) (asset.ref 1) (asset.ref 2)
            test.pictable test.frame ${x} ${y} ${chunk})`;
}

async function originalFetcher(path) {
  const name = path.slice(path.lastIndexOf("/") + 1);
  const root = name === "GAMEPAL.OBJ" ? sourceObject : steam;
  return new Uint8Array(await readFile(new URL(name, root)));
}

test("StatusDrawPic decodes GUNPIC exactly at x*8 and status y", async () => {
  const session = await decoderSession();
  assert.equal(session.evaluate("(list (vh.picture-width test.pictable 92) (vh.picture-height test.pictable 92))"), "(48 24)");

  const planar = session.evaluateBytes(`
    (ca.expand-gr-chunk-exact (asset.ref 0) (asset.ref 1) (asset.ref 2) 92 1152)`);
  assert.equal(planar.length, 1152);
  assert.equal(sha256(planar), WEAPON_PLANAR_SHA);

  session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
  session.evaluateQuietly("(bytes.fill test.frame 0 64000 37)");
  const frame = session.evaluateBytes(drawWeaponForm());
  assert.equal(sha256(rectangle(frame)), WEAPON_ROW_SHA);

  for (let y = 0; y < 200; y += 1) for (let x = 0; x < 320; x += 1) {
    if (x >= WEAPON_LEFT && x < WEAPON_LEFT + WEAPON_WIDTH &&
        y >= WEAPON_TOP && y < WEAPON_TOP + WEAPON_HEIGHT) continue;
    assert.equal(frame[y * 320 + x], 37, `unexpected write at ${x},${y}`);
  }

  assert.notEqual(sha256(rectangle(frame, WEAPON_LEFT + 1, WEAPON_TOP)), WEAPON_ROW_SHA,
    "x without the exact x*8 origin must fail parity");
  assert.notEqual(sha256(rectangle(frame, WEAPON_LEFT, WEAPON_TOP + 1)), WEAPON_ROW_SHA,
    "y without the exact status +160 origin must fail parity");

  const wrongPlaneOrder = new Uint8Array(planar.length);
  for (let plane = 0; plane < 4; plane += 1) {
    wrongPlaneOrder.set(planar.subarray(plane * 288, (plane + 1) * 288), (3 - plane) * 288);
  }
  const mutated = new Uint8Array(1152);
  for (let y = 0; y < 24; y += 1) for (let x = 0; x < 48; x += 1) {
    mutated[y * 48 + x] = wrongPlaneOrder[(x & 3) * 288 + y * 12 + (x >> 2)];
  }
  assert.notEqual(sha256(mutated), WEAPON_ROW_SHA, "reversing the four VGA planes must fail parity");
});

test("DrawWeapon preserves the original unguarded KNIFEPIC arithmetic", async () => {
  const session = await createSeedSession();
  loadWolf3d(session);
  const selected = (weapon) => Number(session.evaluate(`
    (begin (set! wl.weapon ${weapon}) (wl.status-weapon-picture))`));

  assert.deepEqual([selected(0), selected(1), selected(2), selected(3)], [91, 92, 93, 94]);
  assert.deepEqual([selected(-1), selected(4), selected(100)], [90, 95, 191]);
});

test("weapon StatusDrawPic rejects malformed chunks, dimensions, and bounds", async (t) => {
  await t.test("sparse GUNPIC", async () => {
    const head = graphics["VGAHEAD.WL6"].slice();
    head.fill(255, 92 * 3, 92 * 3 + 3);
    const session = await decoderSession({ "VGAHEAD.WL6": head });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawWeaponForm())), /byte index out of range/);
  });

  await t.test("out-of-range GUNPIC offset", async () => {
    const head = graphics["VGAHEAD.WL6"].slice();
    const offset = graphics["VGAGRAPH.WL6"].length + 1;
    head.set([offset & 255, (offset >> 8) & 255, (offset >> 16) & 255], 92 * 3);
    const session = await decoderSession({ "VGAHEAD.WL6": head });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawWeaponForm())), /byte index out of range/);
  });

  await t.test("truncated GUNPIC stream", async () => {
    const head = graphics["VGAHEAD.WL6"].slice();
    const end = 205510 + 100;
    head.set([end & 255, (end >> 8) & 255, (end >> 16) & 255], 93 * 3);
    const session = await decoderSession({ "VGAHEAD.WL6": head });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawWeaponForm())), /byte index out of range/);
  });

  await t.test("wrong GUNPIC expanded length", async () => {
    const graph = graphics["VGAGRAPH.WL6"].slice();
    graph.set([127, 4, 0, 0], 205510);
    const session = await decoderSession({ "VGAGRAPH.WL6": graph });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawWeaponForm())), /byte index out of range/);
  });

  await t.test("invalid GUNPIC STRUCTPIC width", async () => {
    const session = await decoderSession();
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    session.evaluateQuietly("(u16! test.pictable (* (- 92 vh.STARTPICS) 4) 46)");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawWeaponForm())), /byte index out of range/);
  });

  await t.test("weapon status-window bounds", async () => {
    const session = await decoderSession();
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawWeaponForm(35, 8))), /byte index out of range/);
    assert.match(rejectedDiagnostic(() => session.evaluateBytes(drawWeaponForm(32, 17))), /byte index out of range/);
  });

  await t.test("adjacent picture cannot replace GUNPIC selector output", async () => {
    const session = await decoderSession();
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    const adjacent = session.evaluateBytes(drawWeaponForm(32, 8, 93));
    assert.notEqual(sha256(rectangle(adjacent)), WEAPON_ROW_SHA);
    session.evaluateQuietly("(set! wl.weapon 1)");
    assert.equal(session.evaluate("(wl.status-weapon-picture)"), "92");
  });
});

test("initial DrawPlayScreen and weapon selector changes preserve status layers", async () => {
  const session = await createSeedSession();
  loadWolf3d(session);
  const { failed } = await mountDeclaredAssets(session, originalFetcher);
  assert.deepEqual(failed, []);
  assert.equal(session.evaluate("app.GRAPHICS-HEAP-RESERVE"), "2097152");
  assert.equal(session.evaluate("app.drawn-face-picture"), "109");
  assert.equal(session.evaluate("app.drawn-health"), "100");
  assert.equal(session.evaluate("app.drawn-weapon-picture"), "92");
  assert.equal(session.evaluate("app.drawn-score"), "0");

  const initial = session.evaluateBytes("(app.frame-bytes)");
  const repeated = session.evaluateBytes("(app.frame-bytes)");
  assert.equal(sha256(initial.subarray(320 * 160)), INITIAL_STATUS_SHA);
  assert.equal(sha256(rectangle(initial)), WEAPON_ROW_SHA);
  assert.equal(sha256(rectangle(initial, 17 * 8, 164, 24, 32)), FACE_ROW_SHA);
  assert.deepEqual(repeated.subarray(320 * 160), initial.subarray(320 * 160));
  assert.deepEqual(repeated.subarray(0, 320 * 160), initial.subarray(0, 320 * 160));

  session.evaluateQuietly(`(u8! app.frame-buffer ${WEAPON_TOP * 320 + WEAPON_LEFT} 77)`);
  session.evaluateQuietly("(app.refresh-weapon)");
  assert.equal(session.evaluate(`(u8@ app.frame-buffer ${WEAPON_TOP * 320 + WEAPON_LEFT})`), "77",
    "an unchanged selector does not redraw");

  session.evaluateQuietly("(set! wl.weapon 2)");
  session.evaluateQuietly("(app.refresh-weapon)");
  assert.equal(session.evaluate("app.drawn-weapon-picture"), "93");
  assert.equal(sha256(rectangle(session.evaluateBytes("app.frame-buffer"))), CHAINGUN_ROW_SHA);
  assert.equal(sha256(rectangle(session.evaluateBytes("app.frame-buffer"), 17 * 8, 164, 24, 32)), FACE_ROW_SHA);

  session.evaluateQuietly(`(u8! app.frame-buffer ${WEAPON_TOP * 320 + WEAPON_LEFT} 88)`);
  session.evaluateQuietly("(set! wl.weapon -1)");
  assert.match(rejectedDiagnostic(() => session.evaluate("(app.refresh-weapon)")), /byte index out of range/);
  assert.equal(session.evaluate("app.drawn-weapon-picture"), "93",
    "a rejected arithmetic-selected draw preserves the last successful cache entry");
  assert.equal(session.evaluate(`(u8@ app.frame-buffer ${WEAPON_TOP * 320 + WEAPON_LEFT})`), "88",
    "a rejected out-of-latch draw leaves the frame unchanged");

  const before = Number(session.evaluate("(heap.used)"));
  for (let index = 0; index < 12; index += 1) {
    session.evaluateQuietly(`(begin (set! wl.weapon ${index % 2}) (app.refresh-weapon))`);
  }
  const retained = Number(session.evaluate("(heap.used)")) - before;
  assert.ok(retained < 65536, `bounded weapon redraw retained ${retained} bytes`);
});
