import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { mountDeclaredAssets } from "../src/examples/runtime/asset-mount.ts";
import { createSeedSession } from "./seed-session.mjs";
import {
  fromPublic,
  haveWolf3dOriginals as haveOriginals,
  wolf3dSkipReason as skipReason,
  wolf3dSource as source
} from "./wolf3d-source.mjs";

const route = JSON.parse(await readFile(new URL("./fixtures/wolf3d-r1-route-v3.json", import.meta.url), "utf8"));
const number = (session, form) => Number(session.evaluate(form));

async function application() {
  const session = await createSeedSession();
  session.evaluateQuietly(source);
  await mountDeclaredAssets(session, fromPublic);
  return session;
}

function advance(session, record) {
  session.evaluateQuietly(`(app.replay-advance ${record.tics} ${record.controlx} ${record.controly} ${record.buttons})`);
}

test("NewGame owns campaign, pistol, and attack defaults before a nonzero level selection", async () => {
  const session = await createSeedSession();
  session.evaluateQuietly(source);
  session.evaluateQuietly("(set! wl.score 99)");
  session.evaluateQuietly("(set! wl.lives 1)");
  session.evaluateQuietly("(set! wl.weapon 0)");
  session.evaluateQuietly("(set! wl.attackframe 3)");
  session.evaluateQuietly("(wl.new-game 3 4)");
  session.evaluateQuietly("(wl.select-map 7)");

  assert.deepEqual(
    ["wl.score", "wl.lives", "wl.map", "wl.episode", "wl.bestweapon", "wl.weapon",
      "wl.chosenweapon", "wl.difficulty"].map((form) => number(session, form)),
    [0, 3, 7, 4, 1, 1, 1, 3]
  );
  assert.deepEqual(
    ["wl.oldscore", "wl.nextextra", "wl.health", "wl.ammo", "wl.keys", "wl.faceframe",
      "wl.attack-active", "wl.attackframe", "wl.attackcount", "wl.weaponframe"]
      .map((form) => number(session, form)),
    [0, 40000, 100, 8, 0, 0, 0, 0, 0, 0]
  );
});

test("SpawnPlayer installs s_player and FL_NEVERMARK semantics", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  assert.equal(number(session, "(wl.player@ wl.PLAYER-STATE)"), 0);
  assert.equal(number(session, "(wl.player@ wl.PLAYER-FLAGS)"), 4);
  session.evaluateQuietly("(wl.player! wl.PLAYER-STATE 99)");
  session.evaluateQuietly("(wl.player! wl.PLAYER-FLAGS 0)");
  session.evaluateQuietly("(wl.spawn-player 2 3 1)");
  assert.equal(number(session, "(wl.player@ wl.PLAYER-STATE)"), 0);
  assert.equal(number(session, "(wl.player@ wl.PLAYER-FLAGS)"), number(session, "wl.FL-NEVERMARK"));
});

test("ID_US_A table cursor increments before lookup and wraps exactly", async () => {
  const session = await createSeedSession();
  session.evaluateQuietly(source);
  session.evaluateQuietly("(set! wl.rndindex 255)");
  const table = Uint8Array.from({ length: 256 }, () => number(session, "(wl.us-rndt)"));
  assert.equal(
    createHash("sha256").update(table).digest("hex"),
    "908b529108dcbcd3fe82907cd646e08b12404a893eda2165fe58dadd709a413f",
    "all 256 published bytes, beginning at wrapped index zero"
  );
  assert.equal(number(session, "wl.rndindex"), 255);
  session.evaluateQuietly("(set! wl.rndindex 0)");
  assert.deepEqual(
    Array.from({ length: 6 }, () => number(session, "(wl.us-rndt)")),
    [8, 109, 220, 222, 241, 149]
  );
  assert.equal(number(session, "wl.rndindex"), 6);
  session.evaluateQuietly("(set! wl.rndindex 255)");
  assert.equal(number(session, "(wl.us-rndt)"), 0, "index 255 wraps to table byte zero");
  assert.equal(number(session, "wl.rndindex"), 0);
});

test("object-plane tile 114 spawns the source RNG-seeded west patrol", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();

  // Row-major ScanInfoPlane makes this guard actor 10 in the fixed enemy list.
  const actor = 10;
  assert.equal(number(session, `(u16@ app.object-plane ${2 * (33 * 64 + 7)})`), 114);
  assert.equal(number(session, "wl.actorcount"), 21, "twenty enemies plus SpawnDeadGuard");
  assert.equal(number(session, "wl.rndindex"), 6, "six active patrol spawns consume the first six table bytes");
  assert.equal(number(session, `(wl.actor-class@ ${actor})`), 3);
  assert.equal(number(session, `(wl.actor-active@ ${actor})`), 1);
  assert.equal(number(session, `(wl.actor-x@ ${actor})`), 7 * 65536 + 32768);
  assert.equal(number(session, `(wl.actor-y@ ${actor})`), 33 * 65536 + 32768);
  assert.equal(number(session, `(wl.actor-tilex@ ${actor})`), 6, "SpawnPatrol reserves the destination tile");
  assert.equal(number(session, `(wl.actor-dir@ ${actor})`), 4, "west");
  assert.equal(number(session, `(wl.actor-speed@ ${actor})`), 512);
  assert.equal(number(session, `(wl.actor-distance@ ${actor})`), 65536);
  assert.equal(number(session, `(wl.actor-ticcount@ ${actor})`), 8, "rndtable[1] modulo path1's 20 tics");
  assert.equal(number(session, `(wl.actorat@ 6 33)`), actor + 1);
});

test("loaded-map scans own source kill, treasure, and secret totals", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  assert.deepEqual(
    ["wl.killtotal", "wl.treasuretotal", "wl.secrettotal"].map((form) => number(session, form)),
    [20, 23, 5],
    "E1M1 medium totals"
  );
  session.evaluateQuietly("(wl.new-game 1 1)");
  session.evaluateQuietly("(wl.select-map 1)");
  session.evaluateQuietly("(set! wl.killcount 99)");
  session.evaluateQuietly("(define test.e2m2-planes (ca.cache-map app.tinf app.maps 11))");
  session.evaluateQuietly("(wl.setup-game-level (car test.e2m2-planes) (car (cdr test.e2m2-planes)))");
  assert.equal(number(session, "wl.difficulty"), 1);
  assert.equal(number(session, "wl.episode"), 1);
  assert.equal(number(session, "wl.map"), 1);
  assert.equal(number(session, "wl.killcount"), 0, "fresh level setup resets the dynamic count");
  assert.deepEqual(
    ["wl.killtotal", "wl.treasuretotal", "wl.secrettotal"].map((form) => number(session, form)),
    [18, 33, 4],
    "E2M2 easy totals differ in every category"
  );
});

test("the real patrol path opens off-route door 8 at record 148", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const actor = 10;

  for (const record of route.records.slice(0, 147)) advance(session, record);
  assert.equal(number(session, "(wl.door-action@ 8)"), 1, "door remains closed through record 147");
  assert.equal(number(session, "(wl.door-checksum)"), 36463);
  assert.equal(number(session, `(wl.actor-x@ ${actor})`), 426496);
  assert.equal(number(session, `(wl.actor-distance@ ${actor})`), 512);

  advance(session, route.records[147]);
  assert.equal(number(session, "(wl.door-action@ 8)"), 2, "TryWalk calls OpenDoor");
  assert.equal(number(session, "(wl.door-position@ 8)"), 0, "MoveDoors already ran this tick");
  assert.equal(number(session, "(wl.door-checksum)"), 16910);
  assert.equal(number(session, `(wl.actor-tilex@ ${actor})`), 5);
  assert.equal(number(session, `(wl.actor-distance@ ${actor})`), -9, "-door-1 waiting contract");

  advance(session, route.records[148]);
  assert.equal(number(session, "(wl.door-position@ 8)"), 1024);
  assert.equal(number(session, "(wl.door-checksum)"), 10413);
});

test("GunAttack misses honestly and SightPlayer advances the cursor at record 215", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  for (const [index, record] of route.records.slice(0, 214).entries()) {
    advance(session, record);
    assert.equal(number(session, "wl.rndindex"), record.rndindex, `record ${index + 1}`);
  }
  const target = 20;
  assert.equal(number(session, "wl.rndindex"), 229);
  assert.equal(number(session, "wl.attackframe"), 1);
  assert.equal(number(session, "wl.attackcount"), 1);
  assert.equal(number(session, `(wl.actor-viewx@ ${target})`), 502, "retained projection is off crosshair");
  assert.equal(number(session, `(wl.actor-flags@ ${target})`), 1, "renderer visibility remains clear");
  assert.equal(session.evaluate(`(wl.actor-check-line-player ${target})`), "false",
    "the real DDA is blocked; madenoise, not fabricated visibility, wakes this guard");

  advance(session, route.records[214]);
  assert.equal(number(session, "wl.ammo"), 7, "the pistol fires even without a selected target");
  assert.equal(number(session, `(wl.actor-hitpoints@ ${target})`), 25, "GunAttack consumed no damage draw");
  assert.equal(number(session, `(wl.actor-temp2@ ${target})`), 56,
    "madenoise lets SightPlayer consume table[231]=221 and schedule 1+221/4 tics");
  assert.equal(number(session, "wl.rndindex"), 231);
});

test("GunAttack retains blocked viewdist and accepts zero damage", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  for (let actor = 0; actor < 21; actor += 1) {
    session.evaluateQuietly(`(wl.actor-flags! ${actor} (bit.and (wl.actor-flags@ ${actor}) 247))`);
  }
  session.evaluateQuietly("(wl.actor-flags! 0 9)");
  session.evaluateQuietly("(wl.actor-viewx! 0 159)");
  session.evaluateQuietly("(wl.actor-transx! 0 1000)");
  session.evaluateQuietly("(wl.actor-flags! 20 9)");
  session.evaluateQuietly("(wl.actor-viewx! 20 159)");
  session.evaluateQuietly("(wl.actor-transx! 20 2000)");
  const cursor = number(session, "wl.rndindex");
  assert.equal(session.evaluate("(wl.gun-attack)"), "false",
    "the blocked nearest actor prevents selecting the farther actor");
  assert.equal(number(session, "wl.rndindex"), cursor);

  session.evaluateQuietly("(wl.actor-x! 20 (wl.player@ wl.PLAYER-X))");
  session.evaluateQuietly("(wl.actor-y! 20 (wl.player@ wl.PLAYER-Y))");
  session.evaluateQuietly("(wl.actor-tilex! 20 (wl.player@ wl.PLAYER-TILEX))");
  session.evaluateQuietly("(wl.actor-tiley! 20 (wl.player@ wl.PLAYER-TILEY))");
  session.evaluateQuietly("(wl.actor-flags! 0 1)");
  session.evaluateQuietly("(wl.actor-hitpoints! 20 25)");
  session.evaluateQuietly("(set! wl.rndindex 82)");
  assert.equal(session.evaluate("(wl.gun-attack)"), "true");
  assert.equal(number(session, "wl.rndindex"), 83);
  assert.equal(number(session, "(wl.actor-hitpoints@ 20)"), 25,
    "table[83]=0 still enters DamageActor without imposing minimum damage");
  assert.ok(number(session, "(bit.and (wl.actor-flags@ 20) wl.FL-ATTACKMODE)"));
});

test("a shootable live guard death increments killcount exactly once", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const actor = 20;
  assert.equal(number(session, "wl.killcount"), 0, "retained R1 starts with no kills");
  session.evaluateQuietly(`(wl.actor-hitpoints! ${actor} 1)`);
  session.evaluateQuietly(`(wl.actor-flags! ${actor} (bit.or (wl.actor-flags@ ${actor}) wl.FL-SHOOTABLE))`);
  assert.equal(session.evaluate(`(wl.damage-actor ${actor} 1)`), "true");
  assert.equal(number(session, "wl.killcount"), 1);
  assert.equal(number(session, "(app.at (assoc 'killcount (app.trace-record)) 1)"), 1,
    "the owned projection reports the real death count");
  assert.equal(number(session, `(bit.and (wl.actor-flags@ ${actor}) wl.FL-SHOOTABLE)`), 0);
  assert.equal(session.evaluate(`(wl.damage-actor ${actor} 1)`), "true");
  assert.equal(number(session, "wl.killcount"), 1, "an already dead, non-shootable actor cannot count twice");

  const nonshootable = 19;
  session.evaluateQuietly(`(wl.actor-hitpoints! ${nonshootable} 1)`);
  session.evaluateQuietly(`(wl.actor-flags! ${nonshootable} (bit.and (wl.actor-flags@ ${nonshootable}) (- 255 wl.FL-SHOOTABLE)))`);
  session.evaluateQuietly(`(wl.damage-actor ${nonshootable} 1)`);
  assert.equal(number(session, "wl.killcount"), 1, "non-shootable deaths are not KillActor events");
});

test("T_Chase consumes source draws, moves west, and selects the guard shoot state", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  for (const record of route.records.slice(0, 293)) advance(session, record);
  assert.equal(number(session, "wl.rndindex"), 55);
  assert.equal(number(session, "(wl.actor-phase@ 20)"), 103);
  assert.equal(number(session, "(wl.actor-x@ 20)"), 2559488);

  advance(session, route.records[293]);
  assert.equal(number(session, "wl.rndindex"), 57,
    "the first guard chase think contributes the formerly missing source draw");
  assert.equal(number(session, "(wl.actor-dir@ 20)"), 4);
  assert.equal(number(session, "(wl.actor-x@ 20)"), 2557952);
  assert.equal(number(session, "(wl.actor-distance@ 20)"), 34816);

  for (const record of route.records.slice(294, 308)) advance(session, record);
  assert.equal(number(session, "wl.rndindex"), 83);
  assert.equal(number(session, "(wl.actor-phase@ 20)"), 110, "attack chance enters shoot");
  assert.equal(number(session, "(wl.actor-ticcount@ 20)"), 20);
});

test("guard T_Shoot honors area and line gates and preserves zero damage", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const actor = 20;
  const area = number(session, `(wl.actor-area@ ${actor})`);
  const cursor = number(session, "wl.rndindex");
  session.evaluateQuietly(`(u8! wl.areabyplayer ${area} 0)`);
  assert.equal(session.evaluate(`(wl.t-shoot ${actor})`), "false");
  assert.equal(number(session, "wl.rndindex"), cursor, "inactive areas draw nothing");

  session.evaluateQuietly(`(u8! wl.areabyplayer ${area} 1)`);
  assert.equal(session.evaluate(`(wl.t-shoot ${actor})`), "false");
  assert.equal(number(session, "wl.rndindex"), cursor, "blocked CheckLine draws nothing");

  session.evaluateQuietly(`(wl.actor-x! ${actor} (wl.player@ wl.PLAYER-X))`);
  session.evaluateQuietly(`(wl.actor-y! ${actor} (wl.player@ wl.PLAYER-Y))`);
  session.evaluateQuietly(`(wl.actor-tilex! ${actor} (wl.player@ wl.PLAYER-TILEX))`);
  session.evaluateQuietly(`(wl.actor-tiley! ${actor} (wl.player@ wl.PLAYER-TILEY))`);
  session.evaluateQuietly("(set! wl.rndindex 81)");
  assert.equal(session.evaluate(`(wl.t-shoot ${actor})`), "true",
    "table[82]=249 hits at distance zero and table[83]=0 remains zero damage");
  assert.equal(number(session, "wl.rndindex"), 83);
  assert.equal(number(session, "wl.health"), 100);
});

test("guard shoot cadence resolves record 348 and the cursor remains exact through R1", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  for (const [index, record] of route.records.entries()) {
    advance(session, record);
    const cursor = number(session, "wl.rndindex");
    assert.equal(cursor, record.rndindex, `record ${index + 1}`);
    if (index === 347) {
      assert.equal(number(session, "wl.health"), 81,
        "hit roll 136 succeeds and damage roll 156 >> 3 removes 19 health");
      assert.equal(number(session, "(wl.actor-phase@ 20)"), 112);
      assert.equal(number(session, "(wl.actor-ticcount@ 20)"), 20);
    }
  }
  assert.equal(number(session, "wl.rndindex"), 211);
  assert.equal(number(session, "wl.health"), 81);
  assert.equal(number(session, "wl.killcount"), 0, "no retained R1 enemy reaches the real KillActor path");
});

test("the retained bo_clip is picked up once at the source TransformTile boundary", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  assert.equal(number(session, "wl.r1-clip-active"), 1);
  assert.equal(number(session, "wl.r1-clip-x"), 40);
  assert.equal(number(session, "wl.r1-clip-y"), 61);

  for (const record of route.records.slice(0, 365)) advance(session, record);
  assert.equal(number(session, "wl.ammo"), 7, "record 365 remains after the pistol shot");
  assert.equal(number(session, "wl.r1-clip-active"), 1);

  advance(session, route.records[365]);
  assert.equal(number(session, "wl.ammo"), 15, "record 366 applies bo_clip GiveAmmo(8)");
  assert.equal(number(session, "wl.r1-clip-active"), 0, "GetBonus removes the static");
  assert.equal(session.evaluate("(wl.update-r1-clip-bonus)"), "false");
  assert.equal(number(session, "wl.ammo"), 15, "a removed clip cannot be collected twice");

  for (const record of route.records.slice(366)) advance(session, record);
  assert.equal(number(session, "wl.ammo"), 15);
  assert.equal(number(session, "wl.rndindex"), 211);
});

test("bo_clip GiveAmmo clamps at 99 and leaves a full-ammo pickup present", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  session.evaluateQuietly("(set! wl.ammo 95)");
  assert.equal(session.evaluate("(wl.get-r1-clip)"), "true");
  assert.equal(number(session, "wl.ammo"), 99);
  assert.equal(number(session, "wl.r1-clip-active"), 0);

  session.evaluateQuietly("(set! wl.r1-clip-active 1)");
  assert.equal(session.evaluate("(wl.get-r1-clip)"), "false");
  assert.equal(number(session, "wl.ammo"), 99);
  assert.equal(number(session, "wl.r1-clip-active"), 1,
    "source GetBonus returns before deleting a clip at maximum ammo");
});
