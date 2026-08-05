import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import test from "node:test";

const runnable = new URL("../src/examples/wolf3d/", import.meta.url);
const mirror = new URL("../../../../wolf3d-typescript-monorepo-continuation/apps/wolf3d-yalisp/", import.meta.url);

async function mirroredFiles(root) {
  const entries = await readdir(root, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile() && !entry.name.startsWith("._"))
    .map((entry) => entry.name)
    .sort();
}

test("the primary and runnable Wolf3D package directories are byte-identical", async () => {
  const runnableFiles = await mirroredFiles(runnable);
  const mirrorFiles = await mirroredFiles(mirror);
  assert.deepEqual(mirrorFiles, runnableFiles, "both repositories must contain the same non-AppleDouble file set");

  for (const name of runnableFiles) {
    const [expected, actual] = await Promise.all([
      readFile(new URL(name, runnable)),
      readFile(new URL(name, mirror))
    ]);
    assert.deepEqual(actual, expected, `${name} differs between the two repositories`);
  }
});
