import assert from "node:assert/strict";
import test from "node:test";
import { mountDeclaredAssets } from "../src/examples/runtime/asset-mount.ts";
import { createSeedSession } from "./seed-session.mjs";
import {
  fromPublic,
  haveWolf3dOriginals as haveOriginals,
  wolf3dSkipReason as skipReason,
  wolf3dSource as source,
} from "./wolf3d-source.mjs";

const STAT_TYPES = Object.freeze([
  0, 1, 1, 1, 0, 1, 3, 1, 1, 0, 1, 1, 1, 1, 0, 0,
  1, 1, 1, 0, 5, 6, 1, 0, 17, 4, 13, 15, 16, 9, 10, 11,
  12, 18, 2, 1, 1, 1, 2, 1, 1, 0, 0, 0, 0, 1, 1, 0, 14,
]);
const DRESSING = 0;
const BLOCK = 1;
const BONUS = 2;

async function application() {
  const session = await createSeedSession();
  session.evaluateQuietly(source);
  await mountDeclaredAssets(session, fromPublic);
  return session;
}

const number = (session, form) => Number(session.evaluate(form));
const staticRow = (session, index) => ({
  tilex: number(session, `(u8@ wl.staticx ${index})`),
  tiley: number(session, `(u8@ wl.staticy ${index})`),
  shapenum: number(session, `(wl.static-shapenum@ ${index})`),
  flags: number(session, `(wl.static-flags@ ${index})`),
  itemnumber: number(session, `(u8@ wl.staticitem ${index})`),
});

test("the non-SPEAR statinfo table is exact and rejects non-WL6 slots", async () => {
  const session = await createSeedSession();
  session.evaluateQuietly(source);
  assert.deepEqual(
    STAT_TYPES.map((unused, type) => number(session, `(wl.static-info-type ${type})`)),
    STAT_TYPES,
  );
  assert.equal(number(session, "(wl.static-info-type 49)"), -1);
  assert.equal(session.evaluate("(wl.static-tile? 71)"), "true");
  assert.equal(session.evaluate("(wl.static-tile? 72)"), "false");
  assert.equal(number(session, "(wl.static-shape-for-type 47)"), 49);
  assert.equal(number(session, "(wl.static-shape-for-type 48)"), 28,
    "the final clip2 entry aliases SPR_STAT_26");
});

test("SetupGameLevel scans every E1M1 static in plane order with source fields", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const planeBytes = session.evaluateBytes("app.object-plane");
  const plane = new Uint16Array(planeBytes.buffer, planeBytes.byteOffset, 4096);
  const expected = [];
  for (let index = 0; index < plane.length; index += 1) {
    const tile = plane[index];
    if (tile < 23 || tile > 71) continue;
    const type = tile - 23;
    const itemnumber = STAT_TYPES[type];
    expected.push({
      tilex: index & 63,
      tiley: index >> 6,
      shapenum: type === 48 ? 28 : type + 2,
      flags: itemnumber > BLOCK ? BONUS : 0,
      itemnumber: itemnumber > BLOCK ? itemnumber : 0,
    });
  }
  assert.equal(expected.length, 121);
  assert.equal(number(session, "wl.staticcount"), expected.length);
  assert.deepEqual(expected.map((unused, index) => staticRow(session, index)), expected);

  for (let ordinal = 0; ordinal < expected.length; ordinal += 1) {
    const type = plane[expected[ordinal].tiley * 64 + expected[ordinal].tilex] - 23;
    if (STAT_TYPES[type] !== BLOCK) continue;
    assert.equal(number(session,
      `(wl.actorat-wall@ ${expected[ordinal].tilex} ${expected[ordinal].tiley})`), 1,
    `blocking static ${ordinal}`);
  }
});

test("pickup removal retains source metadata and PlaceItemType reuses the slot", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const clip = number(session, "(wl.static-at 40 61 0)");
  const before = staticRow(session, clip);
  session.evaluateQuietly("(set! wl.ammo 0)");
  assert.equal(session.evaluate(`(wl.get-static ${clip})`), "true");
  assert.deepEqual(staticRow(session, clip), { ...before, shapenum: -1 });
  const count = number(session, "wl.staticcount");
  assert.equal(number(session, "(wl.spawn-static-item 3 4 wl.BO-CLIP2)"), clip,
    "PlaceItemType scans from slot zero for the first free shape");
  assert.equal(number(session, "wl.staticcount"), count);
  assert.deepEqual(staticRow(session, clip), {
    tilex: 3, tiley: 4, shapenum: 28, flags: BONUS, itemnumber: 14,
  });
});

test("InitStaticList preserves the original reused-slot itemnumber quirk", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  assert.equal(STAT_TYPES[12], BLOCK);
  session.evaluateQuietly("(u8! wl.staticitem 0 wl.BO-CROWN)");
  session.evaluateQuietly("(wl.setup-game-level app.wall-plane app.object-plane)");
  assert.equal(staticRow(session, 0).flags, DRESSING);
  assert.equal(staticRow(session, 0).itemnumber, number(session, "wl.BO-CROWN"),
    "SpawnStatic does not overwrite itemnumber for dressing/block entries");
});
