import "./docs.css";
import "./project-navigation.css";
import { runDomApplication } from "./dom-lisp";
import seedWat from "./seed/bootstrap.wat?raw";
import seedPageSource from "./site/seed-page.lisp?raw";

const root = document.querySelector<HTMLElement>("[data-dom-lisp-root]");
if (!root) throw new Error("The Seed page is missing its DOM Lisp root.");

void runDomApplication(root, [`(define documented-source ${JSON.stringify(seedWat)})`, seedPageSource]);
