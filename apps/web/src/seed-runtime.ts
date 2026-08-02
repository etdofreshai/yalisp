type SeedStage = "seed" | "bootstrap";

interface SeedExports extends WebAssembly.Exports {
  memory: WebAssembly.Memory;
  init(): void;
  eval_all(pointer: number, length: number): void;
  eval_print(pointer: number, length: number): void;
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
const inputLimit = 8192 - inputPointer;
const benchmarkIterations = 1000;
const benchmarkChunkSize = 50;
const encoder = new TextEncoder();
const decoder = new TextDecoder();

let modulePromise: Promise<WebAssembly.Module> | undefined;
let bootstrapPromise: Promise<string> | undefined;

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

async function createSession(stage: SeedStage) {
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
    evaluateQuietly(source: string) {
      run(() => exports.eval_all(inputPointer, load(source)));
    }
  };
}

function nextFrame() {
  return new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
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
      <p class="section-number">Measured interpreter benchmark</p>
      <h3>1,000 real seed evaluations</h3>
      <p>The benchmark repeatedly parses, evaluates, and prints <code>(benchmark-step 21)</code> through the WAT interpreter. It runs only when tapped and yields between bounded chunks.</p>
      <button type="button" data-seed-benchmark>Run interpreter benchmark</button>
      <output data-seed-benchmark-result>Not run yet.</output>
      <div class="seed-mode-grid" aria-label="Execution mode availability">
        <span><strong>Interpreter</strong><small>Available · WAT evaluator</small></span>
        <span><strong>JIT</strong><small>Unavailable in this YALISP seed</small></span>
        <span><strong>AOT</strong><small>Unavailable in this YALISP seed</small></span>
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
  const benchmarkResult = root.querySelector<HTMLOutputElement>("[data-seed-benchmark-result]")!;

  async function runSource(label: string, text: string) {
    selectedLabel.textContent = label;
    source.textContent = text;
    manual.value = text;
    status.textContent = "Running";
    result.textContent = "Evaluating in WebAssembly…";
    root.setAttribute("aria-busy", "true");
    try {
      const session = await createSession(stage);
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
    benchmarkResult.textContent = "Preparing a fresh seed session…";
    const iterations = benchmarkIterations;
    let completed = 0;
    let elapsed = 0;
    let lastResult = "";
    try {
      const session = await createSession("seed");
      session.evaluateQuietly("(define benchmark-step (lambda (x) (+ (* x x) 1)))");
      while (completed < iterations) {
        const chunk = Math.min(benchmarkChunkSize, iterations - completed);
        const started = performance.now();
        for (let index = 0; index < chunk; index += 1) {
          lastResult = session.evaluate("(benchmark-step 21)");
        }
        elapsed += performance.now() - started;
        completed += chunk;
        benchmarkResult.textContent = `${completed.toLocaleString()} / ${iterations.toLocaleString()} evaluations`;
        if (completed < iterations) await nextFrame();
      }
      const rate = elapsed > 0 ? completed / (elapsed / 1000) : 0;
      benchmarkResult.textContent = `${completed.toLocaleString()} evaluations · ${elapsed.toFixed(2)} ms evaluation time · ${Math.round(rate).toLocaleString()} evaluations/s · last result ${lastResult}`;
    } catch (error) {
      benchmarkResult.textContent = `${completed.toLocaleString()} completed before the interpreter stopped: ${error instanceof Error ? error.message : String(error)}`;
    } finally {
      benchmark.disabled = false;
    }
  });

  renderStage(true);
}

document.querySelectorAll<HTMLElement>("[data-bootstrap-demo]").forEach(mountDemo);
