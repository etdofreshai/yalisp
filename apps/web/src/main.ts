import "./styles.css";
import "./project-navigation.css";
import { mountDomLispChrome } from "./dom-lisp-chrome";
import { runDomApplication } from "./dom-lisp";
import landingSource from "./site/landing.lisp?raw";

const root = document.querySelector<HTMLElement>("[data-dom-lisp-root]");
if (!root) throw new Error("The YALISP landing page needs its DOM Lisp mount point.");

let disposeChrome = () => {};
void runDomApplication(root, landingSource, {
  beforeRender: () => disposeChrome(),
  afterRender: (renderedRoot) => { disposeChrome = mountDomLispChrome(renderedRoot, "collapsed"); }
}).catch((error) => {
  root.textContent = `YALISP DOM application failed to start: ${error instanceof Error ? error.message : String(error)}`;
});
