type NavigationState = "collapsed" | "expanded";

type NavigationOptions = {
  currentPath?: string;
  initialState: NavigationState;
  navigationId: string;
};

const pageAnchors: Record<string, Array<[string, string]>> = {
  "/docs/seed/": [["source", "Checked-in source"]],
  "/docs/bootstrap/": [["source", "Checked-in source"]],
  "/docs/compiler/": [["source", "Checked-in source"]],
  "/docs/assembly/": [["assembly", "Assembly overview"]],
  "/docs/system-interface/": [
    ["model", "Model"],
    ["interfaces", "Functions"],
    ["contracts", "Contracts"],
    ["profiles", "Profiles"]
  ],
  "/docs/dom/": [
    ["architecture", "Architecture"],
    ["application-root", "Application root"],
    ["documents", "Documents"],
    ["rendering", "Rendering"],
    ["events", "Events"]
  ],
  "/docs/sdl/": [
    ["model", "Model"],
    ["video-render", "2D graphics"],
    ["audio", "Audio"],
    ["input", "Input"],
    ["gpu-3d", "3D and GPU"]
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
  const anchorLink = (path: string, hash: string, label: string) => {
    const active = currentPath === path && currentHash === `#${hash}`;
    return `<a class="project-nav-link project-nav-anchor${active ? " active" : ""}" href="${path}#${hash}"${active ? ' aria-current="location"' : ""}><span aria-hidden="true">#</span>${label}</a>`;
  };
  const currentPageAnchors = (path: string) => {
    if (currentPath !== path) return "";
    const anchors = pageAnchors[path] ?? [];
    if (!anchors.length) return "";
    return `<ul class="project-nav-children project-nav-anchor-list">${anchors
      .map(([hash, label]) => `<li>${anchorLink(path, hash, label)}</li>`)
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
              <li>${anchorLink("/docs/", "introduction", "Introduction")}</li>
              <li>${anchorLink("/docs/", "getting-started", "Getting started")}</li>
              <li>${anchorLink("/docs/", "language", "Language guide")}</li>
              <li>${anchorLink("/docs/", "examples", "Examples")}</li>
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
              <li>${pageLink("/docs/assembly/", "Assembly", " project-nav-page-child")}${currentPageAnchors("/docs/assembly/")}</li>
              <li>${pageLink("/docs/system-interface/", "System interface", " project-nav-page-child")}${currentPageAnchors("/docs/system-interface/")}</li>
              <li>${pageLink("/docs/dom/", "DOM", " project-nav-page-child")}${currentPageAnchors("/docs/dom/")}</li>
              <li>${pageLink("/docs/sdl/", "SDL", " project-nav-page-child")}${currentPageAnchors("/docs/sdl/")}</li>
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
