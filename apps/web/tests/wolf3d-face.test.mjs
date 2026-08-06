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
const FACE_PLANAR_SHA = "fae14b5f48c070fae2308c7ab812d7c455a66c6751a624baa36b1bd6a72440de";
const FACE_ROW_SHA = "6d82bbd886150478be5960d7f2f4682bf013331585da6fd7c2eb17d3fc1bcb57";
const FACE_STATUS_SHA = "18d8d180ad6c9631b4ae263ede9ba2ca5f71bdbee5b83e4195f67af35bf135ed";
const FACE_LEFT = 17 * 8;
const FACE_TOP = 160 + 4;
const FACE_WIDTH = 24;
const FACE_HEIGHT = 32;

function rejectedDiagnostic(action) {
  try { action(); } catch (error) { return error.diagnostic ?? ""; }
  assert.fail("malformed face picture input was accepted");
}

function rectangle(frame, left = FACE_LEFT, top = FACE_TOP, width = FACE_WIDTH, height = FACE_HEIGHT) {
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

function drawFaceForm(x = 17, y = 4, chunk = 109) {
  return `(vh.status-draw-picture (asset.ref 0) (asset.ref 1) (asset.ref 2)
            test.pictable test.frame ${x} ${y} ${chunk})`;
}

async function originalFetcher(path) {
  const name = path.slice(path.lastIndexOf("/") + 1);
  const root = name === "GAMEPAL.OBJ" ? sourceObject : steam;
  return new Uint8Array(await readFile(new URL(name, root)));
}

test("StatusDrawPic decodes FACE1APIC exactly at x*8 and status y", async () => {
  const session = await decoderSession();
  assert.equal(session.evaluate("(list (vh.picture-width test.pictable 109) (vh.picture-height test.pictable 109))"), "(24 32)");

  const planar = session.evaluateBytes(`
    (ca.expand-gr-chunk-exact (asset.ref 0) (asset.ref 1) (asset.ref 2) 109 768)`);
  assert.equal(planar.length, 768);
  assert.equal(sha256(planar), FACE_PLANAR_SHA);

  session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
  session.evaluateQuietly("(bytes.fill test.frame 0 64000 37)");
  const frame = session.evaluateBytes(drawFaceForm());
  assert.equal(sha256(rectangle(frame)), FACE_ROW_SHA);

  for (let y = 0; y < 200; y += 1) for (let x = 0; x < 320; x += 1) {
    if (x >= FACE_LEFT && x < FACE_LEFT + FACE_WIDTH && y >= FACE_TOP && y < FACE_TOP + FACE_HEIGHT) continue;
    assert.equal(frame[y * 320 + x], 37, `unexpected write at ${x},${y}`);
  }

  assert.notEqual(sha256(rectangle(frame, FACE_LEFT + 1, FACE_TOP)), FACE_ROW_SHA, "x without the exact x*8 origin must fail parity");
  assert.notEqual(sha256(rectangle(frame, FACE_LEFT, FACE_TOP + 1)), FACE_ROW_SHA, "y without the status +160 origin must fail parity");

  const wrongPlaneOrder = new Uint8Array(planar.length);
  for (let plane = 0; plane < 4; plane += 1) {
    wrongPlaneOrder.set(planar.subarray(plane * 192, (plane + 1) * 192), (3 - plane) * 192);
  }
  const mutated = new Uint8Array(768);
  for (let y = 0; y < 32; y += 1) for (let x = 0; x < 24; x += 1) {
    mutated[y * 24 + x] = wrongPlaneOrder[(x & 3) * 192 + y * 6 + (x >> 2)];
  }
  assert.notEqual(sha256(mutated), FACE_ROW_SHA, "reversing the four VGA planes must fail parity");
});

test("the living non-SPEAR selector follows health tiers and face frames", async () => {
  const session = await createSeedSession();
  loadWolf3d(session);
  const selected = (health, faceframe) => Number(session.evaluate(`
    (begin (set! wl.health ${health}) (set! wl.faceframe ${faceframe}) (wl.living-face-picture))`));

  assert.deepEqual([selected(100, 0), selected(100, 1), selected(100, 2)], [109, 110, 111]);
  assert.equal(selected(85, 0), 109, "health 85 remains in the first face tier");
  assert.equal(selected(84, 0), 112, "health 84 begins the second face tier");
  assert.deepEqual([selected(0, 0), selected(-1, 0), selected(101, 0), selected(100, 3)], [-1, -1, -1, -1]);
});

test("StatusDrawPic rejects malformed chunks, dimensions, and bounds", async (t) => {
  await t.test("sparse face", async () => {
    const head = graphics["VGAHEAD.WL6"].slice();
    head.fill(255, 109 * 3, 109 * 3 + 3);
    const session = await decoderSession({ "VGAHEAD.WL6": head });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    const diagnostic = rejectedDiagnostic(() => session.evaluateBytes(drawFaceForm()));
    assert.match(diagnostic, /byte index out of range/);
  });

  await t.test("out-of-range face offset", async () => {
    const head = graphics["VGAHEAD.WL6"].slice();
    const offset = graphics["VGAGRAPH.WL6"].length + 1;
    head.set([offset & 255, (offset >> 8) & 255, (offset >> 16) & 255], 109 * 3);
    const session = await decoderSession({ "VGAHEAD.WL6": head });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    const diagnostic = rejectedDiagnostic(() => session.evaluateBytes(drawFaceForm()));
    assert.match(diagnostic, /byte index out of range/);
  });

  await t.test("truncated Huffman stream", async () => {
    const head = graphics["VGAHEAD.WL6"].slice();
    const end = 208967 + 100;
    head.set([end & 255, (end >> 8) & 255, (end >> 16) & 255], 110 * 3);
    const session = await decoderSession({ "VGAHEAD.WL6": head });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    const diagnostic = rejectedDiagnostic(() => session.evaluateBytes(drawFaceForm()));
    assert.match(diagnostic, /byte index out of range/);
  });

  await t.test("wrong expanded length", async () => {
    const graph = graphics["VGAGRAPH.WL6"].slice();
    graph.set([255, 2, 0, 0], 208967);
    const session = await decoderSession({ "VGAGRAPH.WL6": graph });
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    const diagnostic = rejectedDiagnostic(() => session.evaluateBytes(drawFaceForm()));
    assert.match(diagnostic, /byte index out of range/);
  });

  await t.test("invalid STRUCTPIC width", async () => {
    const session = await decoderSession();
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    session.evaluateQuietly("(u16! test.pictable (* (- 109 vh.STARTPICS) 4) 22)");
    const diagnostic = rejectedDiagnostic(() => session.evaluateBytes(drawFaceForm()));
    assert.match(diagnostic, /byte index out of range/);
  });

  await t.test("status bounds", async () => {
    const session = await decoderSession();
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    const horizontal = rejectedDiagnostic(() => session.evaluateBytes(drawFaceForm(38, 4)));
    assert.match(horizontal, /byte index out of range/);
  });

  await t.test("vertical status-window bounds", async () => {
    const session = await decoderSession();
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    const vertical = rejectedDiagnostic(() => session.evaluateBytes(drawFaceForm(17, 9)));
    assert.match(vertical, /byte index out of range/);
  });

  await t.test("out-of-latch chunk ids", async () => {
    const session = await decoderSession();
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    for (const chunk of [90, 135]) {
      const diagnostic = rejectedDiagnostic(() => session.evaluateBytes(drawFaceForm(17, 4, chunk)));
      assert.match(diagnostic, /byte index out of range/);
    }
  });

  await t.test("adjacent face cannot replace selector output", async () => {
    const session = await decoderSession();
    session.evaluateQuietly("(define test.frame (bytes.alloc 64000))");
    const adjacent = session.evaluateBytes(drawFaceForm(17, 4, 110));
    assert.notEqual(sha256(rectangle(adjacent)), FACE_ROW_SHA);
    session.evaluateQuietly("(begin (set! wl.health 100) (set! wl.faceframe 0))");
    assert.equal(session.evaluate("(wl.living-face-picture)"), "109");
  });
});

test("initial DrawPlayScreen and selector changes preserve the face layer", async () => {
  const session = await createSeedSession();
  loadWolf3d(session);
  const { failed } = await mountDeclaredAssets(session, originalFetcher);
  assert.deepEqual(failed, []);
  assert.equal(session.evaluate("app.GRAPHICS-HEAP-RESERVE"), "2097152");
  assert.equal(session.evaluate("app.drawn-face-picture"), "109");

  const initial = session.evaluateBytes("(app.frame-bytes)");
  const repeated = session.evaluateBytes("(app.frame-bytes)");
  assert.equal(sha256(initial.subarray(320 * 160)), FACE_STATUS_SHA);
  assert.equal(sha256(rectangle(initial)), FACE_ROW_SHA);
  assert.deepEqual(repeated.subarray(320 * 160), initial.subarray(320 * 160));
  assert.deepEqual(repeated.subarray(0, 320 * 160), initial.subarray(0, 320 * 160));

  session.evaluateQuietly(`(u8! app.frame-buffer ${FACE_TOP * 320 + FACE_LEFT} 77)`);
  session.evaluateQuietly("(app.refresh-face)");
  assert.equal(session.evaluate(`(u8@ app.frame-buffer ${FACE_TOP * 320 + FACE_LEFT})`), "77",
    "an unchanged selector does not redraw");

  session.evaluateQuietly("(set! wl.faceframe 1)");
  session.evaluateQuietly("(app.refresh-face)");
  assert.equal(session.evaluate("app.drawn-face-picture"), "110");
  assert.equal(sha256(rectangle(session.evaluateBytes("app.frame-buffer"))),
    "8db0e7c5e54a4a348a96e9ad49cbf5df8d48803423e14a5bff88c847e65aa083");

  const before = Number(session.evaluate("(heap.used)"));
  for (let index = 0; index < 12; index += 1) {
    session.evaluateQuietly(`(begin (set! wl.faceframe ${index % 2}) (app.refresh-face))`);
  }
  const retained = Number(session.evaluate("(heap.used)")) - before;
  assert.ok(retained < 65536, `bounded face redraw retained ${retained} bytes`);
});
