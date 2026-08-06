import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { mountDeclaredAssets } from "../src/examples/runtime/asset-mount.ts";
import { parseLispValue } from "../src/examples/runtime/lisp-value.ts";
import { createSeedSession } from "./seed-session.mjs";
import {
  fromPublic,
  haveWolf3dOriginals as haveOriginals,
  wolf3dSkipReason as skipReason,
  wolf3dSource as source
} from "./wolf3d-source.mjs";

const fixture = JSON.parse(await readFile(new URL("./fixtures/wolf3d-r1-door-prefix-v3.json", import.meta.url), "utf8"));
const routeFixture = JSON.parse(await readFile(new URL("./fixtures/wolf3d-r1-route-v3.json", import.meta.url), "utf8"));
const promotedFields = [
  "difficulty", "health", "ammo", "keys", "faceframe", "attackframe", "attackcount", "weaponframe",
  "score", "lives", "map", "episode", "bestweapon", "weapon", "chosenweapon", "state", "flags",
  "secrettotal", "treasuretotal", "killtotal", "killcount", "treasurecount", "secretcount",
  "pwallstate", "pwallpos", "pwallx", "pwally", "pwalldir"
];
const newlyPromotedFields = [
  "score", "lives", "map", "episode", "bestweapon", "weapon", "chosenweapon", "state", "flags"
];
const totalPromotedFields = ["secrettotal", "treasuretotal", "killtotal"];
const killcountPromotedFields = ["killcount"];
const treasurecountPromotedFields = ["treasurecount"];
const secretcountPromotedFields = ["secretcount"];
const pwallPromotedFields = ["pwallstate", "pwallpos", "pwallx", "pwally", "pwalldir"];
const rndindexPromotedFields = ["rndindex"];
// TRACE-SCHEMA.md orders the level-progress block secretcount, treasurecount,
// killcount, then the three totals, so secretcount takes the slot between
// weaponframe and treasurecount. Offsets 74-82 then give the five pushwall
// variables the contiguous block between killtotal and doorchecksum; they are
// promoted now that PushWall's activation and MovePWalls' motion are both
// owned, which is every writer of them in the source outside save/load.
const canonicalProjectionFields = [
  "tick", "tics", "score", "health", "ammo", "keys", "lives", "x", "y", "angle", "tilex", "tiley",
  "state", "flags", "controlx", "controly", "buttons", "difficulty", "map", "episode", "bestweapon",
  "weapon", "chosenweapon", "faceframe", "attackframe", "attackcount", "weaponframe",
  "secretcount", "treasurecount", "killcount", "secrettotal", "treasuretotal", "killtotal",
  "pwallstate", "pwallpos", "pwallx", "pwally", "pwalldir",
  "doorchecksum", "rndindex", "plane0hash", "plane1hash", "worldhash"
];
const canonicalOmittedFields = ["actorhash"];

async function application() {
  const session = await createSeedSession();
  session.evaluateQuietly(source);
  await mountDeclaredAssets(session, fromPublic);
  return session;
}

function projectedRecord(text) {
  return Object.fromEntries(parseLispValue(text).map(([name, value]) => [String(name), Number(value)]));
}

async function replay(records) {
  const session = await application();
  const projected = [];
  const rndindices = [];
  for (const record of records) {
    projected.push(projectedRecord(session.evaluate(
      `(app.replay-advance ${record.tics} ${record.controlx} ${record.controly} ${record.buttons})`
    )));
    rndindices.push(Number(session.evaluate("wl.rndindex")));
  }
  return { session, projected, rndindices };
}

function firstDifference(expected, actual, fields = fixture.fields) {
  for (let index = 0; index < expected.length; index += 1) {
    for (const field of fields) {
      if (expected[index][field] !== actual[index]?.[field]) {
        return {
          record: index + 1,
          tick: expected[index].tick,
          field,
          original: expected[index][field],
          lisp: actual[index]?.[field]
        };
      }
    }
  }
  if (actual.length !== expected.length) {
    return { record: expected.length + 1, tick: null, field: "record-count", original: expected.length, lisp: actual.length };
  }
  return null;
}

function assertProjection(expected, actual, fields = fixture.fields) {
  const difference = firstDifference(expected, actual, fields);
  assert.equal(
    difference,
    null,
    difference && `record ${difference.record}, tick ${difference.tick}, field ${difference.field}: original ${difference.original}, Lisp ${difference.lisp}`
  );
}

function assertCanonicalFixtureSchema(candidate, route = false) {
  assert.deepEqual(candidate.fields, canonicalProjectionFields);
  if (route) assert.deepEqual(candidate.fullRouteFields, canonicalProjectionFields);
  assert.deepEqual(candidate.omitted, canonicalOmittedFields);
  if (route) assert.deepEqual(candidate.diagnosticFields, []);
  else assert.ok(!Object.hasOwn(candidate, "diagnosticFields"));
  for (const record of candidate.records) {
    assert.deepEqual(Object.keys(record), canonicalProjectionFields);
    assert.ok(Number.isInteger(record.rndindex) && record.rndindex >= 0 && record.rndindex <= 255);
  }
}

test("the Lisp-owned projection declares its exact v3 subset and exclusions", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const contract = parseLispValue(session.evaluate("(app.trace-projection-contract)"));
  assert.equal(contract[0], "projection");
  assert.equal(contract[1], "wolf3d-trace-bin-v3");
  assert.deepEqual(fixture.fields, canonicalProjectionFields);
  assert.deepEqual(routeFixture.fullRouteFields, canonicalProjectionFields);
  assertCanonicalFixtureSchema(fixture);
  assertCanonicalFixtureSchema(routeFixture, true);
  assert.deepEqual(contract.find((row) => Array.isArray(row) && row[0] === "fields").slice(1), fixture.fields);
  assert.equal(fixture.fields.length, 43);
  for (const field of promotedFields) assert.ok(fixture.fields.includes(field), `${field} must be projected`);
  assert.equal(fixture.fields.indexOf("secretcount"), fixture.fields.indexOf("weaponframe") + 1,
    "secretcount takes the canonical slot immediately after weaponframe");
  assert.equal(fixture.fields.indexOf("treasurecount"), fixture.fields.indexOf("secretcount") + 1);
  assert.equal(fixture.fields.indexOf("killcount"), fixture.fields.indexOf("treasurecount") + 1);
  assert.deepEqual(
    fixture.fields.slice(fixture.fields.indexOf("killtotal") + 1, fixture.fields.indexOf("doorchecksum")),
    pwallPromotedFields,
    "the five pushwall variables are the contiguous canonical block before doorchecksum");
  assert.deepEqual(contract.find((row) => Array.isArray(row) && row[0] === "encoding").slice(1),
    ["plane0hash", "u32-decimal", "plane1hash", "u32-decimal", "worldhash", "u32-decimal"]);
  const omitted = contract.find((row) => Array.isArray(row) && row[0] === "omitted").slice(1);
  assert.deepEqual(fixture.omitted, canonicalOmittedFields);
  assert.deepEqual(omitted, fixture.omitted);
  for (const field of canonicalOmittedFields) assert.ok(!fixture.fields.includes(field));
  for (const field of rndindexPromotedFields) assert.ok(fixture.fields.includes(field), `${field} must be projected`);
  assert.equal(fixture.fields.indexOf("rndindex"), fixture.fields.indexOf("doorchecksum") + 1);
  assert.equal(fixture.fields.indexOf("plane0hash"), fixture.fields.indexOf("rndindex") + 1);
  assert.equal(fixture.fields.indexOf("worldhash"), fixture.fields.indexOf("plane1hash") + 1);
});

test("the promoted cursor is emitted at the setup and first-replay boundaries", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  assert.equal(Number(session.evaluate("wl.rndindex")), 6,
    "deterministic E1M1 setup consumes six active-patrol spawn draws");
  const afterSetup = projectedRecord(session.evaluate("(app.trace-record)"));
  assert.deepEqual(Object.keys(afterSetup), canonicalProjectionFields);
  assert.equal(afterSetup.rndindex, 6, "trace-record reads the live cursor without advancing it");

  const input = routeFixture.records[0];
  const first = projectedRecord(session.evaluate(
    `(app.replay-advance ${input.tics} ${input.controlx} ${input.controly} ${input.buttons})`
  ));
  assert.equal(first.rndindex, 7, "the first retained tic performs the canonical pre-increment draw");

  session.evaluateQuietly("(set! wl.rndindex 200)");
  session.evaluateQuietly("(wl.setup-game-level app.wall-plane app.object-plane)");
  assert.equal(Number(session.evaluate("wl.rndindex")), 6,
    "fresh deterministic setup resets before scanning and consuming the six patrol draws");
  assert.equal(projectedRecord(session.evaluate("(app.trace-record)")).rndindex, 6);
});

test("fixture schema validation rejects partial rndindex promotion", () => {
  const missing = structuredClone(routeFixture);
  delete missing.records[99].rndindex;
  assert.throws(() => assertCanonicalFixtureSchema(missing, true));

  const reordered = structuredClone(routeFixture);
  const value = reordered.records[99].rndindex;
  delete reordered.records[99].rndindex;
  reordered.records[99].rndindex = value;
  assert.throws(() => assertCanonicalFixtureSchema(reordered, true));

  const omitted = structuredClone(routeFixture);
  omitted.omitted = ["worldhash", ...canonicalOmittedFields];
  assert.throws(() => assertCanonicalFixtureSchema(omitted, true));

  const diagnostic = structuredClone(routeFixture);
  diagnostic.diagnosticFields = ["rndindex"];
  assert.throws(() => assertCanonicalFixtureSchema(diagnostic, true));
});

test("the promoted totals report alternate-level scan ownership through the trace boundary", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  assert.deepEqual(totalPromotedFields.map((field) => projectedRecord(session.evaluate("(app.trace-record)"))[field]), [5, 23, 20]);
  session.evaluateQuietly("(wl.new-game 1 1)");
  session.evaluateQuietly("(wl.select-map 1)");
  session.evaluateQuietly("(define test.trace-e2m2 (ca.cache-map app.tinf app.maps 11))");
  session.evaluateQuietly("(wl.setup-game-level (car test.trace-e2m2) (car (cdr test.trace-e2m2)))");
  const alternate = projectedRecord(session.evaluate("(app.trace-record)"));
  assert.deepEqual(Object.keys(alternate), canonicalProjectionFields);
  assert.deepEqual(totalPromotedFields.map((field) => alternate[field]), [4, 33, 18]);
  assert.deepEqual([alternate.difficulty, alternate.episode, alternate.map], [1, 1, 1]);
});

test("the promoted treasurecount reports the live runtime counter, not a constant", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  assert.equal(projectedRecord(session.evaluate("(app.trace-record)")).treasurecount, 0);

  const crown = Number(session.evaluate("(wl.spawn-static-item 1 1 wl.BO-CROWN)"));
  assert.equal(session.evaluate(`(wl.get-static ${crown})`), "true");
  const collected = projectedRecord(session.evaluate("(app.trace-record)"));
  assert.deepEqual(Object.keys(collected), canonicalProjectionFields);
  assert.equal(collected.treasurecount, 1, "the boundary reads wl.treasurecount");
  assert.equal(collected.score, 5000, "the same GetBonus is what moved it");

  session.evaluateQuietly("(wl.setup-game-level app.wall-plane app.object-plane)");
  assert.equal(projectedRecord(session.evaluate("(app.trace-record)")).treasurecount, 0,
    "fresh level setup resets what the projection reports");
});

test("the promoted secretcount reports the live PushWall counter, not a constant", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  assert.equal(projectedRecord(session.evaluate("(app.trace-record)")).secretcount, 0);
  const cachedPlane1 = projectedRecord(session.evaluate("(app.trace-record)")).plane1hash;

  // E1M1 object-plane tile 98 at (18,49); the player stands south of it facing
  // north, which is the only cardinal Cmd_Use can reach it from.
  session.evaluateQuietly("(wl.spawn-player 18 50 wl.NORTH)");
  const pushed = projectedRecord(session.evaluate("(app.replay-advance 1 0 0 8)"));
  assert.deepEqual(Object.keys(pushed), canonicalProjectionFields);
  assert.equal(pushed.secretcount, 1, "the boundary reads wl.secretcount");
  assert.notEqual(pushed.plane1hash, cachedPlane1, "removing the P tile re-fingerprints the object plane");

  const held = projectedRecord(session.evaluate("(app.replay-advance 1 0 0 8)"));
  assert.equal(held.secretcount, 1, "a held use tic still reaches PushWall and pwallstate refuses it");
  assert.equal(held.plane1hash, pushed.plane1hash);

  session.evaluateQuietly("(wl.setup-game-level app.wall-plane app.object-plane)");
  assert.equal(projectedRecord(session.evaluate("(app.trace-record)")).secretcount, 0,
    "fresh level setup resets what the projection reports");
});

// PushWall and MovePWalls are the only writers of these five anywhere in the
// source outside SaveTheGame/LoadTheGame, and canonical R1 pushes no wall, so
// ownership is shown by driving a real E1M1 pushwall through the same replay
// boundary the canonical comparison uses.
test("the promoted pushwall fields report live PushWall and MovePWalls state", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const pwall = (record) => pwallPromotedFields.map((field) => record[field]);
  const resting = projectedRecord(session.evaluate("(app.trace-record)"));
  assert.deepEqual(pwall(resting), [0, 0, 0, 0, 0]);
  const startingPlane0 = resting.plane0hash;

  // (18,50) is the floor south of the object-plane PUSHABLETILE at (18,49).
  session.evaluateQuietly("(wl.spawn-player 18 50 wl.NORTH)");
  const activated = projectedRecord(session.evaluate("(app.replay-advance 1 0 0 8)"));
  assert.deepEqual(Object.keys(activated), canonicalProjectionFields);
  assert.deepEqual(pwall(activated), [1, 0, 18, 49, 0], "PushWall's own five assignments");
  assert.equal(activated.plane0hash, startingPlane0, "activation writes only the object plane");

  // `pwallstate += tics` with tics 6 from 1: the first block crossing is the
  // step that reaches 133, and 259 is the first value past 256.
  const records = [];
  for (let step = 0; step < 43; step += 1) {
    records.push(projectedRecord(session.evaluate("(app.replay-advance 6 0 0 0)")));
  }
  assert.deepEqual(pwall(records[0]), [7, 3, 18, 49, 0], "pwallpos is (pwallstate/2)&63");
  assert.deepEqual(pwall(records[20]), [127, 63, 18, 49, 0], "the last record before the crossing");
  assert.deepEqual(pwall(records[21]), [133, 2, 18, 48, 0], "the block crossed and moved one tile");
  assert.notEqual(records[21].plane0hash, startingPlane0, "the vacated tile rewrote plane 0");
  assert.deepEqual(pwall(records[41]), [253, 62, 18, 48, 0]);
  assert.deepEqual(pwall(records[42]), [0, 62, 18, 48, 0],
    "pwallstate>256 returns before the pwallpos assignment, so 62 is retained");
  // The player stands at (18,50) in area 33, and (18,48) was already area 33,
  // so the second `player->areanumber+AREATILE` write stores the value that
  // cell already held and the fingerprint is unchanged rather than stale.
  assert.equal(records[42].plane0hash, records[21].plane0hash);
  assert.equal(records[42].secretcount, 1, "one activation, one secret");
});

test("the promoted initialization fields report nonzero NewGame ownership in canonical order", async () => {
  const session = await createSeedSession();
  session.evaluateQuietly(source);
  session.evaluateQuietly("(wl.new-game 3 4)");
  session.evaluateQuietly("(wl.select-map 7)");
  session.evaluateQuietly("(wl.spawn-player 2 3 1)");
  const record = projectedRecord(session.evaluate("(app.trace-record)"));
  assert.deepEqual(Object.keys(record), fixture.fields);
  assert.deepEqual(Object.fromEntries(newlyPromotedFields.map((field) => [field, record[field]])), {
    score: 0, lives: 3, map: 7, episode: 4, bestweapon: 1,
    weapon: 1, chosenweapon: 1, state: 0, flags: 4
  });
  assert.equal(record.difficulty, 3);
});

test("canonical R1 records 1-117 match every owned v3 field through the first door", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { projected } = await replay(fixture.records);
  assertProjection(fixture.records, projected);
  assert.equal(projected[34].buttons, 8, "record 35 is the first door use");
  assert.equal(projected[34].doorchecksum, 17152, "use changes action before position");
  assert.equal(projected[98].tilex, 31, "the terminal opening record still precedes traversal");
  assert.equal(projected.at(-1).tick, 117);
  assert.equal(projected.at(-1).tilex, 34, "the prefix ends after traversing the first door");
});

test("the full 401-record route matches every currently owned projected field", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { projected } = await replay(routeFixture.records);
  assertProjection(routeFixture.records, projected, routeFixture.fullRouteFields);
  assert.equal(projected.at(-1).tick, 401);
  assert.equal(projected[347].health, 81, "record 348 includes the guard shot");
  assert.equal(projected[365].ammo, 15, "record 366 includes the retained bo_clip pickup");
});

test("three fresh evaluators produce byte-identical full-route projections", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const runs = [];
  for (let run = 0; run < 3; run += 1) {
    const { projected, rndindices } = await replay(routeFixture.records);
    assert.deepEqual(rndindices, projected.map((record) => record.rndindex),
      `fresh evaluator ${run + 1} side-read agrees with emitted cursor`);
    assert.deepEqual(projected.map((record) => record.rndindex),
      routeFixture.records.map((record) => record.rndindex),
      `fresh evaluator ${run + 1} canonical emitted cursor sequence`);
    runs.push(JSON.stringify(projected));
  }
  assert.equal(runs[1], runs[0]);
  assert.equal(runs[2], runs[0]);
});

test("full-route negative controls identify the intended first divergent field", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);

  const changedControl = structuredClone(routeFixture.records);
  changedControl[230].controlx += 1;
  const controlDifference = firstDifference(routeFixture.records, (await replay(changedControl)).projected,
    routeFixture.fullRouteFields);
  assert.deepEqual(controlDifference, {
    record: 231, tick: 231, field: "controlx", original: 100, lisp: 101
  });

  const changedUse = structuredClone(routeFixture.records);
  changedUse[126].buttons &= ~8;
  const useDifference = firstDifference(routeFixture.records, (await replay(changedUse)).projected,
    routeFixture.fullRouteFields);
  assert.deepEqual(useDifference, {
    record: 127, tick: 127, field: "buttons", original: 8, lisp: 0
  });

  const changedPlaneHash = structuredClone(routeFixture.records);
  changedPlaneHash[299].plane0hash += 1;
  const canonical = (await replay(routeFixture.records)).projected;

  const changedRndindex = structuredClone(routeFixture.records);
  changedRndindex[99].rndindex = (changedRndindex[99].rndindex + 1) & 255;
  assert.deepEqual(firstDifference(changedRndindex, canonical, routeFixture.fullRouteFields), {
    record: 100, tick: 100, field: "rndindex", original: changedRndindex[99].rndindex,
    lisp: routeFixture.records[99].rndindex
  });

  for (const field of [...newlyPromotedFields, ...totalPromotedFields, ...killcountPromotedFields,
    ...treasurecountPromotedFields, ...secretcountPromotedFields, ...pwallPromotedFields]) {
    const changed = structuredClone(routeFixture.records);
    changed[99][field] += 1;
    assert.deepEqual(firstDifference(changed, canonical, routeFixture.fullRouteFields), {
      record: 100, tick: 100, field, original: routeFixture.records[99][field] + 1,
      lisp: routeFixture.records[99][field]
    });
  }

  const changedHealth = structuredClone(routeFixture.records);
  changedHealth[347].health += 1;
  assert.deepEqual(firstDifference(changedHealth, canonical, routeFixture.fullRouteFields), {
    record: 348, tick: 348, field: "health", original: 82, lisp: 81
  });

  const changedAmmo = structuredClone(routeFixture.records);
  changedAmmo[365].ammo += 1;
  assert.deepEqual(firstDifference(changedAmmo, canonical, routeFixture.fullRouteFields), {
    record: 366, tick: 366, field: "ammo", original: 16, lisp: 15
  });

  const planeDifference = firstDifference(changedPlaneHash, canonical, routeFixture.fullRouteFields);
  assert.deepEqual(planeDifference, {
    record: 300, tick: 300, field: "plane0hash", original: 2482106124, lisp: 2482106123
  });
});
