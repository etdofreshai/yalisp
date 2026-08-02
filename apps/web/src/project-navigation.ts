type NavigationState = "collapsed" | "expanded";

type NavigationOptions = {
  currentPath?: string;
  initialState: NavigationState;
  navigationId: string;
};

const pageAnchors: Record<string, Array<[string, string, string?]>> = {
  "/docs/seed/": [
    ["supported-surface", "Supported surface", "01.01"],
    ["source", "Checked-in source", "01.02"],
    ["live-seed", "Live seed", "01.03"]
  ],
  "/docs/bootstrap/": [
    ["source", "Checked-in source", "02.01"],
    ["live-bootstrap", "Live bootstrap", "02.02"],
    ["compiler-status", "Compiler status", "02.03"]
  ],
  "/docs/compiler/": [
    ["supported-subset", "Supported subset", "03.01"],
    ["source", "Source", "03.02"]
  ],
  "/docs/assembly/": [["assembly", "Assembly overview"]],
  "/docs/system-interface/": [
    ["model", "Model", "05.02.01"],
    ["interfaces", "Portable interfaces", "05.02.02"],
    ["contracts", "Contract rules", "05.02.03"],
    ["profiles", "Profiles", "05.02.04"]
  ],
  "/docs/dom/": [
    ["architecture", "Boundary", "05.03.01"],
    ["application-root", "Application root", "05.03.02"],
    ["documents", "Documents and commands", "05.03.03"],
    ["rendering", "Rendering", "05.03.04"],
    ["events", "Input and lifecycle", "05.03.05"],
    ["extension-safety", "Extension safety", "05.03.06"]
  ],
  "/docs/sdl/": [
    ["model", "Model", "05.04.01"],
    ["video-render", "2D graphics", "05.04.02"],
    ["audio", "Audio", "05.04.03"],
    ["input", "Input and devices", "05.04.04"],
    ["gpu-3d", "3D and GPU", "05.04.05"],
    ["profiles", "Profiles and boundaries", "05.04.06"]
  ]
};

const normalizePath = (path: string) => path.replace(/index\.html$/, "");

export function mountProjectNavigation(host: HTMLElement, options: NavigationOptions) {
  const currentPath = normalizePath(options.currentPath ?? window.location.pathname);
  const currentHash = window.location.hash;
  const pageLink = (path: string, label: string, extraClass = "") => {
    const active = currentPath === path;
    return `<a class="project-nav-link project-nav-page${extraClass}${active ? " active" : ""}" href="${path}"${active ? ' aria-current="page"' : ""}>${label}</a>`;
  };
  const anchorLink = (path: string, hash: string, label: string, number?: string) => {
    const active = currentPath === path && currentHash === `#${hash}`;
    return `<a class="project-nav-link project-nav-anchor${number ? " has-number" : ""}${active ? " active" : ""}" href="${path}#${hash}"${active ? ' aria-current="location"' : ""}><span class="project-nav-subindex"${number ? "" : ' aria-hidden="true"'}>${number ?? "#"}</span><span>${label}</span></a>`;
  };
  const currentPageAnchors = (path: string) => {
    if (currentPath !== path) return "";
    const anchors = pageAnchors[path] ?? [];
    if (!anchors.length) return "";
    return `<ul class="project-nav-children project-nav-anchor-list">${anchors
      .map(([hash, label, number]) => `<li>${anchorLink(path, hash, label, number)}</li>`)
      .join("")}</ul>`;
  };

  host.dataset.navigationDefault = options.initialState;
  host.innerHTML = `
    <div class="project-navigation">
      <p class="project-nav-label">Project navigation</p>
      <nav id="${options.navigationId}" class="project-nav" aria-label="Project navigation">
        <ul class="project-nav-tree">
          <li class="project-nav-overview">
            ${pageLink("/", "Project overview")}
            <ul class="project-nav-children project-nav-anchor-list">
              <li>${anchorLink("/", "why", "Why YALisp")}</li>
              <li>${anchorLink("/", "language", "The language")}</li>
            </ul>
          </li>
          <li class="project-nav-overview">
            ${pageLink("/docs/", "Documentation overview")}
            <ul class="project-nav-children project-nav-anchor-list">
              <li>${anchorLink("/docs/", "introduction", "Introduction", "01")}</li>
              <li>${anchorLink("/docs/", "getting-started", "Getting started", "02")}</li>
              <li>${anchorLink("/docs/", "language", "Language guide", "03")}</li>
              <li>${anchorLink("/docs/", "core-repl", "REPL that grows into a compiler", "04")}</li>
              <li>${anchorLink("/docs/", "examples", "Examples", "08")}</li>
            </ul>
          </li>
          <li class="project-nav-context">${pageLink("/docs/foundation/", "Foundation overview")}</li>
          <li class="project-nav-stage">
            ${pageLink("/docs/seed/", '<span class="project-nav-index">01</span><span>Seed</span>')}
            ${currentPageAnchors("/docs/seed/")}
          </li>
          <li class="project-nav-stage">
            ${pageLink("/docs/bootstrap/", '<span class="project-nav-index">02</span><span>Bootstrap</span>')}
            ${currentPageAnchors("/docs/bootstrap/")}
          </li>
          <li class="project-nav-stage">
            ${pageLink("/docs/compiler/", '<span class="project-nav-index">03</span><span>Compiler</span>')}
            ${currentPageAnchors("/docs/compiler/")}
          </li>
          <li class="project-nav-stage">
            ${pageLink("/docs/applications/", '<span class="project-nav-index">04</span><span>Applications</span>')}
          </li>
          <li class="project-nav-stage project-nav-interface-group">
            <a class="project-nav-link project-nav-section-link" href="/docs/#reference-interfaces"><span class="project-nav-index">05</span><span>Interfaces</span></a>
            <ul class="project-nav-children project-nav-page-list">
              <li>${pageLink("/docs/assembly/", '<span class="project-nav-subindex">05.01</span><span>Assembly</span>', " project-nav-page-child")}${currentPageAnchors("/docs/assembly/")}</li>
              <li>${pageLink("/docs/system-interface/", '<span class="project-nav-subindex">05.02</span><span>System interface</span>', " project-nav-page-child")}${currentPageAnchors("/docs/system-interface/")}</li>
              <li>${pageLink("/docs/dom/", '<span class="project-nav-subindex">05.03</span><span>DOM</span>', " project-nav-page-child")}${currentPageAnchors("/docs/dom/")}</li>
              <li>${pageLink("/docs/sdl/", '<span class="project-nav-subindex">05.04</span><span>SDL</span>', " project-nav-page-child")}${currentPageAnchors("/docs/sdl/")}</li>
            </ul>
          </li>
          <li class="project-nav-stage">
            <a class="project-nav-link project-nav-section-link" href="/docs/#game-runtime"><span class="project-nav-index">06</span><span>Game Runtime</span></a>
          </li>
          <li class="project-nav-utility">${pageLink("/playground/", "Playground", " project-nav-playground")}</li>
        </ul>
      </nav>
      <a class="project-nav-source" href="https://github.com/etdofreshai/yalisp">View source <span aria-hidden="true">↗</span></a>
    </div>`;

  return host.querySelector<HTMLElement>(`#${options.navigationId}`)!;
}
