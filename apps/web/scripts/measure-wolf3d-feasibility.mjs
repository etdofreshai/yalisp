import { performance } from "node:perf_hooks";
import { readFile } from "node:fs/promises";
import wabtInit from "wabt";

const wat = await readFile(new URL("../src/seed/bootstrap.wat", import.meta.url), "utf8");
const bootstrap = await readFile(new URL("../public/yalisp/boot.lisp", import.meta.url), "utf8");
const wabt = await wabtInit();
const parsed = wabt.parseWat("bootstrap.wat", wat, {});
parsed.validate();
const { buffer } = parsed.toBinary({ write_debug_names: false });
parsed.destroy();

const encoder = new TextEncoder();
const decoder = new TextDecoder();
const inputPointer = 1024;

async function createSession() {
  let memory;
  let output = [];
  let binaryOutput;
  const { instance } = await WebAssembly.instantiate(buffer, {
    host: {
      write(pointer, length) {
        output.push(new Uint8Array(memory.buffer, pointer, length).slice());
      },
      bytes_write(pointer, length) {
        binaryOutput = new Uint8Array(memory.buffer, pointer, length).slice();
      }
    }
  });
  memory = instance.exports.memory;
  const load = (source) => {
    const bytes = encoder.encode(source);
    new Uint8Array(memory.buffer).set(bytes, inputPointer);
    return bytes.length;
  };
  const text = () => decoder.decode(Uint8Array.from(output.flatMap((chunk) => [...chunk]))).trimEnd();
  const invoke = (method, source) => {
    output = [];
    instance.exports[method](inputPointer, load(source));
    return text();
  };
  invoke("init", "");
  invoke("eval_all", bootstrap);
  return {
    invoke,
    memory,
    bytes(source) {
      binaryOutput = undefined;
      instance.exports.eval_bytes(inputPointer, load(source));
      if (!binaryOutput) throw new Error("The seed did not call the byte-buffer host callback");
      return binaryOutput;
    }
  };
}

async function measure(label, operation) {
  const started = performance.now();
  try {
    const output = await operation();
    return { label, ok: true, milliseconds: Number((performance.now() - started).toFixed(3)), output };
  } catch (error) {
    return {
      label,
      ok: false,
      milliseconds: Number((performance.now() - started).toFixed(3)),
      error: error instanceof Error ? error.message : String(error)
    };
  }
}

const result = {
  kind: "yalisp-wolf3d-feasibility-v1",
  hostMemoryBytes: (await createSession()).memory.buffer.byteLength,
  raycast: [],
  framebuffer: {}
};

for (const work of [16, 64, 256, 1024, 4096, 20480]) {
  // This is deliberately a game-agnostic fixed-point stepping loop. Its work
  // shape is one ray's fixed-point advance, repeated N times; it does not
  // encode a Wolf map, wall rule, or palette in the host or benchmark.
  //
  // The loop recurses in tail position, which the evaluator now runs
  // iteratively, so its depth is bounded by declared heap rather than by the
  // host stack. Each session reserves that heap up front.
  result.raycast.push(await measure(`fixed-point steps ${work}`, async () => (await createSession()).invoke("eval_print", `(begin
    (heap.reserve 33554432)
    (defn benchmark.step (remaining x y angle distance)
      (if (= remaining 0)
          (+ x y angle distance)
          (benchmark.step (- remaining 1)
            (+ x (fx.mul-shift angle 4096 16))
            (+ y (fx.mul-shift distance 2048 16))
            (bit.and (+ angle 10923) 65535)
            (+ distance 1024))))
    (benchmark.step ${work} 65536 131072 98304 65536))`)));
}

result.framebuffer.allocateAndSampleWrite = await measure("64K allocate and sample write", async () => (await createSession()).invoke("eval_print", `(begin
  (define benchmark.frame (bytes.alloc 64000))
  (u8! benchmark.frame 0 18)
  (u8! benchmark.frame 31999 52)
  (u8! benchmark.frame 63999 86)
  (list (bytes.length benchmark.frame)
        (u8@ benchmark.frame 0)
        (u8@ benchmark.frame 31999)
        (u8@ benchmark.frame 63999)))`));

result.framebuffer.domSerialization = await measure("64K legacy DOM serialization", async () => {
  const framebufferSession = await createSession();
  framebufferSession.invoke("eval_all", "(define benchmark.frame (bytes.alloc 64000))");
  return framebufferSession.invoke("eval_dom_print", "benchmark.frame");
});
result.framebuffer.nativeHandoff = await measure("64K raw byte hand-off", async () => {
  const framebufferSession = await createSession();
  framebufferSession.invoke("eval_all", "(define benchmark.frame (bytes.alloc 64000))");
  return framebufferSession.bytes("benchmark.frame").length;
});
result.framebuffer.expectedByteCount = 64000;
result.framebuffer.serializedByteCount = new TextEncoder().encode(result.framebuffer.domSerialization.output ?? "").length;
result.framebuffer.nativeByteHandoffAvailable = result.framebuffer.nativeHandoff.ok
  && result.framebuffer.nativeHandoff.output === result.framebuffer.expectedByteCount;
result.framebuffer.reason = "The legacy DOM path remains diagnostic-only; eval_bytes uses a separate generic byte-buffer callback.";

// --- per-tick state transport, measured at the host boundary ---------------
// Two ways to advance one tick of the same program: print the state into the
// call and parse it back out, or leave the state inside the evaluator. The
// second is what a 320x200 simulation needs; this measures the difference
// rather than asserting it.
const transportApplication = (size) => `
  (defn benchmark.build (n acc) (if (= n 0) acc (benchmark.build (- n 1) (cons n acc))))
  (define benchmark.state (benchmark.build ${size} nil))
  (defn benchmark.step (state) (cons (car state) state))
  (defn benchmark.frame (state) (list (list 'state (benchmark.step state)) (list 'status (car state))))
  (defn benchmark.advance () (set! benchmark.state (benchmark.step benchmark.state)))`;

result.stateTransport = {};
for (const size of [16, 128, 512]) {
  const ticks = 60;
  const printedSession = await createSession();
  printedSession.invoke("eval_all", `(begin (heap.reserve 33554432) ${transportApplication(size)})`);
  let printed = printedSession.invoke("eval_print", "benchmark.state");
  let printedBytes = 0;
  const printedStarted = performance.now();
  for (let tick = 0; tick < ticks; tick += 1) {
    const call = `(car (benchmark.frame '${printed}))`;
    printedBytes += call.length;
    const framed = printedSession.invoke("eval_print", call);
    printedBytes += framed.length;
    printed = framed.slice("(state ".length, -1);
  }
  const printedMs = performance.now() - printedStarted;

  const handleSession = await createSession();
  handleSession.invoke("eval_all", `(begin (heap.reserve 33554432) ${transportApplication(size)})`);
  let handleBytes = 0;
  const handleStarted = performance.now();
  for (let tick = 0; tick < ticks; tick += 1) {
    const call = "(benchmark.advance)";
    handleBytes += call.length;
    handleSession.invoke("eval_all", call);
  }
  const handleMs = performance.now() - handleStarted;

  result.stateTransport[`state-cells-${size}`] = {
    ticks,
    printedStateBytesPerTick: Math.round(printedBytes / ticks),
    stateHandleBytesPerTick: Math.round(handleBytes / ticks),
    printedStateMillisecondsPerTick: Number((printedMs / ticks).toFixed(4)),
    stateHandleMillisecondsPerTick: Number((handleMs / ticks).toFixed(4))
  };
}

// --- what a long-lived session spends per tick ------------------------------
// The seed has no collector, so this rate, not the tick cost, is what bounds
// how long a session can run. It is reported rather than hidden.
const budgetSession = await createSession();
budgetSession.invoke("eval_all", "(heap.reserve 33554432)");
budgetSession.invoke("eval_all", `(begin
  (defn benchmark.tick (state) (list (+ (car state) 1) (car (cdr state))))
  (define benchmark.budget-state (list 0 0)))`);
const budgetBefore = Number(budgetSession.invoke("eval_print", "(heap.used)"));
for (let tick = 0; tick < 500; tick += 1) budgetSession.invoke("eval_all", "(set! benchmark.budget-state (benchmark.tick benchmark.budget-state))");
const budgetPerTick = (Number(budgetSession.invoke("eval_print", "(heap.used)")) - budgetBefore) / 500;
result.heapBudget = {
  bytesPerMinimalTick: Math.round(budgetPerTick),
  ceilingBytes: 4096 * 65536,
  secondsAtSeventyHzWithNoCollector: Math.round((4096 * 65536) / (budgetPerTick * 70)),
  reason: "There is no collector yet, so a long-lived session's lifetime is its declared ceiling divided by this rate."
};

console.log(JSON.stringify(result, null, 2));
