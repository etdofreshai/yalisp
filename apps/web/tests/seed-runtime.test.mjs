import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import wabtInit from "wabt";

const wat = await readFile(new URL("../src/seed/bootstrap.wat", import.meta.url), "utf8");
const bootstrap = await readFile(new URL("../public/yalisp/boot.lisp", import.meta.url), "utf8");
const generatedWasm = await readFile(new URL("../public/yalisp/seed.wasm", import.meta.url));
const uiSource = await readFile(new URL("../src/seed-runtime.ts", import.meta.url), "utf8");
const wabt = await wabtInit();
const parsed = wabt.parseWat("bootstrap.wat", wat, {});
parsed.validate();
const { buffer } = parsed.toBinary({ write_debug_names: false });
parsed.destroy();

const encoder = new TextEncoder();
const decoder = new TextDecoder();
const inputPointer = 1024;

async function createSession({ boot = false } = {}) {
  let memory;
  let output = "";
  const { instance } = await WebAssembly.instantiate(buffer, {
    host: {
      write(pointer, length) {
        output += decoder.decode(new Uint8Array(memory.buffer, pointer, length));
      }
    }
  });
  memory = instance.exports.memory;
  const load = (source) => {
    const bytes = encoder.encode(source);
    assert.ok(bytes.length <= 8192 - inputPointer, "source exceeds the seed input region");
    new Uint8Array(memory.buffer).set(bytes, inputPointer);
    return bytes.length;
  };
  instance.exports.init();
  if (boot) instance.exports.eval_all(inputPointer, load(bootstrap));
  return {
    evaluate(source) {
      output = "";
      instance.exports.eval_print(inputPointer, load(source));
      return output.replace(/\r\n/g, "\n").trimEnd();
    },
    evaluateQuietly(source) {
      output = "";
      instance.exports.eval_all(inputPointer, load(source));
    }
  };
}

test("generated seed is real WebAssembly derived from the documented Lispish milestone", () => {
  assert.equal(generatedWasm.subarray(0, 4).toString("hex"), "0061736d");
  assert.match(wat, /Derived from ETdoFreshAI\/lispish commit c78a2be/);
  assert.match(wat, /\(import "host" "write"/);
  assert.match(bootstrap, /Derived from ETdoFreshAI\/lispish commit c78a2be/);
});

test("WAT seed evaluates its documented primitive surface", async () => {
  const session = await createSession();
  assert.equal(session.evaluate("(+ 20 22)"), "42");
  assert.equal(session.evaluate("((lambda (x) (* x x)) 9)"), "81");
  assert.equal(session.evaluate(`(begin
    (define square (lambda (n) (* n n)))
    (square 12))`), "144");
});

test("Lisp bootstrap adds real macros, list functions, and named recursion", async () => {
  const session = await createSession({ boot: true });
  assert.equal(session.evaluate("(map (lambda (x) (* x x)) '(1 2 3 4))"), "(1 4 9 16)");
  assert.equal(session.evaluate("(reduce + 0 '(1 2 3 4 5))"), "15");
  assert.equal(session.evaluate("(let ((a 3) (b 4)) (+ a b))"), "7");
  assert.equal(session.evaluate(`(defn fib (n)
    (if (<= n 1) n (+ (fib (- n 1)) (fib (- n 2)))))
  (fib 10)`), "<closure>\n55");
});

test("bounded benchmark workload performs actual interpreter evaluations", async () => {
  const session = await createSession();
  session.evaluateQuietly("(define benchmark-step (lambda (x) (+ (* x x) 1)))");
  let result = "";
  for (let index = 0; index < 1000; index += 1) result = session.evaluate("(benchmark-step 21)");
  assert.equal(result, "442");
  assert.match(uiSource, /const iterations = 1000/);
  assert.match(uiSource, /performance\.now\(\)/);
  assert.match(uiSource, /requestAnimationFrame/);
  assert.match(uiSource, /JIT<\/strong><small>Unavailable/);
  assert.match(uiSource, /AOT<\/strong><small>Unavailable/);
});
