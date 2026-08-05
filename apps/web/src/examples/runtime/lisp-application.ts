import { createSeedSession } from "../../seed-runtime";
import { expandIndexedSurface } from "./indexed-surface";
import { createApplicationDriver } from "./application-driver";
import { mountDeclaredAssets } from "./asset-mount";
import { atomText, directive, directives, displayText, isList, listAt, numberAt, parseLispValue, printLispValue, textAt, type LispList, type LispValue } from "./lisp-value";

// The DOM Lisp host reads and prints values through this same binding.
export { parseLispValue, printLispValue };

type MountSpec = {
  width: number;
  height: number;
  title: string;
  controls: Array<{ action: string; mode: "hold" | "press"; label: string; keys: string[] }>;
  indexedSurface?: { palette: string[] };
};

type TimingSpec = { tickRateHz: number; ticksPerAdvance: number };

// Applications that predate the timing declaration keep the host's original
// ten-tick cadence. New applications declare their own logical tick rate with
// app.timing, so the host schedules ticks without owning simulation rules.
const legacyTickRateHz = 10;
// The tick clock is logical, not wall-clock: at most this many ticks are
// replayed to catch up after a slow frame, and the remaining arrears are
// dropped rather than queued.
const maxCatchUpTicks = 4;
const palette = ["#080a08", "#f2f0e8", "#c9f85a", "#fa5b35", "#aaa9a1"];

export function parseMountSpec(value: LispValue): MountSpec {
  if (!isList(value) || textAt(value, 0, "mount tag") !== "mount") throw new Error("The Lisp application must return a (mount ...) form.");
  const controlsValue = listAt(value, 4);
  if (!controlsValue || !isList(controlsValue)) throw new Error("The Lisp application's controls must be a list.");
  const surfaceValue = listAt(value, 5);
  let indexedSurface: MountSpec["indexedSurface"];
  if (surfaceValue) {
    if (!isList(surfaceValue) || textAt(surfaceValue, 0, "surface tag") !== "surface" || textAt(surfaceValue, 1, "surface format") !== "indexed8") {
      throw new Error("A Lisp application surface must be a (surface indexed8 (...palette colors...)) form.");
    }
    const paletteValue = listAt(surfaceValue, 2);
    if (!paletteValue || !isList(paletteValue)) throw new Error("An indexed surface must declare a palette list.");
    const colors = paletteValue.map((entry) => textAt([entry], 0, "palette color"));
    if (!colors.length || colors.length > 256) throw new Error("An indexed surface palette must contain one to 256 colors.");
    indexedSurface = { palette: colors };
  }
  return {
    width: numberAt(value, 1, "canvas width"),
    height: numberAt(value, 2, "canvas height"),
    title: displayText(textAt(value, 3, "title")),
    controls: controlsValue.map((value) => {
      if (!isList(value)) throw new Error("A Lisp application control must be a list.");
      const keys = listAt(value, 3);
      if (!keys || !isList(keys)) throw new Error("A Lisp application control key map must be a list.");
      const mode = textAt(value, 1, "control mode");
      if (mode !== "hold" && mode !== "press") throw new Error("A Lisp application control mode must be hold or press.");
      return { action: textAt(value, 0, "control action"), mode, label: displayText(textAt(value, 2, "control label")), keys: keys.map((key) => textAt([key], 0, "control key")) };
    }),
    indexedSurface
  };
}

export function parseTimingSpec(value?: LispValue): TimingSpec {
  if (value === undefined) return { tickRateHz: legacyTickRateHz, ticksPerAdvance: 1 };
  if (!isList(value) || textAt(value, 0, "timing tag") !== "timing") {
    throw new Error("A Lisp application timing declaration must be a (timing tick-rate-hz [ticks-per-advance]) form.");
  }
  const tickRateHz = numberAt(value, 1, "tick rate");
  if (!Number.isFinite(tickRateHz) || tickRateHz <= 0 || tickRateHz > 1000) {
    throw new Error("A Lisp application tick rate must be greater than zero and no more than 1000 Hz.");
  }
  const ticksPerAdvance = listAt(value, 2) === undefined ? 1 : numberAt(value, 2, "ticks per advance");
  if (!Number.isInteger(ticksPerAdvance) || ticksPerAdvance <= 0) {
    throw new Error("A Lisp application's ticks per advance must be a positive integer.");
  }
  return { tickRateHz, ticksPerAdvance };
}

function color(value: LispValue) {
  if (typeof value === "string" && /^#[0-9a-f]{3,8}$/i.test(value)) return value;
  const index = typeof value === "number" ? value : 1;
  return palette[index] ?? palette[1]!;
}

function drawCommands(context: CanvasRenderingContext2D, commands: LispList) {
  for (const command of commands) {
    if (!isList(command)) continue;
    const kind = atomText(listAt(command, 0) ?? "");
    if (kind === "clear") {
      context.fillStyle = color(listAt(command, 1) ?? 0);
      context.fillRect(0, 0, context.canvas.width, context.canvas.height);
    } else if (kind === "rect") {
      context.fillStyle = color(listAt(command, 5) ?? 1);
      context.fillRect(numberAt(command, 1, "rectangle x"), numberAt(command, 2, "rectangle y"), numberAt(command, 3, "rectangle width"), numberAt(command, 4, "rectangle height"));
    } else if (kind === "circle") {
      context.fillStyle = color(listAt(command, 4) ?? 1);
      context.beginPath();
      context.arc(numberAt(command, 1, "circle x"), numberAt(command, 2, "circle y"), numberAt(command, 3, "circle radius"), 0, Math.PI * 2);
      context.fill();
    } else if (kind === "line") {
      context.strokeStyle = color(listAt(command, 5) ?? 1);
      context.lineWidth = numberAt(command, 6, "line width");
      context.beginPath();
      context.moveTo(numberAt(command, 1, "line x1"), numberAt(command, 2, "line y1"));
      context.lineTo(numberAt(command, 3, "line x2"), numberAt(command, 4, "line y2"));
      context.stroke();
    }
  }
}

function inputForm(held: ReadonlySet<string>, pressed: ReadonlySet<string>, controls: MountSpec["controls"]) {
  return `(${controls.map(({ action }) => `(${action} ${held.has(action) || pressed.has(action) ? 1 : 0})`).join(" ")})`;
}

export async function runApplication(root: HTMLElement, source: string) {
  // Applications are long-lived Lisp programs. Reusing one initialized seed
  // preserves their definitions and avoids recompiling the entire source for
  // every simulation frame; the host still owns only input delivery and draw
  // command presentation.
  const session = await createSeedSession("bootstrap");
  // One long-lived interactive session is declared to be worth this much
  // memory. The seed has no collector yet, so this extends a session's
  // lifetime rather than removing its limit; an application that needs more
  // reserves more from its own Lisp source, and exhaustion still surfaces as
  // the evaluator's own truthful diagnostic.
  session.evaluateQuietly("(heap.reserve 33554432)");
  session.evaluateQuietly(source);
  // A program that reads original data files declares them itself and is
  // handed their handles before it mounts. Retrieval failures are reported to
  // the program rather than raised here: a checkout without the original data
  // still loads the page, and what to say about that is the program's to say.
  await mountDeclaredAssets(session, async (path) => {
    const response = await fetch(path);
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    return new Uint8Array(await response.arrayBuffer());
  });
  const evaluateOutput = async (form: string) => session.evaluate(form);
  const driver = createApplicationDriver(session);
  const spec = parseMountSpec(parseLispValue(await evaluateOutput("(app.mount)")));
  const timing = parseTimingSpec(session.evaluate("(bound? 'app.timing)") === "true"
    ? parseLispValue(await evaluateOutput("(app.timing)"))
    : undefined);
  const frameIntervalMs = (1000 * timing.ticksPerAdvance) / timing.tickRateHz;
  root.replaceChildren();
  root.setAttribute("aria-label", `${spec.title} YALISP application`);
  const canvas = document.createElement("canvas");
  canvas.width = spec.width;
  canvas.height = spec.height;
  canvas.style.aspectRatio = `${spec.width} / ${spec.height}`;
  canvas.style.imageRendering = "pixelated";
  canvas.setAttribute("aria-label", `Interactive ${spec.title} application`);
  root.append(canvas);
  const context = canvas.getContext("2d");
  if (!context) throw new Error("This browser cannot create the Canvas 2D application binding.");
  const indexedFrame = spec.indexedSurface ? context.createImageData(spec.width, spec.height) : undefined;
  const toolbar = document.createElement("div");
  toolbar.className = "game-toolbar";
  const toggle = document.createElement("button");
  toggle.type = "button";
  toggle.textContent = `Play ${spec.title}`;
  toggle.setAttribute("aria-pressed", "false");
  const status = document.createElement("output");
  status.textContent = "paused";
  toolbar.append(toggle, status);
  root.append(toolbar);
  const controls = document.createElement("div");
  controls.className = "game-touch";
  controls.setAttribute("aria-label", `${spec.title} touch controls`);
  root.append(controls);

  const held = new Set<string>();
  const pressed = new Set<string>();
  const byKey = new Map<string, { action: string; mode: "hold" | "press" }>();
  spec.controls.forEach((control) => {
    control.keys.forEach((key) => byKey.set(key.toLowerCase(), control));
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = control.label;
    controls.append(button);
    if (control.mode === "press") button.addEventListener("click", () => {
      pressed.add(control.action);
      if (!running) toggle.click();
    });
    else {
      const begin = () => { held.add(control.action); button.classList.add("active"); };
      const end = () => { held.delete(control.action); button.classList.remove("active"); };
      button.addEventListener("pointerdown", begin);
      button.addEventListener("pointerup", end);
      button.addEventListener("pointercancel", end);
      button.addEventListener("pointerleave", end);
    }
  });
  window.addEventListener("keydown", (event) => {
    const control = byKey.get(event.key.toLowerCase());
    if (!control) return;
    event.preventDefault();
    if (control.mode === "press") {
      if (!event.repeat) {
        pressed.add(control.action);
        if (!running) toggle.click();
      }
    }
    else held.add(control.action);
  });
  window.addEventListener("keyup", (event) => {
    const control = byKey.get(event.key.toLowerCase());
    if (control?.mode === "hold") held.delete(control.action);
  });

  driver.attach();
  let running = false;
  let busy = false;
  let lastStep = 0;
  let displayedResult: string | undefined;
  const render = async (value: LispValue, active: boolean, resultText?: string) => {
    const values = directives(value);
    const draw = directive(values, "draw");
    if (draw) drawCommands(context, draw.slice(1));
    const framebuffer = directive(values, "framebuffer");
    if (framebuffer) {
      if (!spec.indexedSurface || !indexedFrame) throw new Error("The Lisp application requested a framebuffer without declaring an indexed surface.");
      const expression = textAt(framebuffer, 1, "framebuffer expression");
      if (!/^[A-Za-z0-9_.!?+*/<>=-]+$/.test(expression)) throw new Error("A framebuffer expression must be a Lisp symbol.");
      indexedFrame.data.set(expandIndexedSurface(session.evaluateBytes(`(${expression})`), spec.width, spec.height, spec.indexedSurface.palette));
      context.putImageData(indexedFrame, 0, 0);
    }
    const summary = directive(values, "status");
    status.textContent = resultText ?? (summary ? `${summary.slice(1).map(atomText).join(" · ")} · ${active ? "playing" : "paused"}` : active ? "playing" : "paused");
  };
  await render(driver.present(), false);
  toggle.addEventListener("click", () => {
    running = !running;
    lastStep = 0;
    toggle.textContent = `${running ? "Pause" : "Play"} ${spec.title}`;
    toggle.setAttribute("aria-pressed", String(running));
  });
  const frame = async (time: number) => {
    if (running && !busy) {
      busy = true;
      try {
        if (!lastStep) lastStep = time;
        let ticked = false;
        let requested = false;
        // A tick that runs slower than the simulation cadence must not build an
        // unbounded backlog: catch up by at most maxCatchUpTicks and drop the
        // rest of the arrears, so a slow frame degrades instead of spiralling.
        let budget = maxCatchUpTicks;
        while (time - lastStep >= frameIntervalMs) {
          if (budget === 0) { lastStep = time; break; }
          requested = driver.tick(inputForm(held, pressed, spec.controls)).resultRequested || requested;
          pressed.clear();
          lastStep += frameIntervalMs;
          budget -= 1;
          ticked = true;
        }
        if (ticked) {
          const result = driver.present();
          if (requested || directive(directives(result), "result")) displayedResult = await evaluateOutput("(app.result)");
          await render(result, true, displayedResult);
        }
      } catch (error) {
        running = false;
        toggle.textContent = `Play ${spec.title}`;
        toggle.setAttribute("aria-pressed", "false");
        status.textContent = `Interpreter stopped: ${error instanceof Error ? error.message : String(error)}`;
      } finally {
        busy = false;
      }
    }
    requestAnimationFrame(frame);
  };
  requestAnimationFrame(frame);
}
