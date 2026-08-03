const desktopSidebarKey = "yalisp-sidebar-desktop-open";
const mobileQuery = "(max-width: 760px)";

type SidebarOptions = {
  defaultDesktopOpen: boolean;
  header?: HTMLElement | null;
  shell?: HTMLElement | null;
  menuButton: HTMLButtonElement;
  root: HTMLElement | Document;
};

function savedDesktopState(defaultDesktopOpen: boolean) {
  const saved = localStorage.getItem(desktopSidebarKey);
  return saved === null ? defaultDesktopOpen : saved === "true";
}

/**
 * Keeps the shared desktop sidebar preference across routes. Mobile navigation
 * is intentionally transient: it starts closed on every page and closes after
 * choosing a link.
 */
export function mountSidebarState(options: SidebarOptions) {
  const isMobile = () => window.matchMedia(mobileQuery).matches;
  const applyDesktop = (open: boolean) => {
    options.header?.classList.toggle("menu-open", open);
    options.shell?.classList.toggle("sidebar-collapsed", !open);
    options.menuButton.setAttribute("aria-expanded", String(open));
  };
  const closeMobile = () => {
    options.header?.classList.remove("menu-open");
    options.shell?.classList.remove("nav-open");
    options.menuButton.setAttribute("aria-expanded", "false");
  };
  const applyInitialState = () => {
    if (isMobile()) {
      const menuIsAlreadyOpen = options.header?.classList.contains("menu-open") || options.shell?.classList.contains("nav-open");
      if (!menuIsAlreadyOpen) closeMobile();
      return;
    }
    applyDesktop(savedDesktopState(options.defaultDesktopOpen));
  };

  applyInitialState();

  const onCaptureClick = (event: Event) => {
    const target = event.target instanceof Element ? event.target : null;
    if (!target) return;
    const menu = target.closest<HTMLButtonElement>(".menu-button, .docs-menu");
    if (menu === options.menuButton) {
      if (isMobile()) return;
      const currentlyOpen = options.header
        ? options.header.classList.contains("menu-open")
        : !options.shell?.classList.contains("sidebar-collapsed");
      const nextOpen = !currentlyOpen;
      localStorage.setItem(desktopSidebarKey, String(nextOpen));
      // DOM Lisp owns the current click and rerenders its shell. Applying the
      // class before that render would toggle it twice; the after-render mount
      // reads the saved preference. Static pages need the immediate update.
      if (options.root instanceof Document) applyDesktop(nextOpen);
      return;
    }
    if (isMobile() && target.closest(".project-navigation a")) closeMobile();
  };
  const onViewportChange = () => {
    if (isMobile()) closeMobile();
    else applyDesktop(savedDesktopState(options.defaultDesktopOpen));
  };
  options.root.addEventListener("click", onCaptureClick, true);
  window.addEventListener("resize", onViewportChange);

  return () => {
    options.root.removeEventListener("click", onCaptureClick, true);
    window.removeEventListener("resize", onViewportChange);
  };
}
