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

test("add, subtract, and multiply reject every out-of-range intermediate", async () => {
  const controls = await createSeedSession({ boot: false });
  assert.equal(controls.evaluate("(+ 1073741822 1)"), "1073741823");
  assert.equal(controls.evaluate("(- -1073741823 1)"), "-1073741824");
  assert.equal(controls.evaluate("(* 536870911 2)"), "1073741822");

  for (const source of [
    "(+ 1073741823 1)",
    "(+ 1073741823 1 -1)",
    "(- -1073741824)",
    "(- -1073741824 1)",
    "(* 1073741823 2)",
    "(* -1073741824 -1)",
  ]) {
    const session = await createSeedSession({ boot: false });
    assert.throws(() => session.evaluate(source), (error) => {
      assert.ok(error instanceof SeedLanguageError, source);
      assert.equal(error.category, "arithmetic", source);
      assert.equal(error.categoryCode, 6, source);
      assert.equal(error.diagnostic, "value exceeds fixnum range", source);
      assert.equal(error.data, "value exceeds fixnum range", source);
      return true;
    });
  }
});

test("numeric literals reject values outside the fixnum representation", async () => {
  const controls = await createSeedSession({ boot: false });
  assert.equal(controls.evaluate("1073741823"), "1073741823");
  assert.equal(controls.evaluate("-1073741824"), "-1073741824");

  for (const source of [
    "1073741824",
    "+1073741824",
    "-1073741825",
    "2147483648",
    "999999999999999999999999999999999999",
    "-999999999999999999999999999999999999",
  ]) {
    const session = await createSeedSession({ boot: false });
    assert.throws(() => session.evaluate(source), (error) => {
      assert.ok(error instanceof SeedLanguageError, source);
      assert.equal(error.category, "arithmetic", source);
      assert.equal(error.categoryCode, 6, source);
      assert.equal(error.diagnostic, "value exceeds fixnum range", source);
      assert.equal(error.data, "value exceeds fixnum range", source);
      return true;
    });
  }
});

test("fixed-point multiplication rejects an out-of-range shifted result", async () => {
  const control = await createSeedSession({ boot: false });
  assert.equal(control.evaluate("(fx.mul-shift 536870911 2 0)"), "1073741822");

  for (const source of [
    "(fx.mul-shift 1073741823 2 0)",
    "(fx.mul-shift -1073741824 -1 0)",
  ]) {
    const session = await createSeedSession({ boot: false });
    assert.throws(() => session.evaluate(source), (error) => {
      assert.ok(error instanceof SeedLanguageError, source);
      assert.equal(error.category, "arithmetic", source);
      assert.equal(error.diagnostic, "value exceeds fixnum range", source);
      assert.equal(error.data, "value exceeds fixnum range", source);
      return true;
    });
  }
});

test("bit.mul-shr makes wrapped i32 multiplication explicit and checks its result", async () => {
  const session = await createSeedSession({ boot: false });
  assert.equal(session.evaluate("(bit.mul-shr 75099057 63 6)"), "6816770");
  assert.equal(session.evaluate("(bit.mul-shr -75099057 63 6)"), "-6816771");
  assert.equal(session.evaluate("(bit.mul-shr 1073741823 4 0)"), "-4",
    "the multiply wraps as i32 before shifting");
  assert.throws(() => session.evaluate("(bit.mul-shr 1073741823 2 0)"), (error) => {
    assert.ok(error instanceof SeedLanguageError);
    assert.equal(error.categoryCode, 6);
    assert.equal(error.diagnostic, "value exceeds fixnum range");
    return true;
  });
});
