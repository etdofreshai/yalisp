import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const html = await readFile(new URL("../index.html", import.meta.url), "utf8");
const source = await readFile(new URL("../src/main.ts", import.meta.url), "utf8");

test("landing page exposes its essential semantic and social contracts", () => {
  for (const marker of [
    'id="main"',
    'id="why"',
    'id="language"',
    "https://github.com/etdofreshai/yalisp",
    'data-features',
    'data-code',
    'data-principles'
  ]) {
    assert.ok(html.includes(marker), `missing ${marker}`);
  }
});

test("interactive controls have TypeScript behavior", () => {
  assert.ok(source.includes('navigator.clipboard.writeText'));
  assert.ok(source.includes('IntersectionObserver'));
  assert.ok(source.includes('aria-expanded'));
});

test("documentation navigation is shared and remembers its collapsed state", async () => {
  const docsBehavior = await readFile(new URL("../src/docs.ts", import.meta.url), "utf8");
  const overview = await readFile(new URL("../docs/index.html", import.meta.url), "utf8");
  for (const marker of [
    "yalisp-sidebar-collapsed",
    "sidebar-collapsed",
    'href="/docs/foundation/"',
    'href="/docs/sdl/"'
  ]) {
    assert.ok(docsBehavior.includes(marker) || overview.includes(marker), `missing ${marker}`);
  }
});

test("documentation resolves its theme before first paint", async () => {
  const themeBootstrap = await readFile(new URL("../public/theme-init.js", import.meta.url), "utf8");
  const docsBehavior = await readFile(new URL("../src/docs.ts", import.meta.url), "utf8");
  const pages = ["", "applications/", "assembly/", "bootstrap/", "compiler/", "foundation/", "host/", "sdl/", "seed/", "system-interface/"];

  assert.ok(themeBootstrap.includes("prefers-color-scheme: light"));
  assert.ok(themeBootstrap.includes('localStorage.getItem("yalisp-theme")'));
  assert.ok(docsBehavior.includes("document.documentElement.dataset.theme"));
  assert.ok(docsBehavior.includes("setTheme(document.documentElement.dataset.theme"));

  for (const page of pages) {
    const document = await readFile(new URL(`../docs/${page}index.html`, import.meta.url), "utf8");
    const bootstrap = document.indexOf("data-theme-bootstrap");
    const initializer = document.indexOf('src="/theme-init.js"');
    const body = document.indexOf("<body>");
    assert.ok(bootstrap !== -1 && bootstrap < body, `theme canvas is not initialized in ${page || "docs/"}`);
    assert.ok(initializer !== -1 && initializer < body, `theme preference is not initialized in ${page || "docs/"}`);
  }
});

test("documentation presents the four reference interfaces", async () => {
  const docs = await readFile(new URL("../docs/index.html", import.meta.url), "utf8");
  for (const marker of [
    'id="reference-interfaces"',
    'id="assembly"',
    'id="system-interface"',
    'id="host"',
    'id="sdl"'
  ]) {
    assert.ok(docs.includes(marker), `missing ${marker}`);
  }
});

test("assembly documentation exposes its primary instruction groups", async () => {
  const docs = await readFile(new URL("../docs/index.html", import.meta.url), "utf8");
  for (const marker of [
    "assembly.i32.add",
    "assembly.memory.grow",
    "assembly.v128.load",
    "assembly.func"
  ]) {
    assert.ok(docs.includes(marker), `missing ${marker}`);
  }
});

test("assembly documentation uses the bundled inventory", async () => {
  const page = await readFile(new URL("../docs/assembly/index.html", import.meta.url), "utf8");
  const behavior = await readFile(new URL("../src/docs.ts", import.meta.url), "utf8");
  const inventory = await readFile(new URL("../src/assembly-inventory.ts", import.meta.url), "utf8");

  assert.ok(page.includes("data-assembly-inventory"));
  assert.ok(behavior.includes('from "./assembly-inventory"'));
  assert.ok(inventory.includes("assembly.i32.add"));
  assert.ok(!page.includes("raw.githubusercontent.com"));
});

test("documentation explains the bootstrapped core REPL", async () => {
  const docs = await readFile(new URL("../docs/index.html", import.meta.url), "utf8");
  assert.ok(docs.includes('id="core-repl"'));
  assert.match(docs, /bootstrapped compiler/i);
});

test("each reference interface has a dedicated page", async () => {
  for (const page of ["assembly", "system-interface", "host", "sdl"]) {
    const document = await readFile(new URL(`../docs/${page}/index.html`, import.meta.url), "utf8");
    assert.match(document, /normative YALisp/i);
  }
});

test("foundation documentation explains the bootstrapping path", async () => {
  const foundation = await readFile(new URL("../docs/foundation/index.html", import.meta.url), "utf8");
  for (const marker of ["Seed", "Bootstrap", "Compiler", "Applications"]) {
    assert.ok(foundation.includes(marker), `missing ${marker}`);
  }
});

test("applications documentation uses the shared documentation shell", async () => {
  const applications = await readFile(new URL("../docs/applications/index.html", import.meta.url), "utf8");
  for (const marker of [
    'class="docs-header"',
    "data-docs-shell",
    'class="docs-nav"',
    'src="/src/docs.ts"'
  ]) {
    assert.ok(applications.includes(marker), `missing ${marker}`);
  }
});

test("SDL documentation separates 2D rendering from the 3D GPU profile", async () => {
  const sdl = await readFile(new URL("../docs/sdl/index.html", import.meta.url), "utf8");
  for (const marker of [
    'id="video-render"',
    "02 / 2D graphics",
    'id="gpu-3d"',
    "05 / 3D and GPU",
    "sdl.gpu.render",
    "graphics-pipeline.create",
    "render-pass.begin",
    "draw-indexed",
    "sdl.gpu.compute",
    "compute-pass.begin"
  ]) {
    assert.ok(sdl.includes(marker), `missing ${marker}`);
  }
});
