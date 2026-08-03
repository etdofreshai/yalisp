import "./docs";
import "./examples.css";
import { mountHelloWorld } from "./examples/hello-world/browser-app";
import { mountAsteroids } from "./examples/asteroids/app";
import { runApplication } from "./examples/runtime/lisp-application";
import pongApplicationSource from "./examples/pong/app.lisp?raw";
import breakoutApplicationSource from "./examples/breakout/app.lisp?raw";
import asteroidsApplicationSource from "./examples/asteroids/app?raw";
import helloBrowserSource from "./examples/hello-world/browser-app?raw";
import helloLanguageSource from "./examples/hello-world/hello.lisp?raw";
import helloCliSource from "../examples/hello-world/cli.mjs?raw";
import lispApplicationRuntimeSource from "./examples/runtime/lisp-application?raw";

document.querySelectorAll<HTMLElement>('[data-seed-app="hello-world"]').forEach(mountHelloWorld);
document.querySelectorAll<HTMLElement>('[data-lisp-app="pong"]').forEach((root) => { void runApplication(root, pongApplicationSource); });
document.querySelectorAll<HTMLElement>('[data-lisp-app="breakout"]').forEach((root) => { void runApplication(root, breakoutApplicationSource); });
document.querySelectorAll<HTMLElement>('[data-portable-app="asteroids"]').forEach(mountAsteroids);

document.querySelectorAll<HTMLElement>("[data-application-source]").forEach((target) => {
  if (target.dataset.applicationSource === "breakout") target.textContent = breakoutApplicationSource;
  if (target.dataset.applicationSource === "asteroids") target.textContent = asteroidsApplicationSource;
});
document.querySelectorAll<HTMLElement>("[data-hello-browser-source]").forEach((target) => { target.textContent = helloBrowserSource; });
document.querySelectorAll<HTMLElement>("[data-hello-language-source]").forEach((target) => { target.textContent = helloLanguageSource.trim(); });
document.querySelectorAll<HTMLElement>("[data-hello-cli-source]").forEach((target) => { target.textContent = helloCliSource; });
document.querySelectorAll<HTMLElement>("[data-lisp-application-source]").forEach((target) => {
  if (target.dataset.lispApplicationSource === "pong") target.textContent = pongApplicationSource;
  if (target.dataset.lispApplicationSource === "breakout") target.textContent = breakoutApplicationSource;
});
document.querySelectorAll<HTMLElement>("[data-lisp-runtime-source]").forEach((target) => {
  target.textContent = lispApplicationRuntimeSource;
});
