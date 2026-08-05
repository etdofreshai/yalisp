// Shared Node harness for driving the real seed evaluator from tests and
// benchmarks. It is the same contract the browser binding uses: text in,
// printed text or raw bytes out, and nothing application-specific.
import { readFile } from "node:fs/promises";
import wabtInit from "wabt";

const wat = await readFile(new URL("../src/seed/bootstrap.wat", import.meta.url), "utf8");
const bootstrapSource = await readFile(new URL("../public/yalisp/boot.lisp", import.meta.url), "utf8");
const wabt = await wabtInit();
const parsed = wabt.parseWat("bootstrap.wat", wat, {});
parsed.validate();
const { buffer } = parsed.toBinary({ write_debug_names: false });
parsed.destroy();

const encoder = new TextEncoder();
const decoder = new TextDecoder();
const inputPointer = 1024;

export async function createSeedSession({ boot = true } = {}) {
  let memory;
  let outputBytes = [];
  let binaryOutput;
  const { instance } = await WebAssembly.instantiate(buffer, {
    host: {
      write(pointer, length) {
        outputBytes.push(new Uint8Array(memory.buffer, pointer, length).slice());
      },
      bytes_write(pointer, length) {
        binaryOutput = new Uint8Array(memory.buffer, pointer, length).slice();
      }
    }
  });
  memory = instance.exports.memory;

  // Every byte the host hands the evaluator is counted, so a test can assert
  // what a tick actually costs at the boundary instead of trusting a comment.
  const meter = { evaluations: 0, sourceBytes: 0, outputBytes: 0 };

  const load = (source) => {
    const bytes = encoder.encode(source);
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
  // The kernel writes a truthful diagnostic through the ordinary text sink and
  // only then traps, so the message is recoverable even though the instance is
  // not. It is attached to the error rather than folded into its message, so
  // a test can assert on the diagnostic without changing what a trap looks
  // like to everything already matching on it.
  const invoke = (method, source) => {
    outputBytes = [];
    try {
      instance.exports[method](inputPointer, load(source));
    } catch (error) {
      if (error instanceof Error) error.diagnostic = text();
      throw error;
    }
    return text();
  };

  invoke("init", "");
  if (boot) invoke("eval_all", bootstrapSource);

  return {
    meter,
    get memoryBytes() { return memory.buffer.byteLength; },
    evaluate(source) { return invoke("eval_print", source); },
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
      outputBytes = [];
      const pointer = instance.exports.asset_begin(bytes.length);
      // asset_begin may have grown the memory, so the destination view is
      // taken after the call rather than before it.
      new Uint8Array(memory.buffer).set(bytes, pointer);
      return instance.exports.asset_commit();
    }
  };
}
