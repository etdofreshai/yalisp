import { mountCanvasApplication, type DrawingSurface, type InputState, type PortableCanvasApplication } from "../runtime/portable-app.ts";

export type Ball = { x: number; y: number; velocityX: number; velocityY: number; radius: number };
export type Paddle = { x: number; y: number; width: number; height: number; speed: number };
export type PongState = { ball: Ball; player: Paddle; opponent: Paddle; playerScore: number; opponentScore: number };

const width = 640;
const height = 360;

export function createPongState(): PongState {
  return {
    ball: { x: width / 2, y: height / 2, velocityX: 230, velocityY: 145, radius: 8 },
    player: { x: 28, y: 142, width: 12, height: 76, speed: 270 },
    opponent: { x: width - 40, y: 142, width: 12, height: 76, speed: 185 },
    playerScore: 0,
    opponentScore: 0
  };
}

function resetBall(state: PongState, direction: 1 | -1) {
  Object.assign(state.ball, { x: width / 2, y: height / 2, velocityX: 230 * direction, velocityY: 145 * direction });
}

export function updatePong(state: PongState, seconds: number, input: InputState) {
  const playerDirection = input.held("up") ? -1 : input.held("down") ? 1 : 0;
  state.player.y = Math.min(height - state.player.height, Math.max(0, state.player.y + playerDirection * state.player.speed * seconds));
  const opponentTarget = state.ball.y - state.opponent.height / 2;
  const opponentStep = Math.max(-state.opponent.speed * seconds, Math.min(state.opponent.speed * seconds, opponentTarget - state.opponent.y));
  state.opponent.y = Math.min(height - state.opponent.height, Math.max(0, state.opponent.y + opponentStep));
  state.ball.x += state.ball.velocityX * seconds;
  state.ball.y += state.ball.velocityY * seconds;

  if (state.ball.y <= state.ball.radius) { state.ball.y = state.ball.radius; state.ball.velocityY = Math.abs(state.ball.velocityY); }
  if (state.ball.y >= height - state.ball.radius) { state.ball.y = height - state.ball.radius; state.ball.velocityY = -Math.abs(state.ball.velocityY); }
  for (const [paddle, direction] of [[state.player, 1], [state.opponent, -1]] as const) {
    const movingToward = direction === 1 ? state.ball.velocityX < 0 : state.ball.velocityX > 0;
    const crossesPaddle = direction === 1
      ? state.ball.x - state.ball.radius <= paddle.x + paddle.width && state.ball.x > paddle.x - state.ball.radius
      : state.ball.x + state.ball.radius >= paddle.x && state.ball.x < paddle.x + paddle.width + state.ball.radius;
    if (movingToward && crossesPaddle && state.ball.y >= paddle.y && state.ball.y <= paddle.y + paddle.height) {
      state.ball.x = direction === 1 ? paddle.x + paddle.width + state.ball.radius : paddle.x - state.ball.radius;
      state.ball.velocityX = Math.abs(state.ball.velocityX) * 1.025 * direction;
    }
  }
  if (state.ball.x < -state.ball.radius) { state.opponentScore += 1; resetBall(state, 1); }
  if (state.ball.x > width + state.ball.radius) { state.playerScore += 1; resetBall(state, -1); }
}

export function drawPong(state: PongState, drawing: DrawingSurface) {
  drawing.clear("#080a08");
  drawing.line({ x: width / 2, y: 0 }, { x: width / 2, y: height }, "rgba(242,240,232,.24)", 1, [8, 10]);
  drawing.rectangle(state.player.x, state.player.y, state.player.width, state.player.height, "#f2f0e8");
  drawing.rectangle(state.opponent.x, state.opponent.y, state.opponent.width, state.opponent.height, "#f2f0e8");
  drawing.circle(state.ball.x, state.ball.y, state.ball.radius, "#c9f85a");
  drawing.text(String(state.playerScore), width / 2 - 38, 40, "#f2f0e8", 26, "center");
  drawing.text(String(state.opponentScore), width / 2 + 38, 40, "#f2f0e8", 26, "center");
}

export const pongApplication: PortableCanvasApplication<PongState> = {
  name: "Pong",
  width,
  height,
  input: [
    { action: "up", keys: ["ArrowUp", "w"], selector: '[data-app-action="up"]', mode: "hold" },
    { action: "down", keys: ["ArrowDown", "s"], selector: '[data-app-action="down"]', mode: "hold" }
  ],
  createState: createPongState,
  update: updatePong,
  draw: drawPong,
  status: (state, running) => `${state.playerScore} : ${state.opponentScore} · ${running ? "playing" : "paused"}`
};

export function mountPong(root: HTMLElement) {
  return mountCanvasApplication(root, pongApplication);
}
