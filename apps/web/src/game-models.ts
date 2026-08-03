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

export type Asteroid = { x: number; y: number; vx: number; vy: number; radius: number; angle: number; spin: number };
export type AsteroidBullet = { x: number; y: number; vx: number; vy: number; life: number };
export type AsteroidsState = {
  shipX: number; shipY: number; shipVx: number; shipVy: number; shipAngle: number;
  score: number; asteroids: Asteroid[]; bullets: AsteroidBullet[];
};
export type AsteroidsControls = { rotate: -1 | 0 | 1; thrust: boolean };

export function wrapCoordinate(value: number, limit: number) {
  if (value < 0) return value + limit;
  if (value >= limit) return value - limit;
  return value;
}

export function createAsteroidsState(): AsteroidsState {
  return {
    shipX: 320, shipY: 180, shipVx: 0, shipVy: 0, shipAngle: -Math.PI / 2, score: 0, bullets: [],
    asteroids: [
      { x: 80, y: 70, vx: 24, vy: 18, radius: 24, angle: 0, spin: .35 },
      { x: 530, y: 85, vx: -19, vy: 25, radius: 29, angle: 1, spin: -.22 },
      { x: 120, y: 290, vx: 31, vy: -14, radius: 20, angle: 2, spin: .28 },
      { x: 520, y: 290, vx: -27, vy: -17, radius: 23, angle: 3, spin: -.31 }
    ]
  };
}

export function fireAsteroidBullet(state: AsteroidsState) {
  if (state.bullets.length >= 5) return false;
  state.bullets.push({
    x: state.shipX + Math.cos(state.shipAngle) * 16,
    y: state.shipY + Math.sin(state.shipAngle) * 16,
    vx: state.shipVx + Math.cos(state.shipAngle) * 330,
    vy: state.shipVy + Math.sin(state.shipAngle) * 330,
    life: 1.2
  });
  return true;
}

export function stepAsteroids(state: AsteroidsState, dt: number, controls: AsteroidsControls) {
  const step = Math.min(Math.max(dt, 0), 1 / 30);
  state.shipAngle += controls.rotate * 3.2 * step;
  if (controls.thrust) {
    state.shipVx += Math.cos(state.shipAngle) * 92 * step;
    state.shipVy += Math.sin(state.shipAngle) * 92 * step;
  }
  state.shipVx *= Math.pow(.985, step * 60); state.shipVy *= Math.pow(.985, step * 60);
  state.shipX = wrapCoordinate(state.shipX + state.shipVx * step, 640);
  state.shipY = wrapCoordinate(state.shipY + state.shipVy * step, 360);
  for (const asteroid of state.asteroids) {
    asteroid.x = wrapCoordinate(asteroid.x + asteroid.vx * step, 640);
    asteroid.y = wrapCoordinate(asteroid.y + asteroid.vy * step, 360);
    asteroid.angle += asteroid.spin * step;
  }
  for (const bullet of state.bullets) {
    bullet.x = wrapCoordinate(bullet.x + bullet.vx * step, 640);
    bullet.y = wrapCoordinate(bullet.y + bullet.vy * step, 360);
    bullet.life -= step;
  }
  state.bullets = state.bullets.filter((bullet) => {
    if (bullet.life <= 0) return false;
    const hitIndex = state.asteroids.findIndex((asteroid) => Math.hypot(asteroid.x - bullet.x, asteroid.y - bullet.y) <= asteroid.radius);
    if (hitIndex < 0) return true;
    state.asteroids.splice(hitIndex, 1); state.score += 100; return false;
  });
  return state;
}
