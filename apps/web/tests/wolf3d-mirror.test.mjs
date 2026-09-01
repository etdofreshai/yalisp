import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import { promisify } from "node:util";
import test from "node:test";

const runnable = new URL("../src/examples/wolf3d/", import.meta.url);
const mirror = new URL("../../../../wolf3d-typescript-monorepo-continuation/apps/wolf3d-yalisp/", import.meta.url);
const sourceRepository = new URL("../../", mirror);
const promotion = JSON.parse(await readFile(
  new URL("./fixtures/wolf3d-promotion.manifest.json", import.meta.url),
  "utf8",
));
const run = promisify(execFile);

async function sourceHasBlob(object) {
  try {
    await run("git", ["cat-file", "-e", `${object}^{blob}`], { cwd: sourceRepository });
    return true;
  } catch {
    return false;
  }
}

async function mirroredFiles(root) {
  const entries = await readdir(root, { withFileTypes: true });
  return entries
    // The external README owns browser/deployment guidance. Executable source,
    // contracts, declarations, and adapters remain exact promoted payload.
    .filter((entry) => entry.isFile() && !entry.name.startsWith("._") && entry.name !== "README.md")
    .map((entry) => entry.name)
    .sort();
}

test("every Wolf3D payload has exact or explicitly derived source provenance", async () => {
  const runnableFiles = await mirroredFiles(runnable);
  for (const name of runnableFiles) {
    const payload = await readFile(new URL(name, runnable));
    const object = createHash("sha1")
      .update(`blob ${payload.length}\0`)
      .update(payload)
      .digest("hex");
    assert.match(object, /^[0-9a-f]{40}$/, `${name} Git object id`);
    if (await sourceHasBlob(object)) continue;
    const module = name.endsWith(".lisp")
      ? promotion.modules.find(({ name: moduleName }) => `${moduleName}.lisp` === name)
      : undefined;
    assert.match(module?.sourceBlobSha1 ?? "", /^[0-9a-f]{40}$/,
      `${name} local hardening requires an explicit source predecessor`);
    assert.equal(await sourceHasBlob(module.sourceBlobSha1), true,
      `${name} declared source predecessor must remain in source history`);
  }
});
