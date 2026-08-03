import "./docs.css";
import "./project-navigation.css";
import { runDomApplication } from "./dom-lisp";
import foundationSource from "./site/foundation.lisp?raw";

const root = document.querySelector<HTMLElement>("[data-dom-lisp-root]");
if (!root) throw new Error("The Foundation page is missing its DOM Lisp root.");

void runDomApplication(root, foundationSource);
