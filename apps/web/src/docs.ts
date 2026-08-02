import "./docs.css";
import { assemblyInventory } from "./assembly-inventory";

const menuButton = document.querySelector<HTMLButtonElement>("[data-docs-menu]");
const shell = document.querySelector<HTMLElement>("[data-docs-shell]");
const themeToggle = document.querySelector<HTMLButtonElement>("[data-theme-toggle]");
const themeColor = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]');
const docsNav = document.querySelector<HTMLElement>(".docs-nav");

if (!menuButton || !shell || !themeToggle || !docsNav) {
  throw new Error("The YALisp docs page is missing a required UI element.");
}

const currentPath = window.location.pathname.replace(/index\.html$/, "");
const isCurrent = (path: string) => currentPath === path ? " active" : "";

docsNav.innerHTML = `
  <button class="sidebar-toggle" type="button" aria-label="Collapse documentation navigation" aria-expanded="true" data-sidebar-toggle><span aria-hidden="true">←</span><span>Collapse</span></button>
  <div class="sidebar-content">
    <a class="back-link" href="/">← Back to launch page</a>
    <p class="nav-label">Documentation</p>
    <nav>
      <a class="${currentPath === "/docs/" ? "active" : ""}" href="/docs/#introduction">Introduction</a>
      <a href="/docs/#getting-started">Getting started</a>
      <a href="/docs/#language">Language guide</a>
      <a class="${isCurrent("/docs/foundation/")}" href="/docs/foundation/">Foundation</a>
      <a class="nav-child${isCurrent("/docs/seed/")}" href="/docs/seed/">Seed</a>
      <a class="nav-child${isCurrent("/docs/bootstrap/")}" href="/docs/bootstrap/">Bootstrap</a>
      <a class="nav-child${isCurrent("/docs/compiler/")}" href="/docs/compiler/">Compiler</a>
      <a class="nav-child${isCurrent("/docs/applications/")}" href="/docs/applications/">Applications</a>
      <a class="${currentPath === "/docs/" ? "" : ""}" href="/docs/#reference-interfaces">Reference interfaces</a>
      <a class="nav-child${isCurrent("/docs/assembly/")}" href="/docs/assembly/">Assembly</a>
      <a class="nav-child${isCurrent("/docs/system-interface/")}" href="/docs/system-interface/">System interface</a>
      <a class="nav-child${isCurrent("/docs/host/")}" href="/docs/host/">Host</a>
      <a class="nav-child${isCurrent("/docs/sdl/")}" href="/docs/sdl/">SDL</a>
      <a href="/docs/#examples">Examples</a>
    </nav>
    <a class="source-link" href="https://github.com/etdofreshai/yalisp">View source <span aria-hidden="true">↗</span></a>
  </div>`;

const sidebarToggle = docsNav.querySelector<HTMLButtonElement>("[data-sidebar-toggle]")!;
function setSidebarCollapsed(collapsed: boolean) {
  shell!.classList.toggle("sidebar-collapsed", collapsed);
  sidebarToggle.setAttribute("aria-expanded", String(!collapsed));
  sidebarToggle.setAttribute("aria-label", `${collapsed ? "Expand" : "Collapse"} documentation navigation`);
  sidebarToggle.querySelector("span")!.textContent = collapsed ? "→" : "←";
  sidebarToggle.querySelector("span + span")!.textContent = collapsed ? "Expand" : "Collapse";
  localStorage.setItem("yalisp-sidebar-collapsed", String(collapsed));
}

setSidebarCollapsed(localStorage.getItem("yalisp-sidebar-collapsed") === "true");
sidebarToggle.addEventListener("click", () => setSidebarCollapsed(!shell!.classList.contains("sidebar-collapsed")));

function setTheme(theme: "light" | "dark") {
  document.documentElement.dataset.theme = theme;
  localStorage.setItem("yalisp-theme", theme);
  const isDark = theme === "dark";
  themeToggle!.setAttribute("aria-pressed", String(isDark));
  themeToggle!.setAttribute("aria-label", `Switch to ${isDark ? "light" : "dark"} mode`);
  themeToggle!.querySelector("span")!.textContent = isDark ? "☀" : "◐";
  themeToggle!.querySelector("span + span")!.textContent = isDark ? "Light" : "Dark";
  if (themeColor) themeColor.content = isDark ? "#101310" : "#f0eeea";
}

setTheme(localStorage.getItem("yalisp-theme") === "light" ? "light" : "dark");

themeToggle.addEventListener("click", () => {
  setTheme(document.documentElement.dataset.theme === "dark" ? "light" : "dark");
});

menuButton.addEventListener("click", () => {
  const isOpen = shell.classList.toggle("nav-open");
  menuButton.setAttribute("aria-expanded", String(isOpen));
});

document.querySelectorAll<HTMLAnchorElement>(".docs-nav a[href*='#']").forEach((link) => {
  link.addEventListener("click", () => {
    shell.classList.remove("nav-open");
    menuButton.setAttribute("aria-expanded", "false");
  });
});

const inventory = document.querySelector<HTMLElement>("[data-function-source]");
function describeFunction(name: string) {
  const verb = name.split(".").at(-1)?.replaceAll("-", " ") ?? name;
  return `Performs ${verb} through this interface, returning a portable YALisp value or a documented condition.`;
}

document.querySelectorAll<HTMLElement>(".interface-catalog article > p").forEach((catalog) => {
  const names = catalog.textContent?.split("·").map((name) => name.trim()).filter(Boolean) ?? [];
  if (!names.length) return;
  const list = document.createElement("ul");
  list.className = "function-reference";
  names.forEach((name) => {
    const item = document.createElement("li");
    item.innerHTML = `<code>${name}</code><span>${describeFunction(name)}</span>`;
    list.append(item);
  });
  catalog.replaceWith(list);
});

if (inventory) {
  inventory.replaceChildren(...[...assemblyInventory].map(([title, functions]) => {
        const details = document.createElement("details");
        details.open = title === "Control flow";
        const summary = document.createElement("summary");
        summary.textContent = `${title} (${functions.length})`;
        const list = document.createElement("ul");
        list.className = "function-reference";
        functions.forEach((name) => {
          const item = document.createElement("li");
          item.innerHTML = `<code>${name}</code><span>${describeFunction(name)}</span>`;
          list.append(item);
        });
        details.append(summary, list);
        return details;
      }));
}
