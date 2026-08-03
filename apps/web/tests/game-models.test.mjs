import assert from "node:assert/strict";
import test from "node:test";
import { createPongState, updatePong } from "../src/examples/pong/app.ts";
import { createAsteroidsState, createBreakoutState, fireAsteroidBullet, stepAsteroids, stepBreakout, wrapCoordinate } from "../src/game-models.ts";

const input = (held = []) => ({ held: (action) => held.includes(action), pressed: () => false });

test("complete Pong application moves, bounces, and scores deterministically", () => {
  const state = createPongState();
  const startX = state.ball.x;
  updatePong(state, 1 / 30, input());
  assert.ok(state.ball.x > startX && state.ball.x < startX + 10);
  state.ball.y = 2;
  state.ball.velocityY = -100;
  updatePong(state, 1 / 60, input());
  assert.ok(state.ball.velocityY > 0);
  state.ball.x = -20;
  updatePong(state, 1 / 60, input());
  assert.equal(state.opponentScore, 1);
  assert.equal(state.ball.x, 320);
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
