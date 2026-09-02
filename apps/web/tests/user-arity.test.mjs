import assert from "node:assert/strict";
import test from "node:test";

import { SeedLanguageError, createSeedSession } from "./seed-session.mjs";

async function expectArity(source, diagnostic) {
  const session = await createSeedSession({ boot: false });
  assert.throws(() => session.evaluate(source), (error) => {
    assert.ok(error instanceof SeedLanguageError, source);
    assert.equal(error.category, "arity", source);
    assert.equal(error.diagnostic, diagnostic, source);
    assert.equal(error.data, diagnostic.replace(/ expected$/, ""), source);
    assert.equal(error.recoverable, true, source);
    return true;
  });
  assert.equal(session.evaluate("42"), "42", `${source} discarded the session`);
}

test("special forms reject shapes outside their declared ranges", async () => {
  for (const [source, diagnostic] of [
    ["(quote)", "quote expected"], ["(quote 1 2)", "quote expected"],
    ["(if true)", "if expected"], ["(if true 1 2 3)", "if expected"],
    ["(lambda (x))", "lambda expected"], ["(macro (x))", "macro expected"],
    ["(define x)", "define expected"], ["(define x 1 2)", "define expected"],
    ["(set! x)", "set! expected"], ["(set! x 1 2)", "set! expected"],
    ["(quasiquote)", "quasiquote expected"],
    ["(quasiquote 1 2)", "quasiquote expected"],
  ]) await expectArity(source, diagnostic);

  const valid = await createSeedSession({ boot: false });
  assert.equal(valid.evaluate("(if true 1)"), "1");
  assert.equal(valid.evaluate("(if false 1)"), "nil");
  assert.equal(valid.evaluate("(if false 1 2)"), "2");
  assert.equal(valid.evaluate("(begin)"), "nil");
});

test("fixed closures and macros reject missing and extra arguments", async () => {
  for (const source of [
    "(begin (define f (lambda (a b) a)) (f 1))",
    "(begin (define f (lambda (a b) a)) (f 1 2 3))",
    "(begin (define m (macro (a b) a)) (m 1))",
    "(begin (define m (macro (a b) a)) (m 1 2 3))",
  ]) await expectArity(source, source.includes("define f") ? "f expected" : "m expected");
});

test("bare and dotted rest parameters retain their variadic contract", async () => {
  const session = await createSeedSession({ boot: false });
  assert.equal(session.evaluate("((lambda args args) 1 2 3)"), "(1 2 3)");
  assert.equal(session.evaluate("((lambda (a . rest) rest) 1 2 3)"), "(2 3)");
  assert.equal(session.evaluate("(begin (define m (macro args (cons 'list args))) (m 1 2 3))"), "(1 2 3)");
  await expectArity("((lambda (a . rest) rest))", "lambda expected");
});
