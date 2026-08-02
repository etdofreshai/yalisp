import { codeLines, features, principles } from "@yalisp/site-content";
import "./styles.css";

const featureList = document.querySelector<HTMLElement>("[data-features]");
const code = document.querySelector<HTMLElement>("[data-code]");
const principleRow = document.querySelector<HTMLElement>("[data-principles]");
const menuButton = document.querySelector<HTMLButtonElement>("[data-menu]");
const header = document.querySelector<HTMLElement>("[data-header]");
const copyButton = document.querySelector<HTMLButtonElement>("[data-copy]");
const year = document.querySelector<HTMLElement>("[data-year]");
const themeToggle = document.querySelector<HTMLButtonElement>("[data-theme-toggle]");

if (!featureList || !code || !principleRow || !menuButton || !header || !copyButton || !year || !themeToggle) {
  throw new Error("The YALisp landing page is missing a required UI element.");
}

featureList.innerHTML = features
  .map(
    ({ index, title, description, token }) => `
      <article class="feature-card reveal-on-scroll">
        <div class="feature-heading">
          <span class="feature-index">${index}</span>
          <span class="feature-token" aria-hidden="true">${token}</span>
        </div>
        <h3>${title}</h3>
        <p>${description}</p>
      </article>`
  )
  .join("");

code.innerHTML = codeLines
  .map(
    ({ number, html }) =>
      `<span class="code-line"><span class="line-number">${number}</span><span>${html || "&nbsp;"}</span></span>`
  )
  .join("");

principleRow.innerHTML = principles
  .map(
    (principle, index) => `
      <div class="principle reveal-on-scroll">
        <span>0${index + 1}</span>
        <strong>${principle}</strong>
      </div>`
  )
  .join("");

year.textContent = new Date().getFullYear().toString();

const themeColor = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]');

function setTheme(theme: "light" | "dark") {
  document.documentElement.dataset.theme = theme;
  localStorage.setItem("yalisp-theme", theme);
  const isDark = theme === "dark";
  themeToggle!.setAttribute("aria-pressed", String(isDark));
  themeToggle!.setAttribute("aria-label", `Switch to ${isDark ? "light" : "dark"} mode`);
  themeToggle!.querySelector(".theme-toggle-icon")!.textContent = isDark ? "☀" : "◐";
  themeToggle!.querySelector(".theme-toggle-label")!.textContent = isDark ? "Light" : "Dark";
  if (themeColor) themeColor.content = isDark ? "#101310" : "#f0eeea";
}

const savedTheme = localStorage.getItem("yalisp-theme");
setTheme(savedTheme === "light" ? "light" : "dark");

themeToggle.addEventListener("click", () => {
  setTheme(document.documentElement.dataset.theme === "dark" ? "light" : "dark");
});

menuButton.addEventListener("click", () => {
  const isOpen = header.classList.toggle("menu-open");
  menuButton.setAttribute("aria-expanded", String(isOpen));
});

document.querySelectorAll<HTMLAnchorElement>(".nav a").forEach((link) => {
  link.addEventListener("click", () => {
    header.classList.remove("menu-open");
    menuButton.setAttribute("aria-expanded", "false");
  });
});

const plainCode = `;; a tiny taste of YALisp
(define factorial
  (lambda (n)
    (if (<= n 1)
      1
      (* n (factorial (- n 1))))))

(factorial 6) ; => 720`;

copyButton.addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText(plainCode);
    copyButton.textContent = "Copied";
    window.setTimeout(() => {
      copyButton.textContent = "Copy";
    }, 1600);
  } catch {
    copyButton.textContent = "Select code";
  }
});

const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.18 }
);

document.querySelectorAll(".reveal-on-scroll").forEach((element) => observer.observe(element));
