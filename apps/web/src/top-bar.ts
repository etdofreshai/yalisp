type Theme = "light" | "dark";

function currentTheme(): Theme {
  return document.documentElement.dataset.theme === "light" ? "light" : "dark";
}

/** The final, interactive YALISP top bar is rendered from this one contract. */
export function renderTopBar(root: ParentNode = document) {
  const header = root.querySelector<HTMLElement>(".site-header, .docs-header");
  if (!header) return;

  const brand = header.querySelector<HTMLAnchorElement>(".brand");
  if (brand) {
    const accent = Object.assign(document.createElement("span"), {
      className: "brand-accent",
      textContent: "A"
    });
    brand.replaceChildren("Y", accent, "LISP");
    brand.setAttribute("aria-label", "YALisp home");
  }

  const themeToggle = header.querySelector<HTMLButtonElement>(".theme-toggle");
  if (themeToggle) {
    const theme = currentTheme();
    const isDark = theme === "dark";
    const icon = Object.assign(document.createElement("span"), { textContent: isDark ? "☀" : "◐" });
    icon.setAttribute("aria-hidden", "true");
    const label = Object.assign(document.createElement("span"), { textContent: isDark ? "Light" : "Dark" });
    themeToggle.replaceChildren(icon, label);
    themeToggle.setAttribute("aria-pressed", String(isDark));
    themeToggle.setAttribute("aria-label", `Switch to ${isDark ? "light" : "dark"} mode`);
  }

  header.querySelector<HTMLButtonElement>(".menu-button, .docs-menu")?.setAttribute("aria-label", "Toggle project navigation");
}
