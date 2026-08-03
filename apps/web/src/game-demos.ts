import { createAsteroidsState, createBreakoutState, createPongState, fireAsteroidBullet, pongHeight, pongWidth, stepAsteroids, stepBreakout, stepPong } from "./game-models";

export function mountGameDemo(root: HTMLElement) {
  if (root.dataset.gameDemo === "asteroids") { mountAsteroids(root); return; }
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

function mountAsteroids(root: HTMLElement) {
  const canvas = root.querySelector<HTMLCanvasElement>("canvas");
  const toggle = root.querySelector<HTMLButtonElement>("[data-game-toggle]");
  const status = root.querySelector<HTMLOutputElement>("[data-game-status]");
  if (!canvas || !toggle || !status) throw new Error("The Asteroids reference is missing controls.");
  const context = canvas.getContext("2d");
  if (!context) throw new Error("This browser cannot create a 2D canvas context.");
  const state = createAsteroidsState();
  let running = false;
  let rotate: -1 | 0 | 1 = 0;
  let thrust = false;
  let previousTime = performance.now();

  function draw() {
    context!.fillStyle = "#080a08"; context!.fillRect(0, 0, 640, 360);
    context!.strokeStyle = "#f2f0e8"; context!.lineWidth = 2;
    context!.save(); context!.translate(state.shipX, state.shipY); context!.rotate(state.shipAngle);
    context!.beginPath(); context!.moveTo(18, 0); context!.lineTo(-12, -10); context!.lineTo(-7, 0); context!.lineTo(-12, 10); context!.closePath(); context!.stroke();
    if (thrust) { context!.strokeStyle = "#fa5b35"; context!.beginPath(); context!.moveTo(-9, -5); context!.lineTo(-20, 0); context!.lineTo(-9, 5); context!.stroke(); }
    context!.restore();
    for (const asteroid of state.asteroids) {
      context!.save(); context!.translate(asteroid.x, asteroid.y); context!.rotate(asteroid.angle); context!.strokeStyle = "#aaa9a1";
      context!.beginPath();
      for (let point = 0; point < 8; point += 1) {
        const angle = point / 8 * Math.PI * 2;
        const radius = asteroid.radius * (point % 2 ? .78 : 1);
        const x = Math.cos(angle) * radius; const y = Math.sin(angle) * radius;
        if (point === 0) context!.moveTo(x, y); else context!.lineTo(x, y);
      }
      context!.closePath(); context!.stroke(); context!.restore();
    }
    context!.fillStyle = "#c9f85a";
    for (const bullet of state.bullets) { context!.beginPath(); context!.arc(bullet.x, bullet.y, 3, 0, Math.PI * 2); context!.fill(); }
    status!.textContent = `${state.score} points · ${state.asteroids.length} rocks · ${running ? "flying" : "paused"}`;
  }
  function frame(time: number) {
    if (running) stepAsteroids(state, (time - previousTime) / 1000, { rotate, thrust });
    previousTime = time; draw(); requestAnimationFrame(frame);
  }
  const keys = new Set<string>();
  const updateKeys = () => {
    rotate = keys.has("arrowleft") || keys.has("a") ? -1 : keys.has("arrowright") || keys.has("d") ? 1 : 0;
    thrust = keys.has("arrowup") || keys.has("w");
  };
  window.addEventListener("keydown", (event) => {
    if (event.key === " " && !event.repeat) { event.preventDefault(); fireAsteroidBullet(state); return; }
    if (!["ArrowLeft", "ArrowRight", "ArrowUp", "a", "A", "d", "D", "w", "W"].includes(event.key)) return;
    event.preventDefault(); keys.add(event.key.toLowerCase()); updateKeys();
  });
  window.addEventListener("keyup", (event) => { keys.delete(event.key.toLowerCase()); updateKeys(); });
  root.querySelectorAll<HTMLButtonElement>("[data-asteroids-hold]").forEach((button) => {
    const action = button.dataset.asteroidsHold;
    const press = () => { button.classList.add("active"); if (action === "left") rotate = -1; else if (action === "right") rotate = 1; else thrust = true; };
    const release = () => { button.classList.remove("active"); if (action === "thrust") thrust = false; else rotate = 0; };
    button.addEventListener("pointerdown", press); button.addEventListener("pointerup", release);
    button.addEventListener("pointercancel", release); button.addEventListener("pointerleave", release);
  });
  root.querySelector<HTMLButtonElement>("[data-asteroids-fire]")?.addEventListener("click", () => fireAsteroidBullet(state));
  toggle.addEventListener("click", () => { running = !running; toggle.textContent = running ? "Pause Asteroids" : "Play Asteroids"; toggle.setAttribute("aria-pressed", String(running)); });
  draw(); requestAnimationFrame(frame);
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
