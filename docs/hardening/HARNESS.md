# Deterministic conformance and benchmark harness

Status: protocol v2; sequential conformance and M1 golden cross-stage
observations implemented, with property/GC metrics staged by M2/M6.

The implemented M0 runner discovers test files lexicographically and executes
one fresh Node process at a time. Its external manifest pins the complete
working-tree identity, toolchain, inputs, artifacts, raw TAP hashes, exit
status, and stable hierarchical case IDs. Top-level IDs remain
`file::ordinal::name`; nested cases append their full parent/child ordinal and
name path. Promotion mode forbids skips, cancellations, incomplete shards,
abnormal exits, failures, and coverage below the inherited floor. Resume is
allowed only for an exact schema and identity hash.
After the fully green core-IR validation run, the non-regression floor is 350
web tests; later M4 work may raise the observed total but cannot lower that
floor.

## 1. One corpus, independent observations

The golden corpus is declarative data. Each case has:

- stable ID and language-profile requirements;
- setup modules and the program/input/event sequence;
- applicable stages;
- explicit resource caps;
- expected returned value(s), ordered text/byte effects, error record, and named
  state probes;
- tags for reader, expansion, evaluation, compiler, memory, FFI, or application
  coverage.

Expected observations are reviewed fixtures. The harness may provide an
explicit fixture-update command, but a normal test run never rewrites expected
data and never treats one execution stage as the oracle for another.

Each stage emits canonical JSON with ordered arrays. The state hash is SHA-256
over length-delimited UTF-8 names and canonical printed probe values, not a hash
of raw addresses or object layout. Later managed-runtime snapshots must assign
stable traversal IDs so relocation cannot affect semantic hashes.

The differential report sorts cases and stages by their declared order and
stops its headline at the earliest differing tuple:

```text
(case index, event/evaluation index, observation channel, byte/value offset)
```

It still retains the complete report for diagnosis. Unsupported stages are
`not-applicable`, never silently counted as passes.

The implemented M1 corpus is
`apps/web/tests/fixtures/golden-observations-v1.json`; the runner is
`scripts/hardening/golden-differential.mjs`. Probe hashes use four-byte
big-endian byte lengths followed by UTF-8 name and canonical value bytes.
Normal execution never writes the fixture. Source, output, linear memory, and
generated code have authored per-case caps.

The companion reviewed compiler profile is
`apps/web/tests/fixtures/compiler-error-intersection-v1.json`. Its runner
executes every seed error category, checks the compiler disposition, records
the first excluded numeric value divergence, and publishes expected versus
observed jointly supported error counts inside every golden report.

## 2. Conformance suites

### Reader/printer

- fixed edge corpus for comments, quotes, dotted lists, escapes, Unicode,
  numeric bounds, symbols, and 12 malformed prefix/closing/string/dotted forms
  (implemented);
- seeded generated acyclic data for `read(print(v))` (implemented as
  `yalisp-acyclic-data-v1`, seed `0x59414c49`, 256 cases, depth 4);
- seeded source forms for parse/print/parse canonical idempotence (implemented
  as `yalisp-source-forms-v1`, seed `0x53524346`, 512 cases, depth 5);
- persisted seed, generator version, case count, category counts, shrink policy,
  and minimal failure (`null` for the green corpus).

### Macro/IR/compiler

- named outer expansion is independently observable and does not evaluate the
  produced user form (implemented by `expand_dom_print`);
- eight authored boot expansions repeat in four fresh sessions and 16 rounds
  in one warmed session at pinned canonical hash `34214d55...` (implemented);
- capture-sensitive lexical fixtures and nested quasiquote/unquote depth;
- canonical expansion hashes (implemented for M2); IR hashes await M4;
- IR validation plus serialize/decompile round trips when those paths exist;
- interpreted, reference-IR, incrementally compiled, deoptimized, and AOT
  observation comparison over their declared support intersection.
- the bounded compiler's current error intersection is explicit: 11 reviewed
  cases cover ten categories, eight codegen rejections, two precompile
  boundaries, one numeric-domain exclusion, and zero jointly supported errors.
- core IR v1 validation walks canonical YaLisp list data in deterministic
  field order, reports the earliest code/path, and applies exact node, depth,
  literal-node, literal-byte, source-unit, provenance, binding, and cycle caps.
  Lowering and reference execution are still open M4 gates.

### Errors and caps

- every malformed input class and wrong type/arity;
- host input 130,048/130,049 bytes, combined reader depth 511/512, reader work
  32,768/32,769 empty forms, and named outer expansion step 1,024/1,025 have
  fixed passing/failing evidence (implemented);
- output bytes, evaluation work, heap, asset, compilation, and foreign-call
  caps retain their current selected evidence and await their owning milestone
  protocols;
- atomicity probes after failed byte/block/mutation operations;
- no test may rely only on a host exception string when a language error record
  exists.

### Stateful and real workloads

- closure/mutation sessions with redefinition and cache invalidation;
- mode switching after setup, between events, inside recursive workloads at safe
  points, after compilation failure, and after forced deoptimization;
- boot library functions, Hello World, Pong, Breakout, Asteroids, documentation
  DOM programs, and Wolf3D source/runtime contracts;
- application fixtures must retain independent source/trace authority and may
  not encode captured expected state transitions as implementation logic.

## 3. Measurement isolation

A publishable performance run uses a quiet host:

- no build/test/benchmark from another task is consuming the selected CPUs;
- AC power and the machine's performance policy are recorded;
- CPU model, core/thread topology, kernel, architecture, Node, npm, WebAssembly
  engine, WABT, git commit, dirty-state hash, and relevant environment are
  included;
- affinity and concurrency are fixed when supported;
- background load and temperature/frequency indicators are sampled before and
  after; a violated threshold invalidates the run rather than becoming a slow
  baseline.

The initial audit intentionally does not publish timing from a run that shared
the host with multiple high-CPU browser and test workloads.

## 4. Timing protocol

Every benchmark declares operation, input, setup excluded/included, warmups,
measured iterations, samples, timeout, and expected semantic result.

Default protocol unless a workload justifies another checked-in value:

1. create a fresh process for each sample group;
2. run 10 untimed warmups or until five consecutive batch means vary by less
   than 2%, whichever requires more work, capped at 100 warmups;
3. choose a batch size whose measured interval is at least 100 ms;
4. collect at least 30 independent batch samples;
5. retain all raw samples and report min, median, p95, p99, max, mean, standard
   deviation, median absolute deviation, and coefficient of variation;
6. do not delete outliers; mark a run invalid when environmental evidence or
   excessive variance breaches the declared gate;
7. compare medians with bootstrap confidence intervals and require both a
   practical effect threshold and a 95% interval excluding zero for an
   optimization claim.

Latency percentiles are calculated from per-operation observations when the
timer resolution and overhead permit; otherwise batch latency is clearly
labelled. Timer overhead is measured and reported, not blindly subtracted.

## 5. Fixed performance workloads

- cold artifact read/hash/compile/instantiate/init;
- bootstrap source read/eval and compiler source read/eval;
- read, expand, eval, and compile measured separately for fixed small, medium,
  and near-cap programs;
- primitive integer, pair, lexical lookup/mutation, string, byte access, and
  bulk byte operations;
- closure calls, tail recursion, macro-heavy code, and allocation-heavy code;
- compiled equivalents where supported;
- state-handle tick and printed-state boundary transport;
- 64 KiB raw frame handoff;
- Hello World plus the real interactive/application workloads listed above.

Report steady-state operations/second and p50/p95/p99 latency. Compilation
reports generated bytes, cache bytes, and WABT-unfolded static instructions.
Representative runs add dynamic instruction counts when a stable engine/tool
path is available.

## 6. Memory and GC protocol

For every workload record, where available:

- process RSS and peak RSS;
- WebAssembly pages, heap/arena committed and used bytes;
- allocation bytes/counts per operation;
- live and retained object counts/bytes by type;
- free-list/arena fragmentation;
- collector reclaimed bytes and throughput;
- pause p50/p95/p99/max and mutator utilization;
- stable-handle/pinned bytes;
- retained-heap and RSS slope after warmup.

Micro memory runs use fixed operation counts. Soaks use a fixed event trace and
report warmup, duration, sample interval, regression method, confidence, and the
last successful state hash. Required tiers are 10 minutes for presubmit, one
hour for milestone evidence, and 8+ hours for release evidence. Until a
collector exists, the harness reports allocation burn and predicted cap time;
it must not relabel manual `heap.release` as automatic memory safety.

Heap observation must itself be allocation-neutral. For the current seed,
evaluating `(heap.used)` allocates one 12-byte cons before the primitive reads
the bump pointer; the harness subtracts and releases that pinned observer cost,
then verifies the exact clean mark. Long Wolf3D replay fixes linear memory at
240 MiB, separates persistent mutation from transient trace export, verifies
every release, reports maximum transient use and minimum headroom, and retains
all canonical state assertions. These application arenas are bounded evidence,
not a substitute for M6 managed memory.

## 7. Result and baseline policy

Results are append-only JSON plus a concise Markdown summary. A result includes
schema version, corpus version/hash, artifact hashes, commands, machine data,
resource caps, raw samples, statistics, and pass/divergence status.

A baseline is promoted only when:

- conformance is green first;
- the host gate passed;
- commands and inputs reproduce from a clean dependency install;
- repeated runs meet the declared variance limit;
- the scorecard and roadmap link the result;
- changes in coverage, machine, toolchain, or methodology are called out.

Regression thresholds are per metric. Performance defaults to a 5% practical
threshold with statistical support; memory, code size, and pauses have explicit
absolute and relative budgets. A result above threshold fails unless an
approved tradeoff is documented with stronger global evidence.

## 8. Reproducible command surface

Current repository checks:

```bash
npm run typecheck
npm test
npm run build
npm run hardening:golden
node --test --test-concurrency=1 apps/web/tests/reader-printer-property.test.mjs
node --test --test-concurrency=1 apps/web/tests/macro-expansion-determinism.test.mjs
node --test --test-concurrency=1 apps/web/tests/resource-cap-properties.test.mjs
node --test --test-concurrency=1 apps/web/tests/quasiquote-depth.test.mjs
node --test --test-concurrency=1 apps/web/tests/source-form-idempotence.test.mjs
node --test --test-concurrency=1 apps/web/tests/structured-error-boundary.test.mjs
node --test --test-concurrency=1 apps/web/tests/arithmetic-errors.test.mjs
node --test --test-concurrency=1 apps/web/tests/error-transactionality.test.mjs
node --test --test-concurrency=1 apps/web/tests/primitive-arity.test.mjs
node --test --test-concurrency=1 apps/web/tests/user-arity.test.mjs
node --test --test-concurrency=1 apps/web/tests/compiler-error-intersection.test.mjs
node --test --test-concurrency=1 apps/web/tests/core-ir-validator.test.mjs
npm run measure:wolf3d-feasibility --workspace @yalisp/web
node scripts/hardening/artifact-inventory.mjs
```

The focused reader/property command is deterministic and prints its generator
configuration into TAP diagnostics. A failing case reports the stable case
index and source/printed/reparsed triple. The source-form command prints its
fixed generator configuration, category counts, and null minimal failure. The
quasiquote command fixes nested depth, splice context/value shape, and arity.
Malformed fixtures use the independent `read_print` boundary so evaluator
failures cannot masquerade as reader diagnostics.

The structured-error boundary command asserts all ten stable seed category
codes and both sides of the M3 distinction: classified failures have typed host
records with category-specific UTF-8 `data`, while an actual out-of-bounds Wasm
access has category zero, empty data, and remains a native runtime fault. It
also covers metadata reset at host entries through independent fresh
invocations. Its recovery case retains a definition after a
recoverable unbound error, then proves resource exhaustion invalidates the
wrapper and rejects the next call.

The arithmetic-error command proves both zero-divisor diagnostics, both literal
boundaries, every `+`/`-`/`*` fold intermediate, unary negation, fixed-point
shifted results, and the minimum-fixnum divided by `-1` edge while retaining
in-range controls. It also distinguishes checked `*` from the explicit
wrapped-`i32` then arithmetic-shift contract of `bit.mul-shr`, including a
post-shift result that cannot enter the tagged domain.

The transactional-error command intentionally reuses trapped instances only as
an inspection instrument. It records post-failure bindings and destination
bytes for operator/argument order, `set!`/`define`, and the three atomic block
operations. This does not authorize production session reuse.

The primitive-arity command exhaustively checks missing and extra operands for
every fixed primitive and alias, both sides of ranged string slicing, all seven
variadic identities, and same-session recovery. Compiler/golden validation is a
required companion because compiler.lisp uses variadic string concatenation.

The compiler-error-intersection command independently executes the reviewed
profile. A compiler rejection is not counted as error parity; it is an explicit
stage exclusion. The numeric boundary must show both independently observed
values and prove the first intermediate lies outside the declared range.

The user-arity command covers fixed/optional/variadic special forms, fixed
closure and macro calls, bare-rest and dotted-rest parameters, invalid parameter
identifiers, named diagnostics, and same-session recovery.

The resource-cap property command prints its accounting versions and persisted
minimal witnesses. `binary-min-depth-v1` refuses to classify an incidental host
trap as a cap failure; only the exact `depth cap` diagnostic advances its shrink
boundary.

The web test command fixes Node's file concurrency at four workers. This keeps
the same complete file/case set while bounding concurrent 240 MiB application
sessions and making scheduling reproducible across machines with different CPU
counts. Changing concurrency does not authorize removing a case or weakening a
resource cap; the result still reports every test individually.

The current feasibility script is useful evidence but is single-shot and does
not satisfy this protocol's warmup, percentile, raw-sample, quiet-host, or
variance requirements. `hardening:golden` now writes a versioned external JSON
report and concise result; later milestones will add benchmark, memory, and
soak subcommands while keeping schemas versioned.
