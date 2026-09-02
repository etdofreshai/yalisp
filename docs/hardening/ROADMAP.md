# YaLisp hardening roadmap

Status: prioritized roadmap, 2026-09-01.

Only one milestone may be active. Priority is determined by the earliest
semantic/evidence gap, not by novelty or benchmark appeal. Later milestones may
be reordered when measured evidence changes, but their exit criteria may not be
weakened to declare success.

## M0 — control plane and reproducible baseline (complete)

Goal: make the current state legible and obtain a truthful full-suite baseline.
Resource false positives discovered while collecting that baseline may be
closed only by measured ownership changes that preserve the same values,
effects, errors, and state assertions.

Exit criteria:

- semantics, bootstrap, roadmap, harness, scorecard, and dated baseline are
  checked in as mutually consistent documents;
- repository writer/process audit is recorded;
- seed, bootstrap, compiler, and AOT sizes/hashes are recorded and reproducible;
- typecheck, focused core tests, and full test result are recorded separately;
- performance results are accepted only from a quiet-host run satisfying the
  harness variance gate;
- the inherited long Wolf3D replay gates run under one exact memory cap with
  self-neutral heap observations and balanced transient exports;
- no pre-existing content or unpushed commit is discarded; every dirty file
  touched by M0 retains its prior work and has focused conformance evidence.

Exit evidence: frozen promotion identity `bc3b6bb4...` completed all 35 shards
and 301 hierarchical cases with 301 passes and zero failures, skips,
cancellations, abnormal processes, or policy violations. The durable result is
`baselines/2026-09-01-m0-promotion.md`.

## M1 — golden observation corpus and earliest-divergence runner (complete)

Goal: replace hand-selected equality checks with a machine-readable corpus and
a runner that compares every applicable execution stage.

Exit criteria:

- cases cover literals/data, lexical scope, mutation, closure capture, exact
  evaluation/effect order, macros, quasiquote, tail calls, errors, byte effects,
  and resource caps;
- each result records value, ordered effects, error, and named state probes with
  a deterministic hash;
- seed-only, bootstrap interpreter, and the compiler's declared subset run from
  the same case definitions;
- the report names the earliest divergent case and observation field, or says
  there is none over the declared support intersection;
- expected observations are reviewable data and are not generated from the
  implementation under test in the same run;
- at least one deliberately perturbed stage proves the runner detects and
  localizes a divergence.

Exit evidence: 15 reviewed cases and 17 events produced 30 applicable stage
observations with no expected or cross-stage divergence; 15 unsupported stage
slots were explicit `not-applicable`. A deliberate `442` -> `443` bootstrap
perturbation localized to case 12, event 0, `value`, byte 3. See
`baselines/2026-09-01-m1-golden.md`.

## M2 — reader/printer, expansion, and malformed-input properties (complete)

Goal: make code-as-data boundaries deterministic and resource-bounded.

Exit criteria:

- generated acyclic values satisfy canonical `read(print(v)) == v`;
- parse/print/parse is idempotent for source forms in the supported grammar;
- string escaping, dotted pairs, numeric/symbol ambiguity, comments, and Unicode
  have fixed regression cases;
- macro expansion is captured independently from evaluation and hashes
  identically across repeated fresh and long-lived sessions;
- fuzz seeds, generator version, case count, and shrink output are persisted;
- malformed input and depth/size/work caps fail deterministically without
  out-of-bounds access or unbounded host recursion.

Current evidence: generator `yalisp-acyclic-data-v1`, seed `0x59414c49`, 256
cases, and maximum generated depth 4 now pass canonical `read(print(v))` checks.
Nine fixed string cases and 14 grammar cases cover control escapes, delimiters,
Unicode, comments, proper/dotted lists, numeric bounds, and symbols; 12
malformed cases have stable diagnostics. The deterministic first failures were
carriage return and generated case 1 containing byte `0x04`; the seed reader now
decodes the canonical printer's complete control-escape profile.

Independent named outer-macro inspection is also implemented. Eight authored
boot expansions have pinned canonical hash `34214d55...` across four fresh
sessions and 16 rounds in one long-lived session. A two-macro expansion chain
produces a mutation form 16 times at hash `45787172...` while its counter remains
zero, proving the inspection path does not evaluate produced user code.

The fixed cap slice is now explicit and independently minimized. Both hosts
accept exactly 130,048 UTF-8 source bytes and reject the next byte. Combined
form/list-spine depth 511 passes while nested depth 512 is the binary-shrunk
minimal `depth cap` witness. Exactly 32,768 empty forms consume the 65,536-unit
reader work budget; form 32,769 yields `work cap`. A self-reproducing named
macro stops at 1,024 applications with `macro expansion cap` instead of spending
the heap. The generator and shrink evidence have persisted versions and
boundaries.

The malformed reader boundary now independently rejects unmatched/trailing
closing parentheses; leading, missing, unterminated, and overfull dotted tails;
and quote/quasiquote/unquote prefixes without an operand. A valid `(1 . 2)` is
retained. `(1 2))` proves ordered prior output is preserved before the later
`read error`.

The quasiquote boundary now tracks nesting depth and evaluates unquote only at
the matching level. Four deterministic groups cover nested unquote, nested and
outer splicing, matching-depth double unquote, proper and empty splice order,
direct-splice rejection, proper-list enforcement, and exact one-operand arity.
The generated source-form property `yalisp-source-forms-v1` adds 512 cases at
maximum depth 5 with seed `0x53524346`. It covers atoms, strings, proper and
dotted lists, quote/quasiquote/unquote/splice prefixes, comments, and varied
whitespace. Canonical parse/print/parse is idempotent for every case; all required
categories have nonzero coverage and the persisted minimal failure is `null`.
The combined focused hardening set is 43/43. This satisfies every M2 exit
criterion; see `baselines/2026-09-01-m2-source-forms.md`.

## M3 — structured errors and transactional failure boundaries (active)

Goal: replace incidental traps with a minimal inspectable language error record
while preserving bootstrap simplicity.

Exit criteria:

- reader, arity, type, unbound name, apply, arithmetic, bounds, memory, and host
  errors have stable categories and data;
- prior effects and mutations are precisely tested for left-to-right failure;
- operations documented atomic do not partially mutate on failure;
- the host can distinguish a recoverable language error from a corrupted or
  exhausted runtime;
- interpreter/compiler errors are equivalent for every jointly supported case.

Current evidence: the seed-owned `error_kind` export now covers ten stable
categories: unbound name, reader, arity, type, apply, arithmetic range, bounds,
resource exhaustion, mutation, and host contract. Metadata resets at every host
entry. Both Node and browser hosts surface a typed `SeedLanguageError` containing
category code/name, diagnostic, native cause, recoverability, and discarded-
session state. A real out-of-bounds Wasm access retains
`WebAssembly.RuntimeError` identity with category zero. The golden runner uses
typed metadata exclusively and contains no diagnostic-string category inference.
Division and modulo by zero now produce deliberate category-6 diagnostics, and
division rejects a result outside the 31-bit fixnum representation.

Each classified trap now also exports a seed-owned UTF-8 data span. Dynamic
unbound/called names, cap dimensions, and fixed diagnostic tokens are decoded
identically by the Node and browser hosts and exposed as `SeedLanguageError.data`.
The golden error observations review this field; raw traps prove category zero
and an empty span after entry reset. Compiler equivalence remains open.

The transactional observation harness first reused a trapped instance only for
low-level inspection; production hosts now retain only the categories proved
safe by these cases. Operator failure
commits the operator's earlier mutation and evaluates no argument. A failing
second argument preserves the first argument's effect and skips the third.
Primitive division failure occurs only after all argument expressions have run,
so their left-to-right mutations are retained. Failed `set!` and `define` keep
the old binding. Out-of-range `bytes.fill`, `bytes.copy`, and
`bytes.fill-stride` leave every destination byte unchanged. This satisfies the
M3 prior-effect-order and documented atomic-operation exit criteria.

Node and browser hosts retain sessions for transactionally proven category
codes 1–7 and 9. Resource exhaustion, host-contract errors, and raw Wasm faults
invalidate the wrapper; subsequent calls fail as `SeedSessionDiscardedError`.
The browser REPL preserves definitions only after a recoverable typed error.
The reviewed unbound golden observation now records `recoverable: true` at
corpus hash `d6a57946...`. This satisfies the host-distinction exit criterion.

Every primitive and alias now has an explicit fixed, ranged, or variadic arity
policy checked before dispatch. Exhaustive fixtures reject both sides of every
fixed arity, cover the two/three-argument string slice range, preserve the seven
variadic primitives, and prove recovery afterward. The first combined run
caught an incorrect fixed-arity assumption for variadic `string.append`; the
policy was corrected rather than changing the Lisp-written compiler. The final
focused set is 56/56 with no golden divergence.

Special forms and user calls now share the arity boundary. Fixed and optional
special-form shapes are checked before field access; proper parameter lists are
exact, bare symbols capture the full argument list, and dotted symbol tails
capture the remainder. Fixed closures/macros reject missing and extra values
before body entry, including malformed parameter identifiers. The focused set
is 59/59. The payload slice remains 59/59 with golden corpus hash
`d6a57946...`, and leaves explicit compiler error-intersection evidence as the
only open M3 exit.

## M4 — explicit core IR and semantic reference path

Goal: establish one inspectable representation shared by expansion,
interpretation, compilation, decompilation/debugging, and caching.

Exit criteria:

- IR syntax, validation, binding representation, effect order, tail positions,
  and source maps are specified;
- macros lower deterministically to IR and IR remains representable as YaLisp
  data;
- the reference interpreter executes IR;
- IR validation/property tests reject malformed graphs under explicit caps;
- source -> expansion -> IR -> reference execution matches direct interpretation
  across the golden corpus;
- serialization or decompilation round trips preserve all semantic fields.

## M5 — shared-state incremental compilation and hot switching

Goal: compile on the fly without forking language state or losing transparent
development behavior.

Exit criteria:

- compiled closures use the same environment cells and managed objects as the
  interpreter;
- mode switches occur at documented safe points inside a long-lived session;
- corpus workloads alternate interpreted and compiled calls and compare values,
  effects, errors, and state hashes after every switch;
- cache keys include expanded source/IR, module identity, binding generations,
  numeric profile, and relevant capabilities;
- mutation/redefinition triggers deterministic transitive invalidation;
- compilation failure and forced deoptimization roll back without repeated or
  lost effects;
- debugger/source inspection can recover the active source/IR and live values.

## M6 — automatic managed memory

Goal: make idiomatic high-level programs safe without `heap.release` or manual
ownership while retaining explicit low-level arenas and pins.

Exit criteria:

- root maps cover globals, interpreter frames, compiled frames, compiler/cache
  state, assets, stable host handles, and in-flight FFI;
- adversarial graph tests prove live preservation and unreachable reclamation;
- ordinary golden and application workloads run without manual release;
- allocation bytes/counts, live and retained objects, fragmentation, collector
  throughput, and pause p50/p95/p99/max are reported;
- bounded-load soak tests show no statistically significant retained-heap or RSS
  slope after warmup;
- low-level arenas/pins are explicit, cannot invalidate managed references, and
  have negative tests;
- no semantic or interpreter/compiler divergence is introduced.

## M7 — compiler coverage and performance

Goal: expand compilation only behind semantic parity, then optimize measured
real costs.

Exit criteria:

- functions, branches, lexical access, mutation, tail calls, core data, errors,
  and calls cross the compiler boundary under the golden corpus;
- cold parse/expand/compile and code-cache costs are reported separately;
- representative primitives/programs report throughput and p50/p95/p99 latency;
- generated bytes and static/dynamic instruction counts are attributed by
  workload;
- real libraries/apps accompany microbenchmarks;
- improvements exceed the noise/variance gate without weakened checks, and any
  memory, cold-start, or code-size regression is explicit.

## M8 — modules, packages, and capability FFI

Goal: scale YaLisp programs without ambient host authority or load-order mystery.

Exit criteria:

- deterministic module identity, dependency resolution, initialization, cycles,
  imports/exports, reload, and version behavior are specified and tested;
- ABI fixtures cover widths, signedness, endianness, layout, ownership, pins,
  stable handles, callbacks, reentrancy, and errors;
- capabilities deny undeclared clock, entropy, filesystem, network, DOM, and
  native access;
- at least two WebAssembly engines and supported OS/architecture targets pass
  the same conformance bundle and deterministic build check.

## M9 — bootstrap reduction and self-hosting

Goal: move policy upward until the audited assembly seed approaches a minimal
pure apply/eval substrate.

Exit criteria for every reduction step:

- the replacement is written in inspectable YaLisp and independently tested;
- old/new stages pass the full observation corpus with no divergence;
- dependency graph, trust boundary, seed bytes/hash, static instruction count,
  representative dynamic counts, cold start, and memory are updated;
- removed seed behavior is not relocated into opaque host code;
- reproducible clean builds produce the same binary hash.

Terminal criteria: the documented assembly seed and pure apply/eval loop are
small enough for line-by-line audit, while evaluator, compiler, runtime policy,
modules, FFI adapters, standard library, and high-level libraries form explicit
self-hosted layers above it.
