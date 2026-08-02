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
    'href="/playground/"',
    'class="nav-playground"',
    'class="rail-status"',
    'data-theme-bootstrap',
    'src="/theme-init.js"',
    "https://github.com/etdofreshai/yalisp",
    'data-features',
    'data-code',
    'data-principles'
  ]) {
    assert.ok(html.includes(marker), `missing ${marker}`);
  }
});

test("production container builds once and serves with Vite on its declared and checked port", async () => {
  const dockerfile = await readFile(new URL("../../../Dockerfile", import.meta.url), "utf8");
  assert.match(dockerfile, /FROM node:24-alpine/);
  assert.match(dockerfile, /RUN npm run build/);
  assert.match(dockerfile, /EXPOSE 5173/);
  assert.match(dockerfile, /127\.0\.0\.1:5173/);
  assert.match(dockerfile, /"preview"/);
  assert.doesNotMatch(dockerfile, /"dev"/);
  assert.doesNotMatch(dockerfile, /nginx/i);
  assert.doesNotMatch(dockerfile, /EXPOSE 80/);
});

test("interactive controls have TypeScript behavior", () => {
  assert.ok(source.includes('navigator.clipboard.writeText'));
  assert.ok(source.includes('IntersectionObserver'));
  assert.ok(source.includes('aria-expanded'));
  assert.ok(source.includes('document.documentElement.dataset.theme'));
});

test("landing shell provides a persistent desktop rail and responsive mobile navigation", async () => {
  const styles = await readFile(new URL("../src/styles.css", import.meta.url), "utf8");
  assert.match(styles, /--rail-width:/);
  assert.match(styles, /\.site-header\s*\{[\s\S]*position: fixed/);
  assert.match(styles, /main,\s*\nfooter\s*\{\s*margin-left: var\(--rail-width\)/);
  assert.match(styles, /@media \(max-width: 900px\)[\s\S]*main,\s*\n\s*footer \{ margin-left: 0; \}/);
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
  const pages = ["", "applications/", "assembly/", "bootstrap/", "compiler/", "dom/", "foundation/", "host/", "sdl/", "seed/", "system-interface/"];

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

test("documentation presents the four interfaces and planned game runtime", async () => {
  const docs = await readFile(new URL("../docs/index.html", import.meta.url), "utf8");
  for (const marker of [
    'id="reference-interfaces"',
    'id="assembly"',
    'id="system-interface"',
    'id="dom"',
    'id="sdl"',
    'id="game-runtime"',
    "simulation update",
    "render update",
    "competing third update loop"
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

test("documentation explains the executable interpreter and Lisp bootstrap", async () => {
  const docs = await readFile(new URL("../docs/index.html", import.meta.url), "utf8");
  assert.ok(docs.includes('id="core-repl"'));
  assert.match(docs, /WAT interpreter extended by <code>boot\.lisp<\/code>/i);
  assert.match(docs, /Compiler, JIT, and AOT stages remain future verified milestones/i);
});

test("language guide distinguishes evidenced syntax from planned features", async () => {
  const docs = await readFile(new URL("../docs/index.html", import.meta.url), "utf8");
  const siteBehavior = await readFile(new URL("../src/main.ts", import.meta.url), "utf8");

  for (const marker of ["(define factorial", "(lambda (n)", "(factorial 6)"]) {
    assert.ok(siteBehavior.includes(marker), `site source is missing ${marker}`);
    assert.ok(docs.includes(marker), `language guide is missing ${marker}`);
  }
  assert.match(docs, /Module syntax is not implemented/);
  assert.match(docs, /conceptual pipeline, not executable YALisp/);
  assert.match(docs, /no callable <code>compile<\/code>, <code>apply<\/code>, or <code>eval<\/code> form is implemented/);
});

test("each interface has a dedicated page", async () => {
  for (const page of ["assembly", "system-interface", "dom", "sdl"]) {
    const document = await readFile(new URL(`../docs/${page}/index.html`, import.meta.url), "utf8");
    assert.match(document, /normative YALisp/i);
  }
});

test("DOM documentation defines planned adapters and a provisional application root", async () => {
  const page = await readFile(new URL("../docs/dom/index.html", import.meta.url), "utf8");
  const legacy = await readFile(new URL("../docs/host/index.html", import.meta.url), "utf8");

  for (const marker of [
    'id="dom"',
    "native browser DOM",
    "lightweight in-memory document tree",
    "dom.application-root.create",
    "Illustrative name only",
    "To be defined later",
    "no DOM runtime binding is implemented"
  ]) {
    assert.ok(page.includes(marker), `missing ${marker}`);
  }
  assert.ok(!page.includes("host.documents"));
  assert.ok(legacy.includes('location.replace("/docs/dom/")'));
  assert.ok(legacy.includes('rel="canonical" href="https://yalisp.etdofresh.com/docs/dom/"'));
});

test("foundation documentation explains the bootstrapping path", async () => {
  const overview = await readFile(new URL("../docs/index.html", import.meta.url), "utf8");
  const foundation = await readFile(new URL("../docs/foundation/index.html", import.meta.url), "utf8");
  for (const marker of ["Seed", "Bootstrap", "Compiler", "Applications"]) {
    assert.ok(foundation.includes(marker), `missing ${marker}`);
  }
  for (const marker of [
    'aria-label="Foundation overview"',
    '<span>01</span><strong>Seed</strong>',
    '<span>02</span><strong>Bootstrap</strong>',
    '<span>03</span><strong>Compiler</strong>',
    '<span>04</span><strong>Applications</strong>'
  ]) {
    assert.ok(overview.includes(marker), `missing ${marker}`);
  }
});

test("seed and bootstrap docs link to the first-class executable Playground", async () => {
  const seed = await readFile(new URL("../docs/seed/index.html", import.meta.url), "utf8");
  const bootstrap = await readFile(new URL("../docs/bootstrap/index.html", import.meta.url), "utf8");
  const playground = await readFile(new URL("../playground/index.html", import.meta.url), "utf8");
  const overview = await readFile(new URL("../docs/index.html", import.meta.url), "utf8");
  for (const marker of ['href="/playground/"', "real WebAssembly interpreter", "no simulated results"]) {
    assert.ok(seed.includes(marker), `seed page is missing ${marker}`);
  }
  for (const marker of ['href="/playground/"', "boot.lisp", "Fibonacci", "JIT and AOT unavailable"]) {
    assert.ok(bootstrap.includes(marker), `bootstrap page is missing ${marker}`);
  }
  assert.ok(!seed.includes("data-bootstrap-demo"));
  assert.ok(!bootstrap.includes("data-bootstrap-demo"));
  for (const marker of ["data-theme-bootstrap", 'src="/theme-init.js"', "data-bootstrap-demo", "YALISP Playground"]) {
    assert.ok(playground.includes(marker), `playground is missing ${marker}`);
  }
  assert.ok(overview.includes('<a href="/playground/">Open the YALISP Playground</a>'));
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
