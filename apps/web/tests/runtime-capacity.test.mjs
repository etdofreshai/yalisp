import assert from "node:assert/strict";
import test from "node:test";
import { createSeedSession } from "./seed-session.mjs";

// The workload is a generic fixed-point stepping loop. It is not a raycaster,
// a map walk, or any other game shape; it only exercises the property a long
// simulation needs, which is that a tail-recursive Lisp loop of tens of
// thousands of steps completes at all.
const steppingLoop = (steps) => `(begin
  (defn capacity.step (remaining x y angle distance)
    (if (= remaining 0)
        (+ x y angle distance)
        (capacity.step (- remaining 1)
          (+ x (fx.mul-shift angle 4096 16))
          (+ y (fx.mul-shift distance 2048 16))
          (bit.and (+ angle 10923) 65535)
          (+ distance 1024))))
  (capacity.step ${steps} 65536 131072 98304 65536))`;

test("tail position is iterative, so recursion depth is bounded by heap and not by the host stack", async () => {
  const session = await createSeedSession();
  session.evaluate("(heap.reserve 33554432)");
  // 20480 is the regression floor this foundation exists to hold: 64 columns
  // of 320 steps, the order of magnitude a 320x200 per-tick workload needs.
  assert.equal(session.evaluate(steppingLoop(20480)), "370663168");
  assert.equal(session.evaluate(steppingLoop(1024)), "21943488");
});

// Each case gets its own session because the seed has no collector yet: what
// one loop allocates stays allocated for the life of that session.
test("mutual tail recursion stays iterative", async () => {
  const session = await createSeedSession();
  session.evaluate("(heap.reserve 33554432)");
  assert.equal(session.evaluate(`(begin
    (defn capacity.even? (n) (if (= n 0) 'even (capacity.odd? (- n 1))))
    (defn capacity.odd? (n) (if (= n 0) 'odd (capacity.even? (- n 1))))
    (capacity.even? 50000))`), "even");
});

test("tail calls through cond, let, and begin stay iterative", async () => {
  const session = await createSeedSession();
  session.evaluate("(heap.reserve 33554432)");
  // cond and let are macros, so every iteration re-expands them. That costs
  // roughly an order of magnitude more heap per step than a bare if, which is
  // why this case is measured separately from the primitive-only loop above.
  assert.equal(session.evaluate(`(begin
    (defn capacity.count (n total)
      (cond ((= n 0) total)
            (true (let ((next (+ total 1))) (capacity.count (- n 1) next)))))
    (capacity.count 20000 0))`), "20000");

  const begins = await createSeedSession();
  begins.evaluate("(heap.reserve 33554432)");
  assert.equal(begins.evaluate(`(begin
    (defn capacity.begin-tail (n)
      (if (= n 0) 'done (begin (+ n 1) (capacity.begin-tail (- n 1)))))
    (capacity.begin-tail 20000))`), "done");
});

test("non-tail recursion keeps its ordinary call depth and still fails truthfully", async () => {
  const session = await createSeedSession();
  session.evaluate("(heap.reserve 16777216)");
  assert.equal(session.evaluate("(begin (defn capacity.sum (n) (if (= n 0) 0 (+ 1 (capacity.sum (- n 1))))) (capacity.sum 400))"), "400");
  assert.throws(() => session.evaluate("(capacity.sum 1000000)"), /call stack|Maximum/);
});

test("memory is declared rather than taken: capacity grows only when a program reserves it", async () => {
  const session = await createSeedSession();
  const initial = session.memoryBytes;
  assert.equal(initial, 16 * 65536);
  const before = Number(session.evaluate("(heap.capacity)"));
  assert.ok(before < initial, "capacity is what remains above the bump pointer");

  const reserved = Number(session.evaluate("(heap.reserve 8388608)"));
  assert.ok(reserved >= 8388608, `reserve returned ${reserved}`);
  assert.ok(session.memoryBytes > initial, "reserving grew the underlying memory");

  // A reserve that is already satisfied does not grow memory again.
  const settled = session.memoryBytes;
  session.evaluate("(heap.reserve 1024)");
  assert.equal(session.memoryBytes, settled);

  const used = Number(session.evaluate("(heap.used)"));
  assert.ok(used > 0 && used < session.memoryBytes, `heap.used reported ${used}`);

  // The ceiling is a declared limit, so exceeding it is a diagnostic, not a
  // silent allocation of unbounded host memory.
  assert.throws(() => session.evaluate("(heap.reserve 1073741824)"), /unreachable/);
});

test("bound? answers the global environment without evaluating or trapping on unbound names", async () => {
  const session = await createSeedSession();
  assert.equal(session.evaluate("(list (bound? 'map) (bound? 'heap.reserve) (bound? 'app.attach))"), "(true true false)");
  session.evaluateQuietly("(define app.attach (lambda () 1))");
  assert.equal(session.evaluate("(bound? 'app.attach)"), "true");
  assert.throws(() => session.evaluate("(bound? 42)"), /unreachable/);
});

test("a long-lived session's per-tick allocation is measurable, which is what bounds its lifetime", async () => {
  const session = await createSeedSession();
  session.evaluate("(heap.reserve 8388608)");
  session.evaluateQuietly("(defn capacity.tick (state) (list (+ (car state) 1) (car (cdr state))))");
  session.evaluateQuietly("(define capacity.state (list 0 0))");
  const before = Number(session.evaluate("(heap.used)"));
  for (let index = 0; index < 500; index += 1) session.evaluateQuietly("(set! capacity.state (capacity.tick capacity.state))");
  const perTick = (Number(session.evaluate("(heap.used)")) - before) / 500;
  assert.ok(perTick > 0, "a tick allocates");
  // There is no collector yet, so this number is the session's budget burn
  // rate. The assertion is a regression guard on that rate, not a claim that
  // the rate is sustainable indefinitely.
  assert.ok(perTick < 512, `a minimal tick allocated ${perTick} bytes`);
});

// heap.release is the inverse of heap.used, and it is what lets a program that
// recomputes something every frame survive an allocator that never collects.
test("heap.release winds the allocator back to a mark, so a repeated computation is bounded", async () => {
  const session = await createSeedSession();
  session.evaluate("(heap.reserve 8388608)");
  session.evaluateQuietly("(defn capacity.work (n acc) (if (= n 0) acc (capacity.work (- n 1) (+ acc n))))");
  session.evaluateQuietly("(define capacity.sink (bytes.alloc 16))");

  const mark = Number(session.evaluate("(heap.used)"));
  session.evaluate("(capacity.work 2000 0)");
  const spent = Number(session.evaluate("(heap.used)")) - mark;
  assert.ok(spent > 100000, `the work should have allocated something worth reclaiming, spent ${spent}`);

  // The release returns the position it left the allocator at, which is the
  // mark exactly. Asking again costs a form to read, so the follow-up reading
  // is a few bytes past it rather than equal to it.
  assert.equal(Number(session.evaluate(`(heap.release ${mark})`)), mark);
  assert.ok(Number(session.evaluate("(heap.used)")) - mark < 64);

  // Repeating the same work inside the same region costs the session nothing:
  // this is the property a per-frame renderer depends on.
  for (let round = 0; round < 20; round += 1) {
    session.evaluateQuietly(`(begin (u32! capacity.sink 0 (capacity.work 2000 0)) (heap.release ${mark}))`);
  }
  assert.ok(Number(session.evaluate("(heap.used)")) - mark < 65536, "twenty rounds should retain almost nothing");
  // The value the work produced survives, because it was written into a buffer
  // allocated before the mark rather than left on the heap after it.
  assert.equal(session.evaluate("(u32@ capacity.sink 0)"), "2001000");
});

test("a mark the allocator cannot honour is refused rather than corrupting the heap", async () => {
  const session = await createSeedSession();
  session.evaluate("(heap.reserve 1048576)");
  const used = Number(session.evaluate("(heap.used)"));
  // Forward of the current position is not a mark this session ever handed out.
  assert.throws(() => session.evaluate(`(heap.release ${used + 4096})`), /unreachable/);
  assert.throws(() => session.evaluate("(heap.release -1)"), /unreachable/);

  // An ingested asset is permanent by contract, so no mark below one is legal
  // even though the bump pointer could physically be wound back there.
  const beforeAsset = Number(session.evaluate("(heap.used)"));
  session.evaluateQuietly("(asset.reserve 64)");
  session.ingestBytes(Uint8Array.from([7, 8, 9, 10]));
  assert.throws(() => session.evaluate(`(heap.release ${beforeAsset})`), /unreachable/);
  assert.equal(session.evaluate("(u8@ (asset.ref 0) 0)"), "7");
});
