import "./docs";
import "./examples.css";
import { runApplication } from "./examples/runtime/lisp-application";
import helloWorldApplicationSource from "./examples/hello-world/app.lisp?raw";
import pongApplicationSource from "./examples/pong/app.lisp?raw";
import breakoutApplicationSource from "./examples/breakout/app.lisp?raw";
import asteroidsApplicationSource from "./examples/asteroids/app.lisp?raw";
import wolf3dDefSource from "./examples/wolf3d/wl-def.lisp?raw";
import wolf3dFixedSource from "./examples/wolf3d/wl-fixed.lisp?raw";
import wolf3dMapSource from "./examples/wolf3d/id-ca.lisp?raw";
import wolf3dPageSource from "./examples/wolf3d/id-pm.lisp?raw";
import wolf3dPaletteSource from "./examples/wolf3d/id-vl.lisp?raw";
import wolf3dTablesSource from "./examples/wolf3d/wl-main.lisp?raw";
import wolf3dGameSource from "./examples/wolf3d/wl-game.lisp?raw";
import wolf3dAgentSource from "./examples/wolf3d/wl-agent.lisp?raw";
import wolf3dActorsSource from "./examples/wolf3d/wl-act2.lisp?raw";
import wolf3dDrawSource from "./examples/wolf3d/wl-draw.lisp?raw";
import wolf3dScaleSource from "./examples/wolf3d/wl-scale.lisp?raw";
import wolf3dAppSource from "./examples/wolf3d/app.lisp?raw";

import helloCliSource from "../examples/hello-world/cli.mjs?raw";
import lispApplicationRuntimeSource from "./examples/runtime/lisp-application?raw";

// The Wolf3D application is several Lisp modules, each named for the original
// file it is a port of, in an order that mirrors the game's own build: the
// definitions header, the fixed-point layer, the caching manager, the page
// file, the palette, the tables, the level setup, the player, the actor-world
// prerequisite, the raycaster, and then the program that binds them to this
// host. Each module is evaluated in order in the same resident session; the
// joined text is display-only, so what runs is still shown.
const wolf3dApplicationModules = [
  wolf3dDefSource,
  wolf3dFixedSource,
  wolf3dMapSource,
  wolf3dPageSource,
  wolf3dPaletteSource,
  wolf3dTablesSource,
  wolf3dGameSource,
  wolf3dAgentSource,
  wolf3dActorsSource,
  wolf3dDrawSource,
  wolf3dScaleSource,
  wolf3dAppSource
];
const wolf3dApplicationSource = wolf3dApplicationModules.join("\n");

document.querySelectorAll<HTMLElement>('[data-lisp-app="hello-world"]').forEach((root) => { void runApplication(root, helloWorldApplicationSource); });
document.querySelectorAll<HTMLElement>('[data-lisp-app="pong"]').forEach((root) => { void runApplication(root, pongApplicationSource); });
document.querySelectorAll<HTMLElement>('[data-lisp-app="breakout"]').forEach((root) => { void runApplication(root, breakoutApplicationSource); });
document.querySelectorAll<HTMLElement>('[data-lisp-app="asteroids"]').forEach((root) => { void runApplication(root, asteroidsApplicationSource); });
document.querySelectorAll<HTMLElement>('[data-lisp-app="wolf3d"]').forEach((root) => { void runApplication(root, wolf3dApplicationModules); });

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
  if (target.dataset.lispApplicationSource === "wolf3d") target.textContent = wolf3dApplicationSource;
});
document.querySelectorAll<HTMLElement>("[data-lisp-runtime-source]").forEach((target) => {
  target.textContent = lispApplicationRuntimeSource;
});
