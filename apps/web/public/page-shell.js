// The executable DOM-Lisp pages replace this immediately. Keeping the shared
// chrome present during seed startup prevents an empty-page flash on navigation.
(() => {
  const root = document.querySelector("[data-dom-lisp-root]");
  if (!root || root.childElementCount) return;
  const isDark = document.documentElement.dataset.theme !== "light";
  root.innerHTML = `<header class="docs-header" aria-busy="true"><a class="brand" href="/" aria-label="YALisp home">Y<span>A</span>LISP</a><div class="header-actions"><span class="theme-toggle" aria-hidden="true">${isDark ? "☀" : "◐"}<span>${isDark ? "Light" : "Dark"}</span></span><span class="docs-menu" aria-hidden="true"><span></span><span></span></span></div></header><div class="docs-shell page-shell-placeholder"></div>`;
})();
