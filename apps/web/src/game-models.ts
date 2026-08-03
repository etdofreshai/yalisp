export type PongState = {
  ballX: number;
  ballY: number;
  ballVx: number;
  ballVy: number;
  playerY: number;
  opponentY: number;
  playerScore: number;
  opponentScore: number;
};

export const pongWidth = 640;
export const pongHeight = 360;
const paddleHeight = 76;
const paddleWidth = 12;
const ballRadius = 8;

export function createPongState(): PongState {
  return { ballX: pongWidth / 2, ballY: pongHeight / 2, ballVx: 230, ballVy: 145, playerY: 142, opponentY: 142, playerScore: 0, opponentScore: 0 };
}

function resetPongBall(state: PongState, direction: 1 | -1) {
  state.ballX = pongWidth / 2;
  state.ballY = pongHeight / 2;
  state.ballVx = 230 * direction;
  state.ballVy = direction * 145;
}

export function stepPong(state: PongState, dt: number, playerDirection: -1 | 0 | 1) {
  const step = Math.min(Math.max(dt, 0), 1 / 30);
  state.playerY = Math.min(pongHeight - paddleHeight, Math.max(0, state.playerY + playerDirection * 270 * step));
  const opponentTarget = state.ballY - paddleHeight / 2;
  const opponentDelta = Math.max(-185 * step, Math.min(185 * step, opponentTarget - state.opponentY));
  state.opponentY = Math.min(pongHeight - paddleHeight, Math.max(0, state.opponentY + opponentDelta));
  state.ballX += state.ballVx * step;
  state.ballY += state.ballVy * step;
  if (state.ballY <= ballRadius) { state.ballY = ballRadius; state.ballVy = Math.abs(state.ballVy); }
  if (state.ballY >= pongHeight - ballRadius) { state.ballY = pongHeight - ballRadius; state.ballVy = -Math.abs(state.ballVy); }

  const hitsPlayer = state.ballVx < 0 && state.ballX - ballRadius <= 28 + paddleWidth && state.ballX > 20 && state.ballY >= state.playerY && state.ballY <= state.playerY + paddleHeight;
  const hitsOpponent = state.ballVx > 0 && state.ballX + ballRadius >= pongWidth - 28 - paddleWidth && state.ballX < pongWidth - 20 && state.ballY >= state.opponentY && state.ballY <= state.opponentY + paddleHeight;
  if (hitsPlayer) { state.ballX = 28 + paddleWidth + ballRadius; state.ballVx = Math.abs(state.ballVx) * 1.025; }
  if (hitsOpponent) { state.ballX = pongWidth - 28 - paddleWidth - ballRadius; state.ballVx = -Math.abs(state.ballVx) * 1.025; }
  if (state.ballX < -ballRadius) { state.opponentScore += 1; resetPongBall(state, 1); }
  if (state.ballX > pongWidth + ballRadius) { state.playerScore += 1; resetPongBall(state, -1); }
  return state;
}

export type BreakoutBrick = { x: number; y: number; alive: boolean };
export type BreakoutState = {
  ballX: number; ballY: number; ballVx: number; ballVy: number;
  paddleX: number; score: number; lives: number; bricks: BreakoutBrick[];
};

export function createBreakoutState(): BreakoutState {
  const bricks = Array.from({ length: 32 }, (_, index) => ({
    x: 36 + (index % 8) * 72,
    y: 50 + Math.floor(index / 8) * 28,
    alive: true
  }));
  return { ballX: 320, ballY: 278, ballVx: 155, ballVy: -190, paddleX: 272, score: 0, lives: 3, bricks };
}

function resetBreakoutBall(state: BreakoutState) {
  state.ballX = 320; state.ballY = 278; state.ballVx = 155; state.ballVy = -190;
}

export function stepBreakout(state: BreakoutState, dt: number, direction: -1 | 0 | 1) {
  const step = Math.min(Math.max(dt, 0), 1 / 30);
  state.paddleX = Math.min(544, Math.max(0, state.paddleX + direction * 330 * step));
  state.ballX += state.ballVx * step; state.ballY += state.ballVy * step;
  if (state.ballX <= 8) { state.ballX = 8; state.ballVx = Math.abs(state.ballVx); }
  if (state.ballX >= 632) { state.ballX = 632; state.ballVx = -Math.abs(state.ballVx); }
  if (state.ballY <= 8) { state.ballY = 8; state.ballVy = Math.abs(state.ballVy); }
  if (state.ballVy > 0 && state.ballY >= 320 && state.ballY <= 338 && state.ballX >= state.paddleX && state.ballX <= state.paddleX + 96) {
    state.ballY = 320; state.ballVy = -Math.abs(state.ballVy);
    state.ballVx += (state.ballX - (state.paddleX + 48)) * 1.5;
  }
  const hit = state.bricks.find((brick) => brick.alive && state.ballX >= brick.x && state.ballX <= brick.x + 64 && state.ballY >= brick.y && state.ballY <= brick.y + 18);
  if (hit) { hit.alive = false; state.score += 10; state.ballVy = -state.ballVy; }
  if (state.ballY > 370) { state.lives -= 1; resetBreakoutBall(state); }
  return state;
}
