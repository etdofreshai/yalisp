// Resource-safe test boundary for long Wolf3D replays.
//
// A replay tick mutates persistent game state. A trace row is a transient tree
// copied to the host. The seed is a bump allocator, so combining both in
// app.replay-advance and retaining every unreachable export eventually reaches
// the 256 MiB ceiling. Keep the mutator outside the arena and release only the
// export after its bytes have crossed the host boundary. This is the same
// persistent/export split used by the R1/R2 streaming application contracts.

function fixtureInteger(value, name) {
  if (!Number.isSafeInteger(value)) throw new TypeError(`${name} must be a safe integer, got ${value}`);
  return value;
}

export const LONG_REPLAY_CAPACITY_BYTES = 240 * 1024 * 1024;
export const LONG_REPLAY_HEAP_BASE_BYTES = 128 * 1024;
export const LONG_REPLAY_MEMORY_PAGE_BYTES = 64 * 1024;
export const HEAP_OBSERVER_SEED_BYTES = 12;

function nonnegativeInteger(value, label) {
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number < 0) {
    throw new Error(`${label} must be a nonnegative safe integer, got ${value}`);
  }
  return number;
}

// Parsing `(heap.used)` allocates one 12-byte cons before the primitive reads
// the bump pointer. Remove that observer allocation so measurements do not
// introduce drift of their own.
export function observeCleanHeapUsed(session, label = "long replay heap observer") {
  const raw = nonnegativeInteger(session.evaluate("(heap.used)"), `${label} raw value`);
  if (raw < HEAP_OBSERVER_SEED_BYTES) {
    throw new Error(`${label} is below the ${HEAP_OBSERVER_SEED_BYTES}-byte observer cost`);
  }
  const actual = raw - HEAP_OBSERVER_SEED_BYTES;
  const released = nonnegativeInteger(
    session.evaluate(`(heap.release ${actual})`),
    `${label} observer release`,
  );
  if (released !== actual) {
    throw new Error(`${label} observer release returned ${released}, expected ${actual}`);
  }
  return actual;
}

export function releaseHeapToMark(session, mark, label = "long replay heap release") {
  const exactMark = nonnegativeInteger(mark, `${label} mark`);
  const released = nonnegativeInteger(
    session.evaluate(`(heap.release ${exactMark})`),
    `${label} return`,
  );
  if (released !== exactMark) {
    throw new Error(`${label} returned ${released}, expected ${exactMark}`);
  }
  const observed = observeCleanHeapUsed(session, `${label} verification`);
  if (observed !== exactMark) {
    throw new Error(`${label} left heap at ${observed}, expected ${exactMark}`);
  }
  return exactMark;
}

export function prepareLongReplay(session) {
  const initialMemoryBytes = nonnegativeInteger(session.memoryBytes, "initial replay memory");
  if (initialMemoryBytes > LONG_REPLAY_CAPACITY_BYTES) {
    throw new Error(`initial replay memory ${initialMemoryBytes} exceeds the fixed cap`);
  }
  const used = observeCleanHeapUsed(session, "long replay pre-reserve heap");
  const requested = LONG_REPLAY_CAPACITY_BYTES
    - (LONG_REPLAY_HEAP_BASE_BYTES + used)
    - LONG_REPLAY_MEMORY_PAGE_BYTES + 1;
  if (!Number.isSafeInteger(requested) || requested <= 0) {
    throw new Error(`long replay has no positive reserve request at heap use ${used}`);
  }
  try {
    const capacity = nonnegativeInteger(
      session.evaluate(`(heap.reserve ${requested})`),
      "long replay reserve return",
    );
    if (capacity < requested) {
      throw new Error(`long replay reserve returned ${capacity}, expected at least ${requested}`);
    }
  } finally {
    releaseHeapToMark(session, used, "long replay reserve cleanup");
  }
  if (session.memoryBytes !== LONG_REPLAY_CAPACITY_BYTES) {
    throw new Error(
      `long replay memory is ${session.memoryBytes}, expected exact ${LONG_REPLAY_CAPACITY_BYTES}`,
    );
  }
  return Object.freeze({ initialMemoryBytes, memoryBytes: session.memoryBytes, used, requested });
}

export function replayTickPersistent(session, record) {
  const tics = fixtureInteger(record.tics, "tics");
  const controlx = fixtureInteger(record.controlx, "controlx");
  const controly = fixtureInteger(record.controly, "controly");
  const buttons = fixtureInteger(record.buttons, "buttons");
  const result = session.evaluate(
    // replay-tick owns packed fixture-button decoding, then delegates to the
    // persistent mutator. Calling replay-tick-persistent directly would reuse
    // stale button arrays and silently stop matching the canonical route.
    `(app.replay-tick ${tics} ${controlx} ${controly} ${buttons})`,
  );
  if (result !== "true") throw new Error(`persistent replay tick was rejected: ${result}`);
}

export function evaluateTransientExport(session, source) {
  const mark = observeCleanHeapUsed(session, "transient export mark");
  try {
    const output = session.evaluate(source);
    const peak = observeCleanHeapUsed(session, "transient export peak");
    return { output, mark, peak, transientBytes: peak - mark };
  } finally {
    releaseHeapToMark(session, mark, "transient export release");
  }
}

export function replayTraceRecord(session, record) {
  replayTickPersistent(session, record);
  return evaluateTransientExport(session, "(app.trace-record)");
}
