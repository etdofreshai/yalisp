import { createPongState, pongHeight, pongWidth, stepPong } from "./game-models";

export function mountGameDemo(root: HTMLElement) {
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
