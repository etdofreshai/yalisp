import { createSeedSession } from "../../seed-runtime";

type LispValue = number | string | LispValue[];
type LispList = LispValue[];

type MountSpec = {
  width: number;
  height: number;
  title: string;
  controls: Array<{ action: string; mode: "hold" | "press"; label: string; keys: string[] }>;
};

const frameIntervalMs = 100;
const palette = ["#080a08", "#f2f0e8", "#c9f85a", "#fa5b35", "#aaa9a1"];

function isList(value: LispValue): value is LispList {
  return Array.isArray(value);
}

function atomText(value: LispValue) {
  return typeof value === "number" ? String(value) : value;
}

function displayText(value: string) {
  return value.replaceAll("-", " ").replace(/(^|\s)\S/g, (character) => character.toUpperCase());
}

function tokenize(source: string) {
  const tokens: string[] = [];
  let index = 0;
  while (index < source.length) {
    const character = source[index]!;
    if (/\s/.test(character)) { index += 1; continue; }
    if (character === "(" || character === ")") { tokens.push(character); index += 1; continue; }
    if (character === '"') {
      let value = '"';
      index += 1;
      while (index < source.length) {
        const next = source[index]!;
        value += next;
        index += 1;
        if (next === "\\") {
          if (index < source.length) { value += source[index]!; index += 1; }
        } else if (next === '"') break;
      }
      tokens.push(value);
      continue;
    }
    let value = "";
    while (index < source.length && !/[\s()]/.test(source[index]!)) { value += source[index]!; index += 1; }
    tokens.push(value);
  }
  return tokens;
}

export function parseLispValue(source: string): LispValue {
  const tokens = tokenize(source);
  let index = 0;
  const read = (): LispValue => {
    const token = tokens[index++];
    if (token === undefined) throw new Error("The Lisp application returned an incomplete command list.");
    if (token === "(") {
      const values: LispValue[] = [];
      while (tokens[index] !== ")") {
        if (tokens[index] === undefined) throw new Error("The Lisp application returned an unterminated command list.");
        values.push(read());
      }
      index += 1;
      return values;
    }
    if (token === ")") throw new Error("The Lisp application returned an unexpected closing parenthesis.");
    if (token.startsWith('"')) return JSON.parse(token);
    const number = Number(token);
    return Number.isFinite(number) && token !== "" ? number : token;
  };
  const result = read();
  if (index !== tokens.length) throw new Error("The Lisp application returned more than one value.");
  return result;
}

export function printLispValue(value: LispValue): string {
  if (Array.isArray(value)) return `(${value.map(printLispValue).join(" ")})`;
  if (typeof value === "number") return String(value);
  return /^[^\s()";]+$/.test(value) ? value : JSON.stringify(value);
}

function listAt(list: LispList, index: number) {
  return list[index];
}

function numberAt(list: LispList, index: number, label: string) {
  const value = listAt(list, index);
  if (typeof value !== "number") throw new Error(`The Lisp application's ${label} must be a number.`);
  return value;
}

function textAt(list: LispList, index: number, label: string) {
  const value = listAt(list, index);
  if (typeof value !== "string") throw new Error(`The Lisp application's ${label} must be a symbol or string.`);
  return value;
}

function mountSpec(value: LispValue): MountSpec {
  if (!isList(value) || textAt(value, 0, "mount tag") !== "mount") throw new Error("The Lisp application must return a (mount ...) form.");
  const controlsValue = listAt(value, 4);
  if (!controlsValue || !isList(controlsValue)) throw new Error("The Lisp application's controls must be a list.");
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
    })
  };
}

function color(value: LispValue) {
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

function directives(value: LispValue) {
  if (!isList(value)) throw new Error("The Lisp application must return a directive list.");
  return value.filter(isList);
}

function directive(values: LispList[], name: string) {
  return values.find((value) => atomText(value[0] ?? "") === name);
}

function inputForm(held: ReadonlySet<string>, pressed: ReadonlySet<string>, controls: MountSpec["controls"]) {
  return `(${controls.map(({ action }) => `(${action} ${held.has(action) || pressed.has(action) ? 1 : 0})`).join(" ")})`;
}

export async function runApplication(root: HTMLElement, source: string) {
  const evaluate = async (form: string) => {
    const session = await createSeedSession("bootstrap");
    session.evaluateQuietly(source);
    return parseLispValue(session.evaluate(form));
  };
  const spec = mountSpec(await evaluate("(app.mount)"));
  root.replaceChildren();
  root.setAttribute("aria-label", `${spec.title} YALISP application`);
  const canvas = document.createElement("canvas");
  canvas.width = spec.width;
  canvas.height = spec.height;
  canvas.setAttribute("aria-label", `Interactive ${spec.title} application`);
  root.append(canvas);
  const context = canvas.getContext("2d");
  if (!context) throw new Error("This browser cannot create the Canvas 2D application binding.");
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
    if (control.mode === "press") button.addEventListener("click", () => pressed.add(control.action));
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
    if (control.mode === "press") { if (!event.repeat) pressed.add(control.action); }
    else held.add(control.action);
  });
  window.addEventListener("keyup", (event) => {
    const control = byKey.get(event.key.toLowerCase());
    if (control?.mode === "hold") held.delete(control.action);
  });

  let state = await evaluate("(app.initial-state)");
  let running = false;
  let busy = false;
  let lastStep = 0;
  const render = (value: LispValue, active: boolean) => {
    const values = directives(value);
    const draw = directive(values, "draw");
    if (draw) drawCommands(context, draw.slice(1));
    const summary = directive(values, "status");
    status.textContent = summary ? `${summary.slice(1).map(atomText).join(" · ")} · ${active ? "playing" : "paused"}` : active ? "playing" : "paused";
  };
  render(await evaluate(`(app.view '${printLispValue(state)})`), false);
  toggle.addEventListener("click", () => {
    running = !running;
    toggle.textContent = `${running ? "Pause" : "Play"} ${spec.title}`;
    toggle.setAttribute("aria-pressed", String(running));
  });
  const frame = async (time: number) => {
    if (running && !busy && time - lastStep >= frameIntervalMs) {
      busy = true;
      lastStep = time;
      try {
        const result = await evaluate(`(app.frame '${printLispValue(state)} '${inputForm(held, pressed, spec.controls)})`);
        const values = directives(result);
        const next = directive(values, "state");
        if (!next?.[1]) throw new Error("The Lisp application did not return its next state.");
        state = next[1];
        render(result, true);
      } catch (error) {
        running = false;
        toggle.textContent = `Play ${spec.title}`;
        toggle.setAttribute("aria-pressed", "false");
        status.textContent = `Interpreter stopped: ${error instanceof Error ? error.message : String(error)}`;
      } finally {
        pressed.clear();
        busy = false;
      }
    }
    requestAnimationFrame(frame);
  };
  requestAnimationFrame(frame);
}
