import assert from "node:assert/strict";
import test from "node:test";
import { mountDeclaredAssets } from "../src/examples/runtime/asset-mount.ts";
import { createSeedSession } from "./seed-session.mjs";
import {
  fromPublic,
  haveWolf3dOriginals as haveOriginals,
  wolf3dSkipReason as skipReason,
  wolf3dSource as source
} from "./wolf3d-source.mjs";

const number = (session, form) => Number(session.evaluate(form));

async function application() {
  const session = await createSeedSession();
  session.evaluateQuietly(source);
  await mountDeclaredAssets(session, fromPublic);
  return session;
}

test("SpawnDoor follows the source plane scan, numbering, locks, and jamb marks", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();

  // Decode a second untouched copy: app.wall-plane has already undergone
  // SpawnDoor's source-faithful replacement of each door code by an area tile.
  session.evaluateQuietly("(define test.raw-planes (ca.cache-map app.tinf app.maps 0))");
  const raw = new Uint16Array(session.evaluateBytes("(car test.raw-planes)").buffer);
  const live = new Uint16Array(session.evaluateBytes("app.wall-plane").buffer);
  const tilemap = session.evaluateBytes("wl.tilemap");
  const doors = [];
  for (let index = 0; index < raw.length; index += 1) {
    if (raw[index] >= 90 && raw[index] <= 101) doors.push({ index, code: raw[index] });
  }

  assert.ok(doors.length > 0, "the source E1M1 plane should contain doors");
  assert.equal(number(session, "wl.doornum"), doors.length);

  for (let door = 0; door < doors.length; door += 1) {
    const { index, code } = doors[door];
    const x = index % 64;
    const y = Math.floor(index / 64);
    const vertical = code % 2 === 0;
    const lock = Math.floor((code - (vertical ? 90 : 91)) / 2);

    assert.equal(number(session, `(wl.door-x@ ${door})`), x, `door ${door} x`);
    assert.equal(number(session, `(wl.door-y@ ${door})`), y, `door ${door} y`);
    assert.equal(number(session, `(wl.door-vertical@ ${door})`), vertical ? 1 : 0, `door ${door} orientation`);
    assert.equal(number(session, `(wl.door-lock@ ${door})`), lock, `door ${door} lock`);
    assert.equal(number(session, `(wl.door-position@ ${door})`), 0, `door ${door} starts closed`);
    assert.equal(tilemap[x * 64 + y], 0x80 | door, `door ${door} center tile`);

    const copiedArea = vertical ? raw[index - 1] : raw[index - 64];
    assert.equal(live[index], copiedArea, `door ${door} plane-0 area replacement`);
    const jambs = vertical ? [[x, y - 1], [x, y + 1]] : [[x - 1, y], [x + 1, y]];
    for (const [jx, jy] of jambs) {
      assert.ok(tilemap[jx * 64 + jy] & 0x40, `door ${door} jamb ${jx},${jy}`);
    }
  }

  for (let door = doors.length; door < 64; door += 1) {
    assert.equal(number(session, `(wl.door-position@ ${door})`), 0, `unused door ${door} position`);
    assert.equal(number(session, `(wl.door-action@ ${door})`), 0, `unused door ${door} action`);
    assert.equal(number(session, `(wl.door-ticcount@ ${door})`), 0, `unused door ${door} ticcount`);
  }
});

test("closed E1M1 doors and jambs select only the original VSWAP door pages", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  session.evaluate("(app.frame-bytes)");

  const spriteStart = number(session, "pm.sprite-start");
  const doorWall = spriteStart - 8;
  assert.equal(number(session, "(wl.door-wall)"), doorWall);

  for (let door = 0; door < number(session, "wl.doornum"); door += 1) {
    const lock = number(session, `(wl.door-lock@ ${door})`);
    const base = doorWall + (lock === 0 ? 0 : lock === 5 ? 4 : 6);
    assert.equal(number(session, `(wl.door-picture ${door} 0)`), base);
    assert.equal(number(session, `(wl.door-picture ${door} 1)`), base + 1);
    assert.equal(session.evaluate(`(pm.wall-page? ${base})`), "true");
    assert.equal(session.evaluate(`(pm.wall-page? ${base + 1})`), "true");
  }

  const pictures = session.evaluateBytes("wl.wallpic");
  const visibleDoorPages = [...pictures].filter((pic) => pic >= doorWall && pic < spriteStart);
  assert.ok(visibleDoorPages.length > 0, "the initial E1M1 view should contain a door or jamb");
  assert.ok([...pictures].every((pic) => pic === 255 || pic < spriteStart), "no wall post may sample a sprite page");
});

test("use drives the source door action, tic, collision, and hold-edge semantics", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const doorCount = number(session, "wl.doornum");
  let door = -1;
  for (let candidate = 0; candidate < doorCount; candidate += 1) {
    if (number(session, `(wl.door-lock@ ${candidate})`) === 0) {
      door = candidate;
      break;
    }
  }
  assert.notEqual(door, -1, "E1M1 should contain an unlocked door");

  const x = number(session, `(wl.door-x@ ${door})`);
  const y = number(session, `(wl.door-y@ ${door})`);
  const vertical = number(session, `(wl.door-vertical@ ${door})`) === 1;
  const playerX = vertical ? x - 1 : x;
  const playerY = vertical ? y : y - 1;
  const angle = vertical ? 0 : 270;
  session.evaluateQuietly(`
    (begin
      (wl.player! wl.PLAYER-TILEX ${playerX})
      (wl.player! wl.PLAYER-TILEY ${playerY})
      (wl.player! wl.PLAYER-X ${playerX * 65536 + 32768})
      (wl.player! wl.PLAYER-Y ${playerY * 65536 + 32768})
      (wl.player! wl.PLAYER-ANGLE ${angle}))
  `);

  assert.equal(number(session, `(wl.door-action@ ${door})`), 1, "dr_closed");
  assert.equal(number(session, `(wl.door-ticcount@ ${door})`), 0);
  assert.equal(number(session, `(wl.door-position@ ${door})`), 0);
  assert.equal(session.evaluate(`(wl.solid-for-player? (wl.tilemap@ ${x} ${y}))`), "true");

  // PlayLoop moves doors before T_Player calls Cmd_Use: the use tick changes
  // action, while the following 6-tic host advance first changes position.
  session.evaluateQuietly("(app.advance '((use 1)))");
  assert.equal(number(session, `(wl.door-action@ ${door})`), 2, "dr_opening");
  assert.equal(number(session, `(wl.door-position@ ${door})`), 0);
  session.evaluateQuietly("(app.advance '((use 1)))");
  assert.equal(number(session, `(wl.door-position@ ${door})`), 6 << 10);
  assert.equal(number(session, `(wl.door-action@ ${door})`), 2, "held use must not reverse the door");

  for (let tick = 0; tick < 10; tick += 1) session.evaluateQuietly("(app.advance '((use 1)))");
  assert.equal(number(session, `(wl.door-position@ ${door})`), 0xffff, "opening saturates at a word");
  assert.equal(number(session, `(wl.door-action@ ${door})`), 0, "dr_open");
  assert.equal(number(session, `(wl.door-ticcount@ ${door})`), 0);
  assert.equal(session.evaluate(`(wl.solid-for-player? (wl.tilemap@ ${x} ${y}))`), "false");

  // OPENTICS is 300, so 50 six-tic advances begin closing without moving the
  // panel until the following advance. A continuously held key still cannot
  // toggle it manually.
  for (let tick = 0; tick < 50; tick += 1) session.evaluateQuietly("(app.advance '((use 1)))");
  assert.equal(number(session, `(wl.door-ticcount@ ${door})`), 300);
  assert.equal(number(session, `(wl.door-action@ ${door})`), 3, "dr_closing");
  assert.equal(number(session, `(wl.door-position@ ${door})`), 0xffff);
  session.evaluateQuietly("(app.advance '((use 1)))");
  assert.equal(number(session, `(wl.door-position@ ${door})`), 0xffff - (6 << 10));

  // Once the player occupies the center, DoorClosing takes OpenDoor's source
  // safety path and cannot continue through the player.
  session.evaluateQuietly(`
    (begin
      (wl.player! wl.PLAYER-TILEX ${x})
      (wl.player! wl.PLAYER-TILEY ${y})
      (wl.player! wl.PLAYER-X ${x * 65536 + 32768})
      (wl.player! wl.PLAYER-Y ${y * 65536 + 32768})
      (wl.move-doors))
  `);
  assert.equal(number(session, `(wl.door-action@ ${door})`), 2, "obstruction reopens the door");
});
