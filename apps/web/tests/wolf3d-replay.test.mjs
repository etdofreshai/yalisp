import assert from "node:assert/strict";
import test from "node:test";

import {
  HEAP_OBSERVER_SEED_BYTES,
  LONG_REPLAY_CAPACITY_BYTES,
  LONG_REPLAY_HEAP_BASE_BYTES,
  LONG_REPLAY_MEMORY_PAGE_BYTES,
  evaluateTransientExport,
  observeCleanHeapUsed,
  prepareLongReplay,
  replayTickPersistent,
  replayTraceRecord,
} from "./wolf3d-replay.mjs";

function scriptedSession(script) {
  const calls = [];
  return {
    calls,
    memoryBytes: LONG_REPLAY_CAPACITY_BYTES,
    evaluate(source) {
      calls.push(source);
      if (!script.has(source)) throw new Error(`unexpected evaluation: ${source}`);
      return script.get(source);
    },
  };
}

test("persistent replay mutation is separate from the transient trace export", () => {
  const tick = "(app.replay-tick 1 -2 3 8)";
  const session = scriptedSession(new Map([
    [tick, "true"],
    ["(heap.used)", "1012"],
    ["(app.trace-record)", "((tick 1) (health 100))"],
    ["(heap.release 1000)", "1000"],
    ["(heap.release 1456)", "1456"],
  ]));
  // Four clean observations cover the mark, peak, and exact release check.
  let usedReads = 0;
  const evaluate = session.evaluate.bind(session);
  session.evaluate = (source) => source === "(heap.used)"
    ? (session.calls.push(source), String([1012, 1468, 1012][usedReads++] ?? 1012))
    : evaluate(source);

  const result = replayTraceRecord(session, { tics: 1, controlx: -2, controly: 3, buttons: 8 });
  assert.deepEqual(result, {
    output: "((tick 1) (health 100))",
    mark: 1000,
    peak: 1456,
    transientBytes: 456,
  });
  assert.deepEqual(session.calls, [
    tick,
    "(heap.used)",
    "(heap.release 1000)",
    "(app.trace-record)",
    "(heap.used)",
    "(heap.release 1456)",
    "(heap.release 1000)",
    "(heap.used)",
    "(heap.release 1000)",
  ]);
});

test("long replay memory is fixed to an exact 240 MiB without observer drift", () => {
  const used = 1000;
  const requested = LONG_REPLAY_CAPACITY_BYTES - (LONG_REPLAY_HEAP_BASE_BYTES + used)
    - LONG_REPLAY_MEMORY_PAGE_BYTES + 1;
  const request = `(heap.reserve ${requested})`;
  const ready = scriptedSession(new Map([
    ["(heap.used)", String(used + HEAP_OBSERVER_SEED_BYTES)],
    [`(heap.release ${used})`, String(used)],
    [request, String(requested)],
  ]));
  const prepared = prepareLongReplay(ready);
  assert.deepEqual(prepared, {
    initialMemoryBytes: LONG_REPLAY_CAPACITY_BYTES,
    memoryBytes: LONG_REPLAY_CAPACITY_BYTES,
    used,
    requested,
  });

  const oversized = scriptedSession(new Map());
  oversized.memoryBytes = LONG_REPLAY_CAPACITY_BYTES + 1;
  assert.throws(() => prepareLongReplay(oversized), /exceeds the fixed cap/);

  const short = scriptedSession(new Map([
    ["(heap.used)", String(used + HEAP_OBSERVER_SEED_BYTES)],
    [`(heap.release ${used})`, String(used)],
    [request, String(requested - 1)],
  ]));
  assert.throws(() => prepareLongReplay(short), /expected at least/);
});

test("replay fixtures must be integers and rejected ticks fail closed", () => {
  const session = scriptedSession(new Map([
    ["(app.replay-tick 1 0 0 0)", "false"],
  ]));
  assert.throws(
    () => replayTickPersistent(session, { tics: 1.5, controlx: 0, controly: 0, buttons: 0 }),
    /tics must be a safe integer/,
  );
  assert.deepEqual(session.calls, []);
  assert.throws(
    () => replayTickPersistent(session, { tics: 1, controlx: 0, controly: 0, buttons: 0 }),
    /persistent replay tick was rejected/,
  );
});

test("transient export refuses an invalid mark or mismatched release", () => {
  const invalid = scriptedSession(new Map([["(heap.used)", "not-a-number"]]));
  assert.throws(() => evaluateTransientExport(invalid, "(app.trace-record)"), /nonnegative safe integer/);

  const mismatch = scriptedSession(new Map([
    ["(heap.used)", "2012"],
    ["(heap.release 2000)", "1999"],
  ]));
  assert.throws(() => observeCleanHeapUsed(mismatch), /expected 2000/);
});
