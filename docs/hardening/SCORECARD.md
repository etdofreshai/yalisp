# YaLisp living hardening scorecard

Updated: 2026-09-02 M3 complete; active M4 deterministic core-IR lowering. Scale: 0
absent, 1 prototype, 2 bounded and partly evidenced, 3 broadly conformant, 4 production-hardened, 5 independently
reproduced across supported targets. Scores are independent; speed cannot raise
a correctness score and a small binary cannot raise bootstrap purity if work is
hidden in the host.

| Axis | Score | Current evidence | Next exit gate |
| --- | ---: | --- | --- |
| Semantic correctness | 2 | M0 is 301/301; M1/M2 cover reviewed stage observations, generated code-as-data, expansion, malformed input, and exact caps; M3 adds structured data for ten error categories, effect/atomicity boundaries, recoverability, and complete arity policy | M4 explicit core IR and reference execution |
| Interpreter/compiler parity | 2 | Three compiler-subset golden cases match; an 11-case profile covers all ten error categories and proves the current joint error intersection is explicitly empty | General IR/compiler and shared-state corpus expansion |
| Bootstrap purity | 2 | Checked-in WAT seed and YaLisp bootstrap with provenance and reproducible binary | Separate core IR/evaluator policy, then reduce audited seed with ledger |
| Performance | 1 | Cold precompiled setup diagnostic and single-shot feasibility measurements exist | Quiet-host warmups, raw samples, p50/p95/p99, variance/confidence gates |
| Memory / GC | 0 | Bump allocation and explicit arenas; exact 240 MiB replay plus live circuit/render gates and a 20,808-byte two-plane cache ownership gate are measured, but no collector exists | Automatic managed memory, root-map proofs, pause/throughput/leak/soak evidence |
| Code size / instructions | 2 | Current seed is 12,244 bytes with 5,132 static instruction lines; layer bytes/hashes and one 43-byte AOT artifact are recorded | Automated per-stage size/static count and representative dynamic counts |
| Portability | 1 | WebAssembly/Node/browser path on x86_64 Linux; no matrix | Two engines plus declared OS/architecture targets and deterministic builds |
| Developer ergonomics | 1 | Persistent REPL and macros; ten typed categories with structured data, session recovery for proven transactional codes, and enforced discard for unsafe failures; no modules/debug tier switching | Modules, live source/IR inspection, and safe hot switching |
| Documentation | 2 | Extensive web docs and seed boundary notes; initial hierarchical hardening specs | Normative reference linked to conformance cases and cost tables per layer |
| Library completeness | 1 | Small boot list/control library and several real Lisp applications | Versioned standard-library surface, module packaging, broader high-level suites |

## Required metric ledger

| Metric family | Current status | Controlling evidence |
| --- | --- | --- |
| Values/effects/errors/output/state hash by stage | Implemented for 15-case/17-event corpus and 30 applicable stage observations; compiler error profile adds 11 boundary cases with expected/observed joint-error count 0/0 | Expand with each milestone |
| Earliest divergence | Implemented to case/event/channel/byte; deliberate perturbation localized | Preserve and extend |
| Reader/printer round trip | `yalisp-acyclic-data-v1`: 256 values at depth 4, seed `0x59414c49`; `yalisp-source-forms-v1`: 512 forms at depth 5, seed `0x53524346`, all syntax categories covered, minimal failure `null`; 23 fixed edges | Preserve and extend |
| Macro expansion determinism | Independent named outer expansion; 8 authored cases hash `34214d55...` across 4 fresh and 16 warmed corpus runs; produced user mutation is not evaluated; step 1,025 fails explicitly; 4 quasiquote groups cover nesting, context, list shape, and arity | Preserve and extend |
| IR/decompile invariants | Core IR v1 has canonical YaLisp-data syntax, source maps, lexical IDs, tail/effect rules, deterministic earliest-error validation, exact graph/resource caps, and a 256-graph profile; bounded single-form source lowering covers every opcode and named global boot-macro expansion with pinned hashes; no executor or decompiler yet | Complete M4 reference execution, golden parity, and semantic round trips |
| Property/fuzz and malformed caps | 256 generated values, 512 generated general source forms, 256 generated core-source forms, 18 fixed malformed-reader fixtures across the seed and lowerer, 4 quasiquote groups, binary shrink 511/512, and exact host/reader/lowering/expansion boundaries | Extend through M4 reference execution |
| Cold start / parse / expand / eval / compile | Partial cold setup; phases not fully separated | M1/M7 |
| Throughput and latency percentiles | Absent | M7 |
| Generated code bytes / instructions | One 43-byte AOT artifact; seed static count | M0/M7 |
| RSS / heap / allocations / live / retained / fragmentation | Fixed pages plus clean used/peak/headroom for replay, circuit/render retention, and 4,639,928 -> 20,808 byte map-cache ownership evidence; no object census or fragmentation metric | M0, then M6 |
| GC throughput / pause distribution / leak slope / soak | No collector | M6 |
| High-level no-manual-memory acceptance | Fails by design today | M6 |
| Hot switching / invalidation / debug / rollback | Absent | M5 |
| Seed size / graph / hash / auditability | Initial map complete | M0, then every M9 step |
| ABI/FFI | Minimal two-import Wasm boundary only | M8 |
| Deterministic builds | Seed byte identity tested on current toolchain | M8 cross-target expansion |
| Real application workloads | Hello/Pong/Breakout/Asteroids/Wolf3D tests | Preserve and integrate into M1/M7/M6 |

## Current first gap

M1 remains green. Corpus `9740b03f...` records 15 cases, 17 events, 30
applicable stage observations, 15 explicit not-applicable stages, and no
expected or cross-stage divergence. M2's reader/printer property is green at
seed `0x59414c49`, named outer macro expansion has pinned fresh/warmed hashes,
and input/depth/work/expansion caps have exact passing/failing witnesses. Twelve
malformed reader cases now cover dotted, closing, string/list, and missing-prefix
boundaries. Four quasiquote groups cover matching-depth unquote/splicing, valid
order, invalid context/list shape, and exact arity. The 512-case source generator
covers every declared syntax category with no canonical idempotence failure. M2
is complete. M3 distinguishes ten typed language-error categories from raw Wasm
faults, resets metadata at every host entry, and removes diagnostic-string
category inference from the golden runner. Zero divisors and division overflow
are deliberate arithmetic errors. Post-trap inspection proves operator/argument
effect order, binding commit timing, and fail-before-write behavior for fill,
copy, and strided fill. Proven language failures retain the session; resource,
host-contract, and raw faults enforce discard. Every primitive/alias now has an
exhaustive fixed, ranged, or variadic arity contract; special forms and fixed,
bare-rest, and dotted-rest user calls are also explicit. Classified failures
now carry a seed-owned UTF-8 data span, which both hosts and the reviewed golden
errors expose; raw faults reset to an empty span. The earliest gap is an
executable reference path for the explicit core IR. The syntax and validator
exist with a pinned 1,252-byte canonical example and exact malformed/cap
witnesses. The bounded source lowerer now maps all eight opcodes, assigns
lexical IDs, retains UTF-8 spans and ordered macro provenance, and pins both
nested boot-macro and 256-form generated hashes. Dynamic/lexical macros and
current-frame local definition remain honest unsupported boundaries; a
reference executor is the next smallest gap. M3 is complete at 69/69: checked literal and
arithmetic construction closes the overflow found by its 11-case compiler profile,
which covers all ten categories, records eight codegen rejections and two precompile
boundaries, exposes one out-of-range value divergence, and proves expected and
observed jointly supported language errors are both zero. The source-level
`bit.mul-shr` escape hatch keeps a required wrapped-i32 algorithm explicit.
