import "./docs.css";
import "./project-navigation.css";
import { runDomApplication } from "./dom-lisp";
import pageSource from "./site/applications-page.lisp?raw";

const root = document.querySelector<HTMLElement>("[data-dom-lisp-root]");
if (!root) throw new Error("The Applications page is missing its DOM Lisp root.");

void runDomApplication(root, pageSource);
