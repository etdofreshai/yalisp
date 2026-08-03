import assert from "node:assert/strict";
import test from "node:test";
import { createPongState, stepPong } from "../src/game-models.ts";

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
