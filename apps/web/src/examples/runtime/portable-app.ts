export type Point = { x: number; y: number };

export interface DrawingSurface {
  clear(color: string): void;
  rectangle(x: number, y: number, width: number, height: number, color: string): void;
  circle(x: number, y: number, radius: number, color: string): void;
  line(from: Point, to: Point, color: string, width?: number, dash?: number[]): void;
  polygon(points: Point[], color: string, width?: number): void;
  text(value: string, x: number, y: number, color: string, size: number, align?: CanvasTextAlign): void;
}

export interface InputState {
  held(action: string): boolean;
  pressed(action: string): boolean;
}

export type InputBinding = {
  action: string;
  keys?: string[];
  selector: string;
  mode: "hold" | "press";
};

export interface PortableCanvasApplication<State> {
  name: string;
  width: number;
  height: number;
  input: InputBinding[];
  createState(): State;
  update(state: State, seconds: number, input: InputState): void;
  draw(state: State, surface: DrawingSurface, input: InputState): void;
  status(state: State, running: boolean): string;
  canUpdate?(state: State): boolean;
}

class CanvasDrawingSurface implements DrawingSurface {
  private readonly context: CanvasRenderingContext2D;

  constructor(context: CanvasRenderingContext2D) {
    this.context = context;
  }

  clear(color: string) {
    this.context.fillStyle = color;
    this.context.fillRect(0, 0, this.context.canvas.width, this.context.canvas.height);
  }

  rectangle(x: number, y: number, width: number, height: number, color: string) {
    this.context.fillStyle = color;
    this.context.fillRect(x, y, width, height);
  }

  circle(x: number, y: number, radius: number, color: string) {
    this.context.fillStyle = color;
    this.context.beginPath();
    this.context.arc(x, y, radius, 0, Math.PI * 2);
    this.context.fill();
  }

  line(from: Point, to: Point, color: string, width = 1, dash: number[] = []) {
    this.context.strokeStyle = color;
    this.context.lineWidth = width;
    this.context.setLineDash(dash);
    this.context.beginPath();
    this.context.moveTo(from.x, from.y);
    this.context.lineTo(to.x, to.y);
    this.context.stroke();
    this.context.setLineDash([]);
  }

  polygon(points: Point[], color: string, width = 1) {
    const first = points[0];
    if (!first) return;
    this.context.strokeStyle = color;
    this.context.lineWidth = width;
    this.context.beginPath();
    this.context.moveTo(first.x, first.y);
    points.slice(1).forEach(({ x, y }) => this.context.lineTo(x, y));
    this.context.closePath();
    this.context.stroke();
  }

  text(value: string, x: number, y: number, color: string, size: number, align: CanvasTextAlign = "left") {
    this.context.fillStyle = color;
    this.context.font = `${size}px monospace`;
    this.context.textAlign = align;
    this.context.fillText(value, x, y);
  }
}

export function mountCanvasApplication<State>(root: HTMLElement, application: PortableCanvasApplication<State>) {
  const canvas = root.querySelector<HTMLCanvasElement>("canvas");
  const toggle = root.querySelector<HTMLButtonElement>("[data-game-toggle]");
  const status = root.querySelector<HTMLOutputElement>("[data-game-status]");
  if (!canvas || !toggle || !status) throw new Error(`${application.name} is missing its DOM application root.`);
  const context = canvas.getContext("2d");
  if (!context) throw new Error("This browser cannot create the Canvas 2D drawing binding.");
  canvas.width = application.width;
  canvas.height = application.height;

  const surface = new CanvasDrawingSurface(context);
  const state = application.createState();
  const heldActions = new Set<string>();
  const pressedActions = new Set<string>();
  const keyActions = new Map<string, InputBinding>();
  application.input.forEach((binding) => binding.keys?.forEach((key) => keyActions.set(key.toLowerCase(), binding)));
  const input: InputState = {
    held: (action) => heldActions.has(action),
    pressed: (action) => pressedActions.has(action)
  };
  let running = false;
  let previousTime = performance.now();

  const setHeld = (binding: InputBinding, active: boolean) => {
    if (active) heldActions.add(binding.action);
    else heldActions.delete(binding.action);
  };
  window.addEventListener("keydown", (event) => {
    const binding = keyActions.get(event.key.toLowerCase());
    if (!binding) return;
    event.preventDefault();
    if (binding.mode === "hold") setHeld(binding, true);
    else if (!event.repeat) pressedActions.add(binding.action);
  });
  window.addEventListener("keyup", (event) => {
    const binding = keyActions.get(event.key.toLowerCase());
    if (binding?.mode === "hold") setHeld(binding, false);
  });

  application.input.forEach((binding) => {
    root.querySelectorAll<HTMLButtonElement>(binding.selector).forEach((button) => {
      if (binding.mode === "press") {
        button.addEventListener("click", () => pressedActions.add(binding.action));
        return;
      }
      const press = () => { button.classList.add("active"); setHeld(binding, true); };
      const release = () => { button.classList.remove("active"); setHeld(binding, false); };
      button.addEventListener("pointerdown", press);
      button.addEventListener("pointerup", release);
      button.addEventListener("pointercancel", release);
      button.addEventListener("pointerleave", release);
    });
  });

  function frame(time: number) {
    const canUpdate = application.canUpdate?.(state) ?? true;
    if (running && canUpdate) application.update(state, Math.min(Math.max((time - previousTime) / 1000, 0), 1 / 30), input);
    previousTime = time;
    application.draw(state, surface, input);
    status!.textContent = application.status(state, running && canUpdate);
    pressedActions.clear();
    requestAnimationFrame(frame);
  }

  toggle.addEventListener("click", () => {
    running = !running;
    toggle.textContent = running ? `Pause ${application.name}` : `Play ${application.name}`;
    toggle.setAttribute("aria-pressed", String(running));
  });
  application.draw(state, surface, input);
  status.textContent = application.status(state, false);
  requestAnimationFrame(frame);
  return { state, input, surface };
}
