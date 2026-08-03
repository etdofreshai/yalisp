import { createBreakoutState, createPongState, pongHeight, pongWidth, stepBreakout, stepPong } from "./game-models";

export function mountGameDemo(root: HTMLElement) {
  if (root.dataset.gameDemo === "breakout") { mountBreakout(root); return; }
  if (root.dataset.gameDemo !== "pong") return;
  const canvas = root.querySelector<HTMLCanvasElement>("canvas");
  const toggle = root.querySelector<HTMLButtonElement>("[data-game-toggle]");
  const status = root.querySelector<HTMLOutputElement>("[data-game-status]");
  if (!canvas || !toggle || !status) throw new Error("The Pong reference is missing controls.");
  const context = canvas.getContext("2d");
  if (!context) throw new Error("This browser cannot create a 2D canvas context.");
  const state = createPongState();
  let running = false;
  let playerDirection: -1 | 0 | 1 = 0;
  let previousTime = performance.now();

  function draw() {
    context!.fillStyle = "#080a08";
    context!.fillRect(0, 0, pongWidth, pongHeight);
    context!.strokeStyle = "rgba(242,240,232,.24)";
    context!.setLineDash([8, 10]);
    context!.beginPath(); context!.moveTo(pongWidth / 2, 0); context!.lineTo(pongWidth / 2, pongHeight); context!.stroke();
    context!.setLineDash([]);
    context!.fillStyle = "#f2f0e8";
    context!.fillRect(28, state.playerY, 12, 76);
    context!.fillRect(pongWidth - 40, state.opponentY, 12, 76);
    context!.fillStyle = "#c9f85a";
    context!.beginPath(); context!.arc(state.ballX, state.ballY, 8, 0, Math.PI * 2); context!.fill();
    context!.font = "26px monospace"; context!.textAlign = "center"; context!.fillStyle = "#f2f0e8";
    context!.fillText(String(state.playerScore), pongWidth / 2 - 38, 40);
    context!.fillText(String(state.opponentScore), pongWidth / 2 + 38, 40);
    status!.textContent = `${state.playerScore} : ${state.opponentScore} · ${running ? "playing" : "paused"}`;
  }

  function frame(time: number) {
    if (running) stepPong(state, (time - previousTime) / 1000, playerDirection);
    previousTime = time;
    draw();
    requestAnimationFrame(frame);
  }

  function setDirection(direction: -1 | 0 | 1) { playerDirection = direction; }
  const keys = new Set<string>();
  window.addEventListener("keydown", (event) => {
    if (!["ArrowUp", "ArrowDown", "w", "W", "s", "S"].includes(event.key)) return;
    event.preventDefault(); keys.add(event.key.toLowerCase());
    setDirection(keys.has("arrowup") || keys.has("w") ? -1 : 1);
  });
  window.addEventListener("keyup", (event) => {
    keys.delete(event.key.toLowerCase());
    setDirection(keys.has("arrowup") || keys.has("w") ? -1 : keys.has("arrowdown") || keys.has("s") ? 1 : 0);
  });
  root.querySelectorAll<HTMLButtonElement>("[data-pong-direction]").forEach((button) => {
    const direction = button.dataset.pongDirection === "up" ? -1 : 1;
    const press = () => { button.classList.add("active"); setDirection(direction); };
    const release = () => { button.classList.remove("active"); setDirection(0); };
    button.addEventListener("pointerdown", press);
    button.addEventListener("pointerup", release);
    button.addEventListener("pointercancel", release);
    button.addEventListener("pointerleave", release);
  });
  toggle.addEventListener("click", () => {
    running = !running;
    toggle.textContent = running ? "Pause Pong" : "Play Pong";
    toggle.setAttribute("aria-pressed", String(running));
  });
  draw();
  requestAnimationFrame(frame);
}

function mountBreakout(root: HTMLElement) {
  const canvas = root.querySelector<HTMLCanvasElement>("canvas");
  const toggle = root.querySelector<HTMLButtonElement>("[data-game-toggle]");
  const status = root.querySelector<HTMLOutputElement>("[data-game-status]");
  if (!canvas || !toggle || !status) throw new Error("The Breakout reference is missing controls.");
  const context = canvas.getContext("2d");
  if (!context) throw new Error("This browser cannot create a 2D canvas context.");
  const state = createBreakoutState();
  let running = false;
  let direction: -1 | 0 | 1 = 0;
  let previousTime = performance.now();

  function draw() {
    context!.fillStyle = "#080a08"; context!.fillRect(0, 0, 640, 360);
    for (const [index, brick] of state.bricks.entries()) {
      if (!brick.alive) continue;
      context!.fillStyle = index % 2 ? "#fa5b35" : "#c9f85a";
      context!.fillRect(brick.x, brick.y, 64, 18);
    }
    context!.fillStyle = "#f2f0e8"; context!.fillRect(state.paddleX, 328, 96, 12);
    context!.beginPath(); context!.arc(state.ballX, state.ballY, 8, 0, Math.PI * 2); context!.fill();
    status!.textContent = `${state.score} points · ${state.lives} lives · ${running ? "playing" : "paused"}`;
  }
  function frame(time: number) {
    if (running && state.lives > 0 && state.bricks.some(({ alive }) => alive)) stepBreakout(state, (time - previousTime) / 1000, direction);
    previousTime = time; draw(); requestAnimationFrame(frame);
  }
  const keys = new Set<string>();
  const updateKeys = () => { direction = keys.has("arrowleft") || keys.has("a") ? -1 : keys.has("arrowright") || keys.has("d") ? 1 : 0; };
  window.addEventListener("keydown", (event) => {
    if (!["ArrowLeft", "ArrowRight", "a", "A", "d", "D"].includes(event.key)) return;
    event.preventDefault(); keys.add(event.key.toLowerCase()); updateKeys();
  });
  window.addEventListener("keyup", (event) => { keys.delete(event.key.toLowerCase()); updateKeys(); });
  root.querySelectorAll<HTMLButtonElement>("[data-breakout-direction]").forEach((button) => {
    const held = button.dataset.breakoutDirection === "left" ? -1 : 1;
    const press = () => { button.classList.add("active"); direction = held; };
    const release = () => { button.classList.remove("active"); direction = 0; };
    button.addEventListener("pointerdown", press); button.addEventListener("pointerup", release);
    button.addEventListener("pointercancel", release); button.addEventListener("pointerleave", release);
  });
  toggle.addEventListener("click", () => {
    running = !running; toggle.textContent = running ? "Pause Breakout" : "Play Breakout"; toggle.setAttribute("aria-pressed", String(running));
  });
  draw(); requestAnimationFrame(frame);
}
