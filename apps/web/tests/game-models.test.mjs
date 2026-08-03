import assert from "node:assert/strict";
import test from "node:test";
import { createBreakoutState, updateBreakout } from "../src/examples/breakout/app.ts";
import { createAsteroidsState, fireBullet, updateAsteroids, wrapCoordinate } from "../src/examples/asteroids/app.ts";

const input = (held = []) => ({ held: (action) => held.includes(action), pressed: () => false });

test("Asteroids model wraps motion, bounds bullets, and scores real hits", () => {
  assert.equal(wrapCoordinate(-1, 640), 639);
  assert.equal(wrapCoordinate(641, 640), 1);
  const state = createAsteroidsState();
  state.ship.x = 639; state.ship.velocityX = 100;
  updateAsteroids(state, 1 / 30, input());
  assert.ok(state.ship.x < 10);
  state.asteroids = [{ x: 320, y: 100, velocityX: 0, velocityY: 0, radius: 30, angle: 0, spin: 0 }];
  Object.assign(state.ship, { x: 320, y: 130, velocityX: 0, velocityY: 0, angle: -Math.PI / 2 });
  assert.equal(fireBullet(state), true);
  updateAsteroids(state, 0, input());
  assert.equal(state.asteroids.length, 0);
  assert.equal(state.score, 100);
});

test("Breakout model removes a hit brick and guards lost balls with lives", () => {
  const state = createBreakoutState();
  const brick = state.bricks[0];
  state.ball.x = brick.x + 8; state.ball.y = brick.y + 8; state.ball.velocityX = 0; state.ball.velocityY = 1;
  updateBreakout(state, 0, input());
  assert.equal(brick.alive, false);
  assert.equal(state.score, 10);
  state.ball.y = 371;
  updateBreakout(state, 0, input());
  assert.equal(state.lives, 2);
  assert.equal(state.ball.y, 278);
});
