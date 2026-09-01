# YaLisp living hardening scorecard

Updated: 2026-09-01 M1 complete, active M2 reader/printer and macro slices green. Scale: 0
absent, 1 prototype, 2 bounded and partly evidenced, 3 broadly conformant, 4 production-hardened, 5 independently
reproduced across supported targets. Scores are independent; speed cannot raise
a correctness score and a small binary cannot raise bootstrap purity if work is
hidden in the host.

| Axis | Score | Current evidence | Next exit gate |
| --- | ---: | --- | --- |
| Semantic correctness | 2 | M0 is 301/301; M1 adds 15 reviewed cases/17 events with no divergence; M2 adds 256 seeded data round trips, 23 fixed reader/printer cases, two malformed diagnostics, and pinned macro expansion across fresh/warmed sessions | Shrink evidence, nested quasiquote/splice cases, and bounded malformed/depth/work properties |
| Interpreter/compiler parity | 2 | One corpus drives seed/bootstrap plus three compiler-subset cases; all match and unsupported stages are explicit | General IR/compiler and shared-state corpus expansion |
| Bootstrap purity | 2 | Checked-in WAT seed and YaLisp bootstrap with provenance and reproducible binary | Separate core IR/evaluator policy, then reduce audited seed with ledger |
| Performance | 1 | Cold precompiled setup diagnostic and single-shot feasibility measurements exist | Quiet-host warmups, raw samples, p50/p95/p99, variance/confidence gates |
| Memory / GC | 0 | Bump allocation and explicit arenas; exact 240 MiB replay plus live circuit/render gates and a 20,808-byte two-plane cache ownership gate are measured, but no collector exists | Automatic managed memory, root-map proofs, pause/throughput/leak/soak evidence |
| Code size / instructions | 2 | Current seed is 10,093 bytes with 4,136 static instruction lines; layer bytes/hashes and one 43-byte AOT artifact are recorded | Automated per-stage size/static count and representative dynamic counts |
| Portability | 1 | WebAssembly/Node/browser path on x86_64 Linux; no matrix | Two engines plus declared OS/architecture targets and deterministic builds |
| Developer ergonomics | 1 | Persistent REPL and macros; errors trap, no modules/debug tier switching | Structured errors, modules, live source/IR inspection, safe hot switching |
| Documentation | 2 | Extensive web docs and seed boundary notes; initial hierarchical hardening specs | Normative reference linked to conformance cases and cost tables per layer |
| Library completeness | 1 | Small boot list/control library and several real Lisp applications | Versioned standard-library surface, module packaging, broader high-level suites |

## Required metric ledger

| Metric family | Current status | Controlling evidence |
| --- | --- | --- |
| Values/effects/errors/output/state hash by stage | Implemented for 15-case/17-event M1 corpus and 30 applicable stage observations | Expand with each milestone |
| Earliest divergence | Implemented to case/event/channel/byte; deliberate perturbation localized | Preserve and extend |
| Reader/printer round trip | `yalisp-acyclic-data-v1`: 256 cases at depth 4 with seed `0x59414c49`; 23 fixed string/grammar edges; canonical transport green | M2 broader source generation and shrinking |
| Macro expansion determinism | Independent named outer expansion; 8 authored cases hash `34214d55...` across 4 fresh and 16 warmed corpus runs; produced user mutation is not evaluated | M2 nested quasiquote/splice and explicit expansion caps |
| IR/decompile invariants | No IR | M4 |
| Property/fuzz and malformed caps | Seeded acyclic-data property and two stable malformed diagnostics; no persisted shrink or general reader depth/work corpus yet | M2 |
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

M1 remains green. Corpus `e50cfe93...` records 15 cases, 17 events, 30
applicable stage observations, 15 explicit not-applicable stages, and no
expected or cross-stage divergence. M2's reader/printer property is green at
seed `0x59414c49`, and named outer macro expansion now has pinned fresh/warmed
hashes. The earliest remaining gap is persisted shrinking plus broader malformed
reader and expansion depth/work caps; nested quasiquote/splice fixtures are the
next semantic edge. M2 is active.
