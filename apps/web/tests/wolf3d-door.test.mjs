import assert from "node:assert/strict";
import test from "node:test";
import { mountDeclaredAssets } from "../src/examples/runtime/asset-mount.ts";
import { parseLispValue } from "../src/examples/runtime/lisp-value.ts";
import { createSeedSession } from "./seed-session.mjs";
import {
  fromPublic,
  haveWolf3dOriginals as haveOriginals,
  loadWolf3d,
  wolf3dSkipReason as skipReason,
} from "./wolf3d-source.mjs";

const number = (session, form) => Number(session.evaluate(form));

async function application() {
  const session = await createSeedSession();
  loadWolf3d(session);
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

  let advances = 0;
  let lastOwnership = {
    released: number(session, "app.advance-release-count"),
    retained: number(session, "app.advance-retain-count"),
    mask: number(session, "app.advance-last-retain-mask"),
    sdEvents: number(session, "sd.audio-event-count"),
    wlEvents: number(session, "wl.audio-event-count"),
  };
  const advance = () => {
    try {
      session.evaluateQuietly("(app.advance '((use 1)))");
    } catch (error) {
      throw new Error(
        `door live advance ${advances + 1} failed after ownership ${JSON.stringify(lastOwnership)}`,
        { cause: error },
      );
    }
    advances += 1;
    lastOwnership = {
      released: number(session, "app.advance-release-count"),
      retained: number(session, "app.advance-retain-count"),
      mask: number(session, "app.advance-last-retain-mask"),
      sdEvents: number(session, "sd.audio-event-count"),
      wlEvents: number(session, "wl.audio-event-count"),
    };
  };

  assert.equal(number(session, `(wl.door-action@ ${door})`), 1, "dr_closed");
  assert.equal(number(session, `(wl.door-ticcount@ ${door})`), 0);
  assert.equal(number(session, `(wl.door-position@ ${door})`), 0);
  assert.equal(session.evaluate(`(wl.solid-for-player? (wl.tilemap@ ${x} ${y}))`), "true");

  // PlayLoop moves doors before T_Player calls Cmd_Use: the use tick changes
  // action, while the following 6-tic host advance first changes position.
  advance();
  assert.equal(number(session, `(wl.door-action@ ${door})`), 2, "dr_opening");
  assert.equal(number(session, `(wl.door-position@ ${door})`), 0);
  advance();
  assert.equal(number(session, `(wl.door-position@ ${door})`), 6 << 10);
  assert.equal(number(session, `(wl.door-action@ ${door})`), 2, "held use must not reverse the door");

  for (let tick = 0; tick < 10; tick += 1) advance();
  assert.equal(number(session, `(wl.door-position@ ${door})`), 0xffff, "opening saturates at a word");
  assert.equal(number(session, `(wl.door-action@ ${door})`), 0, "dr_open");
  assert.equal(number(session, `(wl.door-ticcount@ ${door})`), 0);
  assert.equal(session.evaluate(`(wl.solid-for-player? (wl.tilemap@ ${x} ${y}))`), "false");

  // OPENTICS is 300, so 50 six-tic advances begin closing without moving the
  // panel until the following advance. A continuously held key still cannot
  // toggle it manually.
  for (let tick = 0; tick < 50; tick += 1) advance();
  assert.equal(number(session, `(wl.door-ticcount@ ${door})`), 300);
  assert.equal(number(session, `(wl.door-action@ ${door})`), 3, "dr_closing");
  assert.equal(number(session, `(wl.door-position@ ${door})`), 0xffff);
  advance();
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
  assert.equal(lastOwnership.released, advances, "every scalar/packed live advance releases its call frames");
  assert.equal(lastOwnership.retained, 0, "no heap-owned aggregate escapes this door lifecycle");
  assert.equal(lastOwnership.mask, 0);
  assert.equal(lastOwnership.sdEvents, lastOwnership.wlEvents,
    "manager and game decision logs retain the same accepted calls");
  assert.ok(lastOwnership.wlEvents >= advances,
    "held-use fallbacks plus door movement should retain at least one source decision per advance");

  const gameEvents = parseLispValue(session.evaluate("(wl.audio-event-log)"));
  const hostEvents = parseLispValue(session.evaluate("(sd.audio-host-event-log)"));
  const legacyEvents = parseLispValue(session.evaluate("(sd.audio-event-log)"));
  assert.equal(gameEvents.length, lastOwnership.wlEvents);
  assert.equal(hostEvents.length, lastOwnership.sdEvents);
  assert.equal(legacyEvents.length, lastOwnership.sdEvents);
  assert.deepEqual(hostEvents.map((row) => [row[0], row[1], row[9]]), gameEvents,
    "packed SD and game rows preserve tick, sound, callsite, and order");
  assert.deepEqual(legacyEvents, hostEvents.map((row) =>
    [row[0], row[1], row[2], row[4], row[5], row[6], row[7], row[9]]),
  "the established eight-field export remains an exact packed-row projection");
  assert.ok(gameEvents.some((row) => row[2] === "Cmd_Use"));
  assert.ok(gameEvents.some((row) => row[2] === "PlaySoundLocGlobal"));
  t.diagnostic(JSON.stringify({ workload: "wolf3d-live-door-use", advances, ...lastOwnership }));
});
