import {
  mountCanvasApplication,
  type DrawingSurface,
  type InputState,
  type Point,
  type PortableCanvasApplication
} from "../runtime/portable-app.ts";

export type Asteroid = { x: number; y: number; velocityX: number; velocityY: number; radius: number; angle: number; spin: number };
export type Bullet = { x: number; y: number; velocityX: number; velocityY: number; life: number };
export type AsteroidsState = {
  ship: { x: number; y: number; velocityX: number; velocityY: number; angle: number };
  asteroids: Asteroid[];
  bullets: Bullet[];
  score: number;
};

const width = 640;
const height = 360;

export function wrapCoordinate(value: number, limit: number) {
  if (value < 0) return value + limit;
  if (value >= limit) return value - limit;
  return value;
}

export function createAsteroidsState(): AsteroidsState {
  return {
    ship: { x: 320, y: 180, velocityX: 0, velocityY: 0, angle: -Math.PI / 2 },
    bullets: [],
    score: 0,
    asteroids: [
      { x: 80, y: 70, velocityX: 24, velocityY: 18, radius: 24, angle: 0, spin: .35 },
      { x: 530, y: 85, velocityX: -19, velocityY: 25, radius: 29, angle: 1, spin: -.22 },
      { x: 120, y: 290, velocityX: 31, velocityY: -14, radius: 20, angle: 2, spin: .28 },
      { x: 520, y: 290, velocityX: -27, velocityY: -17, radius: 23, angle: 3, spin: -.31 }
    ]
  };
}

export function fireBullet(state: AsteroidsState) {
  if (state.bullets.length >= 5) return false;
  state.bullets.push({
    x: state.ship.x + Math.cos(state.ship.angle) * 16,
    y: state.ship.y + Math.sin(state.ship.angle) * 16,
    velocityX: state.ship.velocityX + Math.cos(state.ship.angle) * 330,
    velocityY: state.ship.velocityY + Math.sin(state.ship.angle) * 330,
    life: 1.2
  });
  return true;
}

export function updateAsteroids(state: AsteroidsState, seconds: number, input: InputState) {
  const rotation = input.held("left") ? -1 : input.held("right") ? 1 : 0;
  state.ship.angle += rotation * 3.2 * seconds;
  if (input.held("thrust")) {
    state.ship.velocityX += Math.cos(state.ship.angle) * 92 * seconds;
    state.ship.velocityY += Math.sin(state.ship.angle) * 92 * seconds;
  }
  if (input.pressed("fire")) fireBullet(state);
  state.ship.velocityX *= Math.pow(.985, seconds * 60);
  state.ship.velocityY *= Math.pow(.985, seconds * 60);
  state.ship.x = wrapCoordinate(state.ship.x + state.ship.velocityX * seconds, width);
  state.ship.y = wrapCoordinate(state.ship.y + state.ship.velocityY * seconds, height);

  for (const asteroid of state.asteroids) {
    asteroid.x = wrapCoordinate(asteroid.x + asteroid.velocityX * seconds, width);
    asteroid.y = wrapCoordinate(asteroid.y + asteroid.velocityY * seconds, height);
    asteroid.angle += asteroid.spin * seconds;
  }
  for (const bullet of state.bullets) {
    bullet.x = wrapCoordinate(bullet.x + bullet.velocityX * seconds, width);
    bullet.y = wrapCoordinate(bullet.y + bullet.velocityY * seconds, height);
    bullet.life -= seconds;
  }
  state.bullets = state.bullets.filter((bullet) => {
    if (bullet.life <= 0) return false;
    const hitIndex = state.asteroids.findIndex((asteroid) => Math.hypot(asteroid.x - bullet.x, asteroid.y - bullet.y) <= asteroid.radius);
    if (hitIndex < 0) return true;
    state.asteroids.splice(hitIndex, 1);
    state.score += 100;
    return false;
  });
}

function rotatePoint(point: Point, angle: number, origin: Point): Point {
  return {
    x: origin.x + point.x * Math.cos(angle) - point.y * Math.sin(angle),
    y: origin.y + point.x * Math.sin(angle) + point.y * Math.cos(angle)
  };
}

export function drawAsteroids(state: AsteroidsState, drawing: DrawingSurface, input: InputState) {
  drawing.clear("#080a08");
  const origin = { x: state.ship.x, y: state.ship.y };
  drawing.polygon([
    rotatePoint({ x: 18, y: 0 }, state.ship.angle, origin),
    rotatePoint({ x: -12, y: -10 }, state.ship.angle, origin),
    rotatePoint({ x: -7, y: 0 }, state.ship.angle, origin),
    rotatePoint({ x: -12, y: 10 }, state.ship.angle, origin)
  ], "#f2f0e8", 2);
  if (input.held("thrust")) {
    drawing.polygon([
      rotatePoint({ x: -9, y: -5 }, state.ship.angle, origin),
      rotatePoint({ x: -20, y: 0 }, state.ship.angle, origin),
      rotatePoint({ x: -9, y: 5 }, state.ship.angle, origin)
    ], "#fa5b35", 2);
  }
  for (const asteroid of state.asteroids) {
    const points = Array.from({ length: 8 }, (_, index) => {
      const angle = asteroid.angle + index / 8 * Math.PI * 2;
      const radius = asteroid.radius * (index % 2 ? .78 : 1);
      return { x: asteroid.x + Math.cos(angle) * radius, y: asteroid.y + Math.sin(angle) * radius };
    });
    drawing.polygon(points, "#aaa9a1", 2);
  }
  for (const bullet of state.bullets) drawing.circle(bullet.x, bullet.y, 3, "#c9f85a");
}

export const asteroidsApplication: PortableCanvasApplication<AsteroidsState> = {
  name: "Asteroids",
  width,
  height,
  input: [
    { action: "left", keys: ["ArrowLeft", "a"], selector: '[data-app-action="left"]', mode: "hold" },
    { action: "right", keys: ["ArrowRight", "d"], selector: '[data-app-action="right"]', mode: "hold" },
    { action: "thrust", keys: ["ArrowUp", "w"], selector: '[data-app-action="thrust"]', mode: "hold" },
    { action: "fire", keys: [" "], selector: '[data-app-action="fire"]', mode: "press" }
  ],
  createState: createAsteroidsState,
  update: updateAsteroids,
  draw: drawAsteroids,
  status: (state, running) => `${state.score} points · ${state.asteroids.length} rocks · ${running ? "flying" : "paused"}`
};

export function mountAsteroids(root: HTMLElement) {
  return mountCanvasApplication(root, asteroidsApplication);
}
