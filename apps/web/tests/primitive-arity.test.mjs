import assert from "node:assert/strict";
import test from "node:test";

import { SeedLanguageError, createSeedSession } from "./seed-session.mjs";

const FIXED_ARITIES = Object.freeze({
  cons: 2, car: 1, cdr: 1, atom: 1, eq: 2, "=": 2, "<": 2,
  "nil?": 1, "symbol?": 1, "pair?": 1, "list?": 1, "number?": 1,
  "string?": 1, "boolean?": 1, "function?": 1, "primitive?": 1,
  "closure?": 1, "macro?": 1, "atom?": 1, "eq?": 2, mod: 2,
  "<=": 2, ">": 2, ">=": 2, "string.length": 1,
  "string.contains?": 2, "string=?": 2,
  "to-string": 1, "bytes.alloc": 1, "bytes.length": 1, "u8@": 2,
  "u8!": 3, "u16@": 2, "bit.and": 2, "bit.or": 2, "bit.xor": 2,
  "bit.shl": 2, "bit.shr": 2, "fx.mul-shift": 3, "bit.mul-shr": 3, "bound?": 1,
  "heap.reserve": 1, "heap.used": 0, "heap.capacity": 0,
  "asset.reserve": 1, "asset.used": 0, "asset.count": 0, "asset.ref": 1,
  "asset?": 1, "u16!": 3, "i16@": 2, "u32@": 2, "i32@": 2,
  "u32!": 3, "bytes.fill": 4, "bytes.copy": 5, "heap.release": 1,
  "bytes.fill-stride": 5,
});
const RANGE_ARITIES = Object.freeze({
  "string.slice": [2, 3],
  "string.substring": [2, 3],
});

function call(name, count) {
  return `(${name}${count ? ` ${Array(count).fill("0").join(" ")}` : ""})`;
}

test("every fixed primitive rejects missing and extra operands", async () => {
  for (const [name, arity] of Object.entries(FIXED_ARITIES)) {
    for (const count of new Set([Math.max(0, arity - 1), arity + 1])) {
      if (count === arity) continue;
      const session = await createSeedSession({ boot: false });
      assert.throws(() => session.evaluate(call(name, count)), (error) => {
        assert.ok(error instanceof SeedLanguageError, `${name}/${count}`);
        assert.equal(error.category, "arity", `${name}/${count}`);
        assert.equal(error.diagnostic, `${name} expected`, `${name}/${count}`);
        assert.equal(error.data, name, `${name}/${count}`);
        assert.equal(error.recoverable, true);
        return true;
      });
      assert.equal(session.evaluate("42"), "42", `${name}/${count} discarded the session`);
    }
  }
});

test("the declared variadic primitives retain their existing identities", async () => {
  for (const [source, expected] of [
    ["(+)", "0"], ["(+ 1 2 3)", "6"],
    ["(-)", "0"], ["(- 9 2 3)", "4"],
    ["(*)", "1"], ["(* 2 3 4)", "24"],
    ["(/)", "0"], ["(/ 24 3 2)", "4"],
    ["(list)", "nil"], ["(list 1 2 3)", "(1 2 3)"],
    ["(string.append)", ""], ["(string.append \"a\" \"b\" \"c\")", "abc"],
    ["(string.concat \"a\" \"b\" \"c\")", "abc"],
  ]) {
    const session = await createSeedSession({ boot: false });
    assert.equal(session.evaluate(source), expected, source);
  }
});

test("ranged primitives accept only their documented interval", async () => {
  for (const [name, [minimum, maximum]] of Object.entries(RANGE_ARITIES)) {
    for (const count of [minimum - 1, maximum + 1]) {
      const session = await createSeedSession({ boot: false });
      assert.throws(() => session.evaluate(call(name, count)), (error) => {
        assert.ok(error instanceof SeedLanguageError);
        assert.equal(error.category, "arity");
        assert.equal(error.diagnostic, `${name} expected`);
        assert.equal(error.data, name);
        return true;
      });
    }
  }

  const session = await createSeedSession({ boot: false });
  assert.equal(session.evaluate('(string.slice "abcd" 1)'), "bcd");
  assert.equal(session.evaluate('(string.slice "abcd" 1 3)'), "bc");
});
