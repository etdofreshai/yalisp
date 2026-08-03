import "./docs";
import "./examples.css";
import { runApplication } from "./examples/runtime/lisp-application";
import helloWorldApplicationSource from "./examples/hello-world/app.lisp?raw";
import pongApplicationSource from "./examples/pong/app.lisp?raw";
import breakoutApplicationSource from "./examples/breakout/app.lisp?raw";
import asteroidsApplicationSource from "./examples/asteroids/app.lisp?raw";
import helloCliSource from "../examples/hello-world/cli.mjs?raw";
import lispApplicationRuntimeSource from "./examples/runtime/lisp-application?raw";

document.querySelectorAll<HTMLElement>('[data-lisp-app="hello-world"]').forEach((root) => { void runApplication(root, helloWorldApplicationSource); });
document.querySelectorAll<HTMLElement>('[data-lisp-app="pong"]').forEach((root) => { void runApplication(root, pongApplicationSource); });
document.querySelectorAll<HTMLElement>('[data-lisp-app="breakout"]').forEach((root) => { void runApplication(root, breakoutApplicationSource); });
document.querySelectorAll<HTMLElement>('[data-lisp-app="asteroids"]').forEach((root) => { void runApplication(root, asteroidsApplicationSource); });

document.querySelectorAll<HTMLElement>("[data-application-source]").forEach((target) => {
  if (target.dataset.applicationSource === "breakout") target.textContent = breakoutApplicationSource;
  if (target.dataset.applicationSource === "asteroids") target.textContent = asteroidsApplicationSource;
});
document.querySelectorAll<HTMLElement>("[data-hello-cli-source]").forEach((target) => { target.textContent = helloCliSource; });
document.querySelectorAll<HTMLElement>("[data-lisp-application-source]").forEach((target) => {
  if (target.dataset.lispApplicationSource === "pong") target.textContent = pongApplicationSource;
  if (target.dataset.lispApplicationSource === "breakout") target.textContent = breakoutApplicationSource;
  if (target.dataset.lispApplicationSource === "asteroids") target.textContent = asteroidsApplicationSource;
  if (target.dataset.lispApplicationSource === "hello-world") target.textContent = helloWorldApplicationSource;
});
document.querySelectorAll<HTMLElement>("[data-lisp-runtime-source]").forEach((target) => {
  target.textContent = lispApplicationRuntimeSource;
});
