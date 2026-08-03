import { mountProjectNavigation } from "./project-navigation";
import { mountSidebarState } from "./sidebar-state";
import { renderTopBar } from "./top-bar";

/**
 * The DOM Lisp pages declare the shell and menu state. This tiny browser-side
 * adapter supplies the one shared navigation tree to the declared nav mount so
 * landing, docs, Playground, and examples never drift into separate menus.
 */
export function mountDomLispChrome(root: HTMLElement, initialState: "collapsed" | "expanded") {
  renderTopBar(root);
  const host = root.querySelector<HTMLElement>("[data-project-navigation]");
  if (!host) return () => {};

  const { navigation, dispose } = mountProjectNavigation(host, {
    currentPath: window.location.pathname,
    initialState,
    navigationId: "project-navigation"
  });

  const menuButton = root.querySelector<HTMLButtonElement>(".menu-button, .docs-menu");
  if (!menuButton) throw new Error("The DOM Lisp shell needs a navigation button.");
  const disposeSidebar = mountSidebarState({
    root,
    menuButton,
    defaultDesktopOpen: initialState === "expanded",
    header: root.querySelector<HTMLElement>(".site-header, .docs-header"),
    shell: root.querySelector<HTMLElement>(".docs-shell")
  });

  return () => {
    disposeSidebar();
    dispose();
  };
}
