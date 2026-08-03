import { mountProjectNavigation } from "./project-navigation";

/**
 * The DOM Lisp pages declare the shell and menu state. This tiny browser-side
 * adapter supplies the one shared navigation tree to the declared nav mount so
 * landing, docs, Playground, and examples never drift into separate menus.
 */
export function mountDomLispChrome(root: HTMLElement, initialState: "collapsed" | "expanded") {
  const host = root.querySelector<HTMLElement>("[data-project-navigation]");
  if (!host) return () => {};

  const { navigation, dispose } = mountProjectNavigation(host, {
    currentPath: window.location.pathname,
    initialState,
    navigationId: "project-navigation"
  });

  const closeMenu = () => {
    const shell = root.querySelector<HTMLElement>(".docs-shell");
    const header = root.querySelector<HTMLElement>(".site-header");
    shell?.classList.remove("nav-open", "sidebar-collapsed");
    header?.classList.remove("menu-open");
  };
  navigation.querySelectorAll<HTMLAnchorElement>("a").forEach((link) => link.addEventListener("click", closeMenu));

  return () => {
    dispose();
    navigation.querySelectorAll<HTMLAnchorElement>("a").forEach((link) => link.removeEventListener("click", closeMenu));
  };
}
