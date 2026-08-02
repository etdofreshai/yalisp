import "./docs.css";
import "./project-navigation.css";
import { assemblyInventory } from "./assembly-inventory";
import { mountProjectNavigation } from "./project-navigation";

const menuButton = document.querySelector<HTMLButtonElement>("[data-docs-menu]");
const shell = document.querySelector<HTMLElement>("[data-docs-shell]");
const themeToggle = document.querySelector<HTMLButtonElement>("[data-theme-toggle]");
const themeColor = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]');
const docsNav = document.querySelector<HTMLElement>(".docs-nav");

if (!menuButton || !shell || !themeToggle || !docsNav) {
  throw new Error("The YALisp docs page is missing a required UI element.");
}

const currentPath = window.location.pathname.replace(/index\.html$/, "");
shell.dataset.navigationDefault = "expanded";
docsNav.setAttribute("aria-label", "Project navigation");
const projectNav = mountProjectNavigation(docsNav, {
  currentPath,
  initialState: "expanded",
  navigationId: "project-navigation"
});
const sidebarToggle = document.createElement("button");
sidebarToggle.className = "sidebar-toggle";
sidebarToggle.type = "button";
sidebarToggle.dataset.sidebarToggle = "";
sidebarToggle.innerHTML = '<span aria-hidden="true">←</span><span>Collapse</span>';
docsNav.prepend(sidebarToggle);
menuButton.setAttribute("aria-controls", projectNav.id);
menuButton.setAttribute("aria-label", "Toggle project navigation");
menuButton.setAttribute("aria-expanded", "false");

function setSidebarCollapsed(collapsed: boolean) {
  shell!.classList.toggle("sidebar-collapsed", collapsed);
  sidebarToggle.setAttribute("aria-expanded", String(!collapsed));
  sidebarToggle.setAttribute("aria-label", `${collapsed ? "Expand" : "Collapse"} documentation navigation`);
  sidebarToggle.querySelector("span")!.textContent = collapsed ? "→" : "←";
  sidebarToggle.querySelector("span + span")!.textContent = collapsed ? "Expand" : "Collapse";
}

setSidebarCollapsed(false);
sidebarToggle.addEventListener("click", () => setSidebarCollapsed(!shell!.classList.contains("sidebar-collapsed")));

function setTheme(theme: "light" | "dark", persist = false) {
  document.documentElement.dataset.theme = theme;
  if (persist) localStorage.setItem("yalisp-theme", theme);
  const isDark = theme === "dark";
  themeToggle!.setAttribute("aria-pressed", String(isDark));
  themeToggle!.setAttribute("aria-label", `Switch to ${isDark ? "light" : "dark"} mode`);
  themeToggle!.querySelector("span")!.textContent = isDark ? "☀" : "◐";
  themeToggle!.querySelector("span + span")!.textContent = isDark ? "Light" : "Dark";
  if (themeColor) themeColor.content = isDark ? "#101310" : "#f0eeea";
}

setTheme(document.documentElement.dataset.theme === "light" ? "light" : "dark");

themeToggle.addEventListener("click", () => {
  setTheme(document.documentElement.dataset.theme === "dark" ? "light" : "dark", true);
});

menuButton.addEventListener("click", () => {
  const isOpen = shell.classList.toggle("nav-open");
  menuButton.setAttribute("aria-expanded", String(isOpen));
});

document.querySelectorAll<HTMLAnchorElement>(".project-navigation a").forEach((link) => {
  link.addEventListener("click", () => {
    shell.classList.remove("nav-open");
    menuButton.setAttribute("aria-expanded", "false");
  });
});

document.addEventListener("keydown", (event) => {
  if (event.key !== "Escape" || !shell.classList.contains("nav-open")) return;
  shell.classList.remove("nav-open");
  menuButton.setAttribute("aria-expanded", "false");
  menuButton.focus();
});

const inventory = document.querySelector<HTMLElement>("[data-assembly-inventory]");
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
