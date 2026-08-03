type NavigationState = "collapsed" | "expanded";

type NavigationOptions = {
  currentPath?: string;
  initialState: NavigationState;
  navigationId: string;
};

const pageAnchors: Record<string, Array<[string, string, string?]>> = {
  "/": [
    ["why", "Why YALisp"],
    ["language", "The language"]
  ],
  "/docs/": [
    ["introduction", "Introduction", "01"],
    ["getting-started", "Getting started", "02"],
    ["language", "Language guide", "03"],
    ["core-repl", "REPL that grows into a compiler", "04"],
    ["foundation", "Foundation", "05"],
    ["reference-interfaces", "Interfaces", "06"],
    ["game-runtime", "Game runtime", "07"],
    ["examples", "Examples", "08"]
  ],
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

const foundationPages = new Set([
  "/docs/foundation/",
  "/docs/seed/",
  "/docs/bootstrap/",
  "/docs/compiler/",
  "/docs/applications/"
]);

export const normalizePath = (path: string) => {
  const pathOnly = path.split(/[?#]/, 1)[0] ?? "/";
  const cleanPath = pathOnly.replace(/\/{2,}/g, "/").replace(/index\.html$/, "").replace(/\/+$/, "");
  return cleanPath ? `${cleanPath}/` : "/";
};

export function getNavigationOwnerState(path: string) {
  const currentPath = normalizePath(path);
  return {
    currentPath,
    anchorOwner: Object.hasOwn(pageAnchors, currentPath) ? currentPath : null,
    foundationExpanded: foundationPages.has(currentPath)
  };
}

function setActiveAnchor(navigation: HTMLElement, path: string, hash: string) {
  navigation.querySelectorAll<HTMLAnchorElement>(".project-nav-anchor").forEach((link) => {
    const active = link.dataset.ownerPath === path && link.dataset.anchorId === hash;
    link.classList.toggle("active", active);
    if (active) link.setAttribute("aria-current", "location");
    else link.removeAttribute("aria-current");
  });
}

function trackActiveSection(navigation: HTMLElement, path: string) {
  const anchors = pageAnchors[path] ?? [];
  const sections = anchors
    .map(([hash]) => document.getElementById(hash))
    .filter((section): section is HTMLElement => section !== null);
  if (!sections.length) return () => {};

  const updateFromScroll = () => {
    const activationLine = Math.max(96, window.innerHeight * 0.24);
    let activeSection = sections[0]!;
    for (const section of sections) {
      if (section.getBoundingClientRect().top > activationLine) break;
      activeSection = section;
    }
    setActiveAnchor(navigation, path, activeSection.id);
  };

  let frame = 0;
  const queueScrollUpdate = () => {
    if (frame) return;
    frame = window.requestAnimationFrame(() => {
      frame = 0;
      updateFromScroll();
    });
  };
  const updateFromHash = () => {
    const hash = window.location.hash.slice(1);
    if (anchors.some(([anchor]) => anchor === hash)) setActiveAnchor(navigation, path, hash);
    else queueScrollUpdate();
  };

  let observer: IntersectionObserver | undefined;
  if ("IntersectionObserver" in window) {
    const sectionObserver = new IntersectionObserver(queueScrollUpdate, {
      rootMargin: "-20% 0px -70% 0px",
      threshold: [0, 1]
    });
    sections.forEach((section) => sectionObserver.observe(section));
    observer = sectionObserver;
  }
  window.addEventListener("scroll", queueScrollUpdate, { passive: true });
  window.addEventListener("resize", queueScrollUpdate);
  window.addEventListener("hashchange", updateFromHash);
  updateFromHash();

  return () => {
    observer?.disconnect();
    window.removeEventListener("scroll", queueScrollUpdate);
    window.removeEventListener("resize", queueScrollUpdate);
    window.removeEventListener("hashchange", updateFromHash);
    if (frame) window.cancelAnimationFrame(frame);
  };
}

export function mountProjectNavigation(host: HTMLElement, options: NavigationOptions) {
  const ownerState = getNavigationOwnerState(options.currentPath ?? window.location.pathname);
  const { currentPath, foundationExpanded } = ownerState;
  const currentHash = window.location.hash;
  const pageLink = (path: string, label: string, extraClass = "", extraAttributes = "") => {
    const active = currentPath === path;
    return `<a class="project-nav-link project-nav-page${extraClass}${active ? " active" : ""}" href="${path}"${active ? ' aria-current="page"' : ""}${extraAttributes}>${label}</a>`;
  };
  const anchorLink = (path: string, hash: string, label: string, number?: string) => {
    const active = currentPath === path && currentHash === `#${hash}`;
    return `<a class="project-nav-link project-nav-anchor${number ? " has-number" : ""}${active ? " active" : ""}" href="${path}#${hash}" data-owner-path="${path}" data-anchor-id="${hash}"${active ? ' aria-current="location"' : ""}><span class="project-nav-subindex"${number ? "" : ' aria-hidden="true"'}>${number ?? "#"}</span><span>${label}</span></a>`;
  };
  const anchorGroup = (path: string) => {
    const anchors = pageAnchors[path] ?? [];
    if (!anchors.length) return "";
    const expanded = currentPath === path;
    return `<ul class="project-nav-children project-nav-anchor-list" data-anchor-group data-owner-path="${path}"${expanded ? "" : " hidden"}>${anchors
      .map(([hash, label, number]) => `<li>${anchorLink(path, hash, label, number)}</li>`)
      .join("")}</ul>`;
  };
  const pageGroup = (name: string, ownerPaths: Set<string>, children: string) => {
    const expanded = ownerPaths.has(currentPath);
    return `<ul id="project-nav-${name}-pages" class="project-nav-children project-nav-page-list" data-page-group="${name}" data-owner-paths="${[...ownerPaths].join(" ")}"${expanded ? "" : " hidden"}>${children}</ul>`;
  };

  host.dataset.navigationDefault = options.initialState;
  host.innerHTML = `
    <div class="project-navigation">
      <nav id="${options.navigationId}" class="project-nav" aria-label="Project navigation">
        <ul class="project-nav-tree">
          <li class="project-nav-overview">
            ${pageLink("/", "Project overview")}
            ${anchorGroup("/")}
          </li>
          <li class="project-nav-overview">
            ${pageLink("/docs/", "Documentation overview")}
            ${anchorGroup("/docs/")}
          </li>
          <li class="project-nav-context project-nav-foundation-group">
            ${pageLink("/docs/foundation/", "Foundation overview", "", ` aria-expanded="${foundationExpanded}" aria-controls="project-nav-foundation-pages"`)}
            ${pageGroup("foundation", foundationPages, `
              <li class="project-nav-stage">
                ${pageLink("/docs/seed/", '<span class="project-nav-index">01</span><span>Seed</span>')}
                ${anchorGroup("/docs/seed/")}
              </li>
              <li class="project-nav-stage">
                ${pageLink("/docs/bootstrap/", '<span class="project-nav-index">02</span><span>Bootstrap</span>')}
                ${anchorGroup("/docs/bootstrap/")}
              </li>
              <li class="project-nav-stage">
                ${pageLink("/docs/compiler/", '<span class="project-nav-index">03</span><span>Compiler</span>')}
                ${anchorGroup("/docs/compiler/")}
              </li>
              <li class="project-nav-stage">
                ${pageLink("/docs/applications/", '<span class="project-nav-index">04</span><span>Applications</span>')}
              </li>`)}
          </li>
          <li class="project-nav-utility">${pageLink("/playground/", "Playground", " project-nav-playground")}</li>
          <li>${pageLink("/examples/", "Examples", " project-nav-examples")}</li>
        </ul>
      </nav>
      <a class="project-nav-source" href="https://github.com/etdofreshai/yalisp">View source <span aria-hidden="true">↗</span></a>
    </div>`;

  const navigation = host.querySelector<HTMLElement>(`#${options.navigationId}`)!;
  const dispose = trackActiveSection(navigation, currentPath);
  return { navigation, dispose };
}
