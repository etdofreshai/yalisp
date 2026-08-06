// The Wolf3D application's Lisp source, in the order examples.ts hands it to
// the browser. It lives here rather than in one test file because more than
// one test drives the same program, and a module list that drifted between
// them would be a difference in what is under test rather than in what is
// being asked of it.
import { readFile } from "node:fs/promises";
import { basename, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const wolf3dModules = [
  "wl-def", "wl-fixed", "id-ca", "id-pm", "id-vl", "id-vh",
  "wl-main", "wl-game", "wl-agent", "wl-act2", "wl-draw", "wl-scale", "app"
];

export const wolf3dSources = await Promise.all(wolf3dModules.map((name) =>
  readFile(new URL(`../src/examples/wolf3d/${name}.lisp`, import.meta.url), "utf8")));

export const wolf3dSource = wolf3dSources.join("\n");

export function loadWolf3d(session) {
  for (const module of wolf3dSources) session.evaluateQuietly(module);
}

export const wolf3dAssetRoot = new URL("../public/assets/wolf3d/", import.meta.url);

const wolf3dAssetDeclarationUrl = new URL("../src/examples/wolf3d/assets.manifest.json", import.meta.url);
const wolf3dAssetDeclaration = JSON.parse(await readFile(wolf3dAssetDeclarationUrl, "utf8"));
const wolf3dAssetDeclarationDirectory = dirname(fileURLToPath(wolf3dAssetDeclarationUrl));
const wolf3dDeclaredFiles = new Map(wolf3dAssetDeclaration.files.map((file) => [file.name, file]));

export const wolf3dSkipReason =
  "The original Wolf3D data is unavailable from both its declared source roots and the read-only public mount.";

async function readDeclaredOriginal(name) {
  const file = wolf3dDeclaredFiles.get(name);
  if (!file) throw new Error(`Wolf3D did not declare ${name}.`);
  const roots = [];
  for (const scope of [file, wolf3dAssetDeclaration]) {
    const override = scope.sourceEnvironmentVariable ? process.env[scope.sourceEnvironmentVariable] : undefined;
    if (override) roots.push(resolve(override));
    for (const root of scope.sourceRoots ?? []) roots.push(resolve(wolf3dAssetDeclarationDirectory, root));
  }
  const sourceName = file.source ?? file.name;
  for (const root of roots) {
    try { return new Uint8Array(await readFile(resolve(root, sourceName))); } catch (error) {
      if (error?.code !== "ENOENT") throw error;
    }
  }
  return new Uint8Array(await readFile(new URL(name, wolf3dAssetRoot)));
}

export async function haveWolf3dOriginals() {
  try {
    await Promise.all(wolf3dAssetDeclaration.files.map(({ name }) => readDeclaredOriginal(name)));
    return true;
  } catch {
    return false;
  }
}

// The browser fetches these paths over HTTP. Tests resolve the same declaration
// directly first so protected commercial public assets never have to be copied
// or rewritten merely to validate a checkout; an existing read-only public
// mount remains the fallback used by standalone clones.
export const fromPublic = async (path) => readDeclaredOriginal(basename(path));
