import assert from "node:assert/strict";
import test from "node:test";
import { SeedLanguageError, createSeedSession } from "./seed-session.mjs";

function expectLanguageError(action, category, diagnostic) {
  assert.throws(action, (error) => {
    assert.ok(error instanceof SeedLanguageError);
    assert.equal(error.category, category);
    assert.equal(error.diagnostic, diagnostic);
    return true;
  });
}

// Host-to-runtime byte ingestion, exercised as the generic capability it is.
// Nothing here describes a file format: an asset is a length of bytes the host
// supplied, and every question about what those bytes mean is asked in Lisp.

// A deterministic byte pattern with no repeating period shorter than the
// buffer, so a truncated, duplicated, or misaligned transfer cannot coincide
// with the expected value.
function pattern(length, seed = 1) {
  const bytes = new Uint8Array(length);
  let state = seed;
  for (let index = 0; index < length; index += 1) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    bytes[index] = (state >>> 16) & 0xff;
  }
  return bytes;
}

test("a multi-megabyte asset survives ingestion byte for byte", async () => {
  const session = await createSeedSession();
  // 1.5MB is the scale of an original VSWAP container, and far past the
  // 127KB source input region, which is the reason this path exists at all.
  const source = pattern(1_500_000);
  assert.equal(Number(session.evaluate(`(asset.reserve ${source.length})`)), source.length);

  const handle = session.ingestBytes(source);
  assert.equal(handle, 0);
  assert.equal(session.evaluate("(asset.count)"), "1");
  assert.equal(session.evaluate("(bytes.length (asset.ref 0))"), String(source.length));
  assert.equal(session.evaluate("(asset.used)"), String(source.length));

  // Read the whole asset back out through the generic byte-buffer egress path
  // and compare it to what went in. This is the identity claim; sampling a few
  // offsets would not distinguish a correct transfer from a plausible one.
  session.evaluateQuietly("(define asset.roundtrip (asset.ref 0))");
  const returned = session.evaluateBytes("asset.roundtrip");
  assert.equal(returned.length, source.length);
  assert.ok(Buffer.from(returned).equals(Buffer.from(source)), "the ingested bytes changed in transit");

  // The existing bounds-checked accessors address ingested bytes directly, so
  // a Lisp decoder needs no separate vocabulary for host-supplied data.
  assert.equal(session.evaluate("(u8@ (asset.ref 0) 0)"), String(source[0]));
  assert.equal(session.evaluate(`(u8@ (asset.ref 0) ${source.length - 1})`), String(source[source.length - 1]));
  assert.equal(session.evaluate("(u16@ (asset.ref 0) 0)"), String(source[0] | (source[1] << 8)));
  expectLanguageError(() => session.evaluate(`(u8@ (asset.ref 0) ${source.length})`), "bounds", "byte index out of range");
});

test("several assets keep distinct handles, contents, and lengths", async () => {
  const session = await createSeedSession();
  const buffers = [pattern(1024, 7), pattern(5, 11), pattern(200_000, 13)];
  session.evaluate(`(asset.reserve ${buffers.reduce((total, bytes) => total + bytes.length, 0)})`);

  buffers.forEach((bytes, index) => assert.equal(session.ingestBytes(bytes), index));
  assert.equal(session.evaluate("(asset.count)"), "3");

  buffers.forEach((bytes, index) => {
    session.evaluateQuietly(`(define asset.each (asset.ref ${index}))`);
    assert.equal(session.evaluate("(bytes.length asset.each)"), String(bytes.length));
    assert.ok(Buffer.from(session.evaluateBytes("asset.each")).equals(Buffer.from(bytes)), `asset ${index} changed in transit`);
  });
});

test("capacity is declared rather than taken, and exceeding it fails truthfully", async () => {
  // No capacity has been granted, so the host cannot hand over any asset at
  // all, however small.
  const absent = await createSeedSession();
  assert.equal(absent.evaluate("(asset.used)"), "0");
  expectLanguageError(() => absent.ingestBytes(pattern(1)), "resource-exhausted", "asset capacity exceeded");

  // A grant is an exact allowance, and reserving reports what remains.
  const exceeded = await createSeedSession();
  assert.equal(exceeded.evaluate("(asset.reserve 4096)"), "4096");
  assert.equal(exceeded.evaluate("(asset.reserve 1024)"), "4096", "an already-satisfied reserve grants nothing further");
  expectLanguageError(() => exceeded.ingestBytes(pattern(4097)), "resource-exhausted", "asset capacity exceeded");

  // The transactionality suite independently reuses the trapped low-level
  // instance and proves a refused begin publishes no object or usage.
  const consumed = await createSeedSession();
  assert.equal(consumed.evaluate("(asset.reserve 4096)"), "4096");
  consumed.ingestBytes(pattern(4000));
  assert.equal(consumed.evaluate("(asset.used)"), "4000");
  // Reserving states a floor on what must be available, so it grants exactly
  // the shortfall rather than the sum of the request and the remainder.
  assert.equal(consumed.evaluate("(asset.reserve 1000)"), "1000");
  assert.equal(consumed.ingestBytes(pattern(97)), 1);

  // The declared asset allowance still sits under the kernel's own memory
  // ceiling, so an impossible reserve is a diagnostic rather than a promise.
  const impossible = await createSeedSession();
  expectLanguageError(() => impossible.evaluate("(asset.reserve 1073741823)"), "resource-exhausted", "memory limit reached");
  const negative = await createSeedSession();
  expectLanguageError(() => negative.evaluate("(asset.reserve -1)"), "resource-exhausted", "asset capacity exceeded");
});

test("ingested assets are immutable, and refusing a write says so specifically", async () => {
  const session = await createSeedSession();
  session.evaluate("(asset.reserve 64)");
  session.ingestBytes(pattern(16, 3));

  assert.equal(session.evaluate("(asset? (asset.ref 0))"), "true");
  assert.equal(session.evaluate("(asset? (bytes.alloc 4))"), "false");
  assert.equal(session.evaluate("(to-string (asset.ref 0))"), "<asset>");

  const before = session.evaluate("(u8@ (asset.ref 0) 3)");
  // The refusal names immutability rather than reporting a generic type error,
  // and it is decided before any bounds question is asked: an in-range write
  // and an out-of-range write to an asset both report the same reason.
  assert.match(diagnostic(session, "(u8! (asset.ref 0) 3 99)"), /immutable byte buffer/);
  assert.match(diagnostic(await ingested(), "(u8! (asset.ref 0) 999 99)"), /immutable byte buffer/);
  // A mutable buffer still answers the ordinary bounds diagnostic.
  assert.match(diagnostic(await createSeedSession(), "(u8! (bytes.alloc 4) 9 1)"), /byte index out of range/);
  // Reading an asset out of range is a bounds error, not an immutability one.
  assert.match(diagnostic(await ingested(), "(u8@ (asset.ref 0) 999)"), /byte index out of range/);

  // A trap discards the session, so the surviving proof that nothing was
  // written is taken from a fresh one.
  const intact = await createSeedSession();
  intact.evaluate("(asset.reserve 64)");
  intact.ingestBytes(pattern(16, 3));
  assert.equal(intact.evaluate("(u8@ (asset.ref 0) 3)"), before);

  // Allocated buffers stay mutable; immutability is a property of ingestion.
  assert.equal(intact.evaluate("(begin (define asset.scratch (bytes.alloc 4)) (u8! asset.scratch 1 42) (u8@ asset.scratch 1))"), "42");
});

test("a handle names the same asset for the life of the session", async () => {
  const session = await createSeedSession();
  session.evaluate("(asset.reserve 8192)");
  session.ingestBytes(pattern(32, 5));
  session.ingestBytes(pattern(32, 6));

  // Identity, not just equal contents: the registry hands back one object, so
  // a program can hold a decoded reference to it without copying.
  assert.equal(session.evaluate("(eq? (asset.ref 0) (asset.ref 0))"), "true");
  assert.equal(session.evaluate("(eq? (asset.ref 0) (asset.ref 1))"), "false");

  // The asset outlives every Lisp value that referenced it: it is kept alive
  // by the registry rather than by reachability from user code, which is what
  // keeps it valid once a non-moving collector starts reclaiming the heap.
  session.evaluateQuietly("(define asset.only-reference (asset.ref 0))");
  const sampled = session.evaluate("(u8@ asset.only-reference 7)");
  session.evaluateQuietly("(set! asset.only-reference nil)");
  for (let index = 0; index < 200; index += 1) session.evaluateQuietly(`(define asset.churn (bytes.alloc 64))`);
  assert.equal(session.evaluate("(u8@ (asset.ref 0) 7)"), sampled);
  assert.equal(session.evaluate("(asset.count)"), "2");

  expectLanguageError(() => session.evaluate("(asset.ref 2)"), "bounds", "asset handle out of range");
  expectLanguageError(() => session.evaluate("(asset.ref -1)"), "bounds", "asset handle out of range");
});

// Ingested assets are only as safe as the accessors that address them, so the
// bounds rule itself is pinned here for both byte tags. An index past the end
// once passed the check, because subtracting it from the length wrapped.
test("byte access is bounds-checked for every index past the end, not only adjacent ones", async () => {
  const session = await createSeedSession();
  session.evaluate("(asset.reserve 64)");
  session.ingestBytes(pattern(4, 9));
  session.evaluateQuietly("(define asset.scratch (bytes.alloc 4))");

  for (const [target, kind] of [["asset.scratch", "allocated"], ["(asset.ref 0)", "ingested"]]) {
    for (const index of [4, 5, 9, 900000, 1073741823]) {
      assert.match(diagnostic(await bounds(), `(u8@ ${target} ${index})`), /byte index out of range/, `${kind} u8@ ${index}`);
    }
    assert.match(diagnostic(await bounds(), `(u16@ ${target} 3)`), /byte index out of range/, `${kind} u16@ straddling the end`);
    assert.match(diagnostic(await bounds(), `(u8@ ${target} -1)`), /byte index out of range/, `${kind} negative index`);
  }
  // A write far past the end used to succeed silently, corrupting the heap.
  assert.match(diagnostic(await bounds(), "(u8! asset.scratch 900000 7)"), /byte index out of range/);
  // Every in-range access still works, including the last valid index.
  assert.equal(session.evaluate("(begin (u8! asset.scratch 3 77) (u8@ asset.scratch 3))"), "77");
  assert.equal(session.evaluate("(u16@ asset.scratch 2)"), String(77 << 8));
  assert.equal(session.evaluate("(u8@ (asset.ref 0) 3)"), String(pattern(4, 9)[3]));
});

test("a zero-length asset is a valid asset rather than a special case", async () => {
  const session = await createSeedSession();
  session.evaluate("(asset.reserve 16)");
  assert.equal(session.ingestBytes(new Uint8Array(0)), 0);
  assert.equal(session.evaluate("(bytes.length (asset.ref 0))"), "0");
  assert.equal(session.evaluate("(asset? (asset.ref 0))"), "true");
  expectLanguageError(() => session.evaluate("(u8@ (asset.ref 0) 0)"), "bounds", "byte index out of range");
});

// A trap discards the instance, so each bounds case needs its own session.
async function bounds() {
  const session = await createSeedSession();
  session.evaluate("(asset.reserve 64)");
  session.ingestBytes(pattern(4, 9));
  session.evaluateQuietly("(define asset.scratch (bytes.alloc 4))");
  return session;
}

async function ingested() {
  const session = await createSeedSession();
  session.evaluate("(asset.reserve 64)");
  session.ingestBytes(pattern(16, 3));
  return session;
}

// Evaluate something expected to trap and return the diagnostic the kernel
// emitted on its way out. Asserting the trap alone would not distinguish one
// failure from another, which is the whole point of a truthful message.
function diagnostic(session, source) {
  try {
    session.evaluate(source);
  } catch (error) {
    return error.diagnostic ?? "";
  }
  throw new Error(`${source} was expected to trap`);
}
