// Generic build-time asset bridge.
//
// Some YALISP applications are ports, and a port's input is the original
// program's own data files. Those files are commercial redistributables, so
// they are never committed here: this script mounts them from wherever the
// machine already has them into the served asset tree, and records exactly
// what it mounted.
//
// Nothing in this script knows what any of the bytes mean. It reads a
// declaration from an application's own directory, copies the named files if
// a source root holding them can be found, and writes a manifest of lengths
// and digests. Which files, from where, and under what name is the
// application's business; this is the copying and the accounting.
//
// Usage:
//   node scripts/mount-assets.mjs              mount every declaration
//   node scripts/mount-assets.mjs wolf3d       mount one by target name
//
// A declaration may name an environment variable that overrides its source
// roots, so a machine that keeps the originals somewhere unusual does not
// need this file edited. A single file may carry its own roots and its own
// variable, because one program's inputs do not all have to come from one
// place: a port's data files ship with the game, while something the game
// kept in its executable rather than beside it is found somewhere else
// entirely. Which is which is the application's knowledge, declared per file.

import { createHash } from "node:crypto";
import { copyFile, mkdir, readdir, readFile, stat, writeFile } from "node:fs/promises";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const examplesRoot = join(webRoot, "src", "examples");
const publicAssetsRoot = join(webRoot, "public", "assets");
const declarationName = "assets.manifest.json";

async function exists(path) {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}

async function declarations() {
  const entries = await readdir(examplesRoot, { withFileTypes: true });
  const found = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const path = join(examplesRoot, entry.name, declarationName);
    if (await exists(path)) found.push({ example: entry.name, path, declaration: JSON.parse(await readFile(path, "utf8")) });
  }
  return found;
}

// The roots a single file may be found under: its own first, then the ones the
// declaration gives every file, each with its environment override ahead of
// the paths written down. Order is preference, and the first root actually
// holding the file wins.
function rootsFor(declaration, file, declarationPath) {
  const roots = [];
  for (const scope of [file, declaration]) {
    const override = scope.sourceEnvironmentVariable ? process.env[scope.sourceEnvironmentVariable] : undefined;
    if (override) roots.push(resolve(override));
    for (const root of scope.sourceRoots ?? []) roots.push(resolve(dirname(declarationPath), root));
  }
  return roots;
}

// Each file is located on its own. An earlier version required one root to
// hold every declared file, to keep a half-mounted tree from failing later at
// a point far from the reason - but that reasoning belongs to the program, not
// here: the evaluator's asset mount already reports each retrieval separately,
// and a program that declares an optional input has to be able to see that it
// is the one that is missing. So what this refuses to do is guess; what it
// reports is exactly which files it found and where it looked for the rest.
async function locate(declaration, file, declarationPath) {
  const roots = rootsFor(declaration, file, declarationPath);
  const name = file.source ?? file.name;
  for (const root of roots) if (await exists(join(root, name))) return { root, roots };
  return { root: undefined, roots };
}

async function mount({ example, path, declaration }) {
  const target = declaration.target ?? example;
  const found = [];
  const absent = [];
  for (const file of declaration.files) {
    const { root, roots } = await locate(declaration, file, path);
    if (root) found.push({ file, root });
    else absent.push({ name: file.source ?? file.name, searched: roots.map((candidate) => relative(webRoot, candidate)) });
  }
  if (!found.length) {
    return {
      target,
      mounted: false,
      reason: `None of the ${declaration.files.length} declared files were found.`,
      absent
    };
  }
  const destination = join(publicAssetsRoot, target);
  await mkdir(destination, { recursive: true });
  const files = [];
  for (const { file, root } of found) {
    const source = join(root, file.source ?? file.name);
    const bytes = await readFile(source);
    await copyFile(source, join(destination, file.name));
    files.push({ name: file.name, bytes: bytes.length, sha256: createHash("sha256").update(bytes).digest("hex"), source: root });
  }
  const manifest = {
    kind: "yalisp-mounted-assets-v1",
    target,
    note: declaration.note,
    files,
    absent: absent.map(({ name }) => name)
  };
  await writeFile(join(destination, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
  return { target, mounted: true, destination: relative(webRoot, destination), files, absent };
}

const requested = process.argv.slice(2);
const all = await declarations();
const selected = requested.length ? all.filter(({ example, declaration }) => requested.includes(declaration.target ?? example)) : all;
if (requested.length && selected.length !== requested.length) {
  const known = all.map(({ example, declaration }) => declaration.target ?? example);
  throw new Error(`No asset declaration for ${requested.filter((name) => !known.includes(name)).join(", ")}. Known: ${known.join(", ") || "none"}.`);
}

const results = [];
for (const declaration of selected) results.push(await mount(declaration));
for (const result of results) {
  if (result.mounted) {
    const total = result.files.reduce((sum, file) => sum + file.bytes, 0);
    console.log(`mounted ${result.target}: ${result.files.length} files, ${total} bytes -> ${result.destination}`);
    for (const file of result.files) console.log(`  ${file.name}  ${file.bytes} bytes  sha256:${file.sha256.slice(0, 16)}…`);
  } else {
    // Not an error. Most checkouts will not have the originals, and everything
    // that does not need them still has to build.
    console.log(`skipped ${result.target}: ${result.reason}`);
  }
  // Said the same way whether or not anything was mounted, because a file that
  // was not found is the same fact either way and the program is the thing
  // that decides whether it can do without it.
  for (const file of result.absent ?? []) {
    console.log(`  absent ${file.name}`);
    for (const path of file.searched) console.log(`    looked in ${path}`);
  }
}
