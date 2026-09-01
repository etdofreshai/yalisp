import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { access, mkdir, mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { mountAssetDeclaration } from "../scripts/mount-assets.mjs";
import { pruneMountedAssets } from "../scripts/prune-mounted-assets.mjs";

const missing = async (path) => assert.rejects(access(path), { code: "ENOENT" });
const json = async (path, value) => {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, `${JSON.stringify(value)}\n`);
};

test("partial and empty remounts replace the target exactly without deleting AppleDouble metadata", async () => {
  const root = await mkdtemp(join(tmpdir(), "yalisp-mount-"));
  const declarationPath = join(root, "declaration", "assets.manifest.json");
  const source = join(root, "declaration", "source");
  const destination = join(root, "public", "assets", "wolf3d");
  await mkdir(source, { recursive: true });
  await mkdir(destination, { recursive: true });
  await writeFile(join(source, "A.WL6"), "current-a");
  await writeFile(join(destination, "B.WL6"), "stale-b");
  await writeFile(join(destination, "._keep"), "metadata");
  const declaration = {
    target: "wolf3d",
    sourceRoots: ["source"],
    files: [{ name: "A.WL6" }, { name: "B.WL6" }],
  };

  const partial = await mountAssetDeclaration({ example: "wolf3d", path: declarationPath, declaration }, {
    root,
    assetsRoot: join(root, "public", "assets"),
  });
  assert.equal(partial.mounted, true);
  assert.equal(await readFile(join(destination, "A.WL6"), "utf8"), "current-a");
  assert.equal(await readFile(join(destination, "._keep"), "utf8"), "metadata");
  await missing(join(destination, "B.WL6"));
  assert.deepEqual(JSON.parse(await readFile(join(destination, "manifest.json"), "utf8")).absent, ["B.WL6"]);

  declaration.sourceRoots = ["missing-source"];
  const empty = await mountAssetDeclaration({ example: "wolf3d", path: declarationPath, declaration }, {
    root,
    assetsRoot: join(root, "public", "assets"),
  });
  assert.equal(empty.mounted, false);
  await missing(join(destination, "A.WL6"));
  await missing(join(destination, "manifest.json"));
  assert.equal(await readFile(join(destination, "._keep"), "utf8"), "metadata");
});

async function pruningFixture(manifest) {
  const webRoot = await mkdtemp(join(tmpdir(), "yalisp-prune-"));
  const examplesRoot = join(webRoot, "src", "examples");
  const publicAssetsRoot = join(webRoot, "public", "assets");
  const outputRoot = join(webRoot, "dist", "assets");
  const declaration = { target: "wolf3d", files: [{ name: "A.WL6" }] };
  await json(join(examplesRoot, "wolf3d", "assets.manifest.json"), declaration);
  await mkdir(join(publicAssetsRoot, "wolf3d"), { recursive: true });
  await writeFile(join(publicAssetsRoot, "wolf3d", "A.WL6"), "commercial");
  if (manifest !== undefined) await writeFile(join(publicAssetsRoot, "wolf3d", "manifest.json"), manifest);
  await mkdir(join(outputRoot, "wolf3d"), { recursive: true });
  await writeFile(join(outputRoot, "wolf3d", "A.WL6"), "commercial");
  return { webRoot, examplesRoot, publicAssetsRoot, outputRoot };
}

test("pruning removes declared output before failing closed on missing, malformed, or wrong-kind mount manifests", async () => {
  for (const manifest of [undefined, "{", JSON.stringify({ kind: "wrong", target: "wolf3d", files: [] })]) {
    const fixture = await pruningFixture(manifest);
    await assert.rejects(pruneMountedAssets(fixture), /mount manifest|mount validation/);
    await missing(join(fixture.outputRoot, "wolf3d"));
  }
});

test("a valid local mount is pruned and a clean no-assets build remains valid", async () => {
  const bytes = Buffer.from("commercial");
  const manifest = JSON.stringify({
    kind: "yalisp-mounted-assets-v1",
    target: "wolf3d",
    files: [{ name: "A.WL6", bytes: bytes.length, sha256: createHash("sha256").update(bytes).digest("hex") }],
  });
  const mounted = await pruningFixture(manifest);
  await mkdir(join(mounted.webRoot, "dist", "nested", "metadata"), { recursive: true });
  await writeFile(join(mounted.webRoot, "dist", "._root"), "metadata");
  await writeFile(join(mounted.webRoot, "dist", "nested", "metadata", "._deep"), "metadata");
  const result = await pruneMountedAssets(mounted);
  assert.deepEqual(result.targets, ["wolf3d"]);
  assert.deepEqual(result.appleDoubleFilesPruned.sort(), ["dist/._root", "dist/nested/metadata/._deep"]);
  await missing(join(mounted.outputRoot, "wolf3d"));
  await missing(join(mounted.webRoot, "dist", "._root"));
  await missing(join(mounted.webRoot, "dist", "nested", "metadata", "._deep"));

  const cleanRoot = await mkdtemp(join(tmpdir(), "yalisp-prune-clean-"));
  await json(join(cleanRoot, "src", "examples", "wolf3d", "assets.manifest.json"), {
    target: "wolf3d", files: [{ name: "A.WL6" }],
  });
  assert.deepEqual((await pruneMountedAssets({ webRoot: cleanRoot })).targets, ["wolf3d"]);
});

test("Docker context excludes the local Wolf3D commercial mount", async () => {
  const repositoryRoot = fileURLToPath(new URL("../../../", import.meta.url));
  const ignore = await readFile(join(repositoryRoot, ".dockerignore"), "utf8");
  assert.match(ignore, /^apps\/web\/public\/assets\/wolf3d$/m);
  assert.match(ignore, /^\*\*\/\.\_\*$/m);
});

test("protected basenames fail closed anywhere in the distribution tree", async () => {
  const webRoot = await mkdtemp(join(tmpdir(), "yalisp-prune-leak-"));
  await json(join(webRoot, "src", "examples", "wolf3d", "assets.manifest.json"), {
    target: "wolf3d", files: [{ name: "A.WL6" }],
  });
  await mkdir(join(webRoot, "dist", "scripts", "nested"), { recursive: true });
  await writeFile(join(webRoot, "dist", "scripts", "nested", "A.WL6"), "commercial");
  await assert.rejects(pruneMountedAssets({ webRoot }), /Protected application assets remain.*scripts\/nested\/A\.WL6/);
});
