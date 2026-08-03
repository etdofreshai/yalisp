export type SeedStage = "seed" | "bootstrap";

interface SeedExports extends WebAssembly.Exports {
  memory: WebAssembly.Memory;
  init(): void;
  eval_all(pointer: number, length: number): void;
  eval_print(pointer: number, length: number): void;
  eval_dom_print(pointer: number, length: number): void;
}

interface CompiledExports extends WebAssembly.Exports {
  run(value: number): number;
}

interface SeedExample {
  id: string;
  label: string;
  description: string;
  source: string;
}

const examples: Record<SeedStage, readonly SeedExample[]> = {
  seed: [
    {
      id: "arithmetic",
      label: "Arithmetic",
      description: "Prefix integer arithmetic in the WAT evaluator.",
      source: "(+ 20 22)"
    },
    {
      id: "lambda",
      label: "Lexical lambda",
      description: "Create and immediately call a captured function.",
      source: "((lambda (x) (* x x)) 9)"
    },
    {
      id: "named-function",
      label: "Named function",
      description: "Define a function in the seed environment, then call it.",
      source: `(begin
  (define square (lambda (n) (* n n)))
  (square 12))`
    }
  ],
  bootstrap: [
    {
      id: "map",
      label: "Map a list",
      description: "The Lisp bootstrap adds map above the seed primitives.",
      source: "(map (lambda (x) (* x x)) '(1 2 3 4))"
    },
    {
      id: "reduce",
      label: "Reduce values",
      description: "The Lisp-written fold and reduce functions build on closures.",
      source: "(reduce + 0 '(1 2 3 4 5))"
    },
    {
      id: "let",
      label: "Expand let",
      description: "The bootstrap defines let as a macro over lambda.",
      source: "(let ((a 3) (b 4)) (+ a b))"
    },
    {
      id: "fibonacci",
      label: "Fibonacci",
      description: "A real named recursive function using bootstrap defn.",
      source: `(defn fib (n)
  (if (<= n 1)
      n
      (+ (fib (- n 1)) (fib (- n 2)))))
(fib 10)`
    }
  ]
};

const inputPointer = 1024;
const inputLimit = 131072 - inputPointer;
const benchmarkIterations = 20000;
const benchmarkChunkSize = 1000;
const benchmarkInput = 21;
const benchmarkResultValue = 442;
const compilerRequest = "(cc.compile '(x) '((+ (* x x) 1)))";
const encoder = new TextEncoder();
const decoder = new TextDecoder();

let modulePromise: Promise<WebAssembly.Module> | undefined;
let bootstrapPromise: Promise<string> | undefined;
let compilerSourcePromise: Promise<string> | undefined;

function loadModule() {
  modulePromise ??= fetch("/yalisp/seed.wasm")
    .then((response) => {
      if (!response.ok) throw new Error(`seed.wasm returned ${response.status}`);
      return response.arrayBuffer();
    })
    .then((bytes) => WebAssembly.compile(bytes));
  return modulePromise;
}

function loadBootstrap() {
  bootstrapPromise ??= fetch("/yalisp/boot.lisp").then((response) => {
    if (!response.ok) throw new Error(`boot.lisp returned ${response.status}`);
    return response.text();
  });
  return bootstrapPromise;
}

function loadCompilerSource() {
  compilerSourcePromise ??= fetch("/yalisp/compiler.lisp").then((response) => {
    if (!response.ok) throw new Error(`compiler.lisp returned ${response.status}`);
    return response.text();
  });
  return compilerSourcePromise;
}

export async function createSeedSession(stage: SeedStage) {
  let memory: WebAssembly.Memory | undefined;
  let output = "";
  const instance = await WebAssembly.instantiate(await loadModule(), {
    host: {
      write(pointer: number, length: number) {
        if (!memory) throw new Error("seed memory is not initialized");
        output += decoder.decode(new Uint8Array(memory.buffer, pointer, length));
      }
    }
  });
  const exports = instance.exports as SeedExports;
  memory = exports.memory;

  const load = (source: string) => {
    const bytes = encoder.encode(source);
    if (bytes.length > inputLimit) {
      throw new Error(`source exceeds the seed's ${inputLimit}-byte input region`);
    }
    new Uint8Array(exports.memory.buffer).set(bytes, inputPointer);
    return bytes.length;
  };

  const run = (operation: () => void) => {
    output = "";
    try {
      operation();
    } catch (error) {
      const diagnostic = output.replace(/\r\n/g, "\n").trimEnd();
      const trap = error instanceof Error ? error.message : String(error);
      throw new Error(diagnostic
        ? `${diagnostic} · WebAssembly trap; this fresh session was discarded.`
        : `WebAssembly trap: ${trap}`);
    }
    return output.replace(/\r\n/g, "\n").trimEnd();
  };

  run(() => exports.init());
  if (stage === "bootstrap") {
    const bootstrap = await loadBootstrap();
    run(() => exports.eval_all(inputPointer, load(bootstrap)));
  }

  return {
    evaluate(source: string) {
      return run(() => exports.eval_print(inputPointer, load(source)));
    },
    evaluateDom(source: string) {
      return run(() => exports.eval_dom_print(inputPointer, load(source)));
    },
    evaluateQuietly(source: string) {
      run(() => exports.eval_all(inputPointer, load(source)));
    }
  };
}

function nextFrame() {
  return new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
}

function compiledRunner(instance: WebAssembly.Instance) {
  const exports = instance.exports as CompiledExports;
  if (typeof exports.run !== "function") throw new Error("compiled module does not export run");
  return exports.run;
}

async function prepareJitRunner() {
  const started = performance.now();
  const session = await createSeedSession("bootstrap");
  session.evaluateQuietly(await loadCompilerSource());
  const payload = session.evaluate(compilerRequest);
  if (!payload || payload === "nil") throw new Error("the Lisp compiler rejected the benchmark workload");

  const { default: initializeWabt } = await import("wabt");
  const wabt = await initializeWabt();
  const wat = `(module (func (export "run") ${payload}))`;
  const parsed = wabt.parseWat("yalisp-jit.wat", wat, {});
  let bytes: Uint8Array<ArrayBuffer>;
  try {
    parsed.validate();
    const generated = parsed.toBinary({ write_debug_names: false }).buffer;
    bytes = new Uint8Array(generated.length);
    bytes.set(generated);
  } finally {
    parsed.destroy();
  }
  const module = await WebAssembly.compile(bytes);
  const instance = await WebAssembly.instantiate(module);
  return { prepareMs: performance.now() - started, run: compiledRunner(instance) };
}

async function prepareAotRunner() {
  const started = performance.now();
  const response = await fetch("/yalisp/aot-benchmark.wasm");
  if (!response.ok) throw new Error(`aot-benchmark.wasm returned ${response.status}`);
  const module = await WebAssembly.compile(await response.arrayBuffer());
  const instance = await WebAssembly.instantiate(module);
  return { prepareMs: performance.now() - started, run: compiledRunner(instance) };
}

function benchmarkSummary(iterations: number, prepareMs: number, runMs: number, result: string | number) {
  const rate = runMs > 0 ? iterations / (runMs / 1000) : 0;
  return `${iterations.toLocaleString()} evaluations · prepare ${prepareMs.toFixed(2)} ms · run ${runMs.toFixed(2)} ms · total ${(prepareMs + runMs).toFixed(2)} ms · ${Math.round(rate).toLocaleString()} evaluations/s · result ${result}`;
}

function firstExample(stage: SeedStage) {
  const example = examples[stage][0];
  if (!example) throw new Error(`The ${stage} gallery has no examples.`);
  return example;
}

function mountDemo(root: HTMLElement) {
  let stage: SeedStage = root.dataset.initialStage === "bootstrap" ? "bootstrap" : "seed";
  let selected: SeedExample = firstExample(stage);

  root.innerHTML = `
    <div class="seed-stage-switch" role="group" aria-label="Interpreter stage">
      <button type="button" data-seed-stage="seed">Seed</button>
      <button type="button" data-seed-stage="bootstrap">Bootstrap</button>
    </div>
    <p class="seed-stage-copy" data-seed-stage-copy></p>
    <div class="seed-example-grid" data-seed-examples></div>
    <div class="seed-console" aria-live="polite">
      <div class="seed-console-heading"><span data-seed-selected>Selected form</span><span data-seed-status>Ready</span></div>
      <pre><code data-seed-source></code></pre>
      <div class="seed-result"><span>Actual interpreter result</span><output data-seed-result>Tap an example to run it.</output></div>
    </div>
    <details class="seed-manual">
      <summary>Try another supported form</summary>
      <label for="seed-manual-${root.dataset.initialStage || "seed"}">Form or small script</label>
      <textarea id="seed-manual-${root.dataset.initialStage || "seed"}" rows="6" spellcheck="false" data-seed-manual></textarea>
      <button type="button" data-seed-manual-run>Run typed form</button>
      <small>Input is limited to ${inputLimit.toLocaleString()} UTF-8 bytes. A guarded kernel error ends only that run; the next run starts a fresh instance.</small>
    </details>
    <div class="seed-benchmark">
      <p class="section-number">Measured execution comparison</p>
      <h3>One workload. Three real paths.</h3>
      <p>Each mode evaluates <code>(+ (* x x) 1)</code> with <code>x = 21</code>, ${benchmarkIterations.toLocaleString()} times, only after you tap Run. Interpreter time includes parsing, evaluation, and printing; fresh seed sessions are prepared every ${benchmarkChunkSize.toLocaleString()} calls to stay within the fixed heap. JIT preparation includes the Lisp-written compiler, WAT assembly, WebAssembly compilation, and instantiation. AOT uses the checked-in artifact produced by that compiler during the site build; its browser preparation is fetch, WebAssembly compilation, and instantiation.</p>
      <button type="button" data-seed-benchmark>Run interpreter + JIT + AOT</button>
      <div class="seed-benchmark-results" aria-live="polite">
        <article><strong>Interpreter</strong><output data-seed-benchmark-interpreter>Not run yet.</output></article>
        <article><strong>JIT</strong><output data-seed-benchmark-jit>Not run yet.</output></article>
        <article><strong>AOT</strong><output data-seed-benchmark-aot>Not run yet.</output></article>
      </div>
      <div class="seed-mode-grid" aria-label="Execution mode availability">
        <span><strong>Interpreter</strong><small>WAT reader/evaluator · complete source path per iteration</small></span>
        <span><strong>JIT</strong><small>Lisp compiler → fresh WebAssembly module in this browser</small></span>
        <span><strong>AOT</strong><small>Compiler-produced <code>aot-benchmark.wasm</code> from the production build</small></span>
      </div>
    </div>`;

  const stageCopy = root.querySelector<HTMLElement>("[data-seed-stage-copy]")!;
  const exampleGrid = root.querySelector<HTMLElement>("[data-seed-examples]")!;
  const selectedLabel = root.querySelector<HTMLElement>("[data-seed-selected]")!;
  const status = root.querySelector<HTMLElement>("[data-seed-status]")!;
  const source = root.querySelector<HTMLElement>("[data-seed-source]")!;
  const result = root.querySelector<HTMLOutputElement>("[data-seed-result]")!;
  const manual = root.querySelector<HTMLTextAreaElement>("[data-seed-manual]")!;
  const manualRun = root.querySelector<HTMLButtonElement>("[data-seed-manual-run]")!;
  const benchmark = root.querySelector<HTMLButtonElement>("[data-seed-benchmark]")!;
  const interpreterResult = root.querySelector<HTMLOutputElement>("[data-seed-benchmark-interpreter]")!;
  const jitResult = root.querySelector<HTMLOutputElement>("[data-seed-benchmark-jit]")!;
  const aotResult = root.querySelector<HTMLOutputElement>("[data-seed-benchmark-aot]")!;

  async function runSource(label: string, text: string) {
    selectedLabel.textContent = label;
    source.textContent = text;
    manual.value = text;
    status.textContent = "Running";
    result.textContent = "Evaluating in WebAssembly…";
    root.setAttribute("aria-busy", "true");
    try {
      const session = await createSeedSession(stage);
      result.textContent = session.evaluate(text) || "nil";
      status.textContent = stage === "seed" ? "Seed result" : "Bootstrapped result";
    } catch (error) {
      result.textContent = `Interpreter stopped: ${error instanceof Error ? error.message : String(error)}`;
      status.textContent = "Fresh session required";
    } finally {
      root.removeAttribute("aria-busy");
    }
  }

  function renderStage(runInitial = false) {
    root.querySelectorAll<HTMLButtonElement>("[data-seed-stage]").forEach((button) => {
      const active = button.dataset.seedStage === stage;
      button.classList.toggle("active", active);
      button.setAttribute("aria-pressed", String(active));
    });
    stageCopy.textContent = stage === "seed"
      ? "The WAT kernel reads and evaluates these forms directly."
      : "The same kernel first evaluates boot.lisp, making Lisp-written macros and list functions available.";
    exampleGrid.innerHTML = examples[stage].map((example) => `
      <button type="button" data-seed-example="${example.id}">
        <strong>${example.label}</strong><small>${example.description}</small>
      </button>`).join("");
    exampleGrid.querySelectorAll<HTMLButtonElement>("[data-seed-example]").forEach((button) => {
      button.addEventListener("click", () => {
        const example = examples[stage].find(({ id }) => id === button.dataset.seedExample);
        if (!example) return;
        selected = example;
        void runSource(example.label, example.source);
      });
    });
    selected = firstExample(stage);
    if (runInitial) void runSource(selected.label, selected.source);
    else {
      selectedLabel.textContent = selected.label;
      source.textContent = selected.source;
      manual.value = selected.source;
      result.textContent = "Tap an example to run it.";
      status.textContent = "Ready";
    }
  }

  root.querySelectorAll<HTMLButtonElement>("[data-seed-stage]").forEach((button) => {
    button.addEventListener("click", () => {
      stage = button.dataset.seedStage === "bootstrap" ? "bootstrap" : "seed";
      renderStage(true);
    });
  });

  manualRun.addEventListener("click", () => void runSource("Typed form", manual.value));

  benchmark.addEventListener("click", async () => {
    benchmark.disabled = true;
    interpreterResult.textContent = "Preparing a fresh seed session…";
    jitResult.textContent = "Waiting for interpreter measurement…";
    aotResult.textContent = "Waiting for JIT measurement…";
    const iterations = benchmarkIterations;
    let completed = 0;
    let runMs = 0;
    let lastResult = "";
    try {
      let prepareMs = 0;
      while (completed < iterations) {
        const chunk = Math.min(benchmarkChunkSize, iterations - completed);
        const prepareStarted = performance.now();
        const session = await createSeedSession("seed");
        session.evaluateQuietly("(define benchmark-step (lambda (x) (+ (* x x) 1)))");
        prepareMs += performance.now() - prepareStarted;
        const started = performance.now();
        for (let index = 0; index < chunk; index += 1) {
          lastResult = session.evaluate(`(benchmark-step ${benchmarkInput})`);
        }
        runMs += performance.now() - started;
        completed += chunk;
        interpreterResult.textContent = `${completed.toLocaleString()} / ${iterations.toLocaleString()} evaluations`;
        if (completed < iterations) await nextFrame();
      }
      if (Number(lastResult) !== benchmarkResultValue) throw new Error(`interpreter returned ${lastResult}, expected ${benchmarkResultValue}`);
      interpreterResult.textContent = benchmarkSummary(completed, prepareMs, runMs, lastResult);

      await nextFrame();
      jitResult.textContent = "Running the checked-in Lisp compiler…";
      const jit = await prepareJitRunner();
      const jitStarted = performance.now();
      let jitValue = 0;
      for (let index = 0; index < iterations; index += 1) jitValue = jit.run(benchmarkInput);
      const jitRunMs = performance.now() - jitStarted;
      if (jitValue !== benchmarkResultValue) throw new Error(`JIT returned ${jitValue}, expected ${benchmarkResultValue}`);
      jitResult.textContent = benchmarkSummary(iterations, jit.prepareMs, jitRunMs, jitValue);

      await nextFrame();
      aotResult.textContent = "Loading the compiler-produced AOT artifact…";
      const aot = await prepareAotRunner();
      const aotStarted = performance.now();
      let aotValue = 0;
      for (let index = 0; index < iterations; index += 1) aotValue = aot.run(benchmarkInput);
      const aotRunMs = performance.now() - aotStarted;
      if (aotValue !== benchmarkResultValue) throw new Error(`AOT returned ${aotValue}, expected ${benchmarkResultValue}`);
      aotResult.textContent = benchmarkSummary(iterations, aot.prepareMs, aotRunMs, aotValue);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      let reported = false;
      for (const output of [interpreterResult, jitResult, aotResult]) {
        if (!/Preparing|Waiting|Running|Loading/.test(output.textContent ?? "")) continue;
        output.textContent = reported ? "Not run because the preceding mode stopped." : `Stopped truthfully: ${message}`;
        reported = true;
      }
    } finally {
      benchmark.disabled = false;
    }
  });

  renderStage(true);
}

document.querySelectorAll<HTMLElement>("[data-bootstrap-demo]").forEach(mountDemo);
