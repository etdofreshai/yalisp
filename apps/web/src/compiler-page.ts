import "./project-navigation.css";
import { mountDomLispChrome } from "./dom-lisp-chrome";
import { runDomApplication } from "./dom-lisp";
import compilerSource from "../public/yalisp/compiler.lisp?raw";
import pageSource from "./site/compiler-page.lisp?raw";

const root = document.querySelector<HTMLElement>("[data-dom-lisp-root]");
if (!root) throw new Error("The Compiler page is missing its DOM Lisp root.");

let disposeChrome = () => {};
void runDomApplication(root, [
  `(define documented-source ${JSON.stringify(compilerSource)})`,
  pageSource
], {
  beforeRender: () => disposeChrome(),
  afterRender: (renderedRoot) => { disposeChrome = mountDomLispChrome(renderedRoot, "expanded"); }
});
