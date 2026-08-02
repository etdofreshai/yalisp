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
      try {
        instance.exports.eval_print(inputPointer, load(source));
      } catch (error) {
        error.seedDiagnostic = output.replace(/\r\n/g, "\n").trimEnd();
        throw error;
      }
      return output.replace(/\r\n/g, "\n").trimEnd();
    },
    evaluateTrap(source) {
      output = "";
      try {
        instance.exports.eval_print(inputPointer, load(source));
        assert.fail("expected the seed to trap");
      } catch (error) {
        return { error, diagnostic: output.replace(/\r\n/g, "\n").trimEnd() };
      }
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

test("bootstrap or short-circuits without double evaluation or identifier capture", async () => {
  const session = await createSession({ boot: true });
  assert.equal(session.evaluate(`(begin
    (define hits 0)
    (define chosen (or (begin (set! hits (+ hits 1)) 7)
                       (begin (set! hits (+ hits 100)) 9)))
    (list chosen hits))`), "(7 1)");
  assert.equal(session.evaluate(`(begin
    (define or--once-value 41)
    (define or--rest-thunk 42)
    (list (or false or--once-value) (or false or--rest-thunk)))`), "(41 42)");
});

test("seed reports reader, unbound-name, and string type diagnostics before trapping", async () => {
  for (const [source, expected] of [
    ["missing-name", "unbound: missing-name"],
    ["(string.length 42)", "string expected"],
    ["(string.append \"safe\" 42)", "string expected"],
    ["(string.slice \"abc\" \"x\" 2)", "number expected"],
    ["\"unterminated", "unterminated string"],
    ["(+ 1 2", "unterminated list"]
  ]) {
    const session = await createSession();
    const { error, diagnostic } = session.evaluateTrap(source);
    assert.ok(error instanceof WebAssembly.RuntimeError);
    assert.equal(diagnostic, expected);
  }
});

test("string slices clamp malformed bounds without reading outside the string", async () => {
  const session = await createSession();
  assert.equal(session.evaluate('(string=? (string.slice "abc" 2 1) "")'), "true");
  assert.equal(session.evaluate('(string.slice "abc" -4 99)'), "abc");
});

test("fixed input and heap limits fail truthfully instead of crossing WebAssembly memory", async () => {
  const session = await createSession();
  assert.equal(session.evaluate(`;${"x".repeat(8192 - inputPointer - 1)}`), "");
  assert.throws(() => session.evaluate("x".repeat(8192 - inputPointer + 1)), /input region/);

  const heapSession = await createSession();
  let exhaustion;
  for (let index = 0; index < 10000 && !exhaustion; index += 1) {
    try {
      heapSession.evaluate("(list 1 2 3 4 5 6 7 8)");
    } catch (error) {
      exhaustion = error;
    }
  }
  assert.ok(exhaustion instanceof WebAssembly.RuntimeError, "bounded seed should eventually trap at its heap limit");
  assert.equal(exhaustion.seedDiagnostic, "heap exhausted");
  assert.match(exhaustion.message, /unreachable/);
});

test("bounded benchmark workload performs actual interpreter evaluations", async () => {
  const session = await createSession();
  session.evaluateQuietly("(define benchmark-step (lambda (x) (+ (* x x) 1)))");
  let result = "";
  for (let index = 0; index < 1000; index += 1) result = session.evaluate("(benchmark-step 21)");
  assert.equal(result, "442");
  assert.match(uiSource, /const benchmarkIterations = 1000/);
  assert.match(uiSource, /const benchmarkChunkSize = 50/);
  assert.match(uiSource, /performance\.now\(\)/);
  assert.match(uiSource, /requestAnimationFrame/);
  assert.match(uiSource, /const diagnostic = output/);
  assert.match(uiSource, /WebAssembly trap; this fresh session was discarded/);
  assert.match(uiSource, /source exceeds the seed's/);
  assert.match(uiSource, /JIT<\/strong><small>Unavailable/);
  assert.match(uiSource, /AOT<\/strong><small>Unavailable/);
});
