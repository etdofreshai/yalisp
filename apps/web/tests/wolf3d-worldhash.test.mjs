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
  wolf3dSource as source,
} from "./wolf3d-source.mjs";

const route = JSON.parse(await readFile(
  new URL("./fixtures/wolf3d-r1-route-v3.json", import.meta.url), "utf8"));
const projectedRecord = (text) => Object.fromEntries(
  parseLispValue(text).map(([name, value]) => [String(name), Number(value)]));

async function application() {
  const session = await createSeedSession();
  session.evaluateQuietly(source);
  await mountDeclaredAssets(session, fromPublic);
  return session;
}

test("worldhash is live Lisp state, canonical at the boundary, and operand-sensitive", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const input = route.records[0];
  const emitted = projectedRecord(session.evaluate(
    `(app.replay-advance ${input.tics} ${input.controlx} ${input.controly} ${input.buttons})`));
  assert.equal(emitted.worldhash, 4227316331);
  assert.equal(Number(session.evaluate("(wl.world-hash-decimal)")), emitted.worldhash,
    "a fresh live side read agrees with the emitted field");

  assert.equal(Number(session.evaluate("(wl.static-shapenum@ 0)")), 14);
  session.evaluateQuietly("(wl.static-shapenum! 0 15)");
  assert.equal(Number(session.evaluate("(wl.world-hash-decimal)")), 560732458,
    "changing one live static operand changes the source-order fingerprint");
  session.evaluateQuietly("(wl.static-shapenum! 0 14)");
  assert.equal(Number(session.evaluate("(wl.world-hash-decimal)")), emitted.worldhash);
});

test("worldhash is promoted while actorhash stays explicitly excluded", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const session = await application();
  const contract = parseLispValue(session.evaluate("(app.trace-projection-contract)"));
  const fields = contract.find((row) => Array.isArray(row) && row[0] === "fields").slice(1);
  const omitted = contract.find((row) => Array.isArray(row) && row[0] === "omitted").slice(1);
  assert.equal(fields.length, 43);
  assert.equal(fields.at(-1), "worldhash");
  assert.deepEqual(omitted, ["actorhash"]);
  assert.ok(!fields.includes("actorhash"));
});
