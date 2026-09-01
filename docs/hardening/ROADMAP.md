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

## M2 — reader/printer, expansion, and malformed-input properties (active)

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
Unicode, comments, proper/dotted lists, numeric bounds, and symbols; two
malformed cases have stable diagnostics. The deterministic first failures were
carriage return and generated case 1 containing byte `0x04`; the seed reader now
decodes the canonical printer's complete control-escape profile. This is a
partial M2 slice, not milestone completion: independent macro-expansion hashes,
persisted shrinking, broader source generation, and explicit reader depth/work
caps remain.

## M3 — structured errors and transactional failure boundaries

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
