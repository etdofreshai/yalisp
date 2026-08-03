import {
  mountCanvasApplication,
  type DrawingSurface,
  type InputState,
  type PortableCanvasApplication
} from "../runtime/portable-app.ts";

export type Brick = { x: number; y: number; width: number; height: number; color: string; alive: boolean };
export type BreakoutState = {
  ball: { x: number; y: number; velocityX: number; velocityY: number; radius: number };
  paddle: { x: number; y: number; width: number; height: number; speed: number };
  bricks: Brick[];
  score: number;
  lives: number;
};

const width = 640;
const height = 360;

export function createBreakoutState(): BreakoutState {
  return {
    ball: { x: 320, y: 278, velocityX: 155, velocityY: -190, radius: 8 },
    paddle: { x: 272, y: 328, width: 96, height: 12, speed: 330 },
    bricks: Array.from({ length: 32 }, (_, index) => ({
      x: 36 + (index % 8) * 72,
      y: 50 + Math.floor(index / 8) * 28,
      width: 64,
      height: 18,
      color: index % 2 ? "#fa5b35" : "#c9f85a",
      alive: true
    })),
    score: 0,
    lives: 3
  };
}

function resetBall(state: BreakoutState) {
  Object.assign(state.ball, { x: 320, y: 278, velocityX: 155, velocityY: -190 });
}

export function updateBreakout(state: BreakoutState, seconds: number, input: InputState) {
  if (state.lives <= 0 || !state.bricks.some(({ alive }) => alive)) return;
  const direction = input.held("left") ? -1 : input.held("right") ? 1 : 0;
  state.paddle.x = Math.min(width - state.paddle.width, Math.max(0, state.paddle.x + direction * state.paddle.speed * seconds));
  state.ball.x += state.ball.velocityX * seconds;
  state.ball.y += state.ball.velocityY * seconds;
  if (state.ball.x <= state.ball.radius) { state.ball.x = state.ball.radius; state.ball.velocityX = Math.abs(state.ball.velocityX); }
  if (state.ball.x >= width - state.ball.radius) { state.ball.x = width - state.ball.radius; state.ball.velocityX = -Math.abs(state.ball.velocityX); }
  if (state.ball.y <= state.ball.radius) { state.ball.y = state.ball.radius; state.ball.velocityY = Math.abs(state.ball.velocityY); }

  const paddleHit = state.ball.velocityY > 0
    && state.ball.y + state.ball.radius >= state.paddle.y
    && state.ball.y <= state.paddle.y + state.paddle.height
    && state.ball.x >= state.paddle.x
    && state.ball.x <= state.paddle.x + state.paddle.width;
  if (paddleHit) {
    state.ball.y = state.paddle.y - state.ball.radius;
    state.ball.velocityY = -Math.abs(state.ball.velocityY);
    state.ball.velocityX += (state.ball.x - (state.paddle.x + state.paddle.width / 2)) * 1.5;
  }

  const hit = state.bricks.find((brick) => brick.alive
    && state.ball.x >= brick.x && state.ball.x <= brick.x + brick.width
    && state.ball.y >= brick.y && state.ball.y <= brick.y + brick.height);
  if (hit) { hit.alive = false; state.score += 10; state.ball.velocityY = -state.ball.velocityY; }
  if (state.ball.y - state.ball.radius > height) { state.lives -= 1; resetBall(state); }
}

export function drawBreakout(state: BreakoutState, drawing: DrawingSurface) {
  drawing.clear("#080a08");
  for (const brick of state.bricks) {
    if (brick.alive) drawing.rectangle(brick.x, brick.y, brick.width, brick.height, brick.color);
  }
  drawing.rectangle(state.paddle.x, state.paddle.y, state.paddle.width, state.paddle.height, "#f2f0e8");
  drawing.circle(state.ball.x, state.ball.y, state.ball.radius, "#f2f0e8");
}

export const breakoutApplication: PortableCanvasApplication<BreakoutState> = {
  name: "Breakout",
  width,
  height,
  input: [
    { action: "left", keys: ["ArrowLeft", "a"], selector: '[data-app-action="left"]', mode: "hold" },
    { action: "right", keys: ["ArrowRight", "d"], selector: '[data-app-action="right"]', mode: "hold" }
  ],
  createState: createBreakoutState,
  update: updateBreakout,
  draw: drawBreakout,
  status: (state, running) => {
    const outcome = state.lives <= 0 ? "game over" : state.bricks.some(({ alive }) => alive) ? (running ? "playing" : "paused") : "wall cleared";
    return `${state.score} points · ${state.lives} lives · ${outcome}`;
  }
};

export function mountBreakout(root: HTMLElement) {
  return mountCanvasApplication(root, breakoutApplication);
}
