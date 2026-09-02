export type SeedStage = "seed" | "bootstrap";
export type SeedErrorCategory =
  | "unbound-name"
  | "reader"
  | "arity"
  | "type"
  | "apply"
  | "arithmetic"
  | "bounds"
  | "resource-exhausted"
  | "mutation"
  | "host-contract";

const seedErrorCategories: Readonly<Record<number, SeedErrorCategory>> = Object.freeze({
  1: "unbound-name",
  2: "reader",
  3: "arity",
  4: "type",
  5: "apply",
  6: "arithmetic",
  7: "bounds",
  8: "resource-exhausted",
  9: "mutation",
  10: "host-contract",
});
const recoverableSeedErrorCodes = new Set([1, 2, 3, 4, 5, 6, 7, 9]);

export class SeedSessionDiscardedError extends Error {
  constructor() {
    super("seed session was discarded after a non-recoverable failure");
    this.name = "SeedSessionDiscardedError";
  }
}

export class SeedLanguageError extends Error {
  readonly categoryCode: number;
  readonly category: SeedErrorCategory;
  readonly diagnostic: string;
  readonly data: string;
  readonly recoverable: boolean;
  readonly sessionDiscarded: boolean;

  constructor(categoryCode: number, category: SeedErrorCategory, diagnostic: string, data: string, cause: unknown) {
    const recoverable = recoverableSeedErrorCodes.has(categoryCode);
    super(recoverable
      ? `${diagnostic} · Language error; the session was retained.`
      : `${diagnostic} · WebAssembly trap; this session was discarded.`, { cause });
    this.name = "SeedLanguageError";
    this.categoryCode = categoryCode;
    this.category = category;
    this.diagnostic = diagnostic;
    this.data = data;
    this.recoverable = recoverable;
    this.sessionDiscarded = !recoverable;
  }
}

interface SeedExports extends WebAssembly.Exports {
  memory: WebAssembly.Memory;
  init(): void;
  eval_all(pointer: number, length: number): void;
  eval_print(pointer: number, length: number): void;
  eval_dom_print(pointer: number, length: number): void;
  expand_dom_print(pointer: number, length: number): void;
  eval_bytes(pointer: number, length: number): void;
  asset_begin(length: number): number;
  asset_commit(): number;
  error_kind(): number;
  error_data_pointer(): number;
  error_data_length(): number;
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

export async function createSeedSession(stage: SeedStage) {
  let memory: WebAssembly.Memory | undefined;
  let outputBytes: Uint8Array[] = [];
  let binaryOutput: Uint8Array | undefined;
  let discarded = false;
  const instance = await WebAssembly.instantiate(await loadModule(), {
    host: {
      write(pointer: number, length: number) {
        if (!memory) throw new Error("seed memory is not initialized");
        // The DOM serializer may write one UTF-8 byte at a time. Copy before
        // the seed reuses its scratch buffer, then decode the completed stream.
        outputBytes.push(new Uint8Array(memory.buffer, pointer, length).slice());
      },
      bytes_write(pointer: number, length: number) {
        if (!memory) throw new Error("seed memory is not initialized");
        binaryOutput = new Uint8Array(memory.buffer, pointer, length).slice();
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

  const outputText = () => {
    const total = outputBytes.reduce((size, bytes) => size + bytes.length, 0);
    const bytes = new Uint8Array(total);
    let offset = 0;
    for (const chunk of outputBytes) {
      bytes.set(chunk, offset);
      offset += chunk.length;
    }
    return decoder.decode(bytes).replace(/\r\n/g, "\n").trimEnd();
  };
  const errorData = () => {
    const pointer = exports.error_data_pointer();
    const length = exports.error_data_length();
    if (pointer < 0 || length < 0 || pointer + length > exports.memory.buffer.byteLength) {
      throw new RangeError("seed returned an invalid error-data span");
    }
    return decoder.decode(new Uint8Array(exports.memory.buffer, pointer, length));
  };

  const run = (operation: () => void) => {
    if (discarded) throw new SeedSessionDiscardedError();
    outputBytes = [];
    try {
      operation();
    } catch (error) {
      const diagnostic = outputText();
      const categoryCode = exports.error_kind();
      const category = seedErrorCategories[categoryCode];
      if (category) {
        const classified = new SeedLanguageError(categoryCode, category, diagnostic, errorData(), error);
        if (classified.sessionDiscarded) discarded = true;
        throw classified;
      }
      discarded = true;
      const trap = error instanceof Error ? error.message : String(error);
      throw new Error(diagnostic
        ? `${diagnostic} · WebAssembly trap; this fresh session was discarded.`
        : `WebAssembly trap: ${trap}`);
    }
    return outputText();
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
    expandCanonical(source: string) {
      return run(() => exports.expand_dom_print(inputPointer, load(source)));
    },
    evaluateQuietly(source: string) {
      run(() => exports.eval_all(inputPointer, load(source)));
    },
    evaluateBytes(source: string) {
      binaryOutput = undefined;
      run(() => exports.eval_bytes(inputPointer, load(source)));
      if (!binaryOutput) throw new Error("The Lisp evaluation did not produce a byte buffer.");
      return binaryOutput;
    },
    // Hand the evaluator an immutable buffer of bytes and get back the handle
    // it will be known by. The host does not read, validate, or interpret the
    // bytes: what they mean is decided entirely by the Lisp program that
    // reserved the capacity to hold them.
    ingestBytes(bytes: Uint8Array) {
      let handle = -1;
      run(() => {
        const pointer = exports.asset_begin(bytes.length);
        // asset_begin may have grown the memory, detaching any earlier view,
        // so the destination is taken from the buffer as it is now.
        new Uint8Array(exports.memory.buffer).set(bytes, pointer);
        handle = exports.asset_commit();
      });
      return handle;
    }
  };
}

function firstExample(stage: SeedStage) {
  const example = examples[stage][0];
  if (!example) throw new Error(`The ${stage} gallery has no examples.`);
  return example;
}

function mountDemo(root: HTMLElement) {
  let stage: SeedStage = root.dataset.initialStage === "bootstrap" ? "bootstrap" : "seed";
  let selected: SeedExample = firstExample(stage);
  let session: Awaited<ReturnType<typeof createSeedSession>> | undefined;

  root.innerHTML = `
    <section class="repl-console" aria-label="YALISP read evaluate print loop">
      <header class="repl-console-heading">
        <span>YALISP / <span data-seed-stage-name></span></span>
        <div class="repl-console-actions"><span class="repl-console-status" data-seed-status>Ready</span><button type="button" data-repl-clear>Clear</button><button type="button" data-repl-restart>Restart</button></div>
      </header>
      <ol class="repl-transcript" data-repl-transcript aria-live="polite"></ol>
      <form class="repl-composer" data-seed-manual-form>
        <label for="seed-manual-${root.dataset.initialStage || "seed"}">Expression or small script</label>
        <textarea id="seed-manual-${root.dataset.initialStage || "seed"}" rows="1" spellcheck="false" autocomplete="off" data-seed-manual placeholder="(+ 20 22)"></textarea>
        <div class="repl-composer-footer">
          <label class="repl-example-picker" for="seed-example-${root.dataset.initialStage || "seed"}"><span>Load an example</span><select id="seed-example-${root.dataset.initialStage || "seed"}" data-seed-example-select></select></label>
          <button type="submit" data-seed-manual-run>Evaluate</button>
        </div>
        <small class="repl-composer-hint">Enter adds a line · Ctrl/Cmd + Enter evaluates · ${inputLimit.toLocaleString()} UTF-8 byte limit</small>
      </form>
    </section>`;

  const stageName = root.querySelector<HTMLElement>("[data-seed-stage-name]")!;
  const exampleSelect = root.querySelector<HTMLSelectElement>("[data-seed-example-select]")!;
  const status = root.querySelector<HTMLElement>("[data-seed-status]")!;
  const transcript = root.querySelector<HTMLOListElement>("[data-repl-transcript]")!;
  const form = root.querySelector<HTMLFormElement>("[data-seed-manual-form]")!;
  const manual = root.querySelector<HTMLTextAreaElement>("[data-seed-manual]")!;
  const manualRun = root.querySelector<HTMLButtonElement>("[data-seed-manual-run]")!;
  const clearTerminal = root.querySelector<HTMLButtonElement>("[data-repl-clear]")!;
  const restartEnvironment = root.querySelector<HTMLButtonElement>("[data-repl-restart]")!;

  function resizeComposer() {
    manual.style.height = "auto";
    manual.style.height = `${Math.min(Math.max(manual.scrollHeight, 44), 200)}px`;
    manual.style.overflowY = manual.scrollHeight > 200 ? "auto" : "hidden";
  }

  function scrollTranscript() {
    transcript.scrollTop = transcript.scrollHeight;
  }

  function appendMessage(kind: "notice" | "error", text: string) {
    const entry = document.createElement("li");
    entry.className = `repl-message repl-message-${kind}`;
    entry.textContent = text;
    transcript.append(entry);
    scrollTranscript();
  }

  function appendEvaluation(source: string) {
    const input = document.createElement("li");
    input.className = "repl-terminal-input";

    const prompt = document.createElement("span");
    prompt.className = "repl-terminal-prompt";
    prompt.setAttribute("aria-hidden", "true");
    prompt.textContent = ">";

    const submitted = document.createElement("pre");
    submitted.className = "repl-terminal-source";
    submitted.textContent = source;
    input.append(prompt, submitted);

    const output = document.createElement("output");
    const result = document.createElement("li");
    result.className = "repl-terminal-output";
    result.append(output);

    transcript.append(input, result);
    scrollTranscript();
    return { result, output };
  }

  function renderExamples() {
    exampleSelect.replaceChildren();
    for (const candidateStage of ["seed", "bootstrap"] as const) {
      const group = document.createElement("optgroup");
      group.label = candidateStage === "seed" ? "Seed examples" : "Bootstrap examples";
      for (const example of examples[candidateStage]) {
        const option = document.createElement("option");
        option.value = `${candidateStage}:${example.id}`;
        option.textContent = `${example.label} — ${example.description}`;
        group.append(option);
      }
      exampleSelect.append(group);
    }
    exampleSelect.value = `${stage}:${selected.id}`;
  }

  function renderStage(clearTranscript = false) {
    stageName.textContent = stage === "seed" ? "Seed" : "Bootstrap";
    renderExamples();
    manual.value = selected.source;
    resizeComposer();
    status.textContent = "Ready";
    if (clearTranscript) transcript.replaceChildren();
    if (!transcript.childElementCount) appendMessage("notice", "Choose an example or enter a form below. Seed examples use the WAT evaluator; Bootstrap examples load boot.lisp first.");
  }

  async function runSource(text: string) {
    if (!text.trim()) return;
    if (!session) appendMessage("notice", `Starting a fresh ${stage} session.`);
    const terminal = appendEvaluation(text);
    status.textContent = "Running";
    manualRun.disabled = true;
    clearTerminal.disabled = true;
    restartEnvironment.disabled = true;
    root.setAttribute("aria-busy", "true");
    try {
      session ??= await createSeedSession(stage);
      terminal.output.textContent = session.evaluate(text) || "nil";
      status.textContent = stage === "seed" ? "Seed result" : "Bootstrapped result";
    } catch (error) {
      terminal.result.classList.add("repl-terminal-error");
      terminal.output.textContent = error instanceof Error ? error.message : String(error);
      if (error instanceof SeedLanguageError && error.recoverable) {
        status.textContent = "Language error — session retained";
      } else {
        session = undefined;
        status.textContent = "Fresh session required";
      }
    } finally {
      scrollTranscript();
      manualRun.disabled = false;
      clearTerminal.disabled = false;
      restartEnvironment.disabled = false;
      root.removeAttribute("aria-busy");
    }
  }

  exampleSelect.addEventListener("change", () => {
    const [nextStage, id] = exampleSelect.value.split(":", 2) as [SeedStage, string];
    const example = examples[nextStage]?.find((candidate) => candidate.id === id);
    if (!example) return;
    if (nextStage !== stage) {
      stage = nextStage;
      session = undefined;
      transcript.replaceChildren();
      selected = example;
      renderStage();
      appendMessage("notice", `Loaded a ${stage} example. A new interpreter session will start when you evaluate.`);
    } else {
      selected = example;
      manual.value = example.source;
      resizeComposer();
    }
    manual.focus();
  });

  clearTerminal.addEventListener("click", () => {
    transcript.replaceChildren();
    status.textContent = "Terminal cleared";
    manual.focus();
  });

  restartEnvironment.addEventListener("click", () => {
    transcript.replaceChildren();
    session = undefined;
    status.textContent = "Environment reset";
    manual.focus();
  });

  manual.addEventListener("input", resizeComposer);
  manual.addEventListener("keydown", (event) => {
    if (event.key !== "Enter" || (!event.ctrlKey && !event.metaKey)) return;
    event.preventDefault();
    form.requestSubmit();
  });
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    void runSource(manual.value);
  });

  renderStage();
}

document.querySelectorAll<HTMLElement>("[data-bootstrap-demo]").forEach(mountDemo);
