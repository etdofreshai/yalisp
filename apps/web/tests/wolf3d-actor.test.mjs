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
  session.evaluateQuietly("(set! wl.treasurecount 99)");
  session.evaluateQuietly("(define test.e2m2-planes (ca.cache-map app.tinf app.maps 11))");
  session.evaluateQuietly("(wl.setup-game-level (car test.e2m2-planes) (car (cdr test.e2m2-planes)))");
  assert.equal(number(session, "wl.difficulty"), 1);
  assert.equal(number(session, "wl.episode"), 1);
  assert.equal(number(session, "wl.map"), 1);
  assert.equal(number(session, "wl.killcount"), 0, "fresh level setup resets the dynamic count");
  assert.equal(number(session, "wl.treasurecount"), 0, "fresh level setup resets treasurecount");
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

test("patrol diagonals update both reserved destination coordinates", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const dog = 13;

  for (const record of route.records.slice(0, 102)) advance(session, record);
  assert.deepEqual(
    ["tilex", "tiley", "dir"].map((field) => number(session, `(wl.actor-${field}@ ${dog})`)),
    [54, 44, 5],
    "southwest path state reserved both destination axes"
  );

  advance(session, route.records[102]);
  assert.deepEqual(
    ["tilex", "tiley", "dir"].map((field) => number(session, `(wl.actor-${field}@ ${dog})`)),
    [53, 43, 3],
    "northwest path state reserves both destination axes"
  );

  for (const record of route.records.slice(103, 382)) advance(session, record);
  const guard = 20;
  assert.deepEqual(
    ["x", "y", "tilex", "tiley", "dir"].map((field) =>
      number(session, `(wl.actor-${field}@ ${guard})`)),
    [2524160, 4030464, 38, 61, 4],
    "guard remains westbound through record 382"
  );

  advance(session, route.records[382]);
  assert.deepEqual(
    ["x", "y", "tilex", "tiley", "dir"].map((field) =>
      number(session, `(wl.actor-${field}@ ${guard})`)),
    [2523648, 4029952, 39, 60, 1],
    "reversed north/east ordering selects northeast at record 383"
  );
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
  assert.equal(number(session, `(wl.actor-viewx@ ${target})`), 216,
    "record 106 source transform is retained after visibility clears at record 107");
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
  session.evaluateQuietly("(wl.actor-viewx! 0 119)");
  session.evaluateQuietly("(wl.actor-transx! 0 1000)");
  session.evaluateQuietly("(wl.actor-flags! 20 9)");
  session.evaluateQuietly("(wl.actor-viewx! 20 119)");
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

test("general statics apply each source treasure bonus once", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  assert.deepEqual([49, 52, 53, 54, 55, 56].map((tile) => number(session, `(wl.static-item-for-tile ${tile})`)),
    [13, 9, 10, 11, 12, 18]);

  session.evaluateQuietly("(set! wl.score 0)");
  session.evaluateQuietly("(set! wl.nextextra 40000)");
  session.evaluateQuietly("(set! wl.lives 3)");
  session.evaluateQuietly("(set! wl.treasurecount 0)");
  session.evaluateQuietly("(wl.player! wl.PLAYER-X (- (wl.player@ wl.PLAYER-X) 16000))");
  const cross = number(session, `(wl.spawn-static-item (wl.player@ wl.PLAYER-TILEX) (wl.player@ wl.PLAYER-TILEY) wl.BO-CROSS)`);
  assert.equal(session.evaluate("(wl.update-static-bonuses)"), "true", "TransformTile-range collection owns pickup");
  assert.deepEqual([number(session, "wl.score"), number(session, "wl.treasurecount"),
    number(session, `(wl.static-shapenum@ ${cross})`), number(session, `(u8@ wl.staticitem ${cross})`)],
  [100, 1, -1, number(session, "wl.BO-CROSS")]);
  assert.equal(session.evaluate(`(wl.get-static ${cross})`), "false", "removed cross cannot score twice");

  for (const [item, points] of [["wl.BO-CHALICE", 500], ["wl.BO-CROWN", 5000]]) {
    session.evaluateQuietly("(set! wl.score 0)");
    session.evaluateQuietly("(set! wl.treasurecount 0)");
    const index = number(session, `(wl.spawn-static-item 1 1 ${item})`);
    assert.equal(session.evaluate(`(wl.get-static ${index})`), "true");
    assert.deepEqual([number(session, "wl.score"), number(session, "wl.treasurecount"),
      number(session, `(wl.static-shapenum@ ${index})`), number(session, `(u8@ wl.staticitem ${index})`)],
    [points, 1, -1, number(session, item)]);
    assert.equal(session.evaluate(`(wl.get-static ${index})`), "false");
  }

  session.evaluateQuietly("(set! wl.score 39500)");
  session.evaluateQuietly("(set! wl.nextextra 40000)");
  session.evaluateQuietly("(set! wl.lives 3)");
  session.evaluateQuietly("(set! wl.treasurecount 0)");
  const bible = number(session, "(wl.spawn-static-item 1 1 wl.BO-BIBLE)");
  assert.equal(session.evaluate(`(wl.get-static ${bible})`), "true");
  assert.deepEqual([number(session, "wl.score"), number(session, "wl.nextextra"), number(session, "wl.lives"), number(session, "wl.treasurecount")], [40500, 80000, 4, 1]);
  assert.deepEqual([number(session, `(wl.static-shapenum@ ${bible})`), number(session, `(u8@ wl.staticitem ${bible})`)],
    [-1, number(session, "wl.BO-BIBLE")]);
  assert.equal(session.evaluate(`(wl.get-static ${bible})`), "false");

  session.evaluateQuietly("(set! wl.health 1)");
  session.evaluateQuietly("(set! wl.ammo 0)");
  session.evaluateQuietly("(set! wl.weapon 0)");
  session.evaluateQuietly("(set! wl.chosenweapon 1)");
  session.evaluateQuietly("(set! wl.attackframe 0)");
  session.evaluateQuietly("(set! wl.lives 8)");
  session.evaluateQuietly("(set! wl.treasurecount 0)");
  const fullheal = number(session, "(wl.spawn-static-item 1 1 wl.BO-FULLHEAL)");
  assert.equal(session.evaluate(`(wl.get-static ${fullheal})`), "true");
  assert.deepEqual([number(session, "wl.health"), number(session, "wl.ammo"), number(session, "wl.weapon"), number(session, "wl.lives"), number(session, "wl.treasurecount"),
    number(session, `(wl.static-shapenum@ ${fullheal})`), number(session, `(u8@ wl.staticitem ${fullheal})`)],
  [100, 25, 1, 9, 1, -1, number(session, "wl.BO-FULLHEAL")]);
  assert.equal(session.evaluate(`(wl.get-static ${fullheal})`), "false");
  assert.equal(number(session, "wl.treasurecount"), 1);
  const cappedFullheal = number(session, "(wl.spawn-static-item 1 1 wl.BO-FULLHEAL)");
  assert.equal(session.evaluate(`(wl.get-static ${cappedFullheal})`), "true");
  assert.deepEqual([number(session, "wl.health"), number(session, "wl.ammo"), number(session, "wl.lives"), number(session, "wl.treasurecount")], [100, 50, 9, 2]);
  assert.deepEqual([number(session, `(wl.static-shapenum@ ${cappedFullheal})`), number(session, `(u8@ wl.staticitem ${cappedFullheal})`)],
    [-1, number(session, "wl.BO-FULLHEAL")]);

  session.evaluateQuietly("(set! wl.health 0)");
  const healed = number(session, "(wl.spawn-static-item 1 1 wl.BO-FULLHEAL)");
  assert.equal(session.evaluate(`(wl.get-static ${healed})`), "true");
  assert.equal(number(session, "wl.health"), 99,
    "bo_fullheal asks HealSelf for 99 points and clamps; it does not assign 100");
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
  assert.equal(number(session, "wl.treasurecount"), 0, "retained R1 collects no treasure statics");
});

test("the retained bo_clip is picked up once at the source TransformTile boundary", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const clip = number(session, "(wl.static-at 40 61 0)");
  assert.ok(clip >= 0);
  assert.equal(number(session, `(u8@ wl.staticitem ${clip})`), number(session, "wl.BO-CLIP"));

  for (const record of route.records.slice(0, 365)) advance(session, record);
  assert.equal(number(session, "wl.ammo"), 7, "record 365 remains after the pistol shot");
  assert.equal(number(session, `(u8@ wl.staticitem ${clip})`), number(session, "wl.BO-CLIP"));

  advance(session, route.records[365]);
  assert.equal(number(session, "wl.ammo"), 15, "record 366 applies bo_clip GiveAmmo(8)");
  assert.equal(number(session, `(wl.static-shapenum@ ${clip})`), -1, "GetBonus removes only the shape");
  assert.equal(number(session, `(u8@ wl.staticitem ${clip})`), number(session, "wl.BO-CLIP"),
    "GetBonus retains the source itemnumber");
  assert.equal(session.evaluate("(wl.update-static-bonuses)"), "false");
  assert.equal(number(session, "wl.ammo"), 15, "a removed clip cannot be collected twice");

  for (const record of route.records.slice(366)) advance(session, record);
  assert.equal(number(session, "wl.ammo"), 15);
  assert.equal(number(session, "wl.rndindex"), 211);
});

// PushWall is the only place in the whole source that moves gamestate.secretcount;
// SetupGameLevel is the only other writer and it resets the counter. Canonical R1
// never pushes a wall, so ownership has to be shown at the source boundary
// itself, on the real E1M1 object plane rather than on a fabricated map.
test("PushWall owns secretcount and increments once per successful activation", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const objectAt = (x, y) => number(session, `(u16@ app.object-plane ${2 * (y * 64 + x)})`);

  // Object-plane PUSHABLETILE at (18,49); plane 0 gives it wall texture 1,
  // SetupGameLevel copies that into tilemap and into actorat's wall half.
  assert.equal(objectAt(18, 49), number(session, "wl.PUSHABLETILE"));
  assert.equal(number(session, "(wl.tilemap@ 18 49)"), 1);
  assert.equal(number(session, "(wl.actorat-wall@ 18 49)"), 1);
  assert.equal(number(session, "wl.secretcount"), 0);
  assert.equal(number(session, "wl.pwallstate"), 0);

  // East of it is plane-0 tile 2, a solid wall: `if (actorat[checkx+1][checky])`
  // refuses with NOWAYSND and never reaches the counter.
  assert.equal(number(session, "(wl.actorat-wall@ 19 49)"), 2);
  assert.equal(session.evaluate("(wl.push-wall 18 49 wl.EAST)"), "false");
  assert.deepEqual(["wl.secretcount", "wl.pwallstate"].map((form) => number(session, form)), [0, 0]);
  assert.equal(number(session, "(wl.tilemap@ 18 49)"), 1, "a refused push writes no tile");
  assert.equal(objectAt(18, 49), number(session, "wl.PUSHABLETILE"), "and leaves the P tile in place");

  // The other pushwall at (30,22) is blocked by a live actor instead: (31,22)
  // was an ambush marker, so its wall half is cleared and a guard stands there.
  assert.equal(objectAt(30, 22), number(session, "wl.PUSHABLETILE"));
  assert.equal(number(session, "(wl.actorat-wall@ 31 22)"), 0, "the ambush marker cleared actorat");
  assert.ok(number(session, "(wl.actorat@ 31 22)") > 0, "a spawned guard holds the tile");
  assert.equal(session.evaluate("(wl.push-wall 30 22 wl.EAST)"), "false");
  assert.equal(number(session, "wl.secretcount"), 0);
  assert.equal(objectAt(30, 22), number(session, "wl.PUSHABLETILE"));

  // `oldtile = tilemap[checkx][checky]; if (!oldtile) return;`
  assert.equal(number(session, "(wl.tilemap@ 18 48)"), 0);
  assert.equal(session.evaluate("(wl.push-wall 18 48 wl.NORTH)"), "false");
  assert.equal(number(session, "wl.secretcount"), 0);

  // North is clear, so the switch copies the tile one cell along dir into both
  // actorat and tilemap, and only then does secretcount move.
  assert.equal(session.evaluate("(wl.push-wall 18 49 wl.NORTH)"), "true");
  assert.equal(number(session, "wl.secretcount"), 1);
  assert.deepEqual(
    ["wl.pwallx", "wl.pwally", "wl.pwalldir", "wl.pwallstate", "wl.pwallpos"]
      .map((form) => number(session, form)),
    [18, 49, number(session, "wl.NORTH"), 1, 0]
  );
  assert.equal(number(session, "(wl.tilemap@ 18 48)"), 1, "tilemap[checkx][checky-1] = oldtile");
  assert.equal(number(session, "(wl.actorat-wall@ 18 48)"), 1, "actorat[checkx][checky-1] = oldtile");
  assert.equal(number(session, "(wl.tilemap@ 18 49)"), 1 | 0xc0, "tilemap[pwallx][pwally] |= 0xc0");
  assert.equal(number(session, "(wl.actorat-wall@ 18 49)"), 1, "actorat keeps the wall until MovePWalls");
  assert.equal(objectAt(18, 49), 0, "remove P tile info");

  // `if (pwallstate) return;` is the whole reentrancy guard: a second push of
  // the same wall, and of a different untouched one, both stop before the count.
  assert.equal(session.evaluate("(wl.push-wall 18 49 wl.NORTH)"), "false");
  assert.equal(session.evaluate("(wl.push-wall 13 53 wl.NORTH)"), "false");
  assert.equal(number(session, "wl.secretcount"), 1);
  assert.equal(objectAt(13, 53), number(session, "wl.PUSHABLETILE"), "the untouched wall keeps its P tile");
  assert.equal(number(session, "(wl.tilemap@ 13 52)"), 0, "and wrote no tile");

  // SetupGameLevel's `if (!loadedgame)` block resets secretcount with the other
  // counters, and deliberately does not touch any pushwall variable.
  session.evaluateQuietly("(wl.setup-game-level app.wall-plane app.object-plane)");
  assert.equal(number(session, "wl.secretcount"), 0);
  assert.equal(number(session, "wl.pwallstate"), 1, "the source resets no pushwall variable per level");
});

// MovePWalls is driven straight here so that `tics` is the only variable: the
// PlayLoop integration is covered by the replay-boundary tests instead.
function pwallTicker(session) {
  session.evaluateQuietly(
    "(defn test.pwall-tics (n) (if (= n 0) nil (begin (wl.move-pwalls) (test.pwall-tics (- n 1)))))");
  return (count) => session.evaluateQuietly(`(test.pwall-tics ${count})`);
}

const pwallVariables = ["wl.pwallstate", "wl.pwallpos", "wl.pwallx", "wl.pwally", "wl.pwalldir"];

test("MovePWalls hands each vacated tile to the player's area and stops after two", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const tick = pwallTicker(session);
  const pwall = () => pwallVariables.map((form) => number(session, form));
  const plane0 = (x, y) => number(session, `(u16@ app.wall-plane ${2 * (y * 64 + x)})`);

  // The player is still at the canonical E1M1 spawn (29,57), which is area 2,
  // while the corridor the wall is cut out of is area 33. That difference is
  // the point: `*(mapsegs[0]+...) = player->areanumber+AREATILE` joins the
  // vacated tile to wherever the player stands, not to its own surroundings.
  assert.deepEqual([number(session, "(wl.player@ wl.PLAYER-TILEX)"), number(session, "(wl.player@ wl.PLAYER-TILEY)")],
    [29, 57]);
  assert.equal(number(session, "(wl.player-area)"), 2);
  assert.deepEqual([plane0(18, 48), plane0(18, 49)], [140, 1], "area 33 corridor, wall texture 1");

  session.evaluateQuietly("(set! wl.tics 6)");
  assert.equal(session.evaluate("(wl.push-wall 18 49 wl.NORTH)"), "true");
  assert.equal(number(session, "wl.plane0-dirty"), 0, "activation does not touch plane 0");

  // `oldblock = pwallstate/128` only differs from the new one once pwallstate
  // reaches 128; from 1 with tics 6 that is the step that lands on 133.
  tick(21);
  assert.deepEqual(pwall(), [127, 63, 18, 49, 0]);
  assert.equal(number(session, "(wl.tilemap@ 18 49)"), 1 | 0xc0, "still tagged where it started");

  tick(1);
  assert.deepEqual(pwall(), [133, 2, 18, 48, 0], "pwally-- happened before the beyond-cell test");
  assert.deepEqual([number(session, "(wl.tilemap@ 18 49)"), number(session, "(wl.actorat-wall@ 18 49)")], [0, 0],
    "the tile can now be walked into");
  assert.equal(plane0(18, 49), 2 + 107, "the vacated tile joined the player's area, not area 33");
  assert.equal(number(session, "wl.plane0-dirty"), 1);
  assert.equal(number(session, "(wl.tilemap@ 18 48)"), 1 | 0xc0, "tilemap[pwallx][pwally] = oldtile | 0xc0");
  assert.deepEqual([number(session, "(wl.tilemap@ 18 47)"), number(session, "(wl.actorat-wall@ 18 47)")], [1, 1],
    "and the cell beyond took oldtile in both tables");

  // 259 is the first value past 256, so the twenty-first step after the first
  // crossing is the one that stops it.
  tick(20);
  assert.deepEqual(pwall(), [253, 62, 18, 48, 0]);
  tick(1);
  assert.deepEqual(pwall(), [0, 62, 18, 48, 0],
    "the >256 return is taken before `pwallpos = (pwallstate/2)&63`");
  assert.deepEqual([number(session, "(wl.tilemap@ 18 48)"), plane0(18, 48)], [0, 2 + 107]);
  assert.equal(number(session, "(wl.tilemap@ 18 47)"), 1, "the block rests untagged two tiles along");
  assert.equal(number(session, "wl.secretcount"), 1);

  // pwallstate back at zero is exactly what PushWall's guard tests, so a second
  // secret on the same level is reachable once the first one finishes moving.
  tick(3);
  assert.deepEqual(pwall(), [0, 62, 18, 48, 0], "a cleared pwallstate is the whole early return");
  assert.equal(session.evaluate("(wl.push-wall 13 53 wl.NORTH)"), "true");
  assert.equal(number(session, "wl.secretcount"), 2);
  assert.deepEqual(pwall().slice(0, 4), [1, 0, 13, 53]);
});

test("an exact 256 crossing pushes the block a third tile", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const tick = pwallTicker(session);
  const pwall = () => pwallVariables.map((form) => number(session, form));

  // `if (pwallstate>256)` is strict, and pwallstate walks 1,2,...  with tics 1,
  // so it lands on 256 exactly, fails that test, and takes the push arm again.
  // Reproducing the original defect is the requirement, not avoiding it.
  session.evaluateQuietly("(set! wl.tics 1)");
  assert.equal(session.evaluate("(wl.push-wall 18 49 wl.NORTH)"), "true");

  tick(127);
  assert.deepEqual(pwall(), [128, 0, 18, 48, 0], "first crossing at 128");
  tick(128);
  assert.deepEqual(pwall(), [256, 0, 18, 47, 0], "256/128 is a new block and 256 is not > 256");
  assert.deepEqual([number(session, "(wl.tilemap@ 18 47)"), number(session, "(wl.tilemap@ 18 46)")], [1 | 0xc0, 1],
    "a third tile was written");
  tick(128);
  assert.deepEqual(pwall(), [0, 63, 18, 47, 0], "384 finally stops it");
  assert.deepEqual([number(session, "(wl.tilemap@ 18 47)"), number(session, "(wl.tilemap@ 18 46)")], [0, 1],
    "the block travelled three tiles, not two");
  assert.equal(number(session, "(wl.tilemap@ 18 45)"), 1, "the solid wall it would have hit next");
});

test("MovePWalls refuses an occupied cell mid-motion and leaves the block where it stands", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const tick = pwallTicker(session);
  const pwall = () => pwallVariables.map((form) => number(session, form));

  // No E1M1 pushwall is blocked two tiles along its own pushable direction, so
  // the blocker is a guard put on the real floor tile at (18,47) through the
  // game's own SpawnStand path. `if (actorat[pwallx][pwally-1])` is the test.
  assert.equal(number(session, `(u16@ app.wall-plane ${2 * (47 * 64 + 18)})`), 140, "a real area-33 floor tile");
  assert.equal(number(session, "(wl.actorat@ 18 47)"), 0);
  session.evaluateQuietly(`(wl.spawn-standing app.wall-plane ${47 * 64 + 18} 18 47 wl.NORTH 3)`);
  assert.ok(number(session, "(wl.actorat@ 18 47)") > 0);
  assert.equal(session.evaluate("(wl.actorat-occupied? 18 47)"), "true");

  session.evaluateQuietly("(set! wl.tics 6)");
  assert.equal(session.evaluate("(wl.push-wall 18 49 wl.NORTH)"), "true", "the first cell is still clear");
  tick(21);
  assert.deepEqual(pwall(), [127, 63, 18, 49, 0]);

  tick(1);
  assert.deepEqual(pwall(), [0, 63, 18, 48, 0],
    "pwally-- runs first, then the refusal zeroes pwallstate and returns before pwallpos");
  assert.equal(number(session, "(wl.tilemap@ 18 49)"), 0, "the tile it left is still vacated");
  assert.equal(number(session, `(u16@ app.wall-plane ${2 * (49 * 64 + 18)})`), 2 + 107);
  assert.equal(number(session, "(wl.tilemap@ 18 48)"), 1,
    "the block keeps PushWall's untagged copy where it stopped");
  assert.deepEqual([number(session, "(wl.tilemap@ 18 47)"), number(session, "(wl.actorat-wall@ 18 47)")], [0, 0],
    "and never wrote past the guard");

  tick(5);
  assert.deepEqual(pwall(), [0, 63, 18, 48, 0], "a zero pwallstate stays zero");
  assert.equal(number(session, "wl.secretcount"), 1);
});

test("Cmd_Use reaches PushWall on every held use tic, before the door gate", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const objectAt = (x, y) => number(session, `(u16@ app.object-plane ${2 * (y * 64 + x)})`);
  const doors = number(session, "(wl.door-checksum)");

  // (18,50) is the floor tile south of the pushwall; north is the only cardinal
  // Cmd_Use can pick that reaches it, and SpawnPlayer's north is 90 degrees.
  session.evaluateQuietly("(wl.spawn-player 18 50 wl.NORTH)");
  assert.equal(number(session, "(wl.player@ wl.PLAYER-ANGLE)"), 90);
  assert.equal(number(session, "wl.secretcount"), 0);

  advance(session, { tics: 1, controlx: 0, controly: 0, buttons: 0 });
  assert.equal(number(session, "wl.secretcount"), 0, "no use button, no activation");
  assert.equal(number(session, "wl.buttonheld-use"), 0);

  advance(session, { tics: 1, controlx: 0, controly: 0, buttons: 8 });
  assert.equal(number(session, "wl.secretcount"), 1, "the first use tic activates");
  assert.equal(number(session, "wl.buttonheld-use"), 0, "buttonheld is last frame's button");
  assert.equal(objectAt(18, 49), 0);
  assert.equal(number(session, "(wl.door-checksum)"), doors, "the moving wall is not decoded as a door");

  // Holding use keeps calling Cmd_Use, and the pushable test runs ahead of the
  // buttonheld gate, so PushWall is reached again and refuses on pwallstate.
  advance(session, { tics: 1, controlx: 0, controly: 0, buttons: 8 });
  assert.equal(number(session, "wl.buttonheld-use"), 1);
  assert.equal(number(session, "wl.secretcount"), 1);

  // Facing a wall with no P tile is the do-nothing arm: no counter, no door.
  session.evaluateQuietly("(wl.spawn-player 18 50 wl.SOUTH)");
  advance(session, { tics: 1, controlx: 0, controly: 0, buttons: 8 });
  assert.equal(number(session, "wl.secretcount"), 1);

  // The tilemap tag still decodes structurally as door 65, but the renderer's
  // source 0x40 branch catches it before any door-list read. TryMove reads the
  // untagged actorat wall value, as the original does.
  assert.equal(session.evaluate("(wl.door-tile? 193)"), "true");
  assert.equal(number(session, "(wl.door-number 193)"), 65);
  assert.ok(65 >= number(session, "wl.MAXDOORS"));
  assert.equal(number(session, "(wl.actorat-wall@ 18 49)"), 1,
    "the source's own TryMove input keeps the untagged tile, so the original never decodes it");
});

test("bo_clip GiveAmmo clamps at 99 and leaves a full-ammo pickup present", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const clip = number(session, "(wl.static-at 40 61 0)");
  session.evaluateQuietly("(set! wl.ammo 95)");
  assert.equal(session.evaluate(`(wl.get-static ${clip})`), "true");
  assert.equal(number(session, "wl.ammo"), 99);
  assert.deepEqual([number(session, `(wl.static-shapenum@ ${clip})`), number(session, `(u8@ wl.staticitem ${clip})`)],
    [-1, number(session, "wl.BO-CLIP")]);

  session.evaluateQuietly(`(wl.static-shapenum! ${clip} 28)`);
  assert.equal(session.evaluate(`(wl.get-static ${clip})`), "false");
  assert.equal(number(session, "wl.ammo"), 99);
  assert.equal(number(session, `(u8@ wl.staticitem ${clip})`), number(session, "wl.BO-CLIP"),
    "source GetBonus returns before deleting a clip at maximum ammo");
});
