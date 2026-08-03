import assert from "node:assert/strict";
import test from "node:test";
import { createAsteroidsState, createBreakoutState, createPongState, fireAsteroidBullet, stepAsteroids, stepBreakout, stepPong, wrapCoordinate } from "../src/game-models.ts";

test("Pong model moves, clamps its timestep, bounces, and scores deterministically", () => {
  const state = createPongState();
  const startX = state.ballX;
  stepPong(state, 10, 0);
  assert.ok(state.ballX > startX && state.ballX < startX + 10, "large frame gaps must be clamped");
  state.ballY = 2;
  state.ballVy = -100;
  stepPong(state, 1 / 60, 0);
  assert.ok(state.ballVy > 0);
  state.ballX = -20;
  stepPong(state, 1 / 60, 0);
  assert.equal(state.opponentScore, 1);
  assert.equal(state.ballX, 320);
});

test("Asteroids model wraps motion, bounds bullets, and scores real hits", () => {
  assert.equal(wrapCoordinate(-1, 640), 639);
  assert.equal(wrapCoordinate(641, 640), 1);
  const state = createAsteroidsState();
  state.shipX = 639; state.shipVx = 100;
  stepAsteroids(state, 1 / 30, { rotate: 0, thrust: false });
  assert.ok(state.shipX < 10);
  state.asteroids = [{ x: 320, y: 100, vx: 0, vy: 0, radius: 30, angle: 0, spin: 0 }];
  state.shipX = 320; state.shipY = 130; state.shipVx = 0; state.shipVy = 0; state.shipAngle = -Math.PI / 2;
  assert.equal(fireAsteroidBullet(state), true);
  stepAsteroids(state, 0, { rotate: 0, thrust: false });
  assert.equal(state.asteroids.length, 0);
  assert.equal(state.score, 100);
});

test("Breakout model removes a hit brick and guards lost balls with lives", () => {
  const state = createBreakoutState();
  const brick = state.bricks[0];
  state.ballX = brick.x + 8; state.ballY = brick.y + 8; state.ballVx = 0; state.ballVy = 1;
  stepBreakout(state, 0, 0);
  assert.equal(brick.alive, false);
  assert.equal(state.score, 10);
  state.ballY = 371;
  stepBreakout(state, 0, 0);
  assert.equal(state.lives, 2);
  assert.equal(state.ballY, 278);
});
