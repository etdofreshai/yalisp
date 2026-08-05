import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { createApplicationDriver } from "../src/examples/runtime/application-driver.ts";
import { directive, directives, printLispValue } from "../src/examples/runtime/lisp-value.ts";
import { createSeedSession } from "./seed-session.mjs";

const pongApplication = await readFile(new URL("../src/examples/pong/app.lisp", import.meta.url), "utf8");

// A fixture that implements both contracts over the same transition, so the
// driver can be tested against a program whose state shape this file owns.
// A real application was used here once, and the test then failed whenever
// that application changed for reasons of its own; what is under test is the
// transport, not anyone's gameplay.
const bothContracts = `
  (defn fixture.at (xs n) (if (= n 0) (car xs) (fixture.at (cdr xs) (- n 1))))
  (defn fixture.on? (input name)
    (let ((row (assoc name input))) (if row (= (fixture.at row 1) 1) false)))
  (defn app.mount () '(mount 64 64 fixture ((north hold north (ArrowUp)) (south hold south (ArrowDown)) (mark press mark (Space)))))
  (defn app.initial-state () (list 8 8 0))
  ;; Every declared action changes the state, so a replayed script that drove
  ;; only some of them could not pass by leaving the rest untouched.
  (defn app.step (state input)
    (list (+ (fixture.at state 0) (if (fixture.on? input 'north) 1 0))
          (+ (fixture.at state 1) (if (fixture.on? input 'south) 2 0))
          (+ (fixture.at state 2) (if (fixture.on? input 'mark) 4 1))))
  (defn app.view (state)
    (list (list 'draw (list 'rect (fixture.at state 0) (fixture.at state 1) 2 2 1))
          (list 'status (fixture.at state 2))))
  (defn app.frame (state input)
    (let ((next (app.step state input))) (cons (list 'state next) (app.view next))))
  (define app.resident-state nil)
  (defn app.attach () (set! app.resident-state (app.initial-state)))
  (defn app.advance (input) (set! app.resident-state (app.step app.resident-state input)))
  (defn app.state () app.resident-state)
  (defn app.present () (app.view app.resident-state))`;

// A deterministic input script: no wall clock, no randomness, no host state.
// Replaying it must produce the same ticks in any host that implements the
// same contract, which is what makes a recorded trace comparable at all.
function scriptedInput(actions, tick) {
  return `(${actions.map((action, index) => `(${action} ${(tick >> index) & 1})`).join(" ")})`;
}

async function load(source) {
  const session = await createSeedSession();
  session.evaluate("(heap.reserve 16777216)");
  session.evaluateQuietly(source);
  return session;
}

test("an application without app.attach keeps the original printed-state contract", async () => {
  const session = await load(pongApplication);
  const driver = createApplicationDriver(session);
  assert.equal(driver.mode, "printed-state");
  driver.attach();
  assert.equal(driver.stateText(), "(320 180 230 145 142 142 0 0)");
  driver.tick("((up 1) (down 0))");
  assert.equal(driver.stateText(), "(336 190 230 145 124 142 0 0)");
  assert.ok(directive(directives(driver.present()), "draw"), "the presented value still carries draw commands");
});

test("an application that defines app.attach keeps its state inside the evaluator", async () => {
  const session = await load(bothContracts);
  const driver = createApplicationDriver(session);
  assert.equal(driver.mode, "state-handle");
  driver.attach();
  assert.equal(driver.stateText(), "(8 8 0)");
  driver.tick("((north 1) (south 0) (mark 0))");
  assert.equal(driver.stateText(), "(9 8 1)");
  // The state never crossed the boundary as text on that tick: the driver was
  // given only the input form, which is the point of this contract.
  const values = directives(driver.present());
  assert.ok(directive(values, "draw"), "the presented value carries draw commands");
  assert.ok(directive(values, "status"), "the presented value carries a status line");
});

test("both contracts advance identically over a replayed input script", async () => {
  const actions = ["north", "south", "mark"];
  const printedSession = await load(bothContracts);
  // Drive the same application through the original contract by hiding the
  // opt-in entry point, so the comparison isolates the transport and not the
  // program: same source, same inputs, two state paths.
  printedSession.evaluateQuietly("(define app.attach nil)");
  const printed = createApplicationDriver({
    evaluate: (form) => printedSession.evaluate(form === "(bound? 'app.attach)" ? "false" : form),
    evaluateQuietly: (form) => printedSession.evaluateQuietly(form)
  });
  assert.equal(printed.mode, "printed-state");

  const handleSession = await load(bothContracts);
  const handle = createApplicationDriver(handleSession);
  assert.equal(handle.mode, "state-handle");

  printed.attach();
  handle.attach();
  for (let tick = 0; tick < 64; tick += 1) {
    const input = scriptedInput(actions, tick);
    printed.tick(input);
    handle.tick(input);
    assert.equal(handle.stateText(), printed.stateText(), `tick ${tick} diverged`);
  }
  assert.equal(printLispValue(handle.present()), printLispValue(printed.present()));
});

test("a state-handle tick costs the same at the host boundary however large the state grows", async () => {
  const application = `
    (defn app.mount () '(mount 8 8 sized ()))
    (defn app.build (n acc) (if (= n 0) acc (app.build (- n 1) (cons n acc))))
    (defn app.initial-state () (app.build 400 nil))
    (defn app.step (state input) (cons (car state) state))
    (defn app.view (state) (list (list 'status (car state))))
    (defn app.frame (state input) (let ((next (app.step state input))) (cons (list 'state next) (app.view next))))
    (define app.resident-state nil)
    (defn app.attach () (set! app.resident-state (app.initial-state)))
    (defn app.advance (input) (set! app.resident-state (app.step app.resident-state input)))
    (defn app.state () app.resident-state)
    (defn app.present () (app.view app.resident-state))`;

  const handleSession = await load(application);
  const handle = createApplicationDriver(handleSession);
  handle.attach();
  const handleStart = { ...handleSession.meter };
  for (let tick = 0; tick < 20; tick += 1) handle.tick("()");
  const handleCost = (handleSession.meter.sourceBytes - handleStart.sourceBytes) / 20;
  const handleOutput = (handleSession.meter.outputBytes - handleStart.outputBytes) / 20;

  const printedSession = await load(application);
  printedSession.evaluateQuietly("(define app.attach nil)");
  const printed = createApplicationDriver({
    evaluate: (form) => printedSession.evaluate(form === "(bound? 'app.attach)" ? "false" : form),
    evaluateQuietly: (form) => printedSession.evaluateQuietly(form)
  });
  printed.attach();
  const printedStart = { ...printedSession.meter };
  for (let tick = 0; tick < 20; tick += 1) printed.tick("()");
  const printedCost = (printedSession.meter.sourceBytes - printedStart.sourceBytes) / 20;

  // The handle path sends only "(app.advance '())" and reads nothing back.
  assert.ok(handleCost < 32, `a state-handle tick sent ${handleCost} bytes`);
  assert.equal(handleOutput, 0, "a state-handle tick produces no printed output");
  // The printed path pays for the whole state twice per tick, in both
  // directions, and that cost grows with the state.
  assert.ok(printedCost > 40 * handleCost, `printed ${printedCost} bytes vs handle ${handleCost} bytes`);
});

test("an incomplete state-handle contract fails with a specific diagnostic", async () => {
  const session = await load(`
    (defn app.mount () '(mount 8 8 partial ()))
    (defn app.initial-state () 0)
    (define app.resident-state nil)
    (defn app.attach () (set! app.resident-state 0))`);
  assert.throws(() => createApplicationDriver(session), /must also define app\.advance/);
});
