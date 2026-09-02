import assert from "node:assert/strict";
import test from "node:test";

import { SeedLanguageError, createSeedSession } from "./seed-session.mjs";

test("zero divisors are deliberate arithmetic language errors", async () => {
  for (const [source, diagnostic] of [
    ["(/ 10 0)", "division by zero"],
    ["(mod 10 0)", "modulo by zero"],
  ]) {
    const session = await createSeedSession({ boot: false });
    assert.throws(() => session.evaluate(source), (error) => {
      assert.ok(error instanceof SeedLanguageError);
      assert.equal(error.category, "arithmetic");
      assert.equal(error.categoryCode, 6);
      assert.equal(error.diagnostic, diagnostic);
      return true;
    });
  }
});

test("division cannot construct a value outside the fixnum representation", async () => {
  const ordinary = await createSeedSession({ boot: false });
  assert.equal(ordinary.evaluate("(/ -1073741824 2)"), "-536870912");

  const overflow = await createSeedSession({ boot: false });
  assert.throws(() => overflow.evaluate("(/ -1073741824 -1)"), (error) => {
    assert.ok(error instanceof SeedLanguageError);
    assert.equal(error.category, "arithmetic");
    assert.equal(error.diagnostic, "value exceeds fixnum range");
    return true;
  });
});
