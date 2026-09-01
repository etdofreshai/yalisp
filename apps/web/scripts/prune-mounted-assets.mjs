// Fail-closed distribution boundary for locally mounted application assets.
// Source-controlled declarations identify every protected filename and target;
// the ignored runtime manifest proves that any local public mount was produced
// by mount-assets.mjs. Declared targets are always removed from dist first.

import { createHash } from "node:crypto";
import { readdir, readFile, rm, stat } from "node:fs/promises";
import { basename, dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const defaultWebRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

async function exists(path) {
  try { await stat(path); return true; } catch { return false; }
}

function safeName(value, label) {
  if (typeof value !== "string" || !value || basename(value) !== value || value === "." || value === "..") {
    throw new Error(`${label} must be one safe path segment.`);
  }
  return value;
}

async function declaredApplications(examplesRoot) {
  const entries = await readdir(examplesRoot, { withFileTypes: true });
  const declarations = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const path = join(examplesRoot, entry.name, "assets.manifest.json");
    if (!await exists(path)) continue;
    let declaration;
    try { declaration = JSON.parse(await readFile(path, "utf8")); }
    catch (error) { throw new Error(`Invalid asset declaration ${relative(examplesRoot, path)}: ${error.message}`); }
    const target = safeName(declaration.target ?? entry.name, "asset target");
    if (!Array.isArray(declaration.files) || !declaration.files.length) {
      throw new Error(`Asset declaration ${relative(examplesRoot, path)} has no files.`);
    }
    const files = declaration.files.map((file) => safeName(file?.name, `asset filename for ${target}`));
    if (new Set(files).size !== files.length) throw new Error(`Asset declaration ${target} repeats a filename.`);
    declarations.push({ target, files });
  }
  return declarations;
}

async function validatePublicMount(publicTarget, declaration) {
  const present = [];
  for (const name of declaration.files) if (await exists(join(publicTarget, name))) present.push(name);
  if (!present.length) return;

  let manifest;
  try { manifest = JSON.parse(await readFile(join(publicTarget, "manifest.json"), "utf8")); }
  catch (error) { throw new Error(`Protected ${declaration.target} assets exist without a readable mount manifest: ${error.message}`); }
  if (manifest.kind !== "yalisp-mounted-assets-v1" || manifest.target !== declaration.target || !Array.isArray(manifest.files)) {
    throw new Error(`Protected ${declaration.target} assets have an invalid mount manifest.`);
  }
  const rows = new Map(manifest.files.map((file) => [file?.name, file]));
  if (rows.size !== manifest.files.length || rows.size !== present.length || present.some((name) => !rows.has(name))) {
    throw new Error(`Protected ${declaration.target} assets do not match their mount manifest file set.`);
  }
  for (const name of present) {
    const bytes = await readFile(join(publicTarget, name));
    const row = rows.get(name);
    const sha256 = createHash("sha256").update(bytes).digest("hex");
    if (row.bytes !== bytes.length || row.sha256 !== sha256) {
      throw new Error(`Protected ${declaration.target}/${name} does not match its mount manifest digest.`);
    }
  }
}

async function findProtectedFiles(root, names) {
  if (!await exists(root)) return [];
  const leaks = [];
  for (const entry of await readdir(root, { withFileTypes: true })) {
    const path = join(root, entry.name);
    if (entry.isDirectory()) leaks.push(...await findProtectedFiles(path, names));
    else if (names.has(entry.name)) leaks.push(path);
  }
  return leaks;
}

async function pruneAppleDoubleFiles(root, webRoot) {
  if (!await exists(root)) return [];
  const removed = [];
  for (const entry of await readdir(root, { withFileTypes: true })) {
    const path = join(root, entry.name);
    if (entry.name.startsWith("._")) {
      await rm(path, { recursive: true, force: true });
      removed.push(relative(webRoot, path));
    } else if (entry.isDirectory()) {
      removed.push(...await pruneAppleDoubleFiles(path, webRoot));
    }
  }
  return removed;
}

export async function pruneMountedAssets({
  webRoot = defaultWebRoot,
  examplesRoot = join(webRoot, "src", "examples"),
  publicAssetsRoot = join(webRoot, "public", "assets"),
  outputRoot = join(webRoot, "dist", "assets"),
} = {}) {
  const distributionRoot = dirname(outputRoot);
  const declarations = await declaredApplications(examplesRoot);
  const validationErrors = [];
  for (const declaration of declarations) {
    const outputTarget = join(outputRoot, declaration.target);
    if (await exists(outputTarget)) {
      await rm(outputTarget, { recursive: true, force: true });
      console.log(`pruned ${relative(webRoot, outputTarget)}: declared originals are not ours to redistribute`);
    }
    try { await validatePublicMount(join(publicAssetsRoot, declaration.target), declaration); }
    catch (error) { validationErrors.push(error); }
  }

  const appleDoubleFilesPruned = await pruneAppleDoubleFiles(distributionRoot, webRoot);
  const protectedNames = new Set(declarations.flatMap(({ files }) => files));
  const leaks = await findProtectedFiles(distributionRoot, protectedNames);
  if (leaks.length) throw new Error(`Protected application assets remain in build output: ${leaks.map((path) => relative(webRoot, path)).join(", ")}`);
  if (validationErrors.length) throw new AggregateError(validationErrors, "Local protected-asset mount validation failed after build output was pruned.");
  if (!declarations.length) console.log("no declared application assets to prune");
  return { targets: declarations.map(({ target }) => target), protectedFiles: [...protectedNames], appleDoubleFilesPruned };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await pruneMountedAssets();
}
