import assert from "node:assert/strict";
import test from "node:test";

import { createSeedSession } from "./seed-session.mjs";

function assertDiagnostic(operation, expected) {
  assert.throws(operation, (error) => {
    assert.equal(error.diagnostic, expected);
    return true;
  });
}

test("nested quasiquote evaluates unquote only at its matching depth", async () => {
  const unquote = await createSeedSession();
  assert.equal(unquote.evaluateCanonical(
    "(begin (define qq.x 42) `(outer `(inner ,qq.x) ,qq.x))"),
  "(outer (quasiquote (inner (unquote qq.x))) 42)");

  const splice = await createSeedSession();
  assert.equal(splice.evaluateCanonical(
    "(begin (define qq.x '(a b)) `(outer `(inner ,@qq.x) ,@qq.x))"),
  "(outer (quasiquote (inner (unquote-splicing qq.x))) a b)");

  const matched = await createSeedSession();
  assert.equal(matched.evaluateCanonical(
    "(begin (define qq.x 42) ``(,,qq.x))"),
  "(quasiquote ((unquote 42)))");
});

test("proper and empty splices preserve order at depth one", async () => {
  const proper = await createSeedSession();
  assert.equal(proper.evaluateCanonical(
    "(begin (define qq.x '(1 2)) `(a ,@qq.x b))"), "(a 1 2 b)");

  const empty = await createSeedSession();
  assert.equal(empty.evaluateCanonical(
    "(begin (define qq.x nil) `(a ,@qq.x b))"), "(a b)");
});

test("splicing requires list context and a proper-list value", async () => {
  const direct = await createSeedSession();
  direct.evaluateQuietly("(define qq.x '(1 2))");
  assertDiagnostic(() => direct.evaluateCanonical("`,@qq.x"), "unquote-splicing expected");

  const atom = await createSeedSession();
  atom.evaluateQuietly("(define qq.x 7)");
  assertDiagnostic(() => atom.evaluateCanonical("`(a ,@qq.x b)"), "list expected");

  const dotted = await createSeedSession();
  dotted.evaluateQuietly("(define qq.x '(1 . 2))");
  assertDiagnostic(() => dotted.evaluateCanonical("`(a ,@qq.x b)"), "list expected");
});

test("unquote and splice forms require exactly one operand", async () => {
  for (const [source, expected] of [
    ["(quasiquote (a (unquote) b))", "unquote expected"],
    ["(quasiquote (a (unquote 1 2) b))", "unquote expected"],
    ["(quasiquote (a (unquote-splicing) b))", "unquote-splicing expected"],
    ["(quasiquote (a (unquote-splicing '(1) '(2)) b))", "unquote-splicing expected"],
  ]) {
    const session = await createSeedSession();
    assertDiagnostic(() => session.evaluateCanonical(source), expected);
  }
});
