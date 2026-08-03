import "./docs";
import "./examples.css";
import { mountHelloWorld } from "./examples/hello-world/browser-app";
import { mountPong } from "./examples/pong/app";
import { mountBreakout } from "./examples/breakout/app";
import { mountAsteroids } from "./examples/asteroids/app";
import pongApplicationSource from "./examples/pong/app?raw";
import breakoutApplicationSource from "./examples/breakout/app?raw";
import asteroidsApplicationSource from "./examples/asteroids/app?raw";
import helloBrowserSource from "./examples/hello-world/browser-app?raw";
import helloLanguageSource from "./examples/hello-world/hello.lisp?raw";
import helloCliSource from "../examples/hello-world/cli.mjs?raw";
import portableApplicationSource from "./examples/runtime/portable-app?raw";

document.querySelectorAll<HTMLElement>('[data-seed-app="hello-world"]').forEach(mountHelloWorld);
document.querySelectorAll<HTMLElement>('[data-portable-app="pong"]').forEach(mountPong);
document.querySelectorAll<HTMLElement>('[data-portable-app="breakout"]').forEach(mountBreakout);
document.querySelectorAll<HTMLElement>('[data-portable-app="asteroids"]').forEach(mountAsteroids);

document.querySelectorAll<HTMLElement>("[data-application-source]").forEach((target) => {
  if (target.dataset.applicationSource === "pong") target.textContent = pongApplicationSource;
  if (target.dataset.applicationSource === "breakout") target.textContent = breakoutApplicationSource;
  if (target.dataset.applicationSource === "asteroids") target.textContent = asteroidsApplicationSource;
});
document.querySelectorAll<HTMLElement>("[data-hello-browser-source]").forEach((target) => { target.textContent = helloBrowserSource; });
document.querySelectorAll<HTMLElement>("[data-hello-language-source]").forEach((target) => { target.textContent = helloLanguageSource.trim(); });
document.querySelectorAll<HTMLElement>("[data-hello-cli-source]").forEach((target) => { target.textContent = helloCliSource; });
document.querySelectorAll<HTMLElement>("[data-portable-runtime-source]").forEach((target) => {
  target.textContent = portableApplicationSource;
});
