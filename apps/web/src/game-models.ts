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
