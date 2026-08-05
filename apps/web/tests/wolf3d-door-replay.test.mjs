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
  "secrettotal", "treasuretotal", "killtotal", "killcount"
];
const newlyPromotedFields = [
  "score", "lives", "map", "episode", "bestweapon", "weapon", "chosenweapon", "state", "flags"
];
const totalPromotedFields = ["secrettotal", "treasuretotal", "killtotal"];
const killcountPromotedFields = ["killcount"];
const canonicalProjectionFields = [
  "tick", "tics", "score", "health", "ammo", "keys", "lives", "x", "y", "angle", "tilex", "tiley",
  "state", "flags", "controlx", "controly", "buttons", "difficulty", "map", "episode", "bestweapon",
  "weapon", "chosenweapon", "faceframe", "attackframe", "attackcount", "weaponframe",
  "killcount", "secrettotal", "treasuretotal", "killtotal", "doorchecksum", "plane0hash", "plane1hash"
];
const canonicalOmittedFields = [
  "secretcount", "treasurecount",
  "pwallstate", "pwallpos", "pwallx", "pwally", "pwalldir", "rndindex", "actorhash", "worldhash"
];

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

test("the Lisp-owned projection declares its exact v3 subset and exclusions", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const contract = parseLispValue(session.evaluate("(app.trace-projection-contract)"));
  assert.equal(contract[0], "projection");
  assert.equal(contract[1], "wolf3d-trace-bin-v3");
  assert.deepEqual(fixture.fields, canonicalProjectionFields);
  assert.deepEqual(routeFixture.fullRouteFields, canonicalProjectionFields);
  assert.deepEqual(contract.find((row) => Array.isArray(row) && row[0] === "fields").slice(1), fixture.fields);
  assert.equal(fixture.fields.length, 34);
  for (const field of promotedFields) assert.ok(fixture.fields.includes(field), `${field} must be projected`);
  assert.deepEqual(contract.find((row) => Array.isArray(row) && row[0] === "encoding").slice(1),
    ["plane0hash", "u32-decimal", "plane1hash", "u32-decimal"]);
  const omitted = contract.find((row) => Array.isArray(row) && row[0] === "omitted").slice(1);
  assert.deepEqual(fixture.omitted, canonicalOmittedFields);
  assert.deepEqual(omitted, fixture.omitted);
  for (const field of canonicalOmittedFields) assert.ok(!fixture.fields.includes(field));
  assert.deepEqual(routeFixture.diagnosticFields, ["rndindex"]);
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
    assert.deepEqual(rndindices, routeFixture.records.map((record) => record.rndindex),
      `fresh evaluator ${run + 1} canonical cursor sequence`);
    runs.push(JSON.stringify({ projected, rndindices }));
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

  for (const field of [...newlyPromotedFields, ...totalPromotedFields, ...killcountPromotedFields]) {
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
