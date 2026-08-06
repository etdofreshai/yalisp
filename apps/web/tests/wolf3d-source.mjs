// The Wolf3D application's Lisp source, in the order examples.ts hands it to
// the browser. It lives here rather than in one test file because more than
// one test drives the same program, and a module list that drifted between
// them would be a difference in what is under test rather than in what is
// being asked of it.
import { readFile } from "node:fs/promises";

export const wolf3dModules = [
  "wl-def", "wl-fixed", "id-ca", "id-pm", "id-vl",
  "wl-main", "wl-game", "wl-agent", "wl-act2", "wl-draw", "app"
];

export const wolf3dSources = await Promise.all(wolf3dModules.map((name) =>
  readFile(new URL(`../src/examples/wolf3d/${name}.lisp`, import.meta.url), "utf8")));

export const wolf3dSource = wolf3dSources.join("\n");

export function loadWolf3d(session) {
  for (const module of wolf3dSources) session.evaluateQuietly(module);
}

export const wolf3dAssetRoot = new URL("../public/assets/wolf3d/", import.meta.url);

export const wolf3dSkipReason =
  "The original Wolf3D data is not mounted. Run `node scripts/mount-assets.mjs` with a Steam installation available.";

export async function haveWolf3dOriginals() {
  try {
    await readFile(new URL("manifest.json", wolf3dAssetRoot), "utf8");
    return true;
  } catch {
    return false;
  }
}

// The browser fetches these paths over HTTP; here the same declared paths are
// served out of public/, which is what the dev server does with them anyway.
export const fromPublic = async (path) =>
  new Uint8Array(await readFile(new URL(`../public${path}`, import.meta.url)));
