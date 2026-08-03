import "./docs.css";
import "./project-navigation.css";
import { mountDomLispChrome } from "./dom-lisp-chrome";
import { assemblyInventory } from "./assembly-inventory";
import { runDomApplication } from "./dom-lisp";
import pageSource from "./site/assembly-page.lisp?raw";

const root = document.querySelector<HTMLElement>("[data-dom-lisp-root]");
if (!root) throw new Error("The Assembly page is missing its DOM Lisp root.");

const inventory = [...assemblyInventory]
  .map(([title, functions]) => `(${JSON.stringify(title)} (${functions.map((name) => JSON.stringify(name)).join(" ")}))`)
  .join(" ");

let disposeChrome = () => {};
void runDomApplication(root, [`(define assembly-inventory '(${inventory}))`, pageSource], {
  beforeRender: () => disposeChrome(),
  afterRender: (renderedRoot) => { disposeChrome = mountDomLispChrome(renderedRoot, "expanded"); }
});
