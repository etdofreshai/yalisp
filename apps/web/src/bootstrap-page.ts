import "./docs.css";
import "./project-navigation.css";
import { runDomApplication } from "./dom-lisp";
import bootstrapSource from "../public/yalisp/boot.lisp?raw";
import pageSource from "./site/bootstrap-page.lisp?raw";

const root = document.querySelector<HTMLElement>("[data-dom-lisp-root]");
if (!root) throw new Error("The Bootstrap page is missing its DOM Lisp root.");
void runDomApplication(root, [`(define documented-source ${JSON.stringify(bootstrapSource)})`, pageSource]);
