import "./docs.css";
import { assemblyInventory } from "./assembly-inventory";

const menuButton = document.querySelector<HTMLButtonElement>("[data-docs-menu]");
const shell = document.querySelector<HTMLElement>("[data-docs-shell]");
const themeToggle = document.querySelector<HTMLButtonElement>("[data-theme-toggle]");
const themeColor = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]');

if (!menuButton || !shell || !themeToggle) {
  throw new Error("The YALisp docs page is missing a required UI element.");
}

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

document.querySelectorAll<HTMLAnchorElement>(".docs-nav a[href^='#']").forEach((link) => {
  link.addEventListener("click", () => {
    shell.classList.remove("nav-open");
    menuButton.setAttribute("aria-expanded", "false");
  });
});

const inventory = document.querySelector<HTMLElement>("[data-function-source]");
if (inventory) {
  inventory.replaceChildren(...[...assemblyInventory].map(([title, functions]) => {
        const details = document.createElement("details");
        details.open = title === "Control flow";
        const summary = document.createElement("summary");
        summary.textContent = `${title} (${functions.length})`;
        const list = document.createElement("p");
        list.className = "function-list";
        list.textContent = functions.join(" · ");
        details.append(summary, list);
        return details;
      }));
}
