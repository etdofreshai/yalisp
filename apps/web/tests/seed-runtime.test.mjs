import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { fileURLToPath } from "node:url";
import wabtInit from "wabt";
import { wolf3dSources } from "./wolf3d-source.mjs";

const wat = await readFile(new URL("../src/seed/bootstrap.wat", import.meta.url), "utf8");
const bootstrap = await readFile(new URL("../public/yalisp/boot.lisp", import.meta.url), "utf8");
const helloWorldApplication = await readFile(new URL("../src/examples/hello-world/app.lisp", import.meta.url), "utf8");
const pongApplication = await readFile(new URL("../src/examples/pong/app.lisp", import.meta.url), "utf8");
const breakoutApplication = await readFile(new URL("../src/examples/breakout/app.lisp", import.meta.url), "utf8");
const landingApplication = await readFile(new URL("../src/site/landing.lisp", import.meta.url), "utf8");
const asteroidsApplication = await readFile(new URL("../src/examples/asteroids/app.lisp", import.meta.url), "utf8");
// The Wolf3D port is several Lisp modules, and they are loaded here in the
// order examples.ts uses rather than as a subset: what the application contract
// reaches is the program's business, and a partial load that happened to be
// enough would be this test deciding it.
const wolf3dApplication = wolf3dSources;
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
const inputEnd = 131072;

async function createSession({ boot = false } = {}) {
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
  const load = (source) => {
    const bytes = encoder.encode(source);
    assert.ok(bytes.length <= inputEnd - inputPointer, "source exceeds the seed input region");
    new Uint8Array(memory.buffer).set(bytes, inputPointer);
    return bytes.length;
  };
  instance.exports.init();
  if (boot) instance.exports.eval_all(inputPointer, load(bootstrap));
  return {
    evaluate(source) {
      outputBytes = [];
      try {
        instance.exports.eval_print(inputPointer, load(source));
      } catch (error) {
        error.seedDiagnostic = outputText();
        throw error;
      }
      return outputText();
    },
    evaluateDom(source) {
      outputBytes = [];
      try {
        instance.exports.eval_dom_print(inputPointer, load(source));
      } catch (error) {
        error.seedDiagnostic = outputText();
        throw error;
      }
      return outputText();
    },
    evaluateTrap(source) {
      outputBytes = [];
      try {
        instance.exports.eval_print(inputPointer, load(source));
        assert.fail("expected the seed to trap");
      } catch (error) {
        return { error, diagnostic: outputText() };
      }
    },
    evaluateQuietly(source) {
      outputBytes = [];
      instance.exports.eval_all(inputPointer, load(source));
    },
    evaluateBytes(source) {
      binaryOutput = undefined;
      instance.exports.eval_bytes(inputPointer, load(source));
      assert.ok(binaryOutput, "expected a byte-buffer host callback");
      return binaryOutput;
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

test("DOM evaluation preserves machine-readable strings while normal REPL output stays readable", async () => {
  const session = await createSession();
  assert.equal(session.evaluate('(list "hello world" "say \\"hi\\"" "slash \\\\" "line\nnext" "tab\tend")'), '(hello world say "hi" slash \\ line\nnext tab\tend)');
  assert.equal(session.evaluateDom('(list "hello world" "say \\"hi\\"" "slash \\\\" "line\nnext" "tab\tend")'), '("hello world" "say \\"hi\\"" "slash \\\\" "line\\nnext" "tab\\tend")');
});

test("DOM evaluation preserves complete UTF-8 characters across byte-sized seed writes", async () => {
  const session = await createSession();
  const source = '"sun ☀ moon ◐ lambda λ arrow → emoji 🚀"';
  assert.equal(session.evaluateDom(source), '"sun ☀ moon ◐ lambda λ arrow → emoji 🚀"');
});

test("CLI Hello World prints the actual seed evaluator value", () => {
  const command = spawnSync(process.execPath, [fileURLToPath(new URL("../examples/hello-world/cli.mjs", import.meta.url))], {
    encoding: "utf8"
  });
  assert.equal(command.status, 0, command.stderr);
  assert.equal(command.stderr, "");
  assert.equal(command.stdout.trim(), "Hello, world!");
});

test("Hello World mount, input, and result are evaluated from its Lisp application", async () => {
  const session = await createSession({ boot: true });
  session.evaluateQuietly(helloWorldApplication);
  assert.equal(session.evaluate("(app.mount)"), "(mount 640 160 Hello-world ((run press run (Enter))))");
  assert.equal(session.evaluate("(app.result)"), "Hello, world!");
  assert.match(session.evaluate("(app.frame 0 '((run 1)))"), /^\(\(state 1\).*\(result\)\)$/);
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

test("Pong state, input, collision, and draw protocol execute in the bootstrap evaluator", async () => {
  const session = await createSession({ boot: true });
  session.evaluateQuietly(pongApplication);
  assert.equal(session.evaluate("(app.mount)"), "(mount 640 360 Pong ((up hold move-up (ArrowUp w)) (down hold move-down (ArrowDown s))))");
  assert.equal(session.evaluate("(app.frame '(320 180 230 145 142 142 0 0) '((up 1) (down 0)))"), "((state (336 190 230 145 124 142 0 0)) (draw (clear 0) (line 320 0 320 360 1 1) (rect 28 124 12 76 1) (rect 600 142 12 76 1) (circle 336 190 8 2) (rect 282 22 12 18 1) (rect 342 22 12 18 1)) (status 0 0))");
  assert.equal(session.evaluate("(app.frame '(38 180 -230 145 142 142 0 0) '((up 0) (down 0)))"), "((state (48 190 230 145 142 142 0 0)) (draw (clear 0) (line 320 0 320 360 1 1) (rect 28 142 12 76 1) (rect 600 142 12 76 1) (circle 48 190 8 2) (rect 282 22 12 18 1) (rect 342 22 12 18 1)) (status 0 0))");
});

test("Breakout brick state, input, scoring, and draw protocol execute in the bootstrap evaluator", async () => {
  const session = await createSession({ boot: true });
  session.evaluateQuietly(breakoutApplication);
  assert.equal(session.evaluate("(app.mount)"), "(mount 640 360 Breakout ((left hold move-left (ArrowLeft a)) (right hold move-right (ArrowRight d))))");
  assert.match(session.evaluate("(app.frame '(44 45 155 190 272 0 3 (1 1 1 1 1 1 1 1)) '((left 0) (right 0)))"), /^\(\(state \(56 59 155 -190 272 10 3 \(0 1 1 1 1 1 1 1\)\)\)/);
  assert.match(session.evaluate("(app.frame '(320 278 155 -190 272 0 3 (1 1 1 1 1 1 1 1)) '((left 1) (right 0)))"), /^\(\(state \(332 264 155 -190 252 0 3/);
});

test("the landing document structure and menu state execute in the bootstrap evaluator", async () => {
  const session = await createSession({ boot: true });
  session.evaluateQuietly(landingApplication);
  assert.equal(session.evaluate("(app.initial-state)"), "(closed dark)");
  assert.match(session.evaluate("(app.view '(closed dark))"), /^\(fragment \(\(document-theme dark\)\) \(header/);
  assert.equal(session.evaluate("(app.event '(closed dark) 'toggle-menu)"), "(open dark)");
  assert.equal(session.evaluate("(app.event '(open dark) 'toggle-theme)"), "(open light)");
});

test("Asteroids entities, declared input, hit rules, and draw protocol execute in the bootstrap evaluator", async () => {
  const session = await createSession({ boot: true });
  session.evaluateQuietly(asteroidsApplication);
  assert.equal(session.evaluate("(app.mount)"), "(mount 640 360 Asteroids ((left hold rotate-left (ArrowLeft a)) (right hold rotate-right (ArrowRight d)) (thrust hold thrust (ArrowUp w)) (fire press fire (Space))))");
  assert.match(session.evaluate("(app.frame '(320 180 0 0 nil ((360 180 0 0 20))) '((left 0) (right 0) (thrust 0) (fire 1)))"), /^\(\(state \(320 180 0 100 nil nil\)\)/);
  assert.match(session.evaluate("(app.frame '(320 180 0 0 nil nil) '((left 1) (right 0) (thrust 0) (fire 0)))"), /^\(\(state \(320 180 3 0 nil nil\)\)/);
});

// What Wolf3D decodes, draws, and refuses to draw is checked against the
// original data in wolf3d-map.test.mjs and wolf3d-application.test.mjs. What
// belongs here is only that the shared application contract still holds for it
// in a bare bootstrap session, with no assets and no host.
test("Wolf3D declares a native-resolution indexed surface and reports absent originals", async () => {
  const session = await createSession({ boot: true });
  for (const module of wolf3dApplication) session.evaluateQuietly(module);
  const mount = session.evaluate("(app.mount)");
  assert.match(mount, /^\(mount 320 200 Wolf3D /, "the original's own screen mode is what it mounts");
  assert.match(mount, /\(surface indexed8 \(#[0-9a-f]{6}( #[0-9a-f]{6})*\)\)\)$/, "a paletted byte surface, not draw commands");

  // Nothing has been mounted in this session, so the program is in the state a
  // checkout without the commercial data files is in. It has to say so rather
  // than draw something, which is what keeps the absence visible instead of
  // being filled in with invented content.
  assert.equal(session.evaluate("(app.mounted?)"), "false");
  const view = session.evaluate("(app.view (app.initial-state))");
  assert.ok(!view.includes("framebuffer"), "no framebuffer may be presented without decoded planes");
  assert.match(view, /originals not mounted/);
});

test("generic byte buffers and fixed-point primitives support Wolf3D-sized data without host game logic", async () => {
  const session = await createSession({ boot: true });
  assert.equal(session.evaluate(`(begin
    (define framebuffer (bytes.alloc 64000))
    (u8! framebuffer 0 18)
    (u8! framebuffer 63998 52)
    (u8! framebuffer 63999 18)
    (list (bytes.length framebuffer) (u8@ framebuffer 0) (u16@ framebuffer 63998)))`), "(64000 18 4660)");
  assert.equal(session.evaluate("(list (bit.and 13 11) (bit.or 12 3) (bit.xor 12 10) (bit.shl 3 4) (bit.shr -32 3))"), "(9 15 6 48 -4)");
  assert.equal(session.evaluate("(fx.mul-shift 98304 131072 16)"), "196608");
});

test("generic byte-buffer evaluation transfers raw bytes without DOM serialization", async () => {
  const session = await createSession({ boot: true });
  const bytes = session.evaluateBytes(`(begin
    (define frame (bytes.alloc 64000))
    (u8! frame 0 18)
    (u8! frame 31999 52)
    (u8! frame 63999 86)
    frame)`);
  assert.equal(bytes.length, 64000);
  assert.deepEqual([bytes[0], bytes[31999], bytes[63999]], [18, 52, 86]);
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
  assert.equal(session.evaluate(`;${"x".repeat(inputEnd - inputPointer - 1)}`), "");
  assert.throws(() => session.evaluate("x".repeat(inputEnd - inputPointer + 1)), /input region/);

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

test("ordered module loads accumulate in one session while preserving the per-input limit", async () => {
  const first = `(define ordered-base 41)\n;${"a".repeat(70000)}`;
  const second = `(define ordered-total (+ ordered-base 1))\n;${"b".repeat(70000)}`;
  const limit = inputEnd - inputPointer;
  assert.ok(encoder.encode(first).length <= limit);
  assert.ok(encoder.encode(second).length <= limit);
  assert.ok(encoder.encode(first).length + encoder.encode(second).length > limit);

  const session = await createSession({ boot: true });
  session.evaluateQuietly(first);
  session.evaluateQuietly(second);
  assert.equal(session.evaluate("ordered-total"), "42");

  const reversed = await createSession({ boot: true });
  const { diagnostic } = reversed.evaluateTrap(second);
  assert.equal(diagnostic, "unbound: ordered-base");
});

test("REPL keeps its interpreter session focused while compiler paths remain separately verified", async () => {
  const session = await createSession();
  session.evaluateQuietly("(define benchmark-step (lambda (x) (+ (* x x) 1)))");
  let result = "";
  for (let index = 0; index < 1000; index += 1) result = session.evaluate("(benchmark-step 21)");
  assert.equal(result, "442");
  assert.match(uiSource, /const diagnostic = output/);
  assert.match(uiSource, /WebAssembly trap; this fresh session was discarded/);
  assert.match(uiSource, /source exceeds the seed's/);
  assert.match(uiSource, /createSeedSession/);
  assert.doesNotMatch(uiSource, /benchmarkIterations|prepareJitRunner|prepareAotRunner/);
});
