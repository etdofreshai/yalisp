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
const STATUS_SHA = "f53ff1ff3e318af36f1b839848bb1b2c2713392a1703f0a83c813b864591129e";
const INITIAL_STATUS_SHA = "14e635066e1fe8b9fcc47b71d003a5073cb5cde4f6de1015f31747af15b7b9fd";
const PLANAR_SHA = "45e8cf189bbd973643d9902f23344d77a0090ca21ab0b49d10a18a2a7270c0f6";
const STRUCTPIC_SHA = "21176f816a55d72073ad36f860ab2dfc4ff0e0bc05ec619bcbb55e67e929bb2b";
const STATUS_START = 320 * 160;
const STATUS_BYTES = 320 * 40;

function rejectedDiagnostic(action) {
  try { action(); } catch (error) { return error.diagnostic ?? ""; }
  assert.fail("malformed graphics input was accepted");
}

async function decoderSession(overrides = {}) {
  const session = await createSeedSession();
  loadWolf3d(session);
  session.evaluate("(heap.reserve 2097152)");
  const files = graphicsNames.map((name) => overrides[name] ?? graphics[name]);
  session.evaluate(`(asset.reserve ${files.reduce((total, bytes) => total + bytes.length, 0)})`);
  for (const bytes of files) session.ingestBytes(bytes);
  return session;
}

async function originalFetcher(path) {
  const name = path.slice(path.lastIndexOf("/") + 1);
  const root = name === "GAMEPAL.OBJ" ? sourceObject : steam;
  return new Uint8Array(await readFile(new URL(name, root)));
}

test("Lisp decodes STRUCTPIC and STATUSBARPIC bytes exactly", async () => {
  const source = graphics["VGAGRAPH.WL6"].subarray(109653, 119157);
  assert.equal(source.length, 9504);
  assert.equal(sha256(source), "5ca8a9c10b58c46c15aea4235beb3e0d7fea5f778d6f16db45d8db74b2d15c8f");

  const session = await decoderSession();
  session.evaluateQuietly(`(define test.structpic
    (ca.expand-gr-chunk-exact (asset.ref 0) (asset.ref 1) (asset.ref 2)
                              vh.STRUCTPIC vh.STRUCTPIC-BYTES))`);
  assert.equal(sha256(session.evaluateBytes("test.structpic")), STRUCTPIC_SHA);
  assert.equal(session.evaluate("(list (vh.picture-width test.structpic vh.STATUSBARPIC) (vh.picture-height test.structpic vh.STATUSBARPIC))"), "(320 40)");

  session.evaluateQuietly(`(define test.planar
    (ca.expand-gr-chunk-exact (asset.ref 0) (asset.ref 1) (asset.ref 2)
                              vh.STATUSBARPIC vh.STATUSBAR-BYTES))`);
  const planar = session.evaluateBytes("test.planar");
  assert.equal(planar.length, STATUS_BYTES);
  assert.equal(sha256(planar), PLANAR_SHA);

  session.evaluateQuietly("(define test.status (bytes.alloc vh.STATUSBAR-BYTES))");
  const status = session.evaluateBytes(`(vh.deplane-into test.planar vh.STATUSBAR-WIDTH
    vh.STATUSBAR-HEIGHT test.status 0 0 vh.STATUSBAR-WIDTH)`);
  assert.equal(status.length, STATUS_BYTES);
  assert.equal(sha256(status), STATUS_SHA);

  const wrongPlaneOrder = new Uint8Array(STATUS_BYTES);
  for (let plane = 0; plane < 4; plane += 1) {
    wrongPlaneOrder.set(planar.subarray(plane * 3200, (plane + 1) * 3200), (3 - plane) * 3200);
  }
  const mutated = new Uint8Array(STATUS_BYTES);
  for (let y = 0; y < 40; y += 1) for (let x = 0; x < 320; x += 1) {
    mutated[y * 320 + x] = wrongPlaneOrder[(x & 3) * 3200 + y * 80 + (x >> 2)];
  }
  assert.notEqual(sha256(mutated), STATUS_SHA, "reversing the four source planes must fail byte parity");

  const shifted = new Uint8Array(64001);
  shifted.set(status, STATUS_START + 1);
  assert.notEqual(sha256(shifted.subarray(STATUS_START, STATUS_START + STATUS_BYTES)), STATUS_SHA,
    "a one-pixel physical placement shift must fail byte parity");
});

test("graphics chunk decoding rejects malformed source boundaries", async (t) => {
  await t.test("sparse STATUSBARPIC", async () => {
    const head = graphics["VGAHEAD.WL6"].slice();
    head.fill(255, 86 * 3, 86 * 3 + 3);
    const session = await decoderSession({ "VGAHEAD.WL6": head });
    const diagnostic = rejectedDiagnostic(() => session.evaluateBytes(`
      (ca.expand-gr-chunk-exact (asset.ref 0) (asset.ref 1) (asset.ref 2) 86 vh.STATUSBAR-BYTES)`));
    assert.match(diagnostic, /byte index out of range/);
  });

  await t.test("out-of-range chunk offset", async () => {
    const head = graphics["VGAHEAD.WL6"].slice();
    const offset = graphics["VGAGRAPH.WL6"].length + 1;
    head.set([offset & 255, (offset >> 8) & 255, (offset >> 16) & 255], 86 * 3);
    const session = await decoderSession({ "VGAHEAD.WL6": head });
    const diagnostic = rejectedDiagnostic(() => session.evaluateBytes(`
      (ca.expand-gr-chunk-exact (asset.ref 0) (asset.ref 1) (asset.ref 2) 86 vh.STATUSBAR-BYTES)`));
    assert.match(diagnostic, /byte index out of range/);
  });

  await t.test("truncated Huffman stream", async () => {
    const head = graphics["VGAHEAD.WL6"].slice();
    const end = 109653 + 100;
    head.set([end & 255, (end >> 8) & 255, (end >> 16) & 255], 87 * 3);
    const session = await decoderSession({ "VGAHEAD.WL6": head });
    const diagnostic = rejectedDiagnostic(() => session.evaluateBytes(`
      (ca.expand-gr-chunk-exact (asset.ref 0) (asset.ref 1) (asset.ref 2) 86 vh.STATUSBAR-BYTES)`));
    assert.match(diagnostic, /byte index out of range/);
  });

  await t.test("wrong expanded length", async () => {
    const graph = graphics["VGAGRAPH.WL6"].slice();
    graph.set([255, 49, 0, 0], 109653);
    const session = await decoderSession({ "VGAGRAPH.WL6": graph });
    const diagnostic = rejectedDiagnostic(() => session.evaluateBytes(`
      (ca.expand-gr-chunk-exact (asset.ref 0) (asset.ref 1) (asset.ref 2) 86 vh.STATUSBAR-BYTES)`));
    assert.match(diagnostic, /byte index out of range/);
  });

  await t.test("adjacent picture substitution", async () => {
    const session = await decoderSession();
    const diagnostic = rejectedDiagnostic(() => session.evaluateBytes(`
      (ca.expand-gr-chunk-exact (asset.ref 0) (asset.ref 1) (asset.ref 2) 85 vh.STATUSBAR-BYTES)`));
    assert.match(diagnostic, /byte index out of range/);
  });
});

test("the application requires all graphics files before mounting", async () => {
  const session = await createSeedSession();
  loadWolf3d(session);
  const { failed } = await mountDeclaredAssets(session, async (path) => {
    if (path.endsWith("/VGADICT.WL6")) throw new Error("missing VGADICT.WL6");
    return originalFetcher(path);
  });
  assert.deepEqual(failed.map((entry) => entry.name), ["vgadict"]);
  assert.equal(session.evaluate("(app.mounted?)"), "false");
});

test("initial placement and repeated ThreeDRefresh preserve the source status bytes", async () => {
  const session = await createSeedSession();
  loadWolf3d(session);
  const { failed } = await mountDeclaredAssets(session, originalFetcher);
  assert.deepEqual(failed, []);
  assert.equal(session.evaluate("(app.mounted?)"), "true");

  const initial = session.evaluateBytes("(app.frame-bytes)");
  const repeated = session.evaluateBytes("(app.frame-bytes)");
  assert.equal(sha256(initial.subarray(STATUS_START)), INITIAL_STATUS_SHA);
  assert.deepEqual(repeated.subarray(STATUS_START), initial.subarray(STATUS_START));
  assert.deepEqual(repeated.subarray(0, STATUS_START), initial.subarray(0, STATUS_START),
    "rows 0..159 remain unchanged by the statusbar slice");

  const draw = wolf3dSources[wolf3dModules.indexOf("wl-draw")];
  assert.ok(draw.indexOf("(wl.draw-r1-inert-actors frame)") < draw.indexOf("(wl.draw-r1-ready-pistol frame)"),
    "ThreeDRefresh keeps actors before the ready pistol");
});
