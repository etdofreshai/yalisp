import "./docs.css";
import "./project-navigation.css";
import { runDomApplication } from "./dom-lisp";
import compilerSource from "../public/yalisp/compiler.lisp?raw";
import pageSource from "./site/compiler-page.lisp?raw";

const root = document.querySelector<HTMLElement>("[data-dom-lisp-root]");
if (!root) throw new Error("The Compiler page is missing its DOM Lisp root.");

void runDomApplication(root, [
  `(define documented-source ${JSON.stringify(compilerSource)})`,
  pageSource
]);
