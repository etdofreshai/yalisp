import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const encoder = new TextEncoder();
const decoder = new TextDecoder();
const inputPointer = 1024;

async function createInspectingSession() {
  const bytes = await readFile(new URL("../public/yalisp/seed.wasm", import.meta.url));
  let memory;
  let output = [];
  const { instance } = await WebAssembly.instantiate(bytes, {
    host: {
      write(pointer, length) {
        output.push(new Uint8Array(memory.buffer, pointer, length).slice());
      },
      bytes_write() {},
    },
  });
  memory = instance.exports.memory;
  instance.exports.init();

  function invoke(method, source) {
    output = [];
    const encoded = encoder.encode(source);
    new Uint8Array(memory.buffer).set(encoded, inputPointer);
    try {
      instance.exports[method](inputPointer, encoded.byteLength);
      return {
        value: decoder.decode(Buffer.concat(output)).trimEnd(),
        error: null,
        categoryCode: instance.exports.error_kind(),
      };
    } catch (error) {
      return {
        value: decoder.decode(Buffer.concat(output)).trimEnd(),
        error,
        categoryCode: instance.exports.error_kind(),
      };
    }
  }

  return {
    evaluate(source) {
      const result = invoke("eval_dom_print", source);
      if (result.error) throw result.error;
      return result.value;
    },
    evaluateQuietly(source) {
      const result = invoke("eval_all", source);
      if (result.error) throw result.error;
    },
    trap(source) {
      const result = invoke("eval_dom_print", source);
      assert.ok(result.error instanceof WebAssembly.RuntimeError, source);
      return result;
    },
    trapAssetBegin(length) {
      output = [];
      try {
        instance.exports.asset_begin(length);
        assert.fail(`asset_begin(${length}) was expected to trap`);
      } catch (error) {
        assert.ok(error instanceof WebAssembly.RuntimeError);
        return {
          value: decoder.decode(Buffer.concat(output)).trimEnd(),
          error,
          categoryCode: instance.exports.error_kind(),
        };
      }
    },
  };
}

test("operator and argument failures preserve exact left-to-right effects", async () => {
  const operator = await createInspectingSession();
  operator.evaluateQuietly("(define m3.order 0)");
  const operatorFailure = operator.trap(
    "((begin (set! m3.order 1) m3.missing) (begin (set! m3.order 2) 9))",
  );
  assert.equal(operatorFailure.categoryCode, 1);
  assert.equal(operator.evaluate("m3.order"), "1");

  const argument = await createInspectingSession();
  argument.evaluateQuietly("(define m3.order 0)");
  const argumentFailure = argument.trap(
    "(+ (begin (set! m3.order 1) 8) m3.missing (begin (set! m3.order 3) 9))",
  );
  assert.equal(argumentFailure.categoryCode, 1);
  assert.equal(argument.evaluate("m3.order"), "1");

  const application = await createInspectingSession();
  application.evaluateQuietly("(define m3.order 0)");
  const applicationFailure = application.trap(
    "(/ (begin (set! m3.order 1) 8) (begin (set! m3.order 2) 0) (begin (set! m3.order 3) 1))",
  );
  assert.equal(applicationFailure.categoryCode, 6);
  assert.equal(applicationFailure.value, "division by zero");
  assert.equal(application.evaluate("m3.order"), "3");
});

test("set! and define commit only after their value succeeds", async () => {
  const session = await createInspectingSession();
  session.evaluateQuietly("(define m3.set-target 11) (define m3.define-target 22)");

  assert.equal(session.trap("(set! m3.set-target (/ 1 0))").categoryCode, 6);
  assert.equal(session.evaluate("m3.set-target"), "11");

  assert.equal(session.trap("(define m3.define-target (/ 1 0))").categoryCode, 6);
  assert.equal(session.evaluate("m3.define-target"), "22");
});

test("block byte operations validate their complete range before writing", async () => {
  const fill = await createInspectingSession();
  fill.evaluateQuietly("(define m3.buf (bytes.alloc 4)) (bytes.fill m3.buf 0 4 7)");
  assert.equal(fill.trap("(bytes.fill m3.buf 2 3 9)").categoryCode, 7);
  assert.equal(fill.evaluate("(list (u8@ m3.buf 0) (u8@ m3.buf 1) (u8@ m3.buf 2) (u8@ m3.buf 3))"), "(7 7 7 7)");

  const copy = await createInspectingSession();
  copy.evaluateQuietly("(define m3.dst (bytes.alloc 4)) (bytes.fill m3.dst 0 4 1) (define m3.src (bytes.alloc 4)) (bytes.fill m3.src 0 4 9)");
  assert.equal(copy.trap("(bytes.copy m3.dst 2 m3.src 0 3)").categoryCode, 7);
  assert.equal(copy.evaluate("(list (u8@ m3.dst 0) (u8@ m3.dst 1) (u8@ m3.dst 2) (u8@ m3.dst 3))"), "(1 1 1 1)");

  const stride = await createInspectingSession();
  stride.evaluateQuietly("(define m3.buf (bytes.alloc 4)) (bytes.fill m3.buf 0 4 7)");
  assert.equal(stride.trap("(bytes.fill-stride m3.buf 1 2 3 9)").categoryCode, 7);
  assert.equal(stride.evaluate("(list (u8@ m3.buf 0) (u8@ m3.buf 1) (u8@ m3.buf 2) (u8@ m3.buf 3))"), "(7 7 7 7)");
});

test("a refused host asset begin publishes no partial object or usage", async () => {
  const session = await createInspectingSession();
  assert.equal(session.evaluate("(asset.reserve 4096)"), "4096");
  const failure = session.trapAssetBegin(4097);
  assert.equal(failure.categoryCode, 8);
  assert.equal(failure.value, "asset capacity exceeded");
  assert.equal(session.evaluate("(asset.count)"), "0");
  assert.equal(session.evaluate("(asset.used)"), "0");
});
