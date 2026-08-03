import "./docs.css";
import "./project-navigation.css";
import { mountDomLispChrome } from "./dom-lisp-chrome";
import { runDomApplication } from "./dom-lisp";
import foundationSource from "./site/foundation.lisp?raw";

const root = document.querySelector<HTMLElement>("[data-dom-lisp-root]");
if (!root) throw new Error("The Foundation page is missing its DOM Lisp root.");

let disposeChrome = () => {};
void runDomApplication(root, foundationSource, {
  beforeRender: () => disposeChrome(),
  afterRender: (renderedRoot) => { disposeChrome = mountDomLispChrome(renderedRoot, "expanded"); }
});
