import "./docs.css";
import "./project-navigation.css";
import { runDomApplication } from "./dom-lisp";
import docsOverviewSource from "./site/docs-overview.lisp?raw";

const root = document.querySelector<HTMLElement>("[data-dom-lisp-root]");
if (!root) throw new Error("The documentation overview is missing its DOM Lisp root.");

void runDomApplication(root, docsOverviewSource);
