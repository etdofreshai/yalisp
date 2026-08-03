import "./project-navigation.css";
import { mountDomLispChrome } from "./dom-lisp-chrome";
import { runDomApplication } from "./dom-lisp";
import bootstrapSource from "../public/yalisp/boot.lisp?raw";
import pageSource from "./site/bootstrap-page.lisp?raw";

const root = document.querySelector<HTMLElement>("[data-dom-lisp-root]");
if (!root) throw new Error("The Bootstrap page is missing its DOM Lisp root.");
let disposeChrome = () => {};
void runDomApplication(root, [`(define documented-source ${JSON.stringify(bootstrapSource)})`, pageSource], {
  beforeRender: () => disposeChrome(),
  afterRender: (renderedRoot) => { disposeChrome = mountDomLispChrome(renderedRoot, "expanded"); }
});
