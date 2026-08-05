// Remove mounted originals from the build output.
//
// scripts/mount-assets.mjs puts original data files under public/assets/ so
// that a dev server hands them back at the paths an application declares.
// Vite copies public/ into dist/ wholesale, and publishing dist/ would be
// redistributing files that belong to their publisher, so this takes them
// back out after the build.
//
// It knows no application and no file name: it removes exactly the targets
// that carry the bridge's own manifest, so anything mounted in future is
// covered without this file changing. A deployment that is entitled to serve
// the data mounts it at the target the way a developer mounts it here.

import { readdir, readFile, rm, stat } from "node:fs/promises";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const mountedRoot = join(webRoot, "public", "assets");
const outputRoot = join(webRoot, "dist", "assets");

async function mountedTargets() {
  let entries;
  try {
    entries = await readdir(mountedRoot, { withFileTypes: true });
  } catch {
    return [];
  }
  const targets = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    try {
      const manifest = JSON.parse(await readFile(join(mountedRoot, entry.name, "manifest.json"), "utf8"));
      if (manifest.kind === "yalisp-mounted-assets-v1") targets.push(entry.name);
    } catch {
      // A directory under public/assets/ that the bridge did not write is not
      // ours to remove.
    }
  }
  return targets;
}

const targets = await mountedTargets();
for (const target of targets) {
  const path = join(outputRoot, target);
  try {
    await stat(path);
  } catch {
    continue;
  }
  await rm(path, { recursive: true, force: true });
  console.log(`pruned ${relative(webRoot, path)}: mounted originals are not ours to redistribute`);
}
if (!targets.length) console.log("no mounted originals to prune");
