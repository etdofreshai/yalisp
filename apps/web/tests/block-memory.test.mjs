// The seed's fixed-width accessors and bounded block operations. Nothing here
// knows what the bytes mean: these are the generic primitives a Lisp program
// needs to decode a little-endian binary format and to move a frame's worth of
// pixels without paying interpreter overhead per byte.
import assert from "node:assert/strict";
import test from "node:test";
import { createSeedSession } from "./seed-session.mjs";

const trap = (session, source) => {
  try {
    session.evaluate(source);
  } catch (error) {
    return error.diagnostic;
  }
  return assert.fail(`${source} was expected to trap`);
};

test("sixteen- and thirty-two-bit accessors read and write little-endian", async () => {
  const session = await createSeedSession();
  // The byte order is asserted through u8@ rather than by round-tripping a
  // wide write back through a wide read, which would agree with itself no
  // matter which end the low byte landed on.
  assert.equal(session.evaluate(`(begin
    (define b (bytes.alloc 16))
    (u16! b 0 4660)
    (u32! b 4 305419896)
    (list (u8@ b 0) (u8@ b 1) (u8@ b 4) (u8@ b 5) (u8@ b 6) (u8@ b 7)))`), "(52 18 120 86 52 18)");

  // ...and in the other direction, from bytes the test laid down one at a time.
  assert.equal(session.evaluate(`(begin
    (u8! b 8 1) (u8! b 9 2) (u8! b 10 3) (u8! b 11 4)
    (list (u16@ b 8) (u32@ b 8)))`), "(513 67305985)");
});

test("signed reads sign-extend where the unsigned reads of the same bytes do not", async () => {
  const session = await createSeedSession();
  assert.equal(session.evaluate(`(begin
    (define b (bytes.alloc 8))
    (u16! b 0 65535)
    (u16! b 2 32768)
    (u32! b 4 -2)
    (list (u16@ b 0) (i16@ b 0) (u16@ b 2) (i16@ b 2) (i32@ b 4)))`), "(65535 -1 32768 -32768 -2)");

  // A signed write is the same store as an unsigned one, because two's
  // complement makes them the same four bytes. That is why there is no i32!.
  assert.equal(session.evaluate(`(begin
    (define c (bytes.alloc 4))
    (u32! c 0 -1)
    (list (u8@ c 0) (u8@ c 3) (i32@ c 0)))`), "(255 255 -1)");
});

test("a word too wide for a fixnum is refused rather than silently truncated", async () => {
  // A fixnum holds 31 signed bits, so some 32-bit words have no representation.
  // The failure a decoder could never detect is a quietly wrong number, so the
  // kernel says what happened and traps instead.
  const session = await createSeedSession();
  session.evaluateQuietly("(begin (define b (bytes.alloc 8)) (u32! b 0 -1) (u32! b 4 1073741823))");
  assert.equal(trap(session, "(u32@ b 0)"), "value exceeds fixnum range");

  const signed = await createSeedSession();
  signed.evaluateQuietly("(begin (define b (bytes.alloc 8)) (u16! b 0 0) (u16! b 2 16384))");
  // 0x40000000 is one past the largest fixnum, read either way.
  assert.equal(trap(signed, "(i32@ b 0)"), "value exceeds fixnum range");

  // The boundary value itself still reads, unsigned and signed alike.
  const edge = await createSeedSession();
  assert.equal(edge.evaluate(`(begin
    (define b (bytes.alloc 8))
    (u32! b 0 1073741823)
    (u32! b 4 -1073741824)
    (list (u32@ b 0) (i32@ b 0) (i32@ b 4)))`), "(1073741823 1073741823 -1073741824)");
});

test("block operations fill and copy, including overlapping ranges", async () => {
  const session = await createSeedSession();
  assert.equal(session.evaluate(`(begin
    (define b (bytes.alloc 16))
    (bytes.fill b 4 8 171)
    (list (u8@ b 3) (u8@ b 4) (u8@ b 11) (u8@ b 12)))`), "(0 171 171 0)");

  // Only the low eight bits of the fill value are laid down, as with u8!.
  assert.equal(session.evaluate("(begin (bytes.fill b 0 2 4660) (list (u8@ b 0) (u8@ b 1)))"), "(52 52)");

  assert.equal(session.evaluate(`(begin
    (define src (bytes.alloc 4))
    (u8! src 0 1) (u8! src 1 2) (u8! src 2 3) (u8! src 3 4)
    (bytes.copy b 12 src 0 4)
    (list (u32@ b 12) (bytes.copy b 12 src 0 4)))`), "(67305985 4)");

  // Overlap moves as if through a temporary, so a buffer can be shifted in
  // place. A copy that read forward through its own destination would smear
  // the first source byte across the whole run instead.
  assert.equal(session.evaluate(`(begin
    (define s (bytes.alloc 8))
    (u8! s 0 9) (u8! s 1 8) (u8! s 2 7) (u8! s 3 6)
    (bytes.copy s 1 s 0 4)
    (list (u8@ s 0) (u8@ s 1) (u8@ s 2) (u8@ s 3) (u8@ s 4)))`), "(9 9 8 7 6)");

  // An empty run at the very end of a buffer is in range and does nothing.
  assert.equal(session.evaluate("(list (bytes.fill s 8 0 1) (bytes.copy s 8 s 8 0))"), "(0 0)");
});

test("every fixed-width and block access is bounds-checked before a byte moves", async () => {
  for (const [source, expected] of [
    ["(u16! b 15 1)", "byte index out of range"],
    ["(i16@ b 15)", "byte index out of range"],
    ["(u32@ b 13)", "byte index out of range"],
    ["(i32@ b -1)", "byte index out of range"],
    ["(u32! b 16 0)", "byte index out of range"],
    ["(bytes.fill b 8 9 0)", "byte index out of range"],
    ["(bytes.fill b 0 -1 0)", "byte index out of range"],
    ["(bytes.copy b 0 b 8 9)", "byte index out of range"],
    ["(bytes.copy b 12 b 0 5)", "byte index out of range"],
    ["(u16! 42 0 1)", "byte buffer expected"],
    ["(bytes.fill \"text\" 0 1 0)", "byte buffer expected"]
  ]) {
    const session = await createSeedSession();
    session.evaluateQuietly("(define b (bytes.alloc 16))");
    assert.equal(trap(session, source), expected, source);
  }

  // A partial fill must not have happened before the range was rejected.
  const intact = await createSeedSession();
  intact.evaluateQuietly("(define b (bytes.alloc 16))");
  assert.equal(trap(intact, "(bytes.fill b 8 9 255)"), "byte index out of range");
});

test("ingested assets are a legal copy source and an illegal destination", async () => {
  const session = await createSeedSession();
  session.evaluateQuietly("(asset.reserve 64)");
  session.ingestBytes(Uint8Array.from([0x78, 0x56, 0x34, 0x12, 0xff, 0xff]));
  assert.equal(session.evaluate(`(begin
    (define a (asset.ref 0))
    (define b (bytes.alloc 8))
    (bytes.copy b 0 a 0 6)
    (list (u32@ b 0) (i16@ b 4) (i16@ a 4)))`), "(305419896 -1 -1)");
  assert.equal(trap(session, "(bytes.fill a 0 1 0)"), "immutable byte buffer");

  const writes = await createSeedSession();
  writes.evaluateQuietly("(asset.reserve 64)");
  writes.ingestBytes(Uint8Array.from([1, 2, 3, 4]));
  assert.equal(trap(writes, "(u16! (asset.ref 0) 0 1)"), "immutable byte buffer");
  const copies = await createSeedSession();
  copies.evaluateQuietly("(asset.reserve 64)");
  copies.ingestBytes(Uint8Array.from([1, 2, 3, 4]));
  assert.equal(trap(copies, "(bytes.copy (asset.ref 0) 0 (asset.ref 0) 0 4)"), "immutable byte buffer");
});

test("a 64 KiB block operation is bounded work that allocates nothing", async () => {
  const session = await createSeedSession();
  session.evaluate("(heap.reserve 1048576)");
  session.evaluateQuietly("(begin (define front (bytes.alloc 65536)) (define back (bytes.alloc 65536)))");

  // The property that matters for a long-lived application is not a wall-clock
  // number, which varies by machine, but that clearing and presenting a full
  // 64 KiB page costs the session no heap at all. Without these primitives the
  // same work is 65536 interpreted u8! calls, each of which allocates.
  const before = Number(session.evaluate("(heap.used)"));
  const started = process.hrtime.bigint();
  for (let frame = 0; frame < 32; frame += 1) {
    session.evaluateQuietly("(begin (bytes.fill back 0 65536 41) (bytes.copy front 0 back 0 65536))");
  }
  const elapsed = Number(process.hrtime.bigint() - started) / 1e6;
  const growth = Number(session.evaluate("(heap.used)")) - before;

  assert.equal(session.evaluate("(list (u8@ front 0) (u8@ front 65535) (u8@ back 32768))"), "(41 41 41)");
  // Reading and parsing the 32 source forms allocates; the 4 MiB of block work
  // they drive does not. The bound is per frame, not per byte.
  assert.ok(growth / 32 < 1024, `each 64 KiB fill-and-present frame grew the heap by ${growth / 32} bytes`);
  // A generous ceiling: this is a regression guard against a fill that has
  // silently become a per-byte interpreted loop, not a performance target.
  assert.ok(elapsed < 2000, `32 fill-and-copy frames over 64 KiB took ${elapsed}ms`);
});

test("bytes.fill-stride writes a run that is not contiguous, and only that run", async () => {
  const session = await createSeedSession();
  session.evaluateQuietly("(define surface (bytes.alloc 64))");
  session.evaluateQuietly("(bytes.fill surface 0 64 0)");
  // A column of an eight-wide surface: five writes, eight bytes apart.
  assert.equal(session.evaluate("(bytes.fill-stride surface 3 5 8 9)"), "5");
  const written = [];
  for (let index = 0; index < 64; index += 1) {
    if (session.evaluate(`(u8@ surface ${index})`) !== "0") written.push(index);
  }
  assert.deepEqual(written, [3, 11, 19, 27, 35], "exactly the strided run should have changed");
  // A stride of zero is a legal degenerate run that rewrites one byte, and a
  // count of zero writes nothing at all rather than one byte.
  assert.equal(session.evaluate("(bytes.fill-stride surface 3 4 0 7)"), "4");
  assert.equal(session.evaluate("(u8@ surface 3)"), "7");
  assert.equal(session.evaluate("(bytes.fill-stride surface 63 0 8 5)"), "0");
  assert.equal(session.evaluate("(u8@ surface 63)"), "0");
});

test("a strided run that would leave the buffer is refused before it starts", async () => {
  const session = await createSeedSession();
  session.evaluateQuietly("(define surface (bytes.alloc 64))");
  session.evaluateQuietly("(bytes.fill surface 0 64 0)");
  // The last byte of the run is 3+7*8 = 59 in range and 3+8*8 = 67 out of it.
  assert.equal(session.evaluate("(bytes.fill-stride surface 3 8 8 9)"), "8");
  assert.equal(trap(session, "(bytes.fill-stride surface 3 9 8 9)"), "byte index out of range");
  assert.equal(trap(session, "(bytes.fill-stride surface 3 2 -8 9)"), "byte index out of range");
  // Nothing moved on the refused calls: the check is made before the loop.
  assert.equal(session.evaluate("(u8@ surface 59)"), "9");
  assert.equal(session.evaluate("(u8@ surface 60)"), "0");
});

test("an ingested asset is not a legal strided fill destination either", async () => {
  const session = await createSeedSession();
  session.evaluateQuietly("(asset.reserve 64)");
  session.ingestBytes(Uint8Array.from([1, 2, 3, 4]));
  assert.equal(trap(session, "(bytes.fill-stride (asset.ref 0) 0 2 2 9)"), "immutable byte buffer");
});
