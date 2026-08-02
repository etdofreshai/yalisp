import "./docs.css";
import "./seed-runtime";

const themeToggle = document.querySelector<HTMLButtonElement>("[data-theme-toggle]");
const themeColor = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]');

if (!themeToggle) throw new Error("The YALISP Playground is missing its theme toggle.");

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
