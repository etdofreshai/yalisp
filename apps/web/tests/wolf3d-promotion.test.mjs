import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { wolf3dModules } from "./wolf3d-source.mjs";

const applicationRoot = new URL("../src/examples/wolf3d/", import.meta.url);
const promotion = JSON.parse(await readFile(new URL("./fixtures/wolf3d-promotion.manifest.json", import.meta.url), "utf8"));
const assets = JSON.parse(await readFile(new URL("assets.manifest.json", applicationRoot), "utf8"));
const examplePage = await readFile(new URL("../examples/wolf3d/index.html", import.meta.url), "utf8");
const digest = (bytes) => createHash("sha256").update(bytes).digest("hex");

test("the runnable Wolf3D package matches the exact promoted source manifest", async () => {
  assert.equal(promotion.kind, "wolf3d-yalisp-source-promotion-v1");
  assert.deepEqual(wolf3dModules, promotion.modules.map(({ name }) => name));
  const sourceManifest = [];
  for (const { name, bytes, sha256 } of promotion.modules) {
    const source = await readFile(new URL(`${name}.lisp`, applicationRoot));
    assert.equal(source.length, bytes, `${name} bytes`);
    assert.equal(digest(source), sha256, name);
    sourceManifest.push({ path: `apps/wolf3d-yalisp/${name}.lisp`, bytes, sha256 });
  }
  sourceManifest.sort((left, right) => left.path.localeCompare(right.path));
  assert.equal(digest(Buffer.from(JSON.stringify(sourceManifest))), promotion.sourceManifestSha256);
  assert.equal(digest(await readFile(new URL("yalisp-opl-audio-host.mjs", applicationRoot))), promotion.oplHostSha256);
  assert.equal(
    digest(await readFile(new URL("yalisp-r0-normalized-audio-host.mjs", applicationRoot))),
    promotion.normalizedAudioHostSha256,
  );
  assert.equal(
    digest(await readFile(new URL("yalisp-canonical-normalized-audio-host.mjs", applicationRoot))),
    promotion.canonicalNormalizedAudioHostSha256,
  );
});

test("the runnable Wolf3D package requires all nine original asset inputs", () => {
  assert.deepEqual(assets.files.map(({ name }) => name), promotion.requiredAssets);
  assert.equal(new Set(assets.files.map(({ name }) => name)).size, 9);
});

test("the public Wolf3D example describes the promoted 23-module package", () => {
  assert.match(examplePage, /Twenty-three source-shaped Lisp modules/);
  assert.match(examplePage, />23 YALISP modules</);
  assert.match(examplePage, /executed 23-module package/);
  assert.doesNotMatch(examplePage, /Twenty-two|22 YALISP modules|executed 22-module package/);
});
