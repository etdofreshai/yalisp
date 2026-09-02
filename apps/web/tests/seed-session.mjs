// Shared Node harness for driving the real seed evaluator from tests and
// benchmarks. It is the same contract the browser binding uses: text in,
// printed text or raw bytes out, and nothing application-specific.
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { performance } from "node:perf_hooks";

export const SEED_ARTIFACT_PINS = Object.freeze({
  wat: Object.freeze({
    bytes: 116_403,
    sha256: "a2192105e7edb6af1b78eb85a09deaf3c06f010876526894ecb158e2702d9af8",
  }),
  wasm: Object.freeze({
    bytes: 12_028,
    sha256: "504083c9a42e3ad5dee2f2a9feba50ffd00a35a13fb3b8369ef01768db2671e7",
  }),
  boot: Object.freeze({
    bytes: 4_486,
    sha256: "ac6f82a8a5709181eaf56fc62ecc2311b84f9672940a24e6ccd149d091382dd2",
  }),
});

const artifactUrls = Object.freeze({
  wat: new URL("../src/seed/bootstrap.wat", import.meta.url),
  wasm: new URL("../public/yalisp/seed.wasm", import.meta.url),
  boot: new URL("../public/yalisp/boot.lisp", import.meta.url),
});
const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");

export const SEED_ERROR_CATEGORIES = Object.freeze({
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
const RECOVERABLE_SEED_ERROR_CODES = new Set([1, 2, 3, 4, 5, 6, 7, 9]);

export class SeedSessionDiscardedError extends Error {
  constructor() {
    super("seed session was discarded after a non-recoverable failure");
    this.name = "SeedSessionDiscardedError";
  }
}

export class SeedLanguageError extends Error {
  constructor(categoryCode, category, diagnostic, data, cause) {
    super(diagnostic, { cause });
    this.name = "SeedLanguageError";
    this.categoryCode = categoryCode;
    this.category = category;
    this.diagnostic = diagnostic;
    this.data = data;
    this.recoverable = RECOVERABLE_SEED_ERROR_CODES.has(categoryCode);
    this.sessionDiscarded = !this.recoverable;
  }
}

export function classifySeedTrap(error, categoryCode, diagnostic, data = "") {
  const category = SEED_ERROR_CATEGORIES[categoryCode];
  if (category) return new SeedLanguageError(categoryCode, category, diagnostic, data, error);
  if (error instanceof Error && diagnostic) error.diagnostic = diagnostic;
  return error;
}

export function verifyPinnedSeedArtifacts(artifacts) {
  const verified = {};
  for (const name of ["wat", "wasm", "boot"]) {
    const bytes = artifacts?.[name];
    if (!(bytes instanceof Uint8Array)) throw new TypeError(`seed ${name} must be a Uint8Array`);
    const pin = SEED_ARTIFACT_PINS[name];
    const actual = Object.freeze({ bytes: bytes.byteLength, sha256: sha256(bytes) });
    if (actual.bytes !== pin.bytes || actual.sha256 !== pin.sha256) {
      throw new Error(`seed ${name} drift: expected ${pin.bytes} bytes ${pin.sha256}, got ${actual.bytes} bytes ${actual.sha256}`);
    }
    verified[name] = actual;
  }
  return Object.freeze(verified);
}

const setupStarted = performance.now();
const [watBytes, wasmBytes, bootBytes] = await Promise.all([
  readFile(artifactUrls.wat),
  readFile(artifactUrls.wasm),
  readFile(artifactUrls.boot),
]);
const artifactReadCompleted = performance.now();
const verifiedArtifacts = verifyPinnedSeedArtifacts({ wat: watBytes, wasm: wasmBytes, boot: bootBytes });
const artifactValidationCompleted = performance.now();
const bootstrapSource = new TextDecoder().decode(bootBytes);

const instrumentation = {
  moduleCompilations: 0,
  sessionInstantiations: 0,
  artifactReadMs: artifactReadCompleted - setupStarted,
  artifactValidationMs: artifactValidationCompleted - artifactReadCompleted,
  moduleCompileMs: 0,
  moduleReadyMs: 0,
  totalInstantiationMs: 0,
  lastInstantiationMs: 0,
  totalSessionSetupMs: 0,
  lastSessionSetupMs: 0,
};
const compileStarted = performance.now();
instrumentation.moduleCompilations += 1;
const compiledSeedModule = await WebAssembly.compile(wasmBytes);
instrumentation.moduleCompileMs = performance.now() - compileStarted;
instrumentation.moduleReadyMs = performance.now() - setupStarted;

export function getSeedSessionSetupMetrics() {
  return Object.freeze({
    ...instrumentation,
    artifacts: verifiedArtifacts,
    contentId: `${verifiedArtifacts.wat.sha256}:${verifiedArtifacts.wasm.sha256}:${verifiedArtifacts.boot.sha256}`,
  });
}

const encoder = new TextEncoder();
const decoder = new TextDecoder();
const inputPointer = 1024;
const inputLimit = 131_072 - inputPointer;

export async function createSeedSession({ boot = true } = {}) {
  const sessionSetupStarted = performance.now();
  let memory;
  let outputBytes = [];
  let binaryOutput;
  let discarded = false;
  const instantiateStarted = performance.now();
  const instance = await WebAssembly.instantiate(compiledSeedModule, {
    host: {
      write(pointer, length) {
        outputBytes.push(new Uint8Array(memory.buffer, pointer, length).slice());
      },
      bytes_write(pointer, length) {
        binaryOutput = new Uint8Array(memory.buffer, pointer, length).slice();
      }
    }
  });
  const instantiationMs = performance.now() - instantiateStarted;
  instrumentation.sessionInstantiations += 1;
  instrumentation.lastInstantiationMs = instantiationMs;
  instrumentation.totalInstantiationMs += instantiationMs;
  memory = instance.exports.memory;

  // Every byte the host hands the evaluator is counted, so a test can assert
  // what a tick actually costs at the boundary instead of trusting a comment.
  const meter = { evaluations: 0, sourceBytes: 0, outputBytes: 0 };

  const load = (source) => {
    const bytes = encoder.encode(source);
    if (bytes.length > inputLimit) {
      throw new RangeError(`source exceeds the seed's ${inputLimit}-byte input region`);
    }
    new Uint8Array(memory.buffer).set(bytes, inputPointer);
    meter.evaluations += 1;
    meter.sourceBytes += bytes.length;
    return bytes.length;
  };
  const text = () => {
    const total = outputBytes.reduce((size, chunk) => size + chunk.length, 0);
    const bytes = new Uint8Array(total);
    let offset = 0;
    for (const chunk of outputBytes) { bytes.set(chunk, offset); offset += chunk.length; }
    meter.outputBytes += total;
    return decoder.decode(bytes).trimEnd();
  };
  const errorData = () => {
    const pointer = instance.exports.error_data_pointer();
    const length = instance.exports.error_data_length();
    if (pointer < 0 || length < 0 || pointer + length > memory.buffer.byteLength) {
      throw new RangeError("seed returned an invalid error-data span");
    }
    return decoder.decode(new Uint8Array(memory.buffer, pointer, length));
  };
  // A classified kernel path writes its diagnostic, records a stable category,
  // and traps. Unclassified Wasm faults retain their native error identity.
  const invoke = (method, source) => {
    if (discarded) throw new SeedSessionDiscardedError();
    outputBytes = [];
    const length = load(source);
    try {
      instance.exports[method](inputPointer, length);
    } catch (error) {
      const classified = classifySeedTrap(error, instance.exports.error_kind(), text(), errorData());
      if (!(classified instanceof SeedLanguageError) || classified.sessionDiscarded) discarded = true;
      throw classified;
    }
    return text();
  };

  invoke("init", "");
  if (boot) invoke("eval_all", bootstrapSource);

  const sessionSetupMs = performance.now() - sessionSetupStarted;
  instrumentation.lastSessionSetupMs = sessionSetupMs;
  instrumentation.totalSessionSetupMs += sessionSetupMs;

  return {
    meter,
    get memoryBytes() { return memory.buffer.byteLength; },
    read(source) { return invoke("read_print", source); },
    evaluate(source) { return invoke("eval_print", source); },
    evaluateCanonical(source) { return invoke("eval_dom_print", source); },
    expandCanonical(source) { return invoke("expand_dom_print", source); },
    evaluateQuietly(source) { invoke("eval_all", source); },
    evaluateBytes(source) {
      binaryOutput = undefined;
      invoke("eval_bytes", source);
      if (!binaryOutput) throw new Error("The evaluation did not produce a byte buffer.");
      return binaryOutput;
    },
    // The same minimal ingestion contract the browser binding uses: a length
    // of bytes in, a handle out, and no interpretation of the contents.
    ingestBytes(bytes) {
      if (discarded) throw new SeedSessionDiscardedError();
      outputBytes = [];
      try {
        const pointer = instance.exports.asset_begin(bytes.length);
        // asset_begin may have grown the memory, so the destination view is
        // taken after the call rather than before it.
        new Uint8Array(memory.buffer).set(bytes, pointer);
        return instance.exports.asset_commit();
      } catch (error) {
        const classified = classifySeedTrap(error, instance.exports.error_kind(), text(), errorData());
        if (!(classified instanceof SeedLanguageError) || classified.sessionDiscarded) discarded = true;
        throw classified;
      }
    }
  };
}
