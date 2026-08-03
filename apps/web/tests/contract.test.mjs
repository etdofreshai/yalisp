import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { getNavigationOwnerState, normalizePath } from "../src/project-navigation.ts";

const html = await readFile(new URL("../index.html", import.meta.url), "utf8");
const source = await readFile(new URL("../src/main.ts", import.meta.url), "utf8");
const landing = await readFile(new URL("../src/site/landing.lisp", import.meta.url), "utf8");
const docsOverview = await readFile(new URL("../src/site/docs-overview.lisp", import.meta.url), "utf8");
const navigation = await readFile(new URL("../src/project-navigation.ts", import.meta.url), "utf8");

test("landing page exposes its essential semantic and social contracts", () => {
  for (const marker of [
    'data-theme-bootstrap',
    'src="/theme-init.js"',
    'data-dom-lisp-root'
  ]) {
    assert.ok(html.includes(marker), `missing ${marker}`);
  }
  for (const marker of ["(defn app.view", "(defn app.event", "(defn site-nav", "'main", "(id 'why)", "(id 'language)", "https://github.com/ETdoFreshAI/yalisp"]) {
    assert.ok(landing.includes(marker), `DOM Lisp landing source is missing ${marker}`);
  }
  for (const marker of ['pageLink("/playground/"', 'pageLink("/examples/"', 'pageLink("/docs/"', "project-nav-playground", "https://github.com/etdofreshai/yalisp"]) {
    assert.ok(navigation.includes(marker), `shared navigation is missing ${marker}`);
  }
  assert.ok(!navigation.includes('href="/code/"'), "shared navigation still advertises the retired Code destination");
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

test("landing behavior is a thin TypeScript DOM bridge over executable Lisp", () => {
  assert.ok(source.includes("runDomApplication"));
  assert.ok(!source.includes("navigator.clipboard.writeText"));
  assert.ok(landing.includes("'toggle-menu"));
  assert.ok(landing.includes("'toggle-theme"));
  assert.ok(landing.includes("'document-theme"));
});

test("landing shell starts with a compact rail and exposes its shared tree through the menu", async () => {
  const styles = await readFile(new URL("../src/styles.css", import.meta.url), "utf8");
  assert.match(styles, /--rail-width:/);
  assert.match(styles, /\.site-header\s*\{[\s\S]*width: 76px/);
  assert.match(styles, /\.site-header\.menu-open\s*\{[\s\S]*width: var\(--rail-width\)/);
  assert.match(styles, /\.site-header:not\(\.menu-open\) \.landing-project-navigation/);
  assert.match(styles, /main,\s*\nfooter\s*\{\s*margin-left: 76px/);
  assert.match(styles, /@media \(max-width: 900px\)[\s\S]*main,\s*\n\s*footer \{ margin-left: 0; \}/);
});

test("landing and inner pages mount the same semantic navigation with different defaults", async () => {
  const docsBehavior = await readFile(new URL("../src/docs.ts", import.meta.url), "utf8");
  const playgroundBehavior = await readFile(new URL("../src/playground.ts", import.meta.url), "utf8");
  const navStyles = await readFile(new URL("../src/project-navigation.css", import.meta.url), "utf8");
  for (const marker of [
    '<ul class="project-nav-tree">',
    "project-nav-children",
    "project-nav-page-child",
    "project-nav-anchor",
    'pageLink("/", "Project overview")',
    '["why", "Why YALisp"]',
    '["language", "The language"]',
    'pageLink("/docs/foundation/"',
    'pageLink("/playground/"',
    'pageLink("/docs/sdl/"',
    '<span class="project-nav-index">01</span><span>Seed</span>',
    '<span class="project-nav-index">02</span><span>Bootstrap</span>',
    '<span class="project-nav-index">03</span><span>Compiler</span>',
    '<span class="project-nav-index">04</span><span>Applications</span>',
    '<span class="project-nav-index">05</span><span>Interfaces</span>',
    '<span class="project-nav-index">06</span><span>Game Runtime</span>'
  ]) {
    assert.ok(navigation.includes(marker), `missing ${marker}`);
  }
  assert.match(navStyles, /\.project-nav ul[^}]*list-style: none/);
  assert.match(navStyles, /\.project-nav-anchor[^}]*color: var\(--muted\)/);
  assert.match(navStyles, /\.project-nav-section-link[^}]*color: var\(--muted\)/);
  assert.match(navStyles, /\.project-nav-page-child[^}]*font: 500/);
  assert.match(navStyles, /\.project-nav-link[^}]*justify-content: flex-start/);
  assert.match(navStyles, /\.project-nav-link[^}]*text-align: left/);
  assert.match(navStyles, /\.project-nav-link[^}]*min-height: 2\.25rem/);
  assert.ok(landing.includes("(defn site-nav"));
  assert.ok(docsBehavior.includes('initialState: "expanded"'));
  assert.ok(docsBehavior.includes("setSidebarCollapsed(false)"));
  assert.ok(playgroundBehavior.includes('import "./docs"'));
  assert.ok(!navigation.includes('href="/code/"'), "shared navigation still advertises the retired Code destination");
});

test("sidebar nested numbers mirror printed page section numbers without inventing them", async () => {
  const docs = docsOverview;
  const seed = await readFile(new URL("../docs/seed/index.html", import.meta.url), "utf8");
  const bootstrap = await readFile(new URL("../docs/bootstrap/index.html", import.meta.url), "utf8");
  const compiler = await readFile(new URL("../docs/compiler/index.html", import.meta.url), "utf8");
  const system = await readFile(new URL("../docs/system-interface/index.html", import.meta.url), "utf8");
  const dom = await readFile(new URL("../docs/dom/index.html", import.meta.url), "utf8");
  const sdl = await readFile(new URL("../docs/sdl/index.html", import.meta.url), "utf8");

  for (const [document, hash, printed, nested] of [
    [seed, "supported-surface", "01 / Supported surface", "01.01"],
    [seed, "source", "02 / Checked-in source", "01.02"],
    [seed, "live-seed", "03 / Live seed", "01.03"],
    [bootstrap, "source", "01 / Checked-in source", "02.01"],
    [bootstrap, "live-bootstrap", "02 / Live bootstrap", "02.02"],
    [bootstrap, "compiler-status", "03 / Compiler status", "02.03"],
    [compiler, "supported-subset", "01 / Supported subset", "03.01"],
    [compiler, "source", "02 / Source", "03.02"],
    [system, "profiles", "04 / Profiles", "05.02.04"],
    [dom, "extension-safety", "06 / Extension safety", "05.03.06"],
    [sdl, "profiles", "06 / Profiles and boundaries", "05.04.06"]
  ]) {
    assert.ok(document.includes(`id="${hash}"`), `${hash} is not a real section target`);
    assert.ok(document.includes(printed), `${hash} is missing its printed section number`);
    assert.ok(navigation.includes(`["${hash}",`), `${hash} is absent from the shared tree`);
    assert.ok(navigation.includes(`"${nested}"]`), `${hash} is missing nested number ${nested}`);
  }

  for (const [hash, printed, label] of [
    ["introduction", "01", "Introduction"],
    ["getting-started", "02", "Getting started"],
    ["language", "03", "Language guide"],
    ["core-repl", "04", "REPL that grows into a compiler"],
    ["foundation", "05", "Foundation"],
    ["reference-interfaces", "06", "Interfaces"],
    ["game-runtime", "07", "Game runtime"],
    ["examples", "08", "Examples"]
  ]) {
    assert.ok(docs.includes(`(id '${hash})`));
    assert.ok(docs.includes(`(cls 'section-number)) "${printed}"`));
    assert.ok(navigation.includes(`["${hash}", "${label}", "${printed}"]`));
  }

  for (const marker of [
    '<span class="project-nav-subindex">05.01</span><span>Assembly</span>',
    '<span class="project-nav-subindex">05.02</span><span>System interface</span>',
    '<span class="project-nav-subindex">05.03</span><span>DOM</span>',
    '<span class="project-nav-subindex">05.04</span><span>SDL</span>'
  ]) assert.ok(navigation.includes(marker), `missing numbered interface child ${marker}`);

  assert.ok(navigation.includes('["why", "Why YALisp"]'));
  assert.ok(navigation.includes('["assembly", "Assembly overview"]'));
  assert.ok(navigation.includes('number ? "" : \' aria-hidden="true"\''), "numbered subsection labels should remain in accessible link names");
});

test("anchor groups disclose only for their owning route and track the active section", async () => {
  const navStyles = await readFile(new URL("../src/project-navigation.css", import.meta.url), "utf8");

  for (const marker of [
    "const expanded = currentPath === path",
    'data-anchor-group data-owner-path="${path}"${expanded ? "" : " hidden"}',
    'data-owner-path="${path}" data-anchor-id="${hash}"',
    'link.setAttribute("aria-current", "location")',
    'link.removeAttribute("aria-current")',
    'window.addEventListener("hashchange", updateFromHash)',
    'window.addEventListener("scroll", queueScrollUpdate, { passive: true })',
    'new IntersectionObserver(queueScrollUpdate',
    'rootMargin: "-20% 0px -70% 0px"',
    "getBoundingClientRect().top",
    'getNavigationOwnerState(options.currentPath ?? window.location.pathname)'
  ]) assert.ok(navigation.includes(marker), `missing active-anchor behavior: ${marker}`);

  assert.match(navigation, /replace\(\/\\\/\+\$\/, ""\)/);
  assert.match(navStyles, /\.project-nav-anchor-list\[hidden\], \.project-nav-page-list\[hidden\]\s*\{\s*display: none/);
  assert.match(navStyles, /\.project-nav-anchor\.active[^}]*box-shadow: inset 2px 0 var\(--accent\)/);
});

test("DOM Lisp forwards hash and scroll section changes into the documentation state", async () => {
  const host = await readFile(new URL("../src/dom-lisp.ts", import.meta.url), "utf8");
  for (const marker of [
    'const sectionChangeAttribute = "on-section-change"',
    'window.addEventListener("hashchange", syncActiveSection)',
    'window.addEventListener("scroll", () =>',
    'root.querySelectorAll<HTMLElement>("main section[id]")',
    'dispatch(`${sectionEventPrefix}-${selected}`)'
  ]) assert.ok(host.includes(marker), `missing generic section bridge: ${marker}`);
  for (const marker of [
    "(at 'on-section-change 'section)",
    "(defn active-state",
    "'section-foundation",
    "(aria 'aria-current \"location\")"
  ]) assert.ok(docsOverview.includes(marker), `missing Lisp-owned active-section behavior: ${marker}`);
});

test("Docs, Foundation, and Interfaces disclosures use exact normalized route ownership", () => {
  for (const route of ["/docs", "/docs/", "/docs//", "/docs/index.html", "/docs/#reference-interfaces", "/docs/?from=nav#foundation"]) {
    assert.deepEqual(getNavigationOwnerState(route), {
      currentPath: "/docs/",
      anchorOwner: "/docs/",
      foundationExpanded: false,
      interfacesExpanded: false
    });
  }

  for (const route of ["/docs/foundation", "/docs/foundation/", "/docs/foundation/index.html", "/docs/foundation/#path"]) {
    assert.deepEqual(getNavigationOwnerState(route), {
      currentPath: "/docs/foundation/",
      anchorOwner: null,
      foundationExpanded: true,
      interfacesExpanded: false
    });
  }

  for (const [route, owner] of [
    ["/docs/seed/#source", "/docs/seed/"],
    ["/docs/bootstrap/index.html#live-bootstrap", "/docs/bootstrap/"],
    ["/docs/compiler?view=source#source", "/docs/compiler/"]
  ]) {
    assert.deepEqual(getNavigationOwnerState(route), {
      currentPath: owner,
      anchorOwner: owner,
      foundationExpanded: true,
      interfacesExpanded: false
    });
  }

  for (const route of ["/docs/assembly/", "/docs/system-interface#profiles", "/docs/dom/index.html#rendering", "/docs/sdl//?profile=gpu#gpu-3d"]) {
    const currentPath = normalizePath(route);
    assert.deepEqual(getNavigationOwnerState(route), {
      currentPath,
      anchorOwner: currentPath,
      foundationExpanded: false,
      interfacesExpanded: true
    });
  }

  for (const route of ["/docs/foundation-extra/", "/docs/domains/", "/docs/system-interface-v2/", "/playground/"]) {
    assert.deepEqual(getNavigationOwnerState(route), {
      currentPath: normalizePath(route),
      anchorOwner: null,
      foundationExpanded: false,
      interfacesExpanded: false
    });
  }

  for (const marker of [
    'data-page-group="${name}"',
    'pageGroup("foundation", foundationPages',
    'pageGroup("interfaces", interfacePages',
    'foundationPages.has(currentPath)',
    'interfacePages.has(currentPath)',
    'aria-controls="project-nav-foundation-pages"',
    'aria-controls="project-nav-interfaces-pages"'
  ]) assert.ok(navigation.includes(marker), `missing exact disclosure contract: ${marker}`);
  assert.ok(!navigation.includes("startsWith("), "route-prefix matching could leak a neighboring group");
});

test("Vite redirects canonical page routes to their trailing-slash form", async () => {
  const viteConfig = await readFile(new URL("../vite.config.ts", import.meta.url), "utf8");
  for (const route of [
    "/docs",
    "/docs/foundation",
    "/docs/seed",
    "/docs/system-interface",
    "/docs/dom",
    "/playground",
    "/examples",
    "/examples/hello-world",
    "/examples/pong",
    "/examples/breakout",
    "/examples/asteroids"
  ]) assert.ok(viteConfig.includes(`"${route}"`), `missing canonical redirect route ${route}`);
  assert.ok(viteConfig.includes("configureServer(server)"));
  assert.ok(viteConfig.includes("configurePreviewServer(server)"));
  assert.ok(viteConfig.includes("response.statusCode = 308"));
  assert.ok(viteConfig.includes('response.setHeader("Location", `${url.pathname}/${url.search}`)'));
});

test("expanded rails use their width while keeping navigation aligned left", async () => {
  const docsStyles = await readFile(new URL("../src/docs.css", import.meta.url), "utf8");
  const landingStyles = await readFile(new URL("../src/styles.css", import.meta.url), "utf8");
  assert.match(docsStyles, /grid-template-columns: clamp\(250px, 22vw, 310px\)/);
  assert.match(docsStyles, /\.docs-nav[^}]*padding: 3\.5rem \.65rem 1\.5rem \.9rem/);
  assert.match(landingStyles, /\.site-header\.menu-open[^}]*padding: 2rem \.75rem 1\.5rem 1rem/);
});

test("documentation and Playground shells provide hosts for the common project tree", async () => {
  const pages = ["", "applications/", "assembly/", "bootstrap/", "compiler/", "dom/", "foundation/", "sdl/", "seed/", "system-interface/"];
  for (const page of pages) {
    const document = await readFile(new URL(`../docs/${page}index.html`, import.meta.url), "utf8");
    if (page === "") {
      assert.ok(document.includes("data-dom-lisp-root"), "docs/ is missing its DOM Lisp host");
      assert.ok(document.includes('src="/src/docs-overview.ts"'), "docs/ is missing its thin DOM Lisp launcher");
    } else assert.ok(document.includes('class="docs-nav"'), `${page} is missing the shared navigation host`);
  }
  const playground = await readFile(new URL("../playground/index.html", import.meta.url), "utf8");
  assert.ok(playground.includes("data-docs-shell"));
  assert.ok(playground.includes('class="docs-nav"'));
  assert.ok(playground.includes("data-docs-menu"));
});

test("Hello World exposes its complete Lisp application and generic launchers", async () => {
  const gallery = await readFile(new URL("../examples/index.html", import.meta.url), "utf8");
  const hello = await readFile(new URL("../examples/hello-world/index.html", import.meta.url), "utf8");
  const exampleSource = await readFile(new URL("../src/examples/hello-world/app.lisp", import.meta.url), "utf8");
  const runtime = await readFile(new URL("../src/examples/runtime/lisp-application.ts", import.meta.url), "utf8");
  const cliSource = await readFile(new URL("../examples/hello-world/cli.mjs", import.meta.url), "utf8");
  const behavior = await readFile(new URL("../src/examples.ts", import.meta.url), "utf8");

  for (const page of [gallery, hello]) {
    assert.ok(page.includes('class="docs-nav"'));
    assert.ok(page.includes("data-theme-bootstrap"));
    assert.ok(page.includes('src="/theme-init.js"'));
  }
  assert.ok(gallery.includes('href="/examples/hello-world/"'));
  assert.ok(hello.includes("Executed Lisp source shown"));
  assert.ok(hello.includes("does not yet expose a language-level console"));
  assert.ok(hello.includes("actual printed value"));
  for (const marker of ["data-lisp-app=\"hello-world\"", "Complete executable package", "data-lisp-application-source=\"hello-world\"", "data-hello-cli-source"]) {
    assert.ok(hello.includes(marker), `Hello World page is missing ${marker}`);
  }
  for (const marker of ["(defn app.mount", "(defn app.initial-state", "(defn app.result", '"Hello, world!"', "(defn app.frame"]) {
    assert.ok(exampleSource.includes(marker), `Hello World app source is missing ${marker}`);
  }
  assert.ok(runtime.includes('evaluateOutput("(app.result)")'));
  assert.ok(cliSource.includes("src/examples/hello-world/app.lisp"));
  assert.ok(cliSource.includes('run("(app.result)", true)'));
  assert.ok(behavior.includes('import helloWorldApplicationSource from "./examples/hello-world/app.lisp?raw"'));
  assert.ok(behavior.includes("runApplication(root, helloWorldApplicationSource)"));
});

test("Pong exposes the complete source package that its runner imports", async () => {
  const gallery = await readFile(new URL("../examples/index.html", import.meta.url), "utf8");
  const pong = await readFile(new URL("../examples/pong/index.html", import.meta.url), "utf8");
  const source = await readFile(new URL("../src/examples/pong/app.lisp", import.meta.url), "utf8");
  const runtime = await readFile(new URL("../src/examples/runtime/lisp-application.ts", import.meta.url), "utf8");
  const behavior = await readFile(new URL("../src/examples.ts", import.meta.url), "utf8");

  assert.ok(gallery.includes('href="/examples/pong/"'));
  for (const marker of ["data-lisp-app=\"pong\"", "Complete executable package", "data-lisp-application-source=\"pong\"", "execute in the current YALISP bootstrap evaluator"]) {
    assert.ok(pong.includes(marker), `Pong page is missing ${marker}`);
  }
  for (const marker of ["(defn app.mount", "(defn app.initial-state", "(defn app.step", "(defn app.draw", "(defn app.frame", "player-score", "opponent-score"]) {
    assert.ok(source.includes(marker), `Pong app source is missing ${marker}`);
  }
  for (const marker of ["createSeedSession", "requestAnimationFrame", "drawCommands", "parseLispValue", "frameIntervalMs"]) {
    assert.ok(runtime.includes(marker), `Lisp browser binding is missing ${marker}`);
  }
  assert.ok(behavior.includes('import { runApplication } from "./examples/runtime/lisp-application"'));
  assert.ok(behavior.includes('import pongApplicationSource from "./examples/pong/app.lisp?raw"'));
  assert.ok(behavior.includes("runApplication(root, pongApplicationSource)"));
  assert.equal(runtime.includes("Pong"), false, "generic binding must not contain Pong behavior");
});

test("Breakout exposes the complete Lisp source package that its launcher imports", async () => {
  const gallery = await readFile(new URL("../examples/index.html", import.meta.url), "utf8");
  const page = await readFile(new URL("../examples/breakout/index.html", import.meta.url), "utf8");
  const source = await readFile(new URL("../src/examples/breakout/app.lisp", import.meta.url), "utf8");
  const behavior = await readFile(new URL("../src/examples.ts", import.meta.url), "utf8");
  assert.ok(gallery.includes('href="/examples/breakout/"'));
  for (const marker of ["data-lisp-app=\"breakout\"", "Complete executable package", "data-lisp-application-source=\"breakout\"", "execute in YALISP"]) {
    assert.ok(page.includes(marker), `Breakout page is missing ${marker}`);
  }
  for (const marker of ["(defn app.mount", "(defn app.initial-state", "(defn app.step", "(defn app.draw-bricks", "(defn app.frame", "brick-flags"]) {
    assert.ok(source.includes(marker), `Breakout app source is missing ${marker}`);
  }
  assert.ok(behavior.includes('import breakoutApplicationSource from "./examples/breakout/app.lisp?raw"'));
  assert.ok(behavior.includes("runApplication(root, breakoutApplicationSource)"));
});

test("Asteroids exposes the complete source package that its runner imports", async () => {
  const gallery = await readFile(new URL("../examples/index.html", import.meta.url), "utf8");
  const page = await readFile(new URL("../examples/asteroids/index.html", import.meta.url), "utf8");
  const source = await readFile(new URL("../src/examples/asteroids/app.lisp", import.meta.url), "utf8");
  const runtime = await readFile(new URL("../src/examples/runtime/lisp-application.ts", import.meta.url), "utf8");
  const behavior = await readFile(new URL("../src/examples.ts", import.meta.url), "utf8");
  assert.ok(gallery.includes('href="/examples/asteroids/"'));
  for (const marker of ["data-lisp-app=\"asteroids\"", "Complete executable package", "data-lisp-application-source=\"asteroids\"", "execute in YALISP"]) {
    assert.ok(page.includes(marker), `Asteroids page is missing ${marker}`);
  }
  for (const marker of ["(defn app.mount", "(defn app.initial-state", "(defn app.step", "(defn app.resolve", "(defn app.ship", "(defn app.frame", "four cardinal ship headings"]) {
    assert.ok(source.includes(marker), `Asteroids app source is missing ${marker}`);
  }
  assert.ok(behavior.includes('import asteroidsApplicationSource from "./examples/asteroids/app.lisp?raw"'));
  assert.ok(behavior.includes("runApplication(root, asteroidsApplicationSource)"));
  for (const name of ["Pong", "Breakout", "Asteroids"]) {
    assert.equal(runtime.includes(name), false, `generic binding must not contain ${name} behavior`);
  }
});

test("documentation links all four examples and preserves their runtime boundary", async () => {
  const docs = docsOverview;
  const applications = await readFile(new URL("../docs/applications/index.html", import.meta.url), "utf8");
  for (const route of ["hello-world", "pong", "breakout", "asteroids"]) {
    assert.ok(docs.includes(`"/examples/${route}/"`), `Docs are missing ${route}`);
  }
  assert.ok(docs.includes("do not claim an implemented native YALISP graphics runtime"));
  assert.ok(applications.includes('href="/examples/"'));
  assert.ok(applications.includes("None of the games claim an implemented native YALISP DOM, SDL, or Game Runtime binding"));
});

test("complete source packages use the shared horizontally safe source viewport", async () => {
  const styles = await readFile(new URL("../src/examples.css", import.meta.url), "utf8");
  for (const route of ["hello-world", "pong", "breakout", "asteroids"]) {
    const page = await readFile(new URL(`../examples/${route}/index.html`, import.meta.url), "utf8");
    assert.ok(page.includes('class="application-package"'), `${route} is missing the shared source package layout`);
    assert.ok(page.includes('class="application-source"'), `${route} is missing the shared source viewport`);
  }
  assert.match(styles, /\.application-package \{[^}]*min-width: 0/);
  assert.match(styles, /\.application-source pre \{[^}]*max-width: 100%[^}]*overflow: auto/);
});

test("Foundation docs own their actual checked-in sources and retire the standalone Code destination", async () => {
  const seedPage = await readFile(new URL("../docs/seed/index.html", import.meta.url), "utf8");
  const bootstrapPage = await readFile(new URL("../docs/bootstrap/index.html", import.meta.url), "utf8");
  const compilerPage = await readFile(new URL("../docs/compiler/index.html", import.meta.url), "utf8");
  const legacyCode = await readFile(new URL("../code/index.html", import.meta.url), "utf8");
  const behavior = await readFile(new URL("../src/source-docs.ts", import.meta.url), "utf8");
  const styles = await readFile(new URL("../src/docs.css", import.meta.url), "utf8");
  const wat = await readFile(new URL("../src/seed/bootstrap.wat", import.meta.url), "utf8");
  const bootstrap = await readFile(new URL("../public/yalisp/boot.lisp", import.meta.url), "utf8");
  const compiler = await readFile(new URL("../public/yalisp/compiler.lisp", import.meta.url), "utf8");

  assert.ok(seedPage.includes("data-seed-source"));
  assert.ok(seedPage.includes("apps/web/src/seed/bootstrap.wat"));
  assert.ok(bootstrapPage.includes("data-bootstrap-source"));
  assert.ok(bootstrapPage.includes("apps/web/public/yalisp/boot.lisp"));
  assert.ok(compilerPage.includes("data-compiler-source"));
  assert.ok(compilerPage.includes("apps/web/public/yalisp/compiler.lisp"));
  assert.ok(compilerPage.includes("scripts/build-aot.mjs"));
  assert.ok(compilerPage.includes("aot-benchmark.wasm"));
  for (const page of [seedPage, bootstrapPage, compilerPage]) assert.ok(page.includes('src="/src/source-docs.ts"'));
  assert.match(behavior, /bootstrap\.wat\?raw/);
  assert.match(behavior, /"\/yalisp\/boot\.lisp"/);
  assert.match(behavior, /"\/yalisp\/compiler\.lisp"/);
  assert.match(styles, /\.source-view pre[^}]*overflow: auto/);
  assert.match(styles, /\.source-view code[^}]*white-space: pre/);
  assert.ok(wat.includes("(module"));
  assert.ok(bootstrap.includes("(define"));
  assert.ok(compiler.includes("(defn cc.compile"));
  assert.ok(legacyCode.includes('location.replace("/docs/foundation/")'));
  assert.ok(legacyCode.includes('rel="canonical" href="https://yalisp.etdofresh.com/docs/foundation/"'));
  assert.ok(!legacyCode.includes("data-seed-source"));
  assert.ok(!compilerPage.includes('href="/code/'));
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
  const docs = docsOverview;
  for (const marker of [
    "(id 'reference-interfaces)",
    '"/docs/assembly/"',
    '"/docs/system-interface/"',
    '"/docs/dom/"',
    '"/docs/sdl/"',
    "(id 'game-runtime)",
    "simulation update",
    "render update",
    "Future networking exchanges simulation inputs"
  ]) {
    assert.ok(docs.includes(marker), `missing ${marker}`);
  }
});

test("assembly documentation exposes its primary instruction groups", async () => {
  const inventory = await readFile(new URL("../src/assembly-inventory.ts", import.meta.url), "utf8");
  for (const marker of [
    "assembly.i32.add",
    "assembly.memory.grow",
    "assembly.v128.load",
    "assembly.func"
  ]) {
    assert.ok(inventory.includes(marker), `missing ${marker}`);
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
  assert.ok(docsOverview.includes("(id 'core-repl)"));
  assert.match(docsOverview, /WAT interpreter extended by boot\.lisp/i);
  assert.match(docsOverview, /bounded Lisp-written arithmetic compiler/i);
});

test("language guide distinguishes evidenced syntax from planned features", async () => {
  const docs = docsOverview;
  const siteBehavior = await readFile(new URL("../src/site/landing.lisp", import.meta.url), "utf8");

  for (const marker of ["(define factorial", "(lambda (n)", "(factorial 6)"]) {
    assert.ok(siteBehavior.includes(marker), `site source is missing ${marker}`);
    assert.ok(docs.includes(marker), `language guide is missing ${marker}`);
  }
  assert.match(docs, /Module syntax is not implemented/);
  assert.match(docs, /This cc\.compile form is executed/);
  assert.match(docs, /one-parameter integer expressions/);
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
  const overview = docsOverview;
  const foundation = await readFile(new URL("../docs/foundation/index.html", import.meta.url), "utf8");
  for (const marker of ["Seed", "Bootstrap", "Compiler", "Applications"]) {
    assert.ok(foundation.includes(marker), `missing ${marker}`);
  }
  for (const marker of [
    '"YALisp foundation documentation"',
    '(map-link "01" "/docs/seed/" "Seed"',
    '(map-link "02" "/docs/bootstrap/" "Bootstrap"',
    '(map-link "03" "/docs/compiler/" "Compiler"',
    '(map-link "04" "/docs/applications/" "Applications"'
  ]) {
    assert.ok(overview.includes(marker), `missing ${marker}`);
  }
});

test("seed and bootstrap docs link to the first-class executable Playground", async () => {
  const seed = await readFile(new URL("../docs/seed/index.html", import.meta.url), "utf8");
  const bootstrap = await readFile(new URL("../docs/bootstrap/index.html", import.meta.url), "utf8");
  const playground = await readFile(new URL("../playground/index.html", import.meta.url), "utf8");
  const overview = docsOverview;
  for (const marker of ['href="/playground/"', "real WebAssembly interpreter", "no simulated results"]) {
    assert.ok(seed.includes(marker), `seed page is missing ${marker}`);
  }
  for (const marker of ['href="/playground/"', "boot.lisp", "Fibonacci", "compiler.lisp", "interpreter, JIT, and AOT paths"]) {
    assert.ok(bootstrap.includes(marker), `bootstrap page is missing ${marker}`);
  }
  assert.ok(!seed.includes("data-bootstrap-demo"));
  assert.ok(!bootstrap.includes("data-bootstrap-demo"));
  for (const marker of ["data-theme-bootstrap", 'src="/theme-init.js"', "data-bootstrap-demo", "YALISP Playground"]) {
    assert.ok(playground.includes(marker), `playground is missing ${marker}`);
  }
  assert.ok(overview.includes('(link "/playground/" "Open the YALISP Playground")'));
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
